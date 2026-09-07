import 'package:caride/features/ride_booking/booking_shell/models/booking_shell_step.dart';
import 'package:caride/features/ride_booking/data/ride_options_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking steps have stable order', () {
    expect(BookingShellStep.values, [
      BookingShellStep.fromTo,
      BookingShellStep.rideType,
      BookingShellStep.fare,
      BookingShellStep.bids,
      BookingShellStep.tracking,
    ]);
  });

  test('ride options include Regular/Comfort/Luxury/Courier', () {
    final types =
        RideOptionsRepository.fallbackOptions.map((o) => o.type).toList();
    expect(types, ['Regular', 'Comfort', 'Luxury', 'Courier']);
  });
}
