import '../../models/ride_history_item.dart';
import '../../models/ride_status.dart';

abstract final class MockRideHistory {
  static List<RideHistoryItem> items() => [
        RideHistoryItem(
          id: 'h1',
          routeLabel: 'Lekki → VI',
          date: DateTime.now().subtract(const Duration(days: 2)),
          fare: 4200,
          status: RideStatus.rideCompleted,
          driverName: 'Chidi O.',
        ),
        RideHistoryItem(
          id: 'h2',
          routeLabel: 'Surulere → Airport',
          date: DateTime.now().subtract(const Duration(days: 9)),
          fare: 8500,
          status: RideStatus.rideCompleted,
          driverName: 'Amaka N.',
        ),
      ];
}
