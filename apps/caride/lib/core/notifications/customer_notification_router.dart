import 'package:navigation/navigation.dart';

class CustomerNotificationRouter {
  const CustomerNotificationRouter();

  void handle({
    required GoRouter router,
    required Map<String, dynamic> data,
  }) {
    final type = data['type'];
    final rideId = data['rideId'];
    if (type is! String) return;

    switch (type) {
      case 'ride_booked':
      case 'ride_started':
        if (rideId is String && rideId.trim().isNotEmpty) {
          router.go(
            CustomerRoutePaths.rideSetPrice,
            extra: <String, dynamic>{'rideId': rideId.trim()},
          );
        }
        return;
      case 'ride_completed':
        router.go(CustomerRoutePaths.rideHistory);
        return;
      case 'chat_message':
        router.go(CustomerRoutePaths.chat);
        return;
      default:
        return;
    }
  }
}
