import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Pricing configuration for one ride type, stored in Firestore.
class RideTypePricing {
  const RideTypePricing({
    required this.baseFare,
    required this.perKmRate,
    required this.perMinuteRate,
  });

  final double baseFare;
  final double perKmRate;
  final double perMinuteRate;

  factory RideTypePricing.fromMap(
    Map<String, dynamic> data, {
    required RideTypePricing fallback,
  }) {
    final baseFare = data['baseFare'];
    final perKmRate = data['perKmRate'];
    final perMinuteRate = data['perMinuteRate'];
    if (baseFare is! num || perKmRate is! num) return fallback;
    return RideTypePricing(
      baseFare: baseFare.toDouble(),
      perKmRate: perKmRate.toDouble(),
      perMinuteRate: (perMinuteRate is num) ? perMinuteRate.toDouble() : fallback.perMinuteRate,
    );
  }
}

/// Full pricing config for all four ride types.
class RidePricingConfig {
  const RidePricingConfig({
    required this.regular,
    required this.comfort,
    required this.luxury,
    required this.courier,
  });

  final RideTypePricing regular;
  final RideTypePricing comfort;
  final RideTypePricing luxury;
  final RideTypePricing courier;

  /// Fallback defaults if Firestore is unreachable.
  static const RidePricingConfig defaults = RidePricingConfig(
    regular: RideTypePricing(baseFare: 800, perKmRate: 250, perMinuteRate: 50),
    comfort: RideTypePricing(baseFare: 1200, perKmRate: 350, perMinuteRate: 70),
    luxury: RideTypePricing(baseFare: 2500, perKmRate: 600, perMinuteRate: 120),
    courier: RideTypePricing(baseFare: 600, perKmRate: 200, perMinuteRate: 40),
  );

  factory RidePricingConfig.fromMap(Map<String, dynamic> data) {
    final fallback = RidePricingConfig.defaults;
    return RidePricingConfig(
      regular: RideTypePricing.fromMap(
        (data['regular'] as Map?)?.cast<String, dynamic>() ?? {},
        fallback: fallback.regular,
      ),
      comfort: RideTypePricing.fromMap(
        (data['comfort'] as Map?)?.cast<String, dynamic>() ?? {},
        fallback: fallback.comfort,
      ),
      luxury: RideTypePricing.fromMap(
        (data['luxury'] as Map?)?.cast<String, dynamic>() ?? {},
        fallback: fallback.luxury,
      ),
      courier: RideTypePricing.fromMap(
        (data['courier'] as Map?)?.cast<String, dynamic>() ?? {},
        fallback: fallback.courier,
      ),
    );
  }

  RideTypePricing forType(String rideType) {
    return switch (rideType.toLowerCase()) {
      'comfort' => comfort,
      'luxury' => luxury,
      'courier' => courier,
      _ => regular,
    };
  }
}

/// Distance + duration result from the Google Routes API.
class RouteInfo {
  const RouteInfo({
    required this.distanceKm,
    required this.durationMinutes,
  });

  final double distanceKm;
  final double durationMinutes;
}

class RidePricingRepository {
  RidePricingRepository({
    FirebaseFirestore? firestore,
    String? mapboxAccessToken, // kept for API compatibility
    String? googleMapsApiKey,
    http.Client? httpClient,
  })  : _firestore = firestore,
        _googleKey = googleMapsApiKey ?? mapboxAccessToken ?? '',
        _httpClient = httpClient ?? http.Client();

  final FirebaseFirestore? _firestore;
  final String _googleKey;
  final http.Client _httpClient;

  static const String _routesEndpoint =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  /// Watches the admin-editable pricing config from Firestore.
  Stream<RidePricingConfig> watchPricingConfig() {
    final firestore = _firestore ?? FirebaseFirestore.instance;
    return firestore
        .collection('config')
        .doc('ridePricing')
        .snapshots()
        .map((doc) {
      if (!doc.exists) return RidePricingConfig.defaults;
      return RidePricingConfig.fromMap(doc.data() ?? {});
    });
  }

  /// Calls the Google Routes API to get real-world distance and duration.
  Future<RouteInfo?> getRouteInfo({
    required double fromLng,
    required double fromLat,
    required double toLng,
    required double toLat,
  }) async {
    RouteInfo fallbackInfo() {
      // Haversine fallback distance
      const p = 0.017453292519943295;
      final a = 0.5 - math.cos((toLat - fromLat) * p)/2 + 
                math.cos(fromLat * p) * math.cos(toLat * p) * 
                (1 - math.cos((toLng - fromLng) * p))/2;
      final distanceKm = 12742 * math.asin(math.sqrt(a));
      return RouteInfo(
        distanceKm: distanceKm,
        durationMinutes: (distanceKm / 40) * 60, // 40 km/h avg speed
      );
    }

    if (_googleKey.isEmpty) return fallbackInfo();
    try {
      final response = await _httpClient
          .post(
            Uri.parse(_routesEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _googleKey,
              'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters',
            },
            body: jsonEncode({
              'origin': {
                'location': {
                  'latLng': {'latitude': fromLat, 'longitude': fromLng},
                },
              },
              'destination': {
                'location': {
                  'latLng': {'latitude': toLat, 'longitude': toLng},
                },
              },
              'travelMode': 'DRIVE',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return fallbackInfo();
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = json['routes'] as List?;
      if (routes == null || routes.isEmpty) return fallbackInfo();
      final route = routes.first as Map<String, dynamic>;
      final distanceM = (route['distanceMeters'] as num?)?.toDouble() ?? 0;
      final durationStr = route['duration'] as String? ?? '0s';
      // Duration is returned as "NNs" (e.g. "1234s")
      final durationS =
          double.tryParse(durationStr.replaceAll('s', '')) ?? 0.0;
      return RouteInfo(
        distanceKm: distanceM / 1000,
        durationMinutes: durationS / 60,
      );
    } catch (_) {
      return fallbackInfo();
    }
  }

  /// Calls the Google Routes API and returns the route as a list of [LatLng].
  Future<List<LatLng>?> getRouteLine({
    required double fromLng,
    required double fromLat,
    required double toLng,
    required double toLat,
  }) async {
    if (_googleKey.isEmpty) return null;
    try {
      final response = await _httpClient
          .post(
            Uri.parse(_routesEndpoint),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _googleKey,
              'X-Goog-FieldMask':
                  'routes.polyline.encodedPolyline',
            },
            body: jsonEncode({
              'origin': {
                'location': {
                  'latLng': {'latitude': fromLat, 'longitude': fromLng},
                },
              },
              'destination': {
                'location': {
                  'latLng': {'latitude': toLat, 'longitude': toLng},
                },
              },
              'travelMode': 'DRIVE',
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = json['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;
      final route = routes.first as Map<String, dynamic>;
      final polyline = route['polyline'] as Map<String, dynamic>?;
      final encoded = polyline?['encodedPolyline'] as String?;
      if (encoded == null || encoded.isEmpty) return null;

      return _decodePolyline(encoded);
    } on TimeoutException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Decodes a Google Maps encoded polyline string into [LatLng] list.
  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> result = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int res = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        res |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (res & 1) != 0 ? ~(res >> 1) : res >> 1;
      lat += dlat;

      shift = 0;
      res = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        res |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (res & 1) != 0 ? ~(res >> 1) : res >> 1;
      lng += dlng;

      result.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return result;
  }

  /// Computes the suggested price for a ride type given a route distance and duration.
  ({double min, double suggested, double max}) computePriceRange({
    required RideTypePricing pricing,
    required double distanceKm,
    required double durationMinutes,
  }) {
    final suggested = pricing.baseFare +
        (distanceKm * pricing.perKmRate) +
        (durationMinutes * pricing.perMinuteRate);
    return (
      min: (suggested * 0.80).roundToDouble(),
      suggested: suggested.roundToDouble(),
      max: (suggested * 1.30).roundToDouble(),
    );
  }
}
