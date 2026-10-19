class DriverOffer {
  const DriverOffer({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.rating,
    required this.vehicleLabel,
    required this.offeredPrice,
    required this.etaMinutes,
    this.isCounter,
  });

  final String id;
  final String driverId;
  final String driverName;
  final double rating;
  final String vehicleLabel;
  final double offeredPrice;
  final int etaMinutes;
  final bool? isCounter;
}
