import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:caride/features/ride_booking/booking_shell/models/booking_shell_step.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('smart start: starts at rideType when extra has pickup+dropoff', () {
    final c = BookingShellController.forTest(
      extra: {
        'pickupLabel': 'A',
        'pickupLat': 1.0,
        'pickupLng': 2.0,
        'dropoffLabel': 'B',
        'dropoffLat': 3.0,
        'dropoffLng': 4.0,
      },
    );
    expect(c.step, BookingShellStep.rideType);
  });

  test('smart start: starts at fromTo when extra missing dropoff', () {
    final c = BookingShellController.forTest(
      extra: {
        'pickupLabel': 'A',
        'pickupLat': 1.0,
        'pickupLng': 2.0,
      },
    );
    expect(c.step, BookingShellStep.fromTo);
  });

  test('offer stepper increments/decrements with floor at 0', () {
    final c = BookingShellController.forTest(extra: null);
    c.setOffer(100);
    c.decrementOffer(step: 50);
    expect(c.offerNaira, 50);
    c.decrementOffer(step: 999);
    expect(c.offerNaira, 0);
    c.incrementOffer(step: 25);
    expect(c.offerNaira, 25);
  });
}

