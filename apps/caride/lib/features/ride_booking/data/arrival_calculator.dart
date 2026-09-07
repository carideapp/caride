import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:caride/features/ride_booking/data/ride_pricing_repository.dart';
import 'package:caride/core/config/app_env.dart';

class ArrivalCalculator {
  static final _pricingRepo = RidePricingRepository(googleMapsApiKey: AppEnv.googleMapsApiKey);

  DateTime? _lastApiCallTime;
  double? _lastLat;
  double? _lastLng;
  double? _lastDestLat;
  double? _lastDestLng;
  String _cachedEta = '';

  Future<String> calculateEta({
    required double driverLat,
    required double driverLng,
    required double destinationLat,
    required double destinationLng,
    bool isToPickup = true,
  }) async {
    final now = DateTime.now();

    final destinationChanged = (_lastDestLat != destinationLat || _lastDestLng != destinationLng);

    // Check if driver has moved significantly or if 30s has passed since last API call
    final distanceMoved = (_lastLat != null && _lastLng != null)
        ? Geolocator.distanceBetween(_lastLat!, _lastLng!, driverLat, driverLng)
        : 999.0;

    final timePassed = (_lastApiCallTime != null)
        ? now.difference(_lastApiCallTime!)
        : const Duration(seconds: 999);

    if (!destinationChanged && _cachedEta.isNotEmpty && distanceMoved < 100 && timePassed < const Duration(seconds: 30)) {
      return _cachedEta;
    }

    _lastLat = driverLat;
    _lastLng = driverLng;
    _lastDestLat = destinationLat;
    _lastDestLng = destinationLng;
    _lastApiCallTime = now;

    int mins = 1;
    double distanceKm = 0.0;

    // Try Google Maps Directions API
    try {
      final routeInfo = await _pricingRepo.getRouteInfo(
        fromLng: driverLng,
        fromLat: driverLat,
        toLng: destinationLng,
        toLat: destinationLat,
      );

      if (routeInfo != null) {
        mins = routeInfo.durationMinutes.round().clamp(1, 999);
        distanceKm = routeInfo.distanceKm;
      } else {
        final double distanceM = Geolocator.distanceBetween(driverLat, driverLng, destinationLat, destinationLng);
        distanceKm = distanceM / 1000;
        final double durationMins = (distanceM / 8.33) / 60; // 30 km/h average city speed
        mins = durationMins.round().clamp(1, 999);
      }
    } catch (_) {
      final double distanceM = Geolocator.distanceBetween(driverLat, driverLng, destinationLat, destinationLng);
      distanceKm = distanceM / 1000;
      final double durationMins = (distanceM / 8.33) / 60;
      mins = durationMins.round().clamp(1, 999);
    }

    final minUnit = mins == 1 ? 'min' : 'mins';
    final kmText = distanceKm > 0 ? ' (${distanceKm.toStringAsFixed(1)} km)' : '';
    final prefix = isToPickup ? 'Pickup in' : 'Dropoff in';

    _cachedEta = '$prefix $mins $minUnit$kmText';
    return _cachedEta;
  }
}
