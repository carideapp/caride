import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// A place result returned from the Google Places API (New).
///
/// Named [MapboxPlace] intentionally so existing callers across the codebase
/// don't need to be renamed — same interface, different backend.
class MapboxPlace {
  final String id;
  final String placeName;
  final double centerLng;
  final double centerLat;

  MapboxPlace({
    required this.id,
    required this.placeName,
    required this.centerLng,
    required this.centerLat,
  });
}

/// Address autocomplete / geocoding via the **Google Places API (New)**.
///
/// Replaces the old MapboxSearchService with the same method signature so
/// all callers remain unchanged.
class MapboxSearchService {
  final String accessToken; // kept for API compatibility — holds the Google key
  final http.Client _httpClient;

  MapboxSearchService(this.accessToken, {http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  static const String _placesEndpoint =
      'https://places.googleapis.com/v1/places:searchText';

  Future<List<MapboxPlace>> searchPlaces(
    String query, {
    double? proximityLat,
    double? proximityLng,
  }) async {
    if (accessToken.isEmpty || query.trim().isEmpty) return [];

    final body = <String, dynamic>{
      'textQuery': query,
      'languageCode': 'en',
      'maxResultCount': 7,
    };

    // Bias results toward the user's current location (e.g. Nigeria).
    if (proximityLat != null && proximityLng != null) {
      body['locationBias'] = {
        'circle': {
          'center': {
            'latitude': proximityLat,
            'longitude': proximityLng,
          },
          'radius': 50000.0, // 50 km radius bias
        },
      };
    }

    try {
      final response = await _httpClient
          .post(
            Uri.parse(_placesEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': accessToken,
              'X-Goog-FieldMask':
                  'places.id,places.displayName,places.formattedAddress,places.location',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        debugPrint('MapboxSearchService: Google Places API error: status=${response.statusCode}, body=${response.body}');
        return [];
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final places = data['places'] as List<dynamic>? ?? [];

      return places.map((p) {
        final m = p as Map<String, dynamic>;
        final loc = m['location'] as Map<String, dynamic>? ?? {};
        final displayName = m['displayName'] as Map<String, dynamic>? ?? {};
        final name = displayName['text'] as String? ?? '';
        final address = m['formattedAddress'] as String? ?? name;
        final label = name.isNotEmpty
            ? (address.isNotEmpty ? '$name, $address' : name)
            : address;
        return MapboxPlace(
          id: m['id'] as String? ?? '',
          placeName: label,
          centerLng: (loc['longitude'] as num?)?.toDouble() ?? 0.0,
          centerLat: (loc['latitude'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
    } on TimeoutException catch (e) {
      debugPrint('MapboxSearchService: Timeout searching places: $e');
      return [];
    }
  }

  Future<String?> reverseGeocode(double lat, double lng) async {
    if (accessToken.isEmpty) return null;
    final url = 'https://maps.googleapis.com/maps/api/geocode/json?latlng=$lat,$lng&key=$accessToken';
    try {
      final response = await _httpClient.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) {
        debugPrint('MapboxSearchService: reverseGeocode error status: ${response.statusCode}');
        return null;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final results = data['results'] as List<dynamic>? ?? [];
      if (results.isNotEmpty) {
        return results[0]['formatted_address'] as String?;
      }
    } catch (e) {
      debugPrint('MapboxSearchService: reverseGeocode error: $e');
    }
    return null;
  }
}
