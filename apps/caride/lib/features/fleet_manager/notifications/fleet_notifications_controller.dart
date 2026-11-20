import 'package:caride/core/notifications/app_notification_service.dart';

/// Delegates Fleet Manager push token registration and foreground alert
/// presentation to the unified [AppNotificationService].
class FleetNotificationsController {
  FleetNotificationsController._internal();

  static final FleetNotificationsController _instance =
      FleetNotificationsController._internal();

  factory FleetNotificationsController() => _instance;

  /// Call once after fleet login. [fleetId] is the fleet's Firestore doc ID.
  Future<void> initialize({required String fleetId}) =>
      AppNotificationService.instance.setFleetId(fleetId);

  Future<void> dispose() async {}
}
