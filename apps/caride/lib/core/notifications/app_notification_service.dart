import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:caride/core/auth/customer_auth_controller.dart';
import 'pending_notification_intent_service.dart';
import 'unified_notification_router.dart';

@pragma('vm:entry-point')
Future<void> carideFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  await Firebase.initializeApp();
  final type = (message.data['type'] ?? '').toString().trim().toLowerCase();

  // Android incoming ride requests and cancellation pushes are processed
  // natively in CarideFirebaseMessagingService so custom ringtone channels
  // and notification cancellations apply immediately without starting Dart plugins.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    if (type == 'ride_request' ||
        type == 'new_ride' ||
        type == 'ride_offer' ||
        type == 'ride_alert_cancel') {
      return;
    }
  }
}

class AppNotificationService {
  AppNotificationService._internal({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messagingOverride = messaging,
       _authOverride = auth,
       _firestoreOverride = firestore,
       _localNotificationsOverride = localNotifications;

  @visibleForTesting
  AppNotificationService.forTest({
    FirebaseMessaging? messaging,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _messagingOverride = messaging,
       _authOverride = auth,
       _firestoreOverride = firestore,
       _localNotificationsOverride = localNotifications;

  static final AppNotificationService instance =
      AppNotificationService._internal();

  static const MethodChannel _rideAlertsChannel = MethodChannel(
    'com.caride.app/ride_alerts',
  );
  static const String _deviceIdPrefsKey = 'caride_notification_device_id';

  static const _customerChannel = AndroidNotificationChannel(
    'caride_customer_alerts',
    'CaRide Alerts',
    description: 'Ride status and customer booking notifications',
    importance: Importance.high,
  );

  static const _fleetChannel = AndroidNotificationChannel(
    'caride_fleet_alerts',
    'CaRide Fleet Alerts',
    description: 'Fleet manager booking and payment notifications',
    importance: Importance.high,
  );

  final FirebaseMessaging? _messagingOverride;
  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;
  final FlutterLocalNotificationsPlugin? _localNotificationsOverride;
  FlutterLocalNotificationsPlugin? _cachedLocalNotifications;

  FirebaseMessaging get _messaging =>
      _messagingOverride ?? FirebaseMessaging.instance;
  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;
  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;
  FlutterLocalNotificationsPlugin get _localNotifications =>
      _cachedLocalNotifications ??=
          _localNotificationsOverride ?? FlutterLocalNotificationsPlugin();

  final StreamController<Map<String, dynamic>> _foregroundRideAlertController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _cancelledRideController =
      StreamController<String>.broadcast();
  final StreamController<String> _declinedRideController =
      StreamController<String>.broadcast();

  Stream<Map<String, dynamic>> get foregroundRideAlerts =>
      _foregroundRideAlertController.stream;
  Stream<String> get cancelledRideIds => _cancelledRideController.stream;
  Stream<String> get declinedRideIds => _declinedRideController.stream;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onOpenedSub;

  GoRouter? _goRouter;
  bool _initialized = false;
  Future<void>? _initialIntentFuture;
  String? _lastSyncedToken;
  String? _lastSyncedUid;
  String? _currentFleetId;
  String? _cachedDeviceId;

  Future<void> initialize({required GoRouter router}) async {
    _goRouter = router;
    if (_initialized) return;
    _initialized = true;

    if (!kIsWeb) {
      _rideAlertsChannel.setMethodCallHandler(_handleNativeRideAlertMethod);
    }

    await _initLocalNotifications();
    await _requestPushPermissions();

    _authSub ??= _auth.authStateChanges().listen((user) async {
      if (user == null) {
        _lastSyncedToken = null;
        _lastSyncedUid = null;
        return;
      }
      await syncTokenForCurrentUser(force: true);
    });

    _tokenSub ??= _messaging.onTokenRefresh.listen((token) async {
      final uid = _auth.currentUser?.uid;
      if (uid == null || token.isEmpty) return;
      if (token == _lastSyncedToken && uid == _lastSyncedUid) return;
      await _persistTokenAcrossRoles(uid: uid, token: token);
    });

    _onMessageSub ??= FirebaseMessaging.onMessage.listen((message) async {
      await _handleForegroundMessage(message);
    });

    _onOpenedSub ??= FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(_handleNotificationTap(message.data));
    });

    _initialIntentFuture = _captureInitialIntent();
    unawaited(_initialIntentFuture);

    await syncTokenForCurrentUser();
  }

  Future<void> ensureInitialIntentCaptured() async {
    final future = _initialIntentFuture;
    if (future != null) {
      await future;
    }
  }

  Future<void> setFleetId(String? fleetId) async {
    final cleaned = fleetId?.trim();
    if (cleaned == null || cleaned.isEmpty) return;
    _currentFleetId = cleaned;
    await syncTokenForCurrentUser(force: true);
  }

  Future<void> syncTokenForCurrentUser({bool force = false}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return;
      if (!force && token == _lastSyncedToken && uid == _lastSyncedUid) return;
      await _persistTokenAcrossRoles(uid: uid, token: token);
    } catch (e) {
      debugPrint('[AppNotifications] Failed to fetch/sync FCM token: $e');
    }
  }

  Future<void> cancelRideNotification(String rideId) async {
    final cleaned = rideId.trim();
    if (cleaned.isEmpty || kIsWeb) return;
    try {
      await _rideAlertsChannel.invokeMethod('cancelRideNotification', {
        'rideId': cleaned,
      });
    } catch (_) {}
  }

  Future<void> markRideDeclined(String rideId) async {
    final cleaned = rideId.trim();
    if (cleaned.isEmpty || kIsWeb) return;
    try {
      await _rideAlertsChannel.invokeMethod('markRideDeclined', {
        'rideId': cleaned,
      });
    } catch (_) {}
  }

  Future<List<String>> getDeclinedRideIds() async {
    if (kIsWeb) return const [];
    try {
      final result = await _rideAlertsChannel.invokeListMethod<String>(
        'getDeclinedRideIds',
      );
      return result ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<bool> isBatteryOptimizationIgnored() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final ignored = await _rideAlertsChannel.invokeMethod<bool>(
        'isBatteryOptimizationIgnored',
      );
      return ignored ?? true;
    } catch (_) {
      return true;
    }
  }

  Future<bool> openBatterySettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final opened = await _rideAlertsChannel.invokeMethod<bool>(
        'openBatterySettings',
      );
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> openNotificationChannelSettings({String? channelId}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final opened = await _rideAlertsChannel.invokeMethod<bool>(
        'openNotificationChannelSettings',
        {
          if (channelId != null && channelId.isNotEmpty) 'channelId': channelId,
        },
      );
      return opened ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, String>> getIosNotificationReadiness() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return const {};
    try {
      final raw = await _rideAlertsChannel.invokeMapMethod<String, dynamic>(
        'getIosNotificationReadiness',
      );
      if (raw == null) return const {};
      return raw.map((k, v) => MapEntry(k, v?.toString() ?? 'unknown'));
    } catch (_) {
      return const {};
    }
  }

  Future<dynamic> _handleNativeRideAlertMethod(MethodCall call) async {
    final rawArgs = call.arguments;
    final map = rawArgs is Map
        ? rawArgs.map((k, v) => MapEntry(k.toString(), v))
        : <String, dynamic>{};

    switch (call.method) {
      case 'onForegroundRideAlert':
        final rideId = map['rideId']?.toString().trim() ?? '';
        if (rideId.isNotEmpty) {
          _foregroundRideAlertController.add(map);
        }
        return null;

      case 'onRideAlertCancelled':
        final rideId = map['rideId']?.toString().trim() ?? '';
        if (rideId.isNotEmpty) {
          _cancelledRideController.add(rideId);
        }
        return null;

      case 'onRideNotificationDeclined':
        final rideId = map['rideId']?.toString().trim() ?? '';
        if (rideId.isNotEmpty) {
          _declinedRideController.add(rideId);
        }
        return null;

      case 'onRideNotificationTapped':
        await _handleNotificationTap(map);
        return null;

      default:
        return null;
    }
  }

  Future<void> _captureInitialIntent() async {
    if (!kIsWeb) {
      try {
        final nativePayload = await _rideAlertsChannel
            .invokeMapMethod<String, dynamic>('consumePendingRideIntent');
        if (nativePayload != null && nativePayload.isNotEmpty) {
          PendingNotificationIntentService.instance.capture(nativePayload);
        }
      } catch (_) {}
    }

    try {
      final initial = await _messaging.getInitialMessage();
      if (initial != null &&
          initial.data.isNotEmpty &&
          !PendingNotificationIntentService.instance.hasPending) {
        PendingNotificationIntentService.instance.capture(initial.data);
      }
    } catch (e) {
      debugPrint('[AppNotifications] Failed reading getInitialMessage: $e');
    }
  }

  Future<void> _requestPushPermissions() async {
    if (kIsWeb) return;
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _messaging.setForegroundNotificationPresentationOptions(
          alert: false,
          badge: true,
          sound: false,
        );
      }
    } catch (e) {
      debugPrint('[AppNotifications] Permission request error: $e');
    }
  }

  Future<void> _initLocalNotifications() async {
    if (kIsWeb) return;
    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_stat_caride',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (resp) {
        final payload = resp.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            unawaited(
              _handleNotificationTap(
                decoded.map((k, v) => MapEntry(k.toString(), v)),
              ),
            );
          }
        } catch (_) {}
      },
    );

    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.createNotificationChannel(_customerChannel);
    await androidImpl?.createNotificationChannel(_fleetChannel);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = Map<String, dynamic>.from(message.data);
    final type = (data['type'] ?? '').toString().trim().toLowerCase();

    if (type == 'ride_alert_cancel') {
      final rideId = (data['rideId'] ?? '').toString().trim();
      if (rideId.isNotEmpty) {
        await cancelRideNotification(rideId);
        _cancelledRideController.add(rideId);
      }
      return;
    }

    if (type == 'ride_request' || type == 'new_ride' || type == 'ride_offer') {
      final rideId = (data['rideId'] ?? '').toString().trim();
      if (rideId.isNotEmpty) {
        _foregroundRideAlertController.add(data);
      }
      return;
    }

    await _showForegroundLocalNotification(message);
  }

  Future<void> _showForegroundLocalNotification(RemoteMessage message) async {
    if (kIsWeb) return;
    final notification = message.notification;
    if (notification == null) return;

    final data = Map<String, dynamic>.from(message.data);
    final type = (data['type'] ?? '').toString().trim().toLowerCase();
    final isFleet = type.startsWith('fleet_');
    final isRideAssigned = type == 'ride_assigned';

    final channelId = isFleet
        ? _fleetChannel.id
        : isRideAssigned
        ? 'caride_ride_assigned_v1'
        : _customerChannel.id;
    final channelName = isFleet
        ? _fleetChannel.name
        : isRideAssigned
        ? 'Ride Confirmed'
        : _customerChannel.name;

    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: isFleet
          ? _fleetChannel.description
          : _customerChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@drawable/ic_stat_caride',
      sound: isRideAssigned
          ? const RawResourceAndroidNotificationSound('ride_assigned')
          : null,
    );
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: isRideAssigned ? 'ride_assigned.wav' : null,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    final notifId = DateTime.now().millisecondsSinceEpoch % 100000;

    await _localNotifications.show(
      notifId,
      notification.title,
      notification.body,
      details,
      payload: jsonEncode(data),
    );
  }

  Future<void> _handleNotificationTap(Map<String, dynamic> data) async {
    if (data.isEmpty) return;

    final router = _goRouter;
    if (router != null &&
        customerAuthController.isAuthenticated &&
        customerAuthController.profileLoaded) {
      await UnifiedNotificationRouter.instance.handle(
        router: router,
        data: data,
        switchRoleIfNeeded: true,
      );
      return;
    }

    PendingNotificationIntentService.instance.capture(data);
  }

  Future<void> _persistTokenAcrossRoles({
    required String uid,
    required String token,
  }) async {
    _lastSyncedToken = token;
    _lastSyncedUid = uid;

    final deviceId = await _getOrCreateDeviceId();
    final deviceMeta = await _collectDeviceMetadata(token);

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('devices')
          .doc(deviceId)
          .set(deviceMeta, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[AppNotifications] Failed writing device token record: $e');
    }

    await _updateTokenIfDocExists('customers', uid, token);
    await _updateTokenIfDocExists('drivers', uid, token);

    final fleetId = _currentFleetId;
    if (fleetId != null && fleetId.isNotEmpty) {
      await _updateTokenIfDocExists('fleets', fleetId, token);
    }
  }

  Future<void> _updateTokenIfDocExists(
    String collection,
    String docId,
    String token,
  ) async {
    try {
      final ref = _firestore.collection(collection).doc(docId);
      final snap = await ref.get();
      if (!snap.exists) return;
      await ref.update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<String> _getOrCreateDeviceId() async {
    final cached = _cachedDeviceId;
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_deviceIdPrefsKey);
      if (existing != null && existing.trim().isNotEmpty) {
        _cachedDeviceId = existing.trim();
        return _cachedDeviceId!;
      }
      final generated =
          '${defaultTargetPlatform.name}_${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(999999).toString().padLeft(6, '0')}';
      await prefs.setString(_deviceIdPrefsKey, generated);
      _cachedDeviceId = generated;
      return generated;
    } catch (_) {
      return '${defaultTargetPlatform.name}_default';
    }
  }

  Future<Map<String, dynamic>> _collectDeviceMetadata(String token) async {
    String platform = defaultTargetPlatform.name;
    String model = '';
    bool isPhysicalDevice = true;

    if (!kIsWeb) {
      try {
        final deviceInfo = DeviceInfoPlugin();
        if (defaultTargetPlatform == TargetPlatform.android) {
          final android = await deviceInfo.androidInfo;
          platform = 'android';
          model = '${android.manufacturer} ${android.model}'.trim();
          isPhysicalDevice = android.isPhysicalDevice;
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          final ios = await deviceInfo.iosInfo;
          platform = 'ios';
          model = ios.utsname.machine;
          isPhysicalDevice = ios.isPhysicalDevice;
        }
      } catch (_) {}
    } else {
      platform = 'web';
    }

    return {
      'fcmToken': token,
      'platform': platform,
      if (model.isNotEmpty) 'deviceModel': model,
      'isPhysicalDevice': isPhysicalDevice,
      'activeRole': customerAuthController.activeRole,
      'isActive': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _tokenSub?.cancel();
    await _onMessageSub?.cancel();
    await _onOpenedSub?.cancel();
    _authSub = null;
    _tokenSub = null;
    _onMessageSub = null;
    _onOpenedSub = null;
    _initialized = false;
  }
}
