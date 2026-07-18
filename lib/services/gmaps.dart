import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

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
    _originFocus.addListener(() {
      if (_originFocus.hasFocus) {
        setState(() {
          _activeField = _ActiveField.origin;
          _suggestions = [];
        });
      }
    });
    _destinationFocus.addListener(() {
      if (_destinationFocus.hasFocus) {
        setState(() {
          _activeField = _ActiveField.destination;
          _suggestions = [];
        });
      }
    });
    _goToCurrentLocation(animate: false, silent: true);
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
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
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
        setState(() => _suggestions = []);
        return;
      }
      setState(() => _isSearching = true);
      final results = await _placesService.searchPlaces(
        query,
        bias: _destinationLatLng ?? _originLatLng,
      );
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _isSearching = false;
      });
    });
  }

  Future<void> _selectSuggestion(PlaceSuggestion suggestion) async {
    final latLng = await _placesService.getPlaceLatLng(suggestion.placeId);
    if (latLng == null) {
      if (!mounted) return;
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
      _originLatLng = _destinationLatLng;

      _destinationController.text = tempText == 'Current Location'
          ? ''
          : tempText;
      _destinationLabel = _destinationController.text;
      _destinationLatLng = tempLatLng;

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
            bottom: 190,
            child: Column(
              children: [
                _buildMapButton(
                  icon: Icons.my_location,
                  onPressed: () => _goToCurrentLocation(),
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  icon: Icons.add,
                  onPressed: () =>
                      _mapController?.animateCamera(CameraUpdate.zoomIn()),
                ),
                const SizedBox(height: 8),
                _buildMapButton(
                  icon: Icons.remove,
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        boxShadow: kCardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Origin/destination dots + connecting line
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.brandDark, width: 2),
                  ),
                ),
                Container(width: 1.5, height: 34, color: AppColors.divider),
                Icon(Icons.place, color: AppColors.danger, size: 16),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _originController,
                        focusNode: _originFocus,
                        onChanged: _onSearchChanged,
                        style: const TextStyle(color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Current Location',
                          hintStyle: TextStyle(color: AppColors.textTertiary),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    if (_originController.text != 'Current Location')
                      IconButton(
                        icon: const Icon(
                          Icons.my_location,
                          size: 18,
                          color: AppColors.brandDark,
                        ),
                        onPressed: _useCurrentLocationAsOrigin,
                        tooltip: 'Use current location',
                      ),
                  ],
                ),
                const Divider(height: 1, color: AppColors.divider),
                TextField(
                  controller: _destinationController,
                  focusNode: _destinationFocus,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Search destination...',
                    hintStyle: TextStyle(color: AppColors.textTertiary),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.swap_vert, color: AppColors.textSecondary),
            onPressed: _swapOriginAndDestination,
            tooltip: 'Swap',
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.mdAll,
        boxShadow: kCardShadow,
      ),
      child: _isSearching
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : ListView.separated(
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.divider),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  leading: const Icon(
                    Icons.location_on,
                    color: AppColors.brandDark,
                  ),
                  title: Text(
                    suggestion.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  onTap: () => _selectSuggestion(suggestion),
                );
              },
            ),
    );
  }

  Widget _buildMapButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.smAll,
        boxShadow: kCardShadow,
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.brandDark),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildBottomPanel() {
    final hasDestination = _destinationLatLng != null;

    return Container(
      padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 16),
          if (_route != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.directions_car,
                    color: AppColors.brandDark,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_route!.distanceText} • ${_route!.durationText}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brandDark,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (_isRoutingLoading || !hasDestination)
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
                      : const Icon(Icons.directions),
                  label: Text(
                    _isRoutingLoading ? 'Routing...' : 'Get Directions',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandDark,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.divider,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.smAll,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.brandTint,
                  borderRadius: AppRadius.smAll,
                ),
                child: IconButton(
                  icon: const Icon(Icons.share, color: AppColors.brandDark),
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
          ),
        ],
      ),
    );
  }
}
