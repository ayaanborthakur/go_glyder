import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:go_glyder/core/theme.dart';
import 'places_service.dart';
import 'directions_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

Future<Position> _determinePosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Location services are disabled.');
  }

  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return Future.error(
      'Location permissions are permanently denied, we cannot request permissions.',
    );
  }

  return await Geolocator.getCurrentPosition();
}

// Which field the search-suggestions dropdown is currently feeding.
enum _ActiveField { origin, destination }

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _startPinIcon;

  final PlacesService _placesService = PlacesService();
  final DirectionsService _directionsService = DirectionsService();

  final TextEditingController _originController = TextEditingController(
    text: 'Current Location',
  );
  final TextEditingController _destinationController = TextEditingController();
  final FocusNode _originFocus = FocusNode();
  final FocusNode _destinationFocus = FocusNode();

  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];
  _ActiveField _activeField = _ActiveField.destination;
  bool _isSearching = false;
  bool _isRoutingLoading = false;

  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(
      37.42796133580664,
      -122.085749655962,
    ), // Fallback only, used until GPS resolves
    zoom: 14.0,
  );

  // Set once GPS resolves. Used to jump the camera there as soon as the map
  // (and/or the location fetch) is ready, whichever finishes last.
  LatLng? _resolvedCurrentPosition;

  // null origin means "use current GPS location at route time."
  LatLng? _originLatLng;
  LatLng? _destinationLatLng;
  String _destinationLabel = '';

  DirectionsResult? _route;

  @override
  void initState() {
    super.initState();
    _initCustomMarker();
    _originFocus.addListener(() {
      setState(() {
        if (_originFocus.hasFocus) {
          _activeField = _ActiveField.origin;
          _suggestions = [
            PlaceSuggestion(
              placeId: 'current_location',
              description: 'Use Current Location',
            ),
          ];
        }
      });
    });
    _destinationFocus.addListener(() {
      setState(() {
        if (_destinationFocus.hasFocus) {
          _activeField = _ActiveField.destination;
          _suggestions = [];
        }
      });
    });
    _goToCurrentLocation(animate: false, silent: true);
  }

  Future<void> _initCustomMarker() async {
    try {
      final icon = await _createStartPinIcon();
      if (mounted) {
        setState(() {
          _startPinIcon = icon;
        });
      }
    } catch (e) {
      developer.log('Error creating custom start pin icon: $e');
    }
  }

  Future<BitmapDescriptor> _createStartPinIcon() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const double size = 36.0;

    final Paint fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final Paint borderPaint = Paint()
      ..color = AppColors.brandGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    final Paint dotPaint = Paint()
      ..color = AppColors.brandGreen
      ..style = PaintingStyle.fill;

    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 2, fillPaint);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 2, borderPaint);
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 6, dotPaint);

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _originController.dispose();
    _destinationController.dispose();
    _originFocus.dispose();
    _destinationFocus.dispose();
    super.dispose();
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};
    if (_originLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: _originLatLng!,
          icon: _startPinIcon ?? BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(title: _originController.text),
        ),
      );
    }
    if (_destinationLatLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLatLng!,
          infoWindow: InfoWindow(title: _destinationLabel),
        ),
      );
    }
    return markers;
  }

  Set<Polyline> get _polylines {
    if (_route == null) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: _route!.points,
        color: AppColors.brandDark,
        width: 5,
      ),
    };
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (query.trim().isEmpty) {
        setState(() => _suggestions = [
          if (_activeField == _ActiveField.origin)
            PlaceSuggestion(
              placeId: 'current_location',
              description: 'Use Current Location',
            ),
        ]);
        return;
      }
      setState(() => _isSearching = true);
      final results = await _placesService.searchPlaces(
        query,
        bias: _destinationLatLng ?? _originLatLng,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = [
          if (_activeField == _ActiveField.origin)
            PlaceSuggestion(
              placeId: 'current_location',
              description: 'Use Current Location',
            ),
          ...results,
        ];
        _isSearching = false;
      });
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    if (suggestion.placeId == 'current_location') {
      _useCurrentLocationAsOrigin();
      return;
    }

    final latLng = await _placesService.getPlaceLatLng(suggestion.placeId);
    if (!mounted) return;
    if (latLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not locate "${suggestion.description}"')),
      );
      return;
    }

    setState(() {
      if (_activeField == _ActiveField.origin) {
        _originController.text = suggestion.description;
        _originLatLng = latLng;
      } else {
        _destinationController.text = suggestion.description;
        _destinationLabel = suggestion.description;
        _destinationLatLng = latLng;
      }
      _route = null;
      _suggestions = [];
    });

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(CameraPosition(target: latLng, zoom: 15)),
    );
    FocusScope.of(context).unfocus();

    // Auto-route once both ends are known.
    if (_originLatLng != null || _originController.text == 'Current Location') {
      if (_destinationLatLng != null) {
        _getDirections();
      }
    }
  }

  void _useCurrentLocationAsOrigin() {
    setState(() {
      _originController.text = 'Current Location';
      _originLatLng = null;
      _suggestions = [];
      _route = null;
    });
    FocusScope.of(context).unfocus();
    _goToCurrentLocation();
  }

  void _swapOriginAndDestination() {
    setState(() {
      final tempText = _originController.text;
      final tempLatLng = _originLatLng;

      _originController.text = _destinationController.text.isEmpty
          ? 'Current Location'
          : _destinationController.text;
      _originLatLng = _destinationLatLng ?? 
          (_originController.text == 'Current Location' ? _resolvedCurrentPosition : null);

      _destinationController.text = tempText == 'Current Location'
          ? ''
          : tempText;
      _destinationLabel = _destinationController.text;
      _destinationLatLng = tempLatLng ?? 
          (tempText == 'Current Location' ? _resolvedCurrentPosition : null);

      _route = null;
    });
    if (_destinationLatLng != null) _getDirections();
  }

  Future<void> _goToCurrentLocation({
    bool animate = true,
    bool silent = false,
  }) async {
    try {
      Position position = await _determinePosition();
      final target = LatLng(position.latitude, position.longitude);
      _resolvedCurrentPosition = target;

      if (_originController.text == 'Current Location') {
        setState(() {
          _originLatLng = target;
        });
      }

      if (_mapController != null) {
        // Map already exists -- move it now.
        if (animate) {
          _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: target, zoom: 16.0),
            ),
          );
        } else {
          _mapController!.moveCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: target, zoom: 16.0),
            ),
          );
        }
      }
      // If _mapController is still null (this ran before onMapCreated
      // fired), onMapCreated below will apply _resolvedCurrentPosition
      // itself once it's available.
    } catch (e, stackTrace) {
      developer.log(
        'Failed to get current location',
        name: 'GoGlyder.Map',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted || silent) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Couldn\'t get your location: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _getDirections() async {
    if (_destinationLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Search for a destination first.')),
      );
      return;
    }

    setState(() => _isRoutingLoading = true);
    try {
      LatLng origin;
      if (_originLatLng != null) {
        origin = _originLatLng!;
      } else {
        final position = await _determinePosition();
        origin = LatLng(position.latitude, position.longitude);
        setState(() {
          _originLatLng = origin;
        });
      }

      final result = await _directionsService.getRoute(
        origin: origin,
        destination: _destinationLatLng!,
      );

      if (!mounted) return;

      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not calculate a route.')),
        );
        return;
      }

      setState(() => _route = result);

      final bounds = _boundsFor([
        origin,
        _destinationLatLng!,
        ...result.points,
      ]);
      _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Couldn\'t get directions: $e')));
    } finally {
      if (mounted) setState(() => _isRoutingLoading = false);
    }
  }

  LatLngBounds _boundsFor(List<LatLng> points) {
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final p in points) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLng = p.longitude < minLng ? p.longitude : minLng;
      maxLng = p.longitude > maxLng ? p.longitude : maxLng;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _kInitialPosition,
            mapType: MapType.normal,
            markers: _markers,
            polylines: _polylines,
            myLocationButtonEnabled: false,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            padding: const EdgeInsets.only(bottom: 160),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              // GPS may have already resolved before the map finished
              // loading -- if so, jump straight there now.
              if (_resolvedCurrentPosition != null) {
                controller.moveCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: _resolvedCurrentPosition!,
                      zoom: 16.0,
                    ),
                  ),
                );
              }
            },
            onTap: (_) {
              FocusScope.of(context).unfocus();
              setState(() => _suggestions = []);
            },
          ),
          SafeArea(
            child: Column(
              children: [
                _buildSearchCard(),
                if (_suggestions.isNotEmpty) _buildSuggestionsList(),
              ],
            ),
          ),
          Positioned(
            right: 16,
            bottom: 210,
            child: Column(
              children: [
                _buildMapButton(
                  icon: Icons.my_location_rounded,
                  onPressed: () => _goToCurrentLocation(),
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  icon: Icons.add_rounded,
                  onPressed: () =>
                      _mapController?.animateCamera(CameraUpdate.zoomIn()),
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  icon: Icons.remove_rounded,
                  onPressed: () =>
                      _mapController?.animateCamera(CameraUpdate.zoomOut()),
                ),
              ],
            ),
          ),
          Align(alignment: Alignment.bottomCenter, child: _buildBottomPanel()),
        ],
      ),
    );
  }

  Widget _buildSearchCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: kCardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.brandGreen, width: 2.2),
                    color: AppColors.surface,
                  ),
                  child: Center(
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.brandGreen,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Column(
                  children: List.generate(
                    4,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(vertical: 1.5),
                      width: 2,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                const Icon(Icons.place_rounded, color: AppColors.danger, size: 20),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _originFocus.hasFocus
                        ? AppColors.brandTint.withValues(alpha: 0.45)
                        : Colors.transparent,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _originController,
                          focusNode: _originFocus,
                          onChanged: _onSearchChanged,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Current Location',
                            hintStyle: TextStyle(
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.normal,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      if (_originController.text.isNotEmpty &&
                          _originController.text != 'Current Location')
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppColors.textTertiary,
                          ),
                          onPressed: () {
                            setState(() {
                              _originController.clear();
                              _originLatLng = null;
                              _route = null;
                            });
                            _originFocus.requestFocus();
                            _onSearchChanged('');
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (_originController.text != 'Current Location') ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.my_location_rounded,
                            size: 16,
                            color: AppColors.brandGreen,
                          ),
                          onPressed: _useCurrentLocationAsOrigin,
                          tooltip: 'Use current location',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Container(height: 1, color: AppColors.divider),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: _destinationFocus.hasFocus
                        ? AppColors.brandTint.withValues(alpha: 0.45)
                        : Colors.transparent,
                    borderRadius: AppRadius.smAll,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _destinationController,
                          focusNode: _destinationFocus,
                          onChanged: _onSearchChanged,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Search destination...',
                            hintStyle: TextStyle(
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.normal,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      if (_destinationController.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppColors.textTertiary,
                          ),
                          onPressed: () {
                            setState(() {
                              _destinationController.clear();
                              _destinationLatLng = null;
                              _destinationLabel = '';
                              _route = null;
                            });
                            _destinationFocus.requestFocus();
                            _onSearchChanged('');
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12, left: 8),
            decoration: BoxDecoration(
              color: AppColors.brandTint,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.swap_vert_rounded, color: AppColors.brandGreen, size: 20),
              onPressed: _swapOriginAndDestination,
              tooltip: 'Swap locations',
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.lgAll,
        boxShadow: kCardShadow,
      ),
      child: _isSearching
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.brandGreen,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (_, index) =>
                  const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                
                // Split description by the first comma to separate title from address
                final parts = suggestion.description.split(',');
                final mainText = parts.isNotEmpty ? parts[0].trim() : '';
                final secondaryText = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppColors.brandTint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      suggestion.placeId == 'current_location'
                          ? Icons.my_location_rounded
                          : Icons.location_on_rounded,
                      color: AppColors.brandGreen,
                      size: 18,
                    ),
                  ),
                  title: Text(
                    mainText,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: secondaryText.isNotEmpty
                      ? Text(
                          secondaryText,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : null,
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
    ).animate().fadeIn(duration: 200.ms).slideY(
          begin: -0.04,
          end: 0,
          curve: Curves.easeOutQuad,
        );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        boxShadow: kCardShadow,
      ),
      child: Center(
        child: IconButton(
          icon: Icon(icon, color: AppColors.brandGreen, size: 20),
          onPressed: onPressed,
          padding: EdgeInsets.zero,
        ),
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _originController.text = 'Current Location';
      _originLatLng = null;
      _destinationController.clear();
      _destinationLatLng = null;
      _destinationLabel = '';
      _route = null;
      _suggestions = [];
    });
    FocusScope.of(context).unfocus();
    _goToCurrentLocation(animate: true);
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: AppColors.brandTint,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.directions_car_filled_rounded,
            color: AppColors.brandGreen,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Where are you heading today?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Search for a school, home, or group event above to calculate routes and coordinate carpools.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSelectedState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.brandTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: AppColors.brandGreen,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DESTINATION SELECTED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _destinationLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildActionButtons(hasRoute: false),
      ],
    );
  }

  Widget _buildRouteState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              _route!.durationText,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.brandGreen,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${_route!.distanceText})',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(
              Icons.directions_car_rounded,
              color: AppColors.textSecondary,
              size: 16,
            ),
            const SizedBox(width: 6),
            const Expanded(
              child: Text(
                'Optimal driving route calculated',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              const Icon(Icons.swap_calls_rounded, color: AppColors.brandGreen, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${_originController.text == "Current Location" ? "My Location" : _originController.text.split(',')[0]} to ${_destinationLabel.split(',')[0]}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildActionButtons(hasRoute: true),
      ],
    );
  }

  Widget _buildActionButtons({required bool hasRoute}) {
    return Row(
      children: [
        if (hasRoute) ...[
          Expanded(
            flex: 2,
            child: OutlinedButton.icon(
              onPressed: _clearAll,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reset'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.divider),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.smAll,
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 3,
          child: ElevatedButton.icon(
            onPressed: (_isRoutingLoading)
                ? null
                : _getDirections,
            icon: _isRoutingLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.directions_rounded),
            label: Text(
              _isRoutingLoading ? 'Routing...' : (hasRoute ? 'Re-Route' : 'Get Directions'),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brandDark,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.divider,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.smAll,
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            color: AppColors.brandTint,
            borderRadius: AppRadius.smAll,
          ),
          child: IconButton(
            icon: const Icon(Icons.share_rounded, color: AppColors.brandGreen, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Share location coming soon!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomPanel() {
    final hasDestination = _destinationLatLng != null;
    final hasRoute = _route != null;

    Widget content;
    if (!hasDestination) {
      content = _buildEmptyState();
    } else if (!hasRoute) {
      content = _buildSelectedState();
    } else {
      content = _buildRouteState();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(AppRadius.xl),
          topRight: Radius.circular(AppRadius.xl),
        ),
        boxShadow: kCardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          content.animate(key: ValueKey('${hasDestination}_$hasRoute')).fadeIn(duration: 250.ms).slideY(
                begin: 0.05,
                end: 0,
                curve: Curves.easeOutCubic,
              ),
        ],
      ),
    );
  }
}
