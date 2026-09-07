import 'package:caride/core/ride/ride_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('customerCanCancel allows until started', () {
    expect(customerCanCancel('requested'), true);
    expect(customerCanCancel('bidding'), true);
    expect(customerCanCancel('driverEnRoute'), true);
    expect(customerCanCancel('rideStarted'), false);
    expect(customerCanCancel('completed'), false);
    expect(customerCanCancel('cancelled'), false);
  });

  test('isActiveRideStatus matches active set', () {
    expect(isActiveRideStatus('requested'), true);
    expect(isActiveRideStatus('rideStarted'), true);
    expect(isActiveRideStatus('completed'), false);
  });
}

