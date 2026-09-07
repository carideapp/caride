import 'package:caride/core/ride/ride_lifecycle.dart';
import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:caride/features/ride_booking/booking_shell/models/booking_shell_step.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('status->step mapping: bidding goes to bids', () {
    expect(
      BookingShellController.stepForRideStatus('bidding'),
      BookingShellStep.bids,
    );
  });

  test('status->step mapping: driverEnRoute goes to tracking', () {
    expect(
      BookingShellController.stepForRideStatus('driverEnRoute'),
      BookingShellStep.tracking,
    );
  });

  test('cancel eligibility mirrors lifecycle helper', () {
    for (final s in activeRideStatuses) {
      expect(
        BookingShellController.customerCanCancelStatus(s),
        customerCanCancel(s),
      );
    }
  });
}
