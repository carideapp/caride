import 'package:flutter/material.dart';
import 'package:caride/features/auth/forgot_password_screen.dart';
import 'package:caride/features/auth/login_screen.dart';
import 'package:caride/features/auth/otp_screen.dart';
import 'package:caride/features/auth/signup_screen.dart';
import 'package:caride/features/auth/splash_screen.dart';
import 'package:caride/features/auth/onboarding_screen.dart';
import 'package:caride/features/auth/welcome_screen.dart';
import 'package:caride/features/chat/chat_screen.dart';
import 'package:caride/features/home_map/customer_home_screen.dart';
import 'package:caride/features/profile/account_screen.dart';
import 'package:caride/features/profile/edit_profile_screen.dart';
import 'package:caride/features/profile/become_driver_benefits_screen.dart';
import 'package:caride/features/profile/referral_screen.dart';
import 'package:caride/features/profile/ratings_screen.dart';
import 'package:caride/features/profile/saved_address_screen.dart';
import 'package:caride/features/profile/add_an_address_screen.dart';
import 'package:caride/features/profile/edit_saved_address_screen.dart';
import 'package:caride/features/profile/ride_history_screen.dart';
import 'package:caride/features/profile/type_amount_screen.dart';
import 'package:caride/features/profile/driver_tracking_screen.dart';
import 'package:caride/features/profile/share_receipt_screen.dart';
import 'package:caride/features/profile/webview_screen.dart';
import 'package:caride/features/profile/view_payment_method_screen.dart';
import 'package:caride/features/profile/add_new_payment_screen.dart';
import 'package:caride/features/profile/account_security_screen.dart';
import 'package:caride/features/profile/linked_accounts_screen.dart';
import 'package:caride/features/profile/data_analytics_screen.dart';
import 'package:caride/features/profile/data_usage_screen.dart';
import 'package:caride/features/profile/download_data_screen.dart';
import 'package:caride/features/profile/app_appearance_screen.dart';
import 'package:caride/features/profile/app_language_screen.dart';
import 'package:caride/features/profile/device_management_screen.dart';
import 'package:caride/features/profile/help_support_screen.dart';
import 'package:caride/features/profile/customer_support_screen.dart';
import 'package:caride/features/profile/legal_screen.dart';
import 'package:caride/features/profile/rider_terms_screen.dart';
import 'package:caride/features/profile/rider_privacy_policy_screen.dart';
import 'package:caride/features/ride_booking/booking_shell/booking_shell_screen.dart';
import 'package:caride/features/send_items/send_items_shell_screen.dart';
import 'package:caride/features/ride_booking/offer_fare_screen.dart';
import 'package:caride/features/ride_booking/select_driver_screen.dart';
import 'package:caride/features/ride_booking/ride_track_screen.dart';
import 'package:caride/features/shell/customer_main_shell.dart';
import 'package:caride/features/wallet/wallet_screen.dart';
import 'package:caride/features/wallet/top_up_method_screen.dart';
import 'package:caride/features/profile/monitor_trip_entry_screen.dart';
import 'package:caride/features/profile/monitor_trip_screen.dart';
import 'package:caride/features/auth/role_selector_screen.dart';
import 'package:caride/router/driver_route_factory.dart';
import 'package:caride/features/profile/security_pin_screen.dart';
import 'package:caride/features/wallet/withdraw_bank_details_screen.dart';
import 'package:caride/features/wallet/withdraw_amount_screen.dart';
import 'package:caride/features/wallet/withdraw_pin_screen.dart';
import 'package:caride/features/wallet/withdraw_success_screen.dart';
import 'package:caride/features/wallet/data/withdraw_repository.dart';
import 'package:caride/features/fleet_manager/presentation/screens/fleet_onboarding_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/fleet_dashboard_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/fleet_vehicles_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/add_edit_vehicle_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/fleet_bookings_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/fleet_booking_detail_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/fleet_drivers_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/fleet_profile_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/fleet_profile_details_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/fleet_business_info_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/fleet_verification_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/fleet_appearance_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/fleet_notifications_settings_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/fleet_settings_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/fleet_wallet_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/fleet_transaction_history_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/fleet_legal_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/fleet_help_faqs_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/fleet_support_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/fleet_support_conversation_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/legal/fleet_terms_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/legal/fleet_rental_protocol_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/legal/fleet_insurance_policy_screen.dart';
import 'package:caride/features/fleet_manager/presentation/screens/legal/fleet_privacy_policy_screen.dart';
import 'package:caride/features/fleet_manager/auth/fleet_manager_login_screen.dart';
import 'package:caride/features/fleet_manager/auth/fleet_manager_signup_screen.dart';
import 'package:caride/features/fleet_manager/auth/fleet_manager_otp_screen.dart';
import 'package:caride/features/fleet_manager/auth/fleet_manager_signup_success_screen.dart';
import 'package:caride/features/fleet_manager/auth/fleet_manager_review_status_screen.dart';
import 'package:caride/features/fleet_manager/auth/fleet_manager_forgot_password_screen.dart';
import 'package:shared_models/shared_models.dart';
import 'package:navigation/navigation.dart';

CustomerRouteDelegates buildCustomerRouteDelegates() {
  return CustomerRouteDelegates(
    roleSelector: (_) => const RoleSelectorScreen(),
    driverDelegates: buildDriverRouteDelegates(),
    splash: (_) => const SplashScreen(),
    onboarding: (_) => const OnboardingScreen(),
    welcome: (_) => const WelcomeScreen(),
    login: (_) => const LoginScreen(),
    signup: (_) => const SignupScreen(),
    otp: (_) => const OtpScreen(),
    completeProfile: (_) => const SizedBox.shrink(),
    forgotPassword: (_) => const ForgotPasswordScreen(),
    becomeDriver: (_) => const BecomeDriverBenefitsScreen(),
    mainShell: (context, shell) => CustomerMainShell(navigationShell: shell),
    home: (_) => const CustomerHomeScreen(),
    chat: (_) => const ChatScreen(),
    wallet: (_) => const WalletScreen(),
    activity: (_) => const RideHistoryScreen(),
    profile: (_) => const AccountScreen(),
    editProfile: (_) => const EditProfileScreen(),
    referral: (_) => const ReferralScreen(),
    savedAddresses: (_) => const SavedAddressScreen(),
    addAddress: (_) => const AddAnAddressScreen(),
    editAddress: (_) => const EditSavedAddressScreen(),
    walletFund: (_) => const TypeAmountScreen(), // Replaced
    rideHistory: (_) => const RideHistoryScreen(),
    ratings: (_) => const RatingsScreen(),
    typeAmount: (_) => const TypeAmountScreen(),
    paymentMethod: (context, dynamic extra) {
      final amount = extra is double ? extra : 0.0;
      return TopUpMethodScreen(amountNaira: amount);
    },
    topUpWebview: (context, dynamic extra) {
      if (extra is Map<String, dynamic>) {
        return WebviewScreen(params: extra);
      }
      final amount = extra is double ? extra : 0.0;
      return WebviewScreen(amount: amount);
    },
    viewPaymentMethods: (_) => const ViewPaymentMethodScreen(),
    addNewPayment: (_) => const AddNewPaymentScreen(),
    accountSecurity: (_) => const AccountSecurityScreen(),
    linkedAccounts: (_) => const LinkedAccountsScreen(),
    dataAnalytics: (_) => const DataAnalyticsScreen(),
    dataUsage: (_) => const DataUsageScreen(),
    downloadData: (_) => const DownloadDataScreen(),
    appAppearance: (_) => const AppAppearanceScreen(),
    appLanguage: (_) => const AppLanguageScreen(),
    deviceManagement: (_) => const DeviceManagementScreen(),
    helpSupport: (_) => const HelpSupportScreen(),
    supportChat: (_) => const CustomerSupportScreen(),
    legal: (_) => const LegalScreen(),
    riderTerms: (_) => const RiderTermsScreen(),
    riderPrivacy: (_) => const RiderPrivacyPolicyScreen(),
    rideSetPrice: (context, dynamic extra) => BookingShellScreen(
      extra: extra is Map<String, dynamic> ? extra : null,
    ),
    sendItems: (context, dynamic extra) => SendItemsShellScreen(
      extra: extra is Map<String, dynamic> ? extra : null,
    ),
    rideOffers: (context, dynamic extra) => OfferFareScreen(params: extra is Map<String, dynamic> ? extra : null),
    rideTrack: (context, dynamic extra) => RideTrackScreen(params: extra is Map<String, dynamic> ? extra : null),
    selectDriver: (context, dynamic extra) => SelectDriverScreen(params: extra is Map<String, dynamic> ? extra : null),
    driverTracking: (_) => const DriverTrackingScreen(),
    shareReceipt: (_) => const ShareReceiptScreen(),
    monitorTripEntry: (_) => const MonitorTripEntryScreen(),
    monitorTrip: (context, dynamic extra) => MonitorTripScreen(params: extra is Map<String, dynamic> ? extra : null),
    securityPin: (_) => const SecurityPinScreen(),
    withdraw: (_) => const WithdrawBankDetailsScreen(),
    withdrawAmount: (_) => const WithdrawAmountScreen(resolved: ResolvedAccount(accountName: '', accountNumber: '', bankCode: '', bankName: '')), // fallbacks, though we push with standard Navigator context
    withdrawPin: (_) => const WithdrawPinScreen(resolved: ResolvedAccount(accountName: '', accountNumber: '', bankCode: '', bankName: ''), amountNaira: 0.0),
    withdrawSuccess: (_) => const WithdrawSuccessScreen(resolved: ResolvedAccount(accountName: '', accountNumber: '', bankCode: '', bankName: ''), amountNaira: 0.0, reference: ''),
    fleetLogin: (_) => const FleetManagerLoginScreen(),
    fleetSignup: (_) => const FleetManagerSignupScreen(),
    fleetOtp: (_) => const FleetManagerOtpScreen(),
    fleetRegisterSuccess: (_) => const FleetManagerSignupSuccessScreen(),
    fleetReviewStatus: (_) => const FleetManagerReviewStatusScreen(),
    fleetForgotPassword: (_) => const FleetManagerForgotPasswordScreen(),
    fleetOnboarding: (_) => const FleetOnboardingScreen(),
    fleetDashboard: (_) => const FleetDashboardScreen(),
    fleetVehicles: (_) => const FleetVehiclesScreen(),
    fleetAddVehicle: (_) => const AddEditVehicleScreen(),
    fleetEditVehicle: (context, dynamic extra) => AddEditVehicleScreen(
      vehicle: extra is RentalVehicle ? extra : null,
    ),
    fleetBookings: (_) => const FleetBookingsScreen(),
    fleetBookingDetail: (context, dynamic extra) {
      if (extra is RentalBooking) {
        return FleetBookingDetailScreen(booking: extra);
      }
      return const FleetBookingsScreen();
    },
    fleetDrivers: (_) => const FleetDriversScreen(),
    fleetProfile: (_) => const FleetProfileScreen(),
    fleetProfileDetails: (_) => const FleetProfileDetailsScreen(),
    fleetBusinessInfo: (_) => const FleetBusinessInfoScreen(),
    fleetVerification: (_) => const FleetVerificationScreen(),
    fleetWallet: (_) => const FleetWalletScreen(),
    fleetTransactionHistory: (_) => const FleetTransactionHistoryScreen(),
    fleetSettings: (_) => const FleetSettingsScreen(),
    fleetAppearance: (_) => const FleetAppearanceScreen(),
    fleetNotifications: (_) => const FleetNotificationsSettingsScreen(),
    fleetLegal: (_) => const FleetLegalScreen(),
    fleetLegalTerms: (_) => const FleetTermsScreen(),
    fleetLegalRentalProtocol: (_) => const FleetRentalProtocolScreen(),
    fleetLegalInsurancePolicy: (_) => const FleetInsurancePolicyScreen(),
    fleetLegalPrivacyPolicy: (_) => const FleetPrivacyPolicyScreen(),
    fleetHelpFaqs: (_) => const FleetHelpFaqsScreen(),
    fleetSupport: (_) => const FleetSupportScreen(),
    fleetSupportConversation: (context, dynamic extra) => FleetSupportConversationScreen(
      ticketId: extra is String ? extra : (extra is Map ? extra['ticketId'] ?? '' : ''),
    ),
  );
}
