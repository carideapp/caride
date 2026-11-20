import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:caride/core/driver/notifications/driver_alert_controller.dart';
import 'package:caride/core/driver/state/driver_active_ride_state.dart';
import 'package:navigation/navigation.dart';

class UnifiedNotificationRouter {
  UnifiedNotificationRouter._();

  static final UnifiedNotificationRouter instance =
      UnifiedNotificationRouter._();

  String? inferTargetRole(Map<String, dynamic> data) {
    final explicit = (data['targetRole'] ?? data['role'])
        ?.toString()
        .trim()
        .toLowerCase();
    if (explicit == 'driver' || explicit == 'customer' || explicit == 'fleet') {
      return explicit;
    }

    final type = (data['type'] ?? '').toString().trim().toLowerCase();
    switch (type) {
      case 'ride_request':
      case 'new_ride':
      case 'ride_offer':
      case 'ride_assigned':
      case 'ride_cancelled':
      case 'rental_booking_assigned':
        return 'driver';
      case 'ride_booked':
      case 'chat_message':
      case 'rental_booking_approved':
      case 'rental_booking_declined':
      case 'rental_driver_assigned':
      case 'rental_heading_to_pickup':
      case 'rental_trip_started':
      case 'rental_trip_completed':
      case 'rental_payment_confirmed':
        return 'customer';
      case 'fleet_booking':
      case 'fleet_payment':
      case 'fleet_review':
        return 'fleet';
      default:
        return null;
    }
  }

  Future<bool> handle({
    required GoRouter router,
    required Map<String, dynamic> data,
    bool switchRoleIfNeeded = true,
  }) async {
    final type = (data['type'] ?? '').toString().trim().toLowerCase();
    if (type.isEmpty || type == 'ride_alert_cancel') {
      return false;
    }

    final rideId = data['rideId']?.toString().trim();
    final targetRole = inferTargetRole(data);

    if (switchRoleIfNeeded && targetRole != null) {
      if (targetRole == 'driver') {
        if (!customerAuthController.driverExists ||
            customerAuthController.driverApprovalStatus != 'approved') {
          return false;
        }
        if (customerAuthController.activeRole != 'driver') {
          await customerAuthController.switchRole('driver');
        }
      } else if (targetRole == 'customer') {
        if (customerAuthController.activeRole != 'customer') {
          await customerAuthController.switchRole('customer');
        }
      } else if (targetRole == 'fleet') {
        if (!customerAuthController.fleetExists) {
          return false;
        }
        if (customerAuthController.activeRole != 'fleet') {
          await customerAuthController.switchRole('fleet');
        }
      }
    }

    final resolvedRole = targetRole ?? customerAuthController.activeRole;

    switch (type) {
      case 'ride_request':
      case 'new_ride':
      case 'ride_offer':
        DriverAlertController.instance.stopAlert(
          rideId: (rideId != null && rideId.isNotEmpty) ? rideId : null,
        );
        if (rideId != null && rideId.isNotEmpty) {
          router.go(DriverRoutePaths.requests);
          router.push(DriverRoutePaths.requestDetailFor(rideId));
        } else {
          router.go(DriverRoutePaths.requests);
        }
        return true;

      case 'ride_assigned':
        DriverAlertController.instance.stopAlert();
        if (rideId != null && rideId.isNotEmpty) {
          DriverActiveRideState.instance.activeRideId = rideId;
        }
        router.go(DriverRoutePaths.tripPickup);
        return true;

      case 'ride_started':
        if (resolvedRole == 'driver') {
          if (rideId != null && rideId.isNotEmpty) {
            DriverActiveRideState.instance.activeRideId = rideId;
          }
          router.go(DriverRoutePaths.tripActive);
          return true;
        }
        if (rideId != null && rideId.isNotEmpty) {
          router.go(
            CustomerRoutePaths.rideSetPrice,
            extra: <String, dynamic>{'rideId': rideId},
          );
          return true;
        }
        return false;

      case 'ride_completed':
        if (resolvedRole == 'driver') {
          router.go(DriverRoutePaths.tripComplete);
        } else {
          router.go(CustomerRoutePaths.rideHistory);
        }
        return true;

      case 'ride_cancelled':
        DriverAlertController.instance.stopAlert(
          rideId: (rideId != null && rideId.isNotEmpty) ? rideId : null,
        );
        if (resolvedRole == 'driver') {
          router.go(DriverRoutePaths.rides);
        } else {
          router.go(CustomerRoutePaths.home);
        }
        return true;

      case 'rental_booking_assigned':
        router.go(DriverRoutePaths.rentalBookings);
        return true;

      case 'ride_booked':
        if (rideId != null && rideId.isNotEmpty) {
          router.go(
            CustomerRoutePaths.rideSetPrice,
            extra: <String, dynamic>{'rideId': rideId},
          );
          return true;
        }
        return false;

      case 'chat_message':
        router.go(CustomerRoutePaths.chat);
        return true;

      case 'rental_booking_approved':
      case 'rental_booking_declined':
      case 'rental_driver_assigned':
      case 'rental_heading_to_pickup':
      case 'rental_trip_started':
      case 'rental_trip_completed':
      case 'rental_payment_confirmed':
        router.go(CustomerRoutePaths.rentalBookings);
        return true;

      case 'fleet_booking':
      case 'fleet_payment':
      case 'fleet_review':
        router.go(FleetRoutePaths.bookings);
        return true;

      default:
        return false;
    }
  }
}
