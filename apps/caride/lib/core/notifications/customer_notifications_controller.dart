import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';

import 'customer_notification_router.dart';

@pragma('vm:entry-point')
Future<void> customerFirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class CustomerNotificationsController {
  CustomerNotificationsController({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FlutterLocalNotificationsPlugin? localNotifications,
    CustomerNotificationRouter? router,
  })  : _messaging = messaging ?? FirebaseMessaging.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _localNotifications = localNotifications ?? FlutterLocalNotificationsPlugin(),
        _router = router ?? const CustomerNotificationRouter();

  final FirebaseMessaging _messaging;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final CustomerNotificationRouter _router;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;

  GoRouter? _goRouter;
  // In-memory cache of the last successfully synced FCM token.
  // Prevents redundant Firestore writes when authStateChanges fires multiple
  // times at startup with the same user.
  String? _lastSyncedToken;

  static const _androidChannel = AndroidNotificationChannel(
    'caride_customer_alerts',
    'CaRide Alerts',
    description: 'Ride status notifications',
    importance: Importance.high,
  );

  Future<void> initialize({required GoRouter router}) async {
    _goRouter = router;

    await _initLocalNotifications();
    await _requestPushPermissions();

    _authSub ??= _auth.authStateChanges().listen((user) async {
      if (user == null) return;
      await _syncTokenForUser(user.uid);
    });

    _tokenSub ??= _messaging.onTokenRefresh.listen((token) async {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      // Only write if token changed (avoids double-write on startup)
      if (token == _lastSyncedToken) return;
      _lastSyncedToken = token;
      await _upsertCustomerFcmToken(uid: uid, token: token);
    });

    _onMessageSub ??= FirebaseMessaging.onMessage.listen((message) async {
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

  Future<void> _requestPushPermissions() async {
    if (kIsWeb) return;
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _syncTokenForUser(String uid) async {
    final token = await _messaging.getToken();
    if (token == null || token.isEmpty) return;
    // Skip the Firestore write if the token hasn't changed since last sync.
    if (token == _lastSyncedToken) return;
    _lastSyncedToken = token;
    await _upsertCustomerFcmToken(uid: uid, token: token);
  }

  Future<void> _upsertCustomerFcmToken({
    required String uid,
    required String token,
  }) async {
    try {
      final doc = await _firestore.collection('customers').doc(uid).get();
      if (doc.exists) {
        await _firestore.collection('customers').doc(uid).update({
          'fcmToken': token,
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (_) {
      // Ignore if document doesn't exist or permissions restricted
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

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

    final androidImpl = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidImpl?.createNotificationChannel(_androidChannel);
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    final data = message.data;
    final payload = jsonEncode(data);

    const androidDetails = AndroidNotificationDetails(
      'caride_customer_alerts',
      'CaRide Alerts',
      channelDescription: 'Ride status notifications',
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

  void _handleRemoteMessage(RemoteMessage message) {
    _handleData(message.data);
  }

  void _handleData(Map<String, dynamic> data) {
    final router = _goRouter;
    if (router == null) return;
    _router.handle(router: router, data: data);
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _tokenSub?.cancel();
    await _onMessageSub?.cancel();
    await _onOpenedSub?.cancel();
  }
}

