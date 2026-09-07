import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:caride/core/driver/models/ride_model.dart';
import 'package:caride/core/driver/utils/distance_helper.dart';
import 'driver_alert_audio_service.dart';

/// Central controller managing ride request notifications, deduplication, sound, and vibration.
class DriverAlertController {
  DriverAlertController._();
  static final DriverAlertController instance = DriverAlertController._();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  final Map<String, DateTime> _alertedRideIds = {};
  String? _activeAlertRideId;

  static const int _notificationId = 8888;

  static const AndroidNotificationChannel _rideAlertChannel =
      AndroidNotificationChannel(
    'caride_ride_alerts',
    'Ride Request Alerts',
    description: 'High priority alerts for incoming driver ride requests',
    importance: Importance.max,
    sound: RawResourceAndroidNotificationSound('notification'),
    playSound: true,
    enableVibration: true,
  );

  /// Initializes the local notification plugin and channel settings for ride alerts.
  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(settings);

    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_rideAlertChannel);
  }

  /// Processes active ride stream updates from `IncomingRequestsScreen`.
  void onRidesUpdated(
    List<RideModel> rides, {
    double? driverLat,
    double? driverLng,
  }) {
    _cleanOldDeduplicationEntries();

    if (rides.isEmpty) {
      stopAlert();
      return;
    }

    // Filter available requested/bidding rides
    final pendingRides = rides.where((r) => r.status == 'requested' || r.status == 'bidding').toList();

    if (pendingRides.isEmpty) {
      stopAlert();
      return;
    }

    // Check if current active alert ride is still pending
    if (_activeAlertRideId != null) {
      final activeStillExists = pendingRides.any((r) => r.id == _activeAlertRideId);
      if (!activeStillExists) {
        stopAlert();
      }
    }

    // Find first ride that has not been alerted yet
    for (final ride in pendingRides) {
      if (!_alertedRideIds.containsKey(ride.id)) {
        double? dist;
        if (driverLat != null &&
            driverLng != null &&
            ride.pickupLat != null &&
            ride.pickupLng != null) {
          dist = calculateDistance(
            driverLat,
            driverLng,
            ride.pickupLat!,
            ride.pickupLng!,
          );
        }
        _triggerRideAlert(ride, dist);
        break;
      }
    }
  }

  /// Handles incoming FCM push messages (foreground & background).
  Future<void> handleIncomingFcmMessage(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'] as String?;
    final rideId = data['rideId'] as String?;

    if (type == 'new_ride' || type == 'ride_request') {
      if (rideId != null && !_alertedRideIds.containsKey(rideId)) {
        _alertedRideIds[rideId] = DateTime.now();
        await DriverAlertAudioService.instance.startAlert();
      }
    }
  }

  /// Triggers a fresh alert for a ride request.
  Future<void> _triggerRideAlert(RideModel ride, double? distanceKm) async {
    _activeAlertRideId = ride.id;
    _alertedRideIds[ride.id] = DateTime.now();

    // Start looping audio and vibration
    await DriverAlertAudioService.instance.startAlert();

    // Show heads-up local notification
    await _showRideNotification(ride, distanceKm);
  }

  /// Shows high-priority local push notification.
  Future<void> _showRideNotification(RideModel ride, double? distanceKm) async {
    final distText =
        distanceKm != null ? ' • ${distanceKm.toStringAsFixed(1)} km' : '';
    final title = 'Ride Available (${ride.rideType})';
    final body =
        'Pickup: ${ride.pickupLabel}\nFare: ₦${ride.customerOffer.toStringAsFixed(0)}$distText';

    const androidDetails = AndroidNotificationDetails(
      'caride_ride_alerts',
      'Ride Request Alerts',
      channelDescription: 'High priority alerts for incoming driver ride requests',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('notification'),
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'notification.wav',
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final payload = jsonEncode({
      'path': '/driver/requests',
      'rideId': ride.id,
      'type': 'ride_request',
    });

    try {
      await _localNotifications.show(
        _notificationId,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[DriverAlertController] Notification error: $e');
    }
  }

  /// Stops current alert audio, vibration, and notification for a resolved ride.
  void resolveRide(String rideId) {
    if (_activeAlertRideId == rideId) {
      stopAlert();
    }
  }

  /// Stops all active audio, vibration, and clears the notification.
  void stopAlert() {
    _activeAlertRideId = null;
    DriverAlertAudioService.instance.stopAlert();
    _localNotifications.cancel(_notificationId);
  }

  /// Purges old deduplication entries to avoid unbounded memory growth.
  void _cleanOldDeduplicationEntries() {
    final now = DateTime.now();
    _alertedRideIds.removeWhere(
      (_, timestamp) => now.difference(timestamp).inMinutes > 5,
    );
  }

  /// Dispose resources.
  void dispose() {
    stopAlert();
  }
}
