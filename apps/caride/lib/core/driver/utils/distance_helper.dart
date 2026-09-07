import 'dart:math';

/// Calculates the distance in kilometers between two GPS coordinates using the Haversine formula.
double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const p = 0.017453292519943295; // Math.PI / 180
  final a = 0.5 - cos((lat2 - lat1) * p) / 2 +
      cos(lat1 * p) * cos(lat2 * p) *
      (1 - cos((lon2 - lon1) * p)) / 2;
  return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
}

/// Estimates ETA in minutes based on distance in kilometers.
/// Assumes an average speed of 24 km/h (0.4 km per minute).
int estimateEtaMinutes(double distanceKm) {
  if (distanceKm <= 0) return 3;
  return (distanceKm / 0.4).round().clamp(3, 45);
}
