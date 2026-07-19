// lib/services/places_service.dart
//
// Wrapper around Places API (New) -- Autocomplete + Place Details.
// This targets the *new* Places API, not the legacy one, so requests use
// JSON POST bodies and the X-Goog-Api-Key / X-Goog-FieldMask headers rather
// than a `?key=` query param. Make sure "Places API (New)" is enabled for
// your key in Google Cloud Console (APIs & Services -> Library).

import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

// TODO: move this into a --dart-define / secrets file rather than a
// hardcoded constant once you're ready to lock this down further.
const String kMapsApiKey = 'AIzaSyAFcM1vkIjJ6XbDXIVy-w7ZO01hsvQIftA';

class PlaceSuggestion {
  final String placeId;
  final String description;

  PlaceSuggestion({required this.placeId, required this.description});
}

class PlacesService {
  static const _autocompleteUrl =
      'https://places.googleapis.com/v1/places:autocomplete';

  static Uri _detailsUrl(String placeId) =>
      Uri.parse('https://places.googleapis.com/v1/places/$placeId');

  /// Returns place suggestions matching [query]. Empty list on error or
  /// empty query.
  Future<List<PlaceSuggestion>> searchPlaces(
    String query, {
    LatLng? bias,
  }) async {
    if (query.trim().isEmpty) return [];

    final body = {
      'input': query,
      if (bias != null)
        'locationBias': {
          'circle': {
            'center': {'latitude': bias.latitude, 'longitude': bias.longitude},
            'radius': 50000.0,
          },
        },
    };

    try {
      final response = await http.post(
        Uri.parse(_autocompleteUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': kMapsApiKey,
        },
        body: jsonEncode(body),
      );

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final suggestions = data['suggestions'] as List<dynamic>?;
      if (suggestions == null) return [];

      return suggestions
          .map((s) => s['placePrediction'] as Map<String, dynamic>?)
          .whereType<Map<String, dynamic>>()
          .map(
            (p) => PlaceSuggestion(
              placeId: p['placeId'] as String,
              description:
                  (p['text'] as Map<String, dynamic>)['text'] as String,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Best-effort geocode of a free-text address (e.g. a calendar event's
  /// location) to a lat/lng. Reuses the autocomplete + details flow so it
  /// needs only "Places API (New)" — already enabled — rather than a
  /// separate Geocoding API. Returns null if nothing matches.
  Future<LatLng?> geocodeAddress(String address) async {
    if (address.trim().isEmpty) return null;
    final matches = await searchPlaces(address);
    if (matches.isEmpty) return null;
    return getPlaceLatLng(matches.first.placeId);
  }

  /// Resolves a place ID (from [searchPlaces]) to a lat/lng.
  Future<LatLng?> getPlaceLatLng(String placeId) async {
    try {
      final response = await http.get(
        _detailsUrl(placeId),
        headers: {
          'X-Goog-Api-Key': kMapsApiKey,
          'X-Goog-FieldMask': 'location',
        },
      );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final location = data['location'] as Map<String, dynamic>?;
      if (location == null) return null;

      return LatLng(
        (location['latitude'] as num).toDouble(),
        (location['longitude'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}
