import 'package:flutter/material.dart';
import 'package:caride/features/driver/auth/driver_forgot_password_screen.dart';
import 'package:caride/features/driver/auth/driver_get_started_screen.dart';
import 'package:caride/features/driver/auth/driver_login_screen.dart';
import 'package:caride/features/driver/auth/driver_otp_screen.dart';
import 'package:caride/features/driver/auth/driver_pending_approval_screen.dart';
import 'package:caride/features/driver/auth/driver_register_success_screen.dart';
import 'package:caride/features/driver/auth/driver_signup_screen.dart';
import 'package:caride/features/driver/auth/driver_splash_screen.dart';
import 'package:caride/features/driver/chat/driver_chat_screen.dart';
import 'package:caride/features/driver/chat/driver_conversation_screen.dart';
import 'package:caride/features/driver/home/driver_home_screen.dart';
import 'package:caride/features/driver/notifications/driver_notification_screen.dart';
import 'package:caride/features/driver/profile/driver_about_screen.dart';
import 'package:caride/features/driver/profile/driver_basic_info_screen.dart';
import 'package:caride/features/driver/profile/driver_document_upload_screen.dart';
import 'package:caride/features/driver/profile/driver_documents_screen.dart';
import 'package:caride/features/driver/profile/driver_profile_picture_screen.dart';
import 'package:caride/features/driver/profile/driver_support_screen.dart';
import 'package:caride/features/driver/profile/driver_vehicle_info_screen.dart';
import 'package:caride/features/driver/profile/driver_help_faq_screen.dart';
import 'package:caride/features/driver/profile/driver_privacy_policy_screen.dart';
import 'package:caride/features/driver/profile/driver_profile_detail_screen.dart';
import 'package:caride/features/driver/profile/driver_profile_screen.dart';
import 'package:caride/features/driver/profile/driver_ratings_screen.dart';
import 'package:caride/features/driver/profile/driver_referral_screen.dart';
import 'package:caride/features/driver/profile/driver_ride_history_screen.dart';
import 'package:caride/features/driver/profile/driver_tiers_screen.dart';
import 'package:caride/features/driver/profile/driver_vehicle_screen.dart';
import 'package:caride/features/driver/profile/driver_account_security_screen.dart';
import 'package:caride/features/driver/profile/driver_linked_fleets_screen.dart';
import 'package:caride/features/driver/profile/driver_fleet_profile_view_screen.dart';
import 'package:caride/features/driver/profile/become_customer_benefits_screen.dart';
import 'package:shared_models/shared_models.dart';
import 'package:caride/features/driver/requests/incoming_requests_screen.dart';
import 'package:caride/features/driver/rides/driver_rides_screen.dart';
import 'package:caride/features/driver/rides/driver_ride_detail_screen.dart';
import 'package:caride/features/driver/trip/driver_leave_a_rate.dart';
import 'package:caride/features/driver/requests/request_detail_screen.dart';
import 'package:caride/features/driver/shell/driver_main_shell.dart';
import 'package:caride/features/driver/trip/trip_active_screen.dart';
import 'package:caride/features/driver/trip/trip_complete_screen.dart';
import 'package:caride/features/driver/trip/trip_pickup_screen.dart';
import 'package:caride/features/driver/wallet/driver_bank_account_screen.dart';
import 'package:caride/features/driver/wallet/driver_wallet_screen.dart';
import 'package:caride/features/driver/rental/driver_rental_bookings_screen.dart';
import 'package:caride/features/driver/rental/driver_rental_trip_screen.dart';
import 'package:navigation/navigation.dart';

DriverRouteDelegates buildDriverRouteDelegates() {
  return DriverRouteDelegates(
    splash: (_) => const DriverSplashScreen(),
    getStarted: (_) => const DriverGetStartedScreen(),
    login: (_) => const DriverLoginScreen(),
    signup: (_) => const DriverSignupScreen(),
    otp: (_) => const DriverOtpScreen(),
    registerSuccess: (_) => const DriverRegisterSuccessScreen(),
    forgotPassword: (_) => const DriverForgotPasswordScreen(),
    onboarding: (_) => const SizedBox.shrink(),
    pendingApproval: (_) => const DriverPendingApprovalScreen(),
    mainShell: (context, shell) => DriverMainShell(navigationShell: shell),
    home: (_) => const DriverHomeScreen(),
    notifications: (_) => const DriverNotificationScreen(),
    chat: (_) => const DriverChatScreen(),
    conversation: (context, extra) => DriverConversationScreen(
      customerName: (extra?['customerName'] as String?) ?? 'Customer',
      rideId: extra?['rideId'] as String?,
    ),
    rides: (_) => const DriverRidesScreen(),
    rideDetail: (context, rideId) => DriverRideDetailScreen(rideId: rideId),
    wallet: (_) => const DriverWalletScreen(),
    walletBankAccount: (_) => const DriverBankAccountScreen(),
    profile: (_) => const DriverProfileScreen(),
    profileHistory: (_) => const DriverRideHistoryScreen(),
    profileRatings: (_) => const DriverRatingsScreen(),
    profileDetail: (_) => const DriverProfileDetailScreen(),
    profileDocuments: (_) => const DriverDocumentsScreen(),
    profileVehicle: (_) => const DriverVehicleScreen(),
    helpFaq: (_) => const DriverHelpFaqScreen(),
    privacyPolicy: (_) => const DriverPrivacyPolicyScreen(),
    aboutApp: (_) => const DriverAboutScreen(),
    requests: (_) => const IncomingRequestsScreen(),
    requestDetail: (_) => const RequestDetailScreen(),
    tripPickup: (_) => const TripPickupScreen(),
    tripActive: (_) => const TripActiveScreen(),
    tripComplete: (_) => const TripCompleteScreen(),
    rateCustomer: (_) => const DriverLeaveARateScreen(),
    documentUpload: (context, title, documentType) {
      return DriverDocumentUploadScreen(
        docTitle: title,
        documentType: documentType,
      );
    },
    profileBasicInfo: (_) => const DriverBasicInfoScreen(),
    profilePicture: (_) => const DriverProfilePictureScreen(),
    helpSupport: (_) => const DriverSupportScreen(),
    vehicleInfo: (_) => const DriverVehicleInfoScreen(),
    profileTiers: (_) => const DriverTiersScreen(),
    referral: (_) => const DriverReferralScreen(),
    becomeCustomer: (_) => const BecomeCustomerBenefitsScreen(),
    accountSecurity: (_) => const DriverAccountSecurityScreen(),
    linkedFleets: (_) => const DriverLinkedFleetsScreen(),
    fleetProfileView: (context, extra) {
      if (extra is FleetProfile) {
        return DriverFleetProfileViewScreen(fleet: extra);
      }
      return const DriverLinkedFleetsScreen();
    },
    rentalBookings: (_) => const DriverRentalBookingsScreen(),
    rentalTrip: (context, dynamic extra) {
      if (extra is RentalBooking) {
        return DriverRentalTripScreen(booking: extra);
      }
      return const DriverRentalBookingsScreen();
    },
  );
}
