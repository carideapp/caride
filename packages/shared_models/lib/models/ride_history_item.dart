import 'ride_status.dart';

class RideHistoryItem {
  const RideHistoryItem({
    required this.id,
    required this.routeLabel,
    required this.date,
    required this.fare,
    required this.status,
    this.driverName,
  });

  final String id;
  final String routeLabel;
  final DateTime date;
  final double fare;
  final RideStatus status;
  final String? driverName;
}
