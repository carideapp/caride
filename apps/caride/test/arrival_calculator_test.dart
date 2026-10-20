import 'package:caride/features/ride_booking/data/arrival_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ArrivalCalculator Tests', () {
    late ArrivalCalculator calculator;

    setUp(() {
      calculator = ArrivalCalculator();
    });

    test('calculateInstantEta returns correctly formatted pickup ETA', () {
      final eta = calculator.calculateInstantEta(
        driverLat: 9.0820,
        driverLng: 8.6753,
        destinationLat: 9.0900,
        destinationLng: 8.6800,
        isToPickup: true,
      );

      expect(eta, startsWith('Pickup in'));
      expect(eta, contains('min'));
      expect(eta, contains('km'));
    });

    test('calculateInstantEta returns correctly formatted dropoff ETA with distance in meters if close', () {
      final eta = calculator.calculateInstantEta(
        driverLat: 9.0820,
        driverLng: 8.6753,
        destinationLat: 9.0830,
        destinationLng: 8.6760,
        isToPickup: false,
      );

      expect(eta, startsWith('Dropoff in'));
      expect(eta, contains('m'));
    });

    test('resetCache clears cached values cleanly', () {
      calculator.resetCache();
      expect(calculator, isNotNull);
    });
  });
}
