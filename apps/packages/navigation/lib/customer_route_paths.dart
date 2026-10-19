/// Deep-link-friendly paths for the customer app.
abstract final class CustomerRoutePaths {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const welcome = '/welcome';
  static const login = '/login';
  static const signup = '/signup';
  static const otp = '/otp';
  static const completeProfile = '/complete-profile';
  static const forgotPassword = '/forgot-password';
  static const roleSelector = '/role-selector';

  static const home = '/home';
  static const chat = '/chat';
  static const wallet = '/profile/wallet';
  static const activity = '/activity';
  static const walletFund = '/wallet/fund';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const savedAddresses = '/profile/saved-addresses';
  static const addAddress = '/profile/saved-addresses/add';
  static const editAddress = '/profile/saved-addresses/edit';
  static const rideHistory = '/profile/history';
  static const ratings = '/profile/ratings';
  static const typeAmount = '/profile/top-up';
  static const paymentMethod = '/profile/top-up/payment';
  static const topUpWebview = '/profile/top-up/webview';
  static const viewPaymentMethods = '/profile/payment-methods';
  static const addNewPayment = '/profile/payment-methods/add';
  static const accountSecurity = '/profile/security';
  static const linkedAccounts = '/profile/linked-accounts';
  static const dataAnalytics = '/profile/data-analytics';
  static const dataUsage = '/profile/data-analytics/data-usage';
  static const downloadData = '/profile/data-analytics/download-data';
  static const appAppearance = '/profile/appearance';
  static const appLanguage = '/profile/appearance/language';
  static const referral = '/profile/referral';
  static const deviceManagement = '/profile/security/device-management';
  static const helpSupport = '/profile/help-support';
  static const supportChat = '/profile/help-support/chat';
  static const legal = '/profile/legal';
  static const riderTerms = '/profile/legal/terms';
  static const riderPrivacy = '/profile/legal/privacy';

  static const rideSetPrice = '/ride/set-price';
  static const sendItems = '/send-items';
  static const rideOffers = '/ride/offers';
  static const selectDriver = '/ride/select-driver';
  static const rideTrack = '/ride/track';
  static const driverTracking = '/ride/driver-tracking';
  static const shareReceipt = '/ride/share-receipt';
  static const monitorTripEntry = '/profile/monitor-trip-entry';
  static const monitorTrip = '/profile/monitor-trip';
  static const becomeDriver = '/profile/become-driver';
  static const securityPin = '/profile/security/pin';
  static const withdraw = '/profile/wallet/withdraw';
  static const withdrawAmount = '/profile/wallet/withdraw/amount';
  static const withdrawPin = '/profile/wallet/withdraw/pin';
  static const withdrawSuccess = '/profile/wallet/withdraw/success';

  // ── Car Rental Booking Flow ────────────────────────────────────────────────
  static const rentalBrowse = '/rental/browse';
  static const popularCars = '/rental/popular';
  static const rentalVehicleDetail = '/rental/vehicle';
  static const vehicleDetailsRating = '/rental/vehicle/reviews';
  static const rentalBookingForm = '/rental/booking';
  static const rentalBookingSummary = '/rental/summary';
  static const rentalBookings = '/rental/bookings';
  static const rentalBookingDetails = '/rental/booking-details';
  static const rentalPayment = '/rental/payment';

  // ── Educational / Blog Article Reader ─────────────────────────────────────
  static const forYouPosts = '/for-you/posts';
  static const forYouDetail = '/for-you/detail';
}
