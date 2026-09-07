import 'package:navigation/navigation.dart';

class DriverNotificationRouter {
  const DriverNotificationRouter();

  void handle({
    required GoRouter router,
    required Map<String, dynamic> data,
  }) {
    final type = data['type'];
    if (type is! String) return;

    switch (type) {
      case 'ride_assigned':
        router.go(DriverRoutePaths.tripPickup);
        return;
      case 'ride_started':
        router.go(DriverRoutePaths.tripActive);
        return;
      case 'ride_completed':
        router.go(DriverRoutePaths.tripComplete);
        return;
      case 'ride_cancelled':
        router.go(DriverRoutePaths.rides);
        return;
      default:
        return;
    }
  }
}
