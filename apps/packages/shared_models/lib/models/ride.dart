import 'place.dart';
import 'ride_status.dart';

class Ride {
  const Ride({
    required this.id,
    required this.pickup,
    required this.destination,
    required this.customerPrice,
    required this.suggestedMin,
    required this.suggestedMax,
    required this.status,
    this.driverId,
    this.distanceKm,
    this.etaMinutes,
  });

  final String id;
  final Place pickup;
  final Place destination;
  final double customerPrice;
  final double suggestedMin;
  final double suggestedMax;
  final RideStatus status;
  final String? driverId;
  final double? distanceKm;
  final int? etaMinutes;
}
