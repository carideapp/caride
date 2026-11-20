import 'dart:async';

import 'package:caride/core/notifications/pending_notification_intent_service.dart';
import 'package:caride/core/notifications/unified_notification_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';

import 'app_notification_service.dart';

@pragma('vm:entry-point')
Future<void> customerFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) => carideFirebaseMessagingBackgroundHandler(message);

/// Backwards-compatible delegate forwarding to [AppNotificationService].
class CustomerNotificationsController {
  Future<void> initialize({required GoRouter router}) =>
      AppNotificationService.instance.initialize(router: router);

  Future<void> handleData(Map<String, dynamic> data) =>
      UnifiedNotificationRouter.instance.handle(
        router: _requireRouter,
        data: data,
      );

  static GoRouter get _requireRouter {
    throw StateError('Use AppNotificationService.instance directly.');
  }

  void capturePending(Map<String, dynamic> data) {
    if (kDebugMode) {
      debugPrint('[CustomerNotificationsController] Delegated capture.');
    }
    PendingNotificationIntentService.instance.capture(data);
  }

  Future<void> dispose() => AppNotificationService.instance.dispose();
}
