import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import 'driver_alert_controller.dart';
import 'driver_notification_router.dart';

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final DriverNotificationRouter _router = const DriverNotificationRouter();

  GoRouter? _goRouter;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
    'caride_alerts',
    'CaRide Alerts',
    description: 'Driver notifications',
    importance: Importance.high,
  );

  Future<void> initialize({required GoRouter router}) async {
    _goRouter = router;

    await _initLocalNotifications();
    await DriverAlertController.instance.initialize();
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _authSub ??= _auth.authStateChanges().listen((user) async {
      if (user == null) return;
      await _registerToken(user.uid);
    });

    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      await _registerToken(currentUser.uid);
    }

    _tokenSub ??= _messaging.onTokenRefresh.listen((token) async {
      final uid = _auth.currentUser?.uid;
      if (uid != null) await _saveToken(uid, token);
    });

    _onMessageSub ??= FirebaseMessaging.onMessage.listen((message) async {
      await DriverAlertController.instance.handleIncomingFcmMessage(message);
      await _showForegroundNotification(message);
    });

    _onOpenedSub ??= FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleRemoteMessage(message);
    });

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _handleRemoteMessage(initial);
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings();
    const settings =
        InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload == null || payload.isEmpty) return;
        final decoded = jsonDecode(payload);
        if (decoded is! Map) return;
        _handleData(decoded.cast<String, dynamic>());
      },
    );

    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_androidChannel);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    final payload = jsonEncode(message.data);

    const androidDetails = AndroidNotificationDetails(
      'caride_alerts',
      'CaRide Alerts',
      channelDescription: 'Driver notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      n.title,
      n.body,
      details,
      payload: payload,
    );
  }

  void _handleRemoteMessage(RemoteMessage message) {
    _handleData(message.data);
  }

  void _handleData(Map<String, dynamic> data) {
    final router = _goRouter;
    if (router == null) return;
    _router.handle(router: router, data: data);
  }

  Future<void> _registerToken(String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(uid, token);
    } catch (e) {
      debugPrint('[FCM] Token registration failed: $e');
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    try {
      await _firestore.collection('drivers').doc(uid).update(
        {'fcmToken': token, 'updatedAt': FieldValue.serverTimestamp()},
      );
    } catch (e) {
      debugPrint('[FCM] Failed to update token (doc may not exist): $e');
    }
  }

  Future<void> clearToken() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestore.collection('drivers').doc(uid).update(
        {'fcmToken': FieldValue.delete(), 'updatedAt': FieldValue.serverTimestamp()},
      );
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('[FCM] Failed to clear token: $e');
    }
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _tokenSub?.cancel();
    await _onMessageSub?.cancel();
    await _onOpenedSub?.cancel();
  }
}
