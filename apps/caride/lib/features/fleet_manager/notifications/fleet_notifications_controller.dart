import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Manages FCM token registration and foreground push notifications
/// for the Fleet Manager. Token is stored in `fleets/{fleetId}`.
class FleetNotificationsController {
  FleetNotificationsController._internal({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FlutterLocalNotificationsPlugin? localNotifications,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _localNotifications =
            localNotifications ?? FlutterLocalNotificationsPlugin();

  static final FleetNotificationsController _instance =
      FleetNotificationsController._internal();

  factory FleetNotificationsController() => _instance;

  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FlutterLocalNotificationsPlugin _localNotifications;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;

  String? _lastSyncedToken;
  String? _currentFleetId;

  static const _androidChannel = AndroidNotificationChannel(
    'caride_fleet_alerts',
    'CaRide Fleet Alerts',
    description: 'Fleet manager booking and payment notifications',
    importance: Importance.high,
  );

  /// Call once after fleet login. [fleetId] is the fleet's Firestore doc ID.
  Future<void> initialize({required String fleetId}) async {
    _currentFleetId = fleetId;

    await _initLocalNotifications();
    await _requestPushPermissions();

    _authSub ??= _auth.authStateChanges().listen((user) async {
      if (user == null) return;
      await _syncTokenForFleet();
    });

    _tokenSub ??= _messaging.onTokenRefresh.listen((token) async {
      if (token == _lastSyncedToken) return;
      _lastSyncedToken = token;
      await _saveTokenToFleet(token);
    });

    _onMessageSub ??= FirebaseMessaging.onMessage.listen((message) async {
      await _showForegroundNotification(message);
    });

    await _syncTokenForFleet();
  }

  Future<void> _requestPushPermissions() async {
    if (kIsWeb) return;
    await _messaging.requestPermission(alert: true, badge: true, sound: true);
  }

  Future<void> _syncTokenForFleet() async {
    final fleetId = _currentFleetId;
    if (fleetId == null || fleetId.isEmpty) return;
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    if (token == _lastSyncedToken) return;
    _lastSyncedToken = token;
    await _saveTokenToFleet(token);
  }

  Future<void> _saveTokenToFleet(String token) async {
    final fleetId = _currentFleetId;
    if (fleetId == null || fleetId.isEmpty) return;
    try {
      await _firestore.collection('fleets').doc(fleetId).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[FleetFCM] Failed to save FCM token: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload == null || payload.isEmpty) return;
        final data = jsonDecode(payload);
        if (data is! Map) return;
        _handleData(data.cast<String, dynamic>());
      },
    );

    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_androidChannel);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    final payload = jsonEncode(message.data);

    const androidDetails = AndroidNotificationDetails(
      'caride_fleet_alerts',
      'CaRide Fleet Alerts',
      channelDescription: 'Fleet manager booking and payment notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      n.title,
      n.body,
      details,
      payload: payload,
    );
  }

  void _handleData(Map<String, dynamic> data) {
    debugPrint('[FleetFCM] Notification data received: $data');
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _tokenSub?.cancel();
    await _onMessageSub?.cancel();
  }
}
