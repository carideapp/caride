import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:navigation/navigation.dart';

import '../auth/driver_auth_controller.dart';

String? driverAuthRedirect(GoRouterState state) {
  final location = state.matchedLocation;
  final isAuthenticated = driverAuthController.isAuthenticated;

  const unauthenticatedRoutes = <String>{
    DriverRoutePaths.splash,
    DriverRoutePaths.getStarted,
    DriverRoutePaths.login,
    DriverRoutePaths.signup,
    DriverRoutePaths.otp,
    DriverRoutePaths.forgotPassword,
    DriverRoutePaths.registerSuccess,
  };

  if (!isAuthenticated && !unauthenticatedRoutes.contains(location)) {
    return DriverRoutePaths.login;
  }

  if (isAuthenticated && unauthenticatedRoutes.contains(location)) {
    return DriverRoutePaths.home;
  }

  return null;
}

/// Extended redirect that also checks driver approval status from Firestore.
/// Wraps [driverAuthRedirect] with async profile check.
Future<String?> driverAuthRedirectAsync(GoRouterState state) async {
  final basicRedirect = driverAuthRedirect(state);
  if (basicRedirect != null) return basicRedirect;

  final uid = driverAuthController.currentUid;
  if (uid == null) return null;

  final location = state.matchedLocation;

  try {
    final doc = await FirebaseFirestore.instance.collection('drivers').doc(uid).get();
    if (!doc.exists) return null;

    final approvalStatus = doc.data()?['approvalStatus'] as String? ?? 'draft';
    final profileCompleted = doc.data()?['profileCompleted'] as bool? ?? false;

    if (!profileCompleted && location != DriverRoutePaths.onboarding) {
      return DriverRoutePaths.onboarding;
    }

    if (approvalStatus == 'draft' && location == DriverRoutePaths.pendingApproval) {
      return DriverRoutePaths.profileVehicle;
    }

    if (approvalStatus == 'approved' &&
        location == DriverRoutePaths.pendingApproval) {
      return DriverRoutePaths.home;
    }
  } catch (_) {}

  return null;
}
