// lib/services/directions_service.dart
//
// Wrapper around Routes API (computeRoutes), not the legacy Directions API.
// Requests are JSON POSTs with an X-Goog-Api-Key header and an explicit
// X-Goog-FieldMask (Routes API returns nothing unless you ask for it).
// Make sure "Routes API" is enabled for your key in Google Cloud Console.

import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import 'places_service.dart' show kMapsApiKey;

class DirectionsResult {
  final List<LatLng> points;
  final String distanceText;
  final String durationText;

  DirectionsResult({
    required this.points,
    required this.distanceText,
    required this.durationText,
  });
}

class DirectionsService {
  static const _url =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  Future<DirectionsResult?> getRoute({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final body = {
      'origin': {
        'location': {
          'latLng': {
            'latitude': origin.latitude,
            'longitude': origin.longitude,
          },
        },
      },
      'destination': {
        'location': {
          'latLng': {
            'latitude': destination.latitude,
            'longitude': destination.longitude,
          },
        },
      },
      'travelMode': 'DRIVE',
      'routingPreference': 'TRAFFIC_AWARE',
    };

    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': kMapsApiKey,
          // Routes API returns an empty body unless the fields you want
          // are explicitly requested here.
          'X-Goog-FieldMask':
              'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map<String, dynamic>;
      final encodedPolyline =
          (route['polyline'] as Map<String, dynamic>)['encodedPolyline']
              as String;
      final distanceMeters = route['distanceMeters'] as int;
      // duration comes back as a string like "917s"
      final durationSeconds = int.parse(
        (route['duration'] as String).replaceAll('s', ''),
      );

      return DirectionsResult(
        points: _decodePolyline(encodedPolyline),
        distanceText: _formatDistance(distanceMeters),
        durationText: _formatDuration(durationSeconds),
      );
    } catch (_) {
      return null;
    }
  }

  String _formatDistance(int meters) {
    final miles = meters / 1609.34;
    return '${miles.toStringAsFixed(miles < 10 ? 1 : 0)} mi';
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return remainingMinutes == 0
        ? '$hours hr'
        : '$hours hr $remainingMinutes min';
  }

  // Standard Google polyline decoding algorithm (same format used by both
  // the legacy Directions API and the new Routes API).
  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
}
