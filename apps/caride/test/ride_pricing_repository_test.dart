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

  group('RidePricingConfig state-specific pricing', () {
    final config = RidePricingConfig.fromMap({
      'regular': {'baseFare': 800, 'perKmRate': 200, 'perMinuteRate': 50},
      'tricycle': {'baseFare': 400, 'perKmRate': 100, 'perMinuteRate': 20},
      'luxury': {'baseFare': 2000, 'perKmRate': 500, 'perMinuteRate': 100},
      'statePricing': {
        'Edo': {
          'regular': {'mode': 'percentage', 'adjustmentPercent': 5}, // +5%
          'tricycle': {'mode': 'percentage', 'adjustmentPercent': -10}, // -10%
        },
        'Lagos': {
          'luxury': {
            'mode': 'custom',
            'baseFare': 3500,
            'perKmRate': 700,
            'perMinuteRate': 150,
          },
        },
      },
    });

    test('falls back to national default if state is null or unconfigured', () {
      final pricingNullState = config.getPricingFor(rideType: 'regular', operatingState: null);
      expect(pricingNullState.baseFare, 800);
      expect(pricingNullState.perKmRate, 200);

      final pricingDelta = config.getPricingFor(rideType: 'regular', operatingState: 'Delta');
      expect(pricingDelta.baseFare, 800);
      expect(pricingDelta.perKmRate, 200);
    });

    test('applies percentage increase for Edo regular (+5%)', () {
      final pricing = config.getPricingFor(rideType: 'regular', operatingState: 'Edo');
      // 800 * 1.05 = 840, 200 * 1.05 = 210, 50 * 1.05 = 52.5
      expect(pricing.baseFare, 840);
      expect(pricing.perKmRate, 210);
      expect(pricing.perMinuteRate, 52.5);
    });

    test('normalizes state names like "Edo State"', () {
      final pricing = config.getPricingFor(rideType: 'regular', operatingState: 'Edo State');
      expect(pricing.baseFare, 840);
      expect(pricing.perKmRate, 210);
    });

    test('applies percentage decrease for Edo tricycle (-10%)', () {
      final pricing = config.getPricingFor(rideType: 'tricycle', operatingState: 'Edo');
      // 400 * 0.9 = 360, 100 * 0.9 = 90, 20 * 0.9 = 18
      expect(pricing.baseFare, 360);
      expect(pricing.perKmRate, 90);
      expect(pricing.perMinuteRate, 18);
    });

    test('applies custom rate override for Lagos luxury', () {
      final pricing = config.getPricingFor(rideType: 'luxury', operatingState: 'Lagos');
      expect(pricing.baseFare, 3500);
      expect(pricing.perKmRate, 700);
      expect(pricing.perMinuteRate, 150);
    });
  });
}
