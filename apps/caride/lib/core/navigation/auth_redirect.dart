import 'package:navigation/navigation.dart';
import '../auth/customer_auth_controller.dart';
import '../driver/auth/driver_auth_controller.dart';
import '../../features/fleet_manager/controllers/fleet_manager_controller.dart';
import '../../features/fleet_manager/auth/controllers/fleet_auth_controller.dart';

bool _hasShownSplash = false;

String? customerAuthRedirect(GoRouterState state) {
  if (!_hasShownSplash) {
    _hasShownSplash = true;
    return CustomerRoutePaths.splash;
  }
  final location = state.matchedLocation;
  final isAuthenticated = customerAuthController.isAuthenticated;

  // Guest-only routes that require or allow the user to be logged OUT.
  const guestOnlyRoutes = <String>{
    CustomerRoutePaths.onboarding,
    CustomerRoutePaths.welcome,
    CustomerRoutePaths.login,
    CustomerRoutePaths.signup,
    CustomerRoutePaths.otp,
    CustomerRoutePaths.forgotPassword,
    DriverRoutePaths.getStarted,
    DriverRoutePaths.login,
    DriverRoutePaths.signup,
    DriverRoutePaths.otp,
    DriverRoutePaths.forgotPassword,
    FleetRoutePaths.login,
    FleetRoutePaths.signup,
    FleetRoutePaths.otp,
    FleetRoutePaths.forgotPassword,
  };

  // Auth-required routes for Customer.
  const customerAuthRoutes = <String>{
    CustomerRoutePaths.home,
    CustomerRoutePaths.chat,
    CustomerRoutePaths.wallet,
    CustomerRoutePaths.activity,
    CustomerRoutePaths.profile,
    CustomerRoutePaths.completeProfile,
  };

  // Auth-required routes for Driver.
  const driverAuthRoutes = <String>{
    DriverRoutePaths.home,
    DriverRoutePaths.notifications,
    DriverRoutePaths.chat,
    DriverRoutePaths.rides,
    DriverRoutePaths.requests,
    DriverRoutePaths.profile,
    DriverRoutePaths.wallet,
    DriverRoutePaths.onboarding,
    DriverRoutePaths.pendingApproval,
  };

  // Auth-required routes for Fleet Manager.
  const fleetAuthRoutes = <String>{
    FleetRoutePaths.dashboard,
    FleetRoutePaths.vehicles,
    FleetRoutePaths.addVehicle,
    FleetRoutePaths.editVehicle,
    FleetRoutePaths.bookings,
    FleetRoutePaths.bookingDetail,
    FleetRoutePaths.drivers,
    FleetRoutePaths.onboarding,
    FleetRoutePaths.reviewStatus,
    FleetRoutePaths.registerSuccess,
    FleetRoutePaths.signup,
    FleetRoutePaths.otp,
    FleetRoutePaths.profile,
  };

  // Always allow staying on Role Selector Screen if navigated there or on app start
  if (location == CustomerRoutePaths.roleSelector) {
    return null;
  }

  // If the user is authenticated but the metadata has not loaded,
  // or if either auth controller is currently busy performing a sign in transaction,
  // hold redirects to prevent screen flashing. Return null so the user stays on
  // the login/loading screen until Firestore updates the activeRole.
  if (isAuthenticated && (!customerAuthController.profileLoaded || customerAuthController.isBusy || driverAuthController.isBusy || fleetAuthController.isBusy)) {
    return null;
  }

  if (isAuthenticated) {
    // 2. Route guards based on active role
    if (customerAuthController.activeRole == 'customer') {
      // If the user is on a fleet signup/OTP/onboarding path, allow it.
      // This covers the race condition where Firebase Auth fires before
      // Firestore 'users/{uid}' activeRole has been updated to 'fleet'.
      final isFleetSignupPath = location == FleetRoutePaths.signup ||
          location == FleetRoutePaths.otp ||
          location == FleetRoutePaths.registerSuccess ||
          location == FleetRoutePaths.reviewStatus ||
          location == FleetRoutePaths.onboarding;
      if (isFleetSignupPath) return null;

      if (!customerAuthController.isProfileComplete) {
        if (location != CustomerRoutePaths.completeProfile) {
          return CustomerRoutePaths.completeProfile;
        }
      } else {
        // Customer profile is complete
        final isDriverRoute = driverAuthRoutes.contains(location) || 
                              (location.startsWith('/driver') && !guestOnlyRoutes.contains(location));
        final isFleetProtected = (fleetAuthRoutes.contains(location) || location.startsWith('/fleet')) &&
                                 location != FleetRoutePaths.signup &&
                                 location != FleetRoutePaths.otp &&
                                 location != FleetRoutePaths.onboarding;
        if (guestOnlyRoutes.contains(location) || 
            location == CustomerRoutePaths.completeProfile ||
            isDriverRoute ||
            isFleetProtected) {
          return CustomerRoutePaths.home;
        }
      }
    } else if (customerAuthController.activeRole == 'driver') {
      // Driver profile
      final isCustomerRoute = customerAuthRoutes.contains(location) || 
                              (!location.startsWith('/driver') && !location.startsWith('/fleet') && location != CustomerRoutePaths.roleSelector && !guestOnlyRoutes.contains(location));
      if (guestOnlyRoutes.contains(location) || 
          location == DriverRoutePaths.onboarding || 
          location == DriverRoutePaths.pendingApproval ||
          isCustomerRoute) {
        return DriverRoutePaths.home;
      }
    } else if (customerAuthController.activeRole == 'fleet') {
      // Fleet profile
      final isFleetRoute = location.startsWith('/fleet') || fleetAuthRoutes.contains(location);
      final hasFleetProfile = customerAuthController.fleetExists || fleetManagerController.hasFleetProfile;

      // Allow registration, review-status, OTP, success, profile, and chat screens anytime in fleet mode
      if (location == FleetRoutePaths.signup ||
          location == FleetRoutePaths.otp ||
          location == FleetRoutePaths.registerSuccess ||
          location == FleetRoutePaths.reviewStatus ||
          location == FleetRoutePaths.onboarding ||
          location == CustomerRoutePaths.roleSelector ||
          location == CustomerRoutePaths.profile ||
          location == CustomerRoutePaths.chat) {
        return null;
      }

      if (guestOnlyRoutes.contains(location) || 
          (!isFleetRoute && location != CustomerRoutePaths.profile && location != CustomerRoutePaths.roleSelector && location != CustomerRoutePaths.chat)) {
        if (hasFleetProfile) {
          // Always allow direct access to Fleet Dashboard regardless of verificationStatus
          return FleetRoutePaths.dashboard;
        } else {
          return FleetRoutePaths.signup;
        }
      }
    }
  } else {
    // Unauthenticated user
    final isAuthRoute = customerAuthRoutes.contains(location) || 
                        driverAuthRoutes.contains(location) || 
                        (fleetAuthRoutes.contains(location) && location != FleetRoutePaths.signup && location != FleetRoutePaths.otp) ||
                        location == FleetRoutePaths.dashboard ||
                        location == FleetRoutePaths.vehicles ||
                        location == FleetRoutePaths.bookings ||
                        location == FleetRoutePaths.drivers ||
                        (location.startsWith('/driver') && !guestOnlyRoutes.contains(location));
    if (isAuthRoute) {
      return CustomerRoutePaths.welcome;
    }
  }

  return null;
}
