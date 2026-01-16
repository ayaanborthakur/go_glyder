import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Define the initial camera position
  static const CameraPosition _kInitialPosition = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962), // Example: GooglePlex
    zoom: 14.0,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('GoGlyder Map'),
      ),
      // Use the GoogleMap widget
      body: GoogleMap(
        initialCameraPosition: _kInitialPosition,
        // You can customize the map type, add markers, polylines, etc.
        mapType: MapType.normal,
        onMapCreated: (GoogleMapController controller) {
          // You can use the controller to programmatically move the camera, etc.
        },
      ),
    );
  }
}
