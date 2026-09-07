import 'package:caride/features/ride_booking/data/ride_pricing_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RidePricingRepository.computePriceRange', () {
    test('returns expected min/suggested/max values', () {
      final repository = RidePricingRepository(mapboxAccessToken: 'token');
      const pricing = RideTypePricing(baseFare: 500, perKmRate: 120, perMinuteRate: 30);

      final result = repository.computePriceRange(
        pricing: pricing,
        distanceKm: 10,
        durationMinutes: 20,
      );

      expect(result.suggested, 2300);
      expect(result.min, 1840);
      expect(result.max, 2990);
    });
  });
}
