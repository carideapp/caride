import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Route delegates for the driver application.
class DriverRouteDelegates {
  const DriverRouteDelegates({
    required this.splash,
    required this.getStarted,
    required this.login,
    required this.signup,
    required this.otp,
    required this.registerSuccess,
    required this.forgotPassword,
    required this.onboarding,
    required this.pendingApproval,
    required this.mainShell,
    required this.home,
    required this.notifications,
    required this.chat,
    required this.conversation,
    required this.rides,
    required this.rideDetail,
    required this.wallet,
    required this.walletBankAccount,
    required this.profile,
    required this.profileHistory,
    required this.profileRatings,
    required this.profileDetail,
    required this.profileDocuments,
    required this.profileVehicle,
    required this.helpFaq,
    required this.privacyPolicy,
    required this.aboutApp,
    required this.requests,
    required this.requestDetail,
    required this.tripPickup,
    required this.tripActive,
    required this.tripComplete,
    required this.rateCustomer,
    required this.documentUpload,
    required this.profileBasicInfo,
    required this.profilePicture,
    required this.helpSupport,
    required this.vehicleInfo,
    required this.profileTiers,
    required this.referral,
    required this.becomeCustomer,
    this.accountSecurity,
    this.linkedFleets,
    this.fleetProfileView,
    this.rentalBookings,
    this.rentalTrip,
  });

  final WidgetBuilder splash;
  final WidgetBuilder getStarted;
  final WidgetBuilder login;
  final WidgetBuilder signup;
  final WidgetBuilder otp;
  final WidgetBuilder registerSuccess;
  final WidgetBuilder forgotPassword;
  final WidgetBuilder onboarding;
  final WidgetBuilder pendingApproval;

  final Widget Function(BuildContext context, StatefulNavigationShell shell)
      mainShell;

  final WidgetBuilder home;
  final WidgetBuilder notifications;
  final WidgetBuilder chat;
  final Widget Function(BuildContext context, Map<String, dynamic>? extra)
      conversation;
  final WidgetBuilder rides;
  final Widget Function(BuildContext context, String? rideId) rideDetail;
  final WidgetBuilder wallet;
  final WidgetBuilder walletBankAccount;
  final WidgetBuilder profile;
  final WidgetBuilder profileHistory;
  final WidgetBuilder profileRatings;
  final WidgetBuilder profileDetail;
  final WidgetBuilder profileDocuments;
  final WidgetBuilder profileVehicle;
  final WidgetBuilder helpFaq;
  final WidgetBuilder privacyPolicy;
  final WidgetBuilder aboutApp;

  final WidgetBuilder requests;
  final WidgetBuilder requestDetail;
  final WidgetBuilder tripPickup;
  final WidgetBuilder tripActive;
  final WidgetBuilder tripComplete;
  final WidgetBuilder rateCustomer;
  final Widget Function(
    BuildContext context,
    String docTitle,
    String? documentType,
  ) documentUpload;
  final WidgetBuilder profileBasicInfo;
  final WidgetBuilder profilePicture;
  final WidgetBuilder helpSupport;
  final WidgetBuilder vehicleInfo;
  final WidgetBuilder profileTiers;
  final WidgetBuilder referral;
  final WidgetBuilder becomeCustomer;
  final WidgetBuilder? accountSecurity;
  final WidgetBuilder? linkedFleets;
  final Widget Function(BuildContext context, dynamic extra)? fleetProfileView;
  final WidgetBuilder? rentalBookings;
  final Widget Function(BuildContext context, dynamic extra)? rentalTrip;
}
