class Place {
  const Place({
    required this.label,
    required this.address,
    this.lat,
    this.lng,
  });

  final String label;
  final String address;
  final double? lat;
  final double? lng;
}
