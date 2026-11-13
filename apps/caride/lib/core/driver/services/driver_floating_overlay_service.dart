import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Controls the Android floating driver icon overlay (`SYSTEM_ALERT_WINDOW`).
///
/// No-ops safely on non-Android platforms (iOS, web, desktop).
class DriverFloatingOverlayService {
  DriverFloatingOverlayService._() {
    if (_isAndroid) {
      _channel.setMethodCallHandler(_handleNativeCall);
    }
  }

  static final DriverFloatingOverlayService instance =
      DriverFloatingOverlayService._();

  static const MethodChannel _channel = MethodChannel(
    'com.caride.app/floating_overlay',
  );

  final StreamController<void> _tapController =
      StreamController<void>.broadcast();

  /// Emits whenever the driver taps the floating icon to view ride requests.
  Stream<void> get onOverlayTapped => _tapController.stream;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onOverlayTapped') {
      _tapController.add(null);
    }
  }

  /// Returns `true` if "Display over other apps" permission is granted.
  Future<bool> hasOverlayPermission() async {
    if (!_isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } catch (e) {
      debugPrint('DriverFloatingOverlayService.hasOverlayPermission error: $e');
      return false;
    }
  }

  /// Opens Android system settings for "Display over other apps".
  Future<void> requestOverlayPermission() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('requestOverlayPermission');
    } catch (e) {
      debugPrint(
        'DriverFloatingOverlayService.requestOverlayPermission error: $e',
      );
    }
  }

  /// Starts the foreground service and shows the floating driver icon.
  Future<bool> start() async {
    if (!_isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>('startFloatingOverlay');
      return result ?? false;
    } catch (e) {
      debugPrint('DriverFloatingOverlayService.start error: $e');
      return false;
    }
  }

  /// Stops the foreground service and removes the floating driver icon.
  Future<void> stop() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('stopFloatingOverlay');
    } catch (e) {
      debugPrint('DriverFloatingOverlayService.stop error: $e');
    }
  }

  /// Updates the floating icon with a pulsing badge & banner for a ride offer.
  Future<void> notifyRideOffer({
    String title = 'New Ride Offer',
    int count = 1,
  }) async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('notifyRideOffer', {
        'title': title,
        'count': count,
      });
    } catch (e) {
      debugPrint('DriverFloatingOverlayService.notifyRideOffer error: $e');
    }
  }

  /// Clears any active ride offer badge/banner on the floating icon.
  Future<void> clearRideOffer() async {
    if (!_isAndroid) return;
    try {
      await _channel.invokeMethod<bool>('clearRideOffer');
    } catch (e) {
      debugPrint('DriverFloatingOverlayService.clearRideOffer error: $e');
    }
  }

  /// Checks if the app was cold-launched by tapping the floating icon.
  Future<bool> consumePendingOpenRequests() async {
    if (!_isAndroid) return false;
    try {
      final result = await _channel.invokeMethod<bool>(
        'consumePendingOpenRequests',
      );
      return result ?? false;
    } catch (e) {
      debugPrint(
        'DriverFloatingOverlayService.consumePendingOpenRequests error: $e',
      );
      return false;
    }
  }
}
