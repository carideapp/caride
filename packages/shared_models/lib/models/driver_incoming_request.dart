class DriverIncomingRequest {
  const DriverIncomingRequest({
    required this.id,
    required this.routeLabel,
    required this.customerOffer,
    required this.pickupEtaMinutes,
    required this.passengerRating,
  });

  final String id;
  final String routeLabel;
  final double customerOffer;
  final int pickupEtaMinutes;
  final double passengerRating;
}
