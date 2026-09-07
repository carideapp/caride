import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('setOffer clamps negatives to zero', () {
    final c = BookingShellController.forTest(extra: null);
    c.setOffer(-10);
    expect(c.offerNaira, 0);
  });
}

