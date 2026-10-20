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
  double _roadCurvatureFactor = 1.25; // Typical urban road network multiplier

  void resetCache() {
    _lastApiCallTime = null;
    _lastLat = null;
    _lastLng = null;
    _lastDestLat = null;
    _lastDestLng = null;
    _cachedEta = '';
  }

  /// Synchronously computes instantaneous distance and ETA with 0ms network latency.
  String calculateInstantEta({
    required double driverLat,
    required double driverLng,
    required double destinationLat,
    required double destinationLng,
    bool isToPickup = true,
  }) {
    final distanceM = Geolocator.distanceBetween(driverLat, driverLng, destinationLat, destinationLng);
    final straightKm = distanceM / 1000.0;
    final effectiveKm = straightKm * _roadCurvatureFactor;

    // City driving average speed: ~30 km/h (0.5 km/min)
    final double durationMins = effectiveKm / 0.5;
    final mins = durationMins.round().clamp(1, 999);

    final prefix = isToPickup ? 'Pickup in' : 'Dropoff in';
    final minUnit = mins == 1 ? 'min' : 'mins';
    final kmText = distanceM < 1000
        ? ' (${distanceM.round()} m)'
        : ' (${straightKm.toStringAsFixed(1)} km)';

    return '$prefix $mins $minUnit$kmText';
  }

  Future<String> calculateEta({
    required double driverLat,
    required double driverLng,
    required double destinationLat,
    required double destinationLng,
    bool isToPickup = true,
  }) async {
    final now = DateTime.now();

    final destinationChanged = (_lastDestLat != destinationLat || _lastDestLng != destinationLng);
    if (destinationChanged) {
      resetCache();
    }

    // Always compute current live local ETA immediately so UI ticks smoothly with movement
    final localInstantEta = calculateInstantEta(
      driverLat: driverLat,
      driverLng: driverLng,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      isToPickup: isToPickup,
    );

    final timePassed = (_lastApiCallTime != null)
        ? now.difference(_lastApiCallTime!)
        : const Duration(seconds: 999);

    final distanceMovedSinceLastApi = (_lastLat != null && _lastLng != null)
        ? Geolocator.distanceBetween(_lastLat!, _lastLng!, driverLat, driverLng)
        : 999.0;

    // Throttle Google Routes API calls to every 30 seconds or 300m movement,
    // while returning live local continuous distance in the meantime
    if (!destinationChanged && _cachedEta.isNotEmpty && distanceMovedSinceLastApi < 300 && timePassed < const Duration(seconds: 30)) {
      _cachedEta = localInstantEta;
      return _cachedEta;
    }

    _lastLat = driverLat;
    _lastLng = driverLng;
    _lastDestLat = destinationLat;
    _lastDestLng = destinationLng;
    _lastApiCallTime = now;

    try {
      final routeInfo = await _pricingRepo.getRouteInfo(
        fromLng: driverLng,
        fromLat: driverLat,
        toLng: destinationLng,
        toLat: destinationLat,
      );

      if (routeInfo != null) {
        final straightM = Geolocator.distanceBetween(driverLat, driverLng, destinationLat, destinationLng);
        if (straightM > 100 && routeInfo.distanceKm > 0) {
          final factor = routeInfo.distanceKm / (straightM / 1000.0);
          if (factor >= 1.0 && factor <= 2.5) {
            _roadCurvatureFactor = factor;
          }
        }
        final mins = routeInfo.durationMinutes.round().clamp(1, 999);
        final minUnit = mins == 1 ? 'min' : 'mins';
        final distanceKm = routeInfo.distanceKm;
        final kmText = distanceKm > 0 ? ' (${distanceKm.toStringAsFixed(1)} km)' : '';
        final prefix = isToPickup ? 'Pickup in' : 'Dropoff in';
        _cachedEta = '$prefix $mins $minUnit$kmText';
        return _cachedEta;
      }
    } catch (_) {
      // Fallback cleanly to local instant ETA
    }

    _cachedEta = localInstantEta;
    return _cachedEta;
  }
}
