import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Controls the iOS Live Activity (Lock Screen & Dynamic Island trip card)
/// for an ongoing customer ride.
///
/// No-ops safely on non-iOS platforms (Android, web, desktop).
class RideLiveActivityService {
  RideLiveActivityService._();

  static final RideLiveActivityService instance = RideLiveActivityService._();

  static const MethodChannel _channel = MethodChannel(
    'com.caride.app/live_activity',
  );

  bool get _isIOS => !kIsWeb && Platform.isIOS;

  /// Starts a Live Activity on the iPhone Lock Screen & Dynamic Island.
  Future<void> startRideActivity({
    required String rideId,
    required String status,
    required String driverName,
    required String vehicleInfo,
    required int etaMinutes,
    required String pickup,
    required String dropoff,
  }) async {
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod<void>('startRideActivity', {
        'rideId': rideId,
        'status': status,
        'driverName': driverName,
        'vehicleInfo': vehicleInfo,
        'etaMinutes': etaMinutes,
        'pickup': pickup,
        'dropoff': dropoff,
      });
    } catch (e) {
      debugPrint('RideLiveActivityService.startRideActivity error: $e');
    }
  }

  /// Updates the active Live Activity with new ride status and ETA.
  Future<void> updateRideActivity({
    required String status,
    required int etaMinutes,
  }) async {
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod<void>('updateRideActivity', {
        'status': status,
        'etaMinutes': etaMinutes,
      });
    } catch (e) {
      debugPrint('RideLiveActivityService.updateRideActivity error: $e');
    }
  }

  /// Ends and dismisses the active Live Activity.
  Future<void> endRideActivity() async {
    if (!_isIOS) return;
    try {
      await _channel.invokeMethod<void>('endRideActivity');
    } catch (e) {
      debugPrint('RideLiveActivityService.endRideActivity error: $e');
    }
  }
}
