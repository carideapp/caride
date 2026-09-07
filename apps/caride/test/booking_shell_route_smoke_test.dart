import 'package:caride/features/ride_booking/booking_shell/booking_shell_screen.dart';
import 'package:caride/router/customer_route_factory.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('customer route factory builds BookingShell for rideSetPrice', (tester) async {
    final delegates = buildCustomerRouteDelegates();
    Widget? built;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            built = delegates.rideSetPrice(context, <String, dynamic>{});
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(built, isA<BookingShellScreen>());
  });
}
