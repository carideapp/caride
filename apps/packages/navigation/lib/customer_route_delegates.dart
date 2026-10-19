import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'driver_route_delegates.dart';

/// Screen factories for the customer app — keeps `navigation` free of app imports.
class CustomerRouteDelegates {
  const CustomerRouteDelegates({
    required this.splash,
    required this.onboarding,
    required this.welcome,
    required this.login,
    required this.signup,
    required this.otp,
    required this.completeProfile,
    required this.forgotPassword,
    required this.mainShell,
    required this.home,
    this.chat,
    this.wallet,
    required this.activity,
    required this.profile,
    required this.editProfile,
    required this.savedAddresses,
    required this.addAddress,
    required this.editAddress,
    required this.walletFund,
    required this.rideHistory,
    required this.ratings,
    required this.typeAmount,
    required this.paymentMethod,
    required this.topUpWebview,
    required this.viewPaymentMethods,
    required this.addNewPayment,
    required this.accountSecurity,
    required this.linkedAccounts,
    required this.dataAnalytics,
    required this.dataUsage,
    required this.downloadData,
    required this.appAppearance,
    required this.appLanguage,
    required this.referral,
    required this.deviceManagement,
    required this.helpSupport,
    required this.supportChat,
    required this.rideSetPrice,
    required this.rideOffers,
    required this.rideTrack,
    required this.selectDriver,
    required this.driverTracking,
    required this.shareReceipt,
    required this.monitorTripEntry,
    required this.monitorTrip,
    required this.roleSelector,
    this.becomeDriver,
    this.driverDelegates,
    this.securityPin,
    this.withdraw,
    this.withdrawAmount,
    this.withdrawPin,
    this.withdrawSuccess,
    this.sendItems,
    this.legal,
    this.riderTerms,
    this.riderPrivacy,
    this.fleetLogin,
    this.fleetSignup,
    this.fleetOtp,
    this.fleetRegisterSuccess,
    this.fleetReviewStatus,
    this.fleetForgotPassword,
    this.fleetOnboarding,
    this.fleetDashboard,
    this.fleetVehicles,
    this.fleetAddVehicle,
    this.fleetEditVehicle,
    this.fleetBookings,
    this.fleetBookingDetail,
    this.fleetDrivers,
    this.fleetProfile,
    this.fleetProfileDetails,
    this.fleetOperatingStates,
    this.fleetBusinessInfo,
    this.fleetViewBusinessInfo,
    this.fleetVerification,
    this.fleetWallet,
    this.fleetTransactionHistory,
    this.fleetSettings,
    this.fleetAppearance,
    this.fleetNotifications,
    this.fleetLegal,
    this.fleetLegalTerms,
    this.fleetLegalRentalProtocol,
    this.fleetLegalInsurancePolicy,
    this.fleetLegalPrivacyPolicy,
    this.fleetHelpFaqs,
    this.fleetSupport,
    this.fleetSupportConversation,
    this.fleetChat,
    this.fleetConversation,
    this.rentalBrowse,
    this.rentalVehicleDetail,
    this.vehicleDetailsRating,
    this.rentalBookingForm,
    this.rentalBookingSummary,
    this.rentalBookings,
    this.rentalBookingDetails,
    this.rentalPayment,
    this.popularCars,
    this.fleetReviews,
    this.forYouPosts,
    this.forYouDetail,
  }) : assert(
          chat != null || wallet != null,
          'Either chat or wallet delegate must be provided.',
        );

  final WidgetBuilder splash;
  final WidgetBuilder onboarding;
  final WidgetBuilder welcome;
  final WidgetBuilder login;
  final WidgetBuilder signup;
  final WidgetBuilder otp;
  final WidgetBuilder completeProfile;
  final WidgetBuilder forgotPassword;

  /// Wraps [StatefulNavigationShell] with bottom navigation / branch UI.
  final Widget Function(BuildContext context, StatefulNavigationShell shell)
      mainShell;

  final WidgetBuilder home;
  final WidgetBuilder? chat;
  // Backward-compatible alias for older call sites still using `wallet`.
  final WidgetBuilder? wallet;
  WidgetBuilder get chatOrWallet => chat ?? wallet!;
  final WidgetBuilder activity;
  final WidgetBuilder profile;
  final WidgetBuilder editProfile;
  final WidgetBuilder savedAddresses;
  final WidgetBuilder addAddress;
  final WidgetBuilder editAddress;
  final WidgetBuilder walletFund;
  final WidgetBuilder rideHistory;
  final WidgetBuilder ratings;
  final WidgetBuilder typeAmount;
  final Widget Function(BuildContext context, dynamic extra) paymentMethod;
  final Widget Function(BuildContext context, dynamic extra) topUpWebview;
  final WidgetBuilder viewPaymentMethods;
  final WidgetBuilder addNewPayment;
  final WidgetBuilder accountSecurity;
  final WidgetBuilder linkedAccounts;
  final WidgetBuilder dataAnalytics;
  final WidgetBuilder dataUsage;
  final WidgetBuilder downloadData;
  final WidgetBuilder appAppearance;
  final WidgetBuilder appLanguage;
  final WidgetBuilder referral;
  final WidgetBuilder deviceManagement;
  final WidgetBuilder helpSupport;
  final WidgetBuilder supportChat;
  final WidgetBuilder? legal;
  final WidgetBuilder? riderTerms;
  final WidgetBuilder? riderPrivacy;
  final Widget Function(BuildContext context, dynamic extra) rideSetPrice;
  final Widget Function(BuildContext context, dynamic extra) rideOffers;
  final Widget Function(BuildContext context, dynamic extra) rideTrack;
  final Widget Function(BuildContext context, dynamic extra) selectDriver;
  final WidgetBuilder driverTracking;
  final WidgetBuilder shareReceipt;
  final WidgetBuilder monitorTripEntry;
  final Widget Function(BuildContext context, dynamic extra) monitorTrip;
  final WidgetBuilder roleSelector;
  final WidgetBuilder? becomeDriver;
  final DriverRouteDelegates? driverDelegates;
  final WidgetBuilder? securityPin;
  final WidgetBuilder? withdraw;
  final WidgetBuilder? withdrawAmount;
  final WidgetBuilder? withdrawPin;
  final WidgetBuilder? withdrawSuccess;
  final Widget Function(BuildContext context, dynamic extra)? sendItems;
  final WidgetBuilder? fleetLogin;
  final WidgetBuilder? fleetSignup;
  final WidgetBuilder? fleetOtp;
  final WidgetBuilder? fleetRegisterSuccess;
  final WidgetBuilder? fleetReviewStatus;
  final WidgetBuilder? fleetForgotPassword;
  final WidgetBuilder? fleetOnboarding;
  final WidgetBuilder? fleetDashboard;
  final WidgetBuilder? fleetVehicles;
  final WidgetBuilder? fleetAddVehicle;
  final Widget Function(BuildContext context, dynamic extra)? fleetEditVehicle;
  final WidgetBuilder? fleetBookings;
  final Widget Function(BuildContext context, dynamic extra)? fleetBookingDetail;
  final WidgetBuilder? fleetDrivers;
  final WidgetBuilder? fleetProfile;
  final WidgetBuilder? fleetProfileDetails;
  final WidgetBuilder? fleetOperatingStates;
  final WidgetBuilder? fleetBusinessInfo;
  final WidgetBuilder? fleetViewBusinessInfo;
  final WidgetBuilder? fleetVerification;
  final WidgetBuilder? fleetWallet;
  final WidgetBuilder? fleetTransactionHistory;
  final WidgetBuilder? fleetSettings;
  final WidgetBuilder? fleetAppearance;
  final WidgetBuilder? fleetNotifications;
  final WidgetBuilder? fleetLegal;
  final WidgetBuilder? fleetLegalTerms;
  final WidgetBuilder? fleetLegalRentalProtocol;
  final WidgetBuilder? fleetLegalInsurancePolicy;
  final WidgetBuilder? fleetLegalPrivacyPolicy;
  final WidgetBuilder? fleetHelpFaqs;
  final WidgetBuilder? fleetSupport;
  final Widget Function(BuildContext context, dynamic extra)? fleetSupportConversation;
  final WidgetBuilder? fleetChat;
  final Widget Function(BuildContext context, dynamic extra)? fleetConversation;

  // ── Car Rental Booking Flow ───────────────────────────────────────────────
  final WidgetBuilder? rentalBrowse;
  final Widget Function(BuildContext context, dynamic extra)? rentalVehicleDetail;
  final Widget Function(BuildContext context, dynamic extra)? vehicleDetailsRating;
  final Widget Function(BuildContext context, dynamic extra)? rentalBookingForm;
  final Widget Function(BuildContext context, dynamic extra)? rentalBookingSummary;
  final WidgetBuilder? rentalBookings;
  final Widget Function(BuildContext context, dynamic extra)? rentalBookingDetails;
  final Widget Function(BuildContext context, dynamic extra)? rentalPayment;
  final WidgetBuilder? popularCars;
  final WidgetBuilder? fleetReviews;

  // ── Educational / Blog Article Reader ─────────────────────────────────────
  final WidgetBuilder? forYouPosts;
  final Widget Function(BuildContext context, dynamic extra)? forYouDetail;
}
