import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:caride/core/config/app_env.dart';
import 'package:caride/core/utils/disk_cache_manager.dart';

class DriverRentalTripScreen extends StatefulWidget {
  const DriverRentalTripScreen({super.key, required this.booking});

  final RentalBooking booking;

  @override
  State<DriverRentalTripScreen> createState() => _DriverRentalTripScreenState();
}

class _DriverRentalTripScreenState extends State<DriverRentalTripScreen> {
  late RentalBooking _booking;
  final TextEditingController _pinController = TextEditingController();

  bool _isProcessing = false;
  String? _errorMessage;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: AppEnv.firebaseFunctionsRegion);

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  String _parseErrorMessage(dynamic error) {
    if (error == null) return 'An unexpected error occurred. Please try again.';
    final str = error.toString().toLowerCase();

    if (str.contains('invalid-pin') || str.contains('invalid pin') || str.contains('incorrect-pin') || str.contains('pin')) {
      return 'Invalid 4-digit PIN. Please ask the customer for the correct start PIN displayed in their CaRide app.';
    }
    if (str.contains('not-found') || str.contains('booking-not-found')) {
      return 'Rental booking could not be found or has been modified. Please refresh your bookings.';
    }
    if (str.contains('unauthenticated') || str.contains('permission-denied')) {
      return 'Authentication session expired or unauthorized. Please sign in again.';
    }
    if (str.contains('network') || str.contains('unavailable') || str.contains('socketexception') || str.contains('timeout')) {
      return 'Network connection failure. Please check your internet connection and try again.';
    }
    if (str.contains('already-exists') || str.contains('invalid-state')) {
      return 'This rental trip status has already been updated.';
    }

    final clean = error
        .toString()
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll('FirebaseException:', '')
        .replaceAll('Exception:', '')
        .trim();
    if (clean.isNotEmpty) {
      return clean;
    }
    return 'Failed to complete operation. Please check your connection and try again.';
  }

  void _setError(String message) {
    setState(() => _errorMessage = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> _callCustomer() async {
    _clearError();
    final phone = _booking.customerPhone.trim();
    if (phone.isEmpty) {
      _setError('Customer phone number is not available for this booking.');
      return;
    }
    try {
      final uri = Uri.parse('tel:$phone');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _setError('Could not open phone dialer on your device.');
      }
    } catch (e) {
      _setError(_parseErrorMessage(e));
    }
  }

  Future<void> _openDirections(String location) async {
    _clearError();
    final loc = location.trim();
    if (loc.isEmpty) {
      _setError('Location address is missing or empty.');
      return;
    }
    try {
      final encoded = Uri.encodeComponent(loc);
      final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encoded');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        _setError('Could not open map directions application.');
      }
    } catch (e) {
      _setError(_parseErrorMessage(e));
    }
  }

  Future<void> _triggerHeadingToPickup() async {
    _clearError();
    setState(() => _isProcessing = true);
    try {
      final callable = _functions.httpsCallable('updateRentalTripStatus');
      await callable.call({
        'bookingId': _booking.id,
        'action': 'headingToPickup',
      });
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _booking = _booking.copyWith(rentalTripStatus: RentalTripStatus.headingToPickup);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Customer notified that you are heading to pickup!'),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _setError(_parseErrorMessage(e));
    }
  }

  Future<void> _startRideWithPin() async {
    _clearError();
    final pin = _pinController.text.trim();
    if (pin.length != 4) {
      _setError('Please enter the 4-digit start PIN provided by the customer.');
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final callable = _functions.httpsCallable('updateRentalTripStatus');
      await callable.call({
        'bookingId': _booking.id,
        'action': 'startRide',
        'pin': pin,
      });
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _booking = _booking.copyWith(
          status: RentalBookingStatus.inProgress,
          rentalTripStatus: RentalTripStatus.inProgress,
          startPinUsed: true,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('PIN verified! Rental ride has started.'),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _setError(_parseErrorMessage(e));
    }
  }

  void _showEndRideConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'End Rental Ride',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to end this rental ride for ${_booking.customerName}?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: () async {
                    Navigator.pop(bottomSheetContext);
                    await _executeEndRide();
                  },
                  child: const Text('Yes, End Rental Ride', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(bottomSheetContext),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _executeEndRide() async {
    _clearError();
    setState(() => _isProcessing = true);
    try {
      final callable = _functions.httpsCallable('updateRentalTripStatus');
      await callable.call({
        'bookingId': _booking.id,
        'action': 'endRide',
      });
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _booking = _booking.copyWith(
          status: RentalBookingStatus.completed,
          rentalTripStatus: RentalTripStatus.completed,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Rental ride completed successfully!'),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _setError(_parseErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('rental_bookings').doc(_booking.id).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists && snapshot.data!.data() != null) {
          _booking = RentalBooking.fromMap(snapshot.data!.data()!, snapshot.data!.id);
        }

        final isCompleted = _booking.status == RentalBookingStatus.completed;
        final isInProgress = _booking.status == RentalBookingStatus.inProgress;
        final isHeading = _booking.rentalTripStatus == RentalTripStatus.headingToPickup;
        final isAssigned = _booking.rentalTripStatus == RentalTripStatus.assigned ||
            (_booking.rentalTripStatus == null && !isInProgress && !isCompleted);

        // Step index: 0 = Assigned, 1 = En Route, 2 = In Progress, 3 = Completed
        int currentStep = 0;
        if (isCompleted) {
          currentStep = 3;
        } else if (isInProgress) {
          currentStep = 2;
        } else if (isHeading) {
          currentStep = 1;
        }

        final bookingShortId = '#CR-${_booking.id.length > 6 ? _booking.id.substring(0, 6).toUpperCase() : _booking.id.toUpperCase()}';

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          body: SafeArea(
            child: Column(
              children: [
                // ── Top Header Navigation Bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: primaryTextColor),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Active Rental Trip',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // In-View Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.error),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Action Required',
                                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.error, fontSize: 13),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _errorMessage!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? const Color(0xFFFECACA) : const Color(0xFF991B1B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _clearError,
                                  child: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // ── Card 1: Status Stepper & Action Module ──
                        _buildStatusStepperCard(
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                          currentStep: currentStep,
                          bookingShortId: bookingShortId,
                          isAssigned: isAssigned,
                          isHeading: isHeading,
                          isInProgress: isInProgress,
                          isCompleted: isCompleted,
                        ),
                        const SizedBox(height: 16),

                        // ── Card 2: Route Locations Card ──
                        _buildRouteCard(
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                        ),
                        const SizedBox(height: 16),

                        // ── Card 3: Dedicated Customer Info Card ──
                        _buildCustomerInfoCard(
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                        ),
                        const SizedBox(height: 16),

                        // ── Card 4: Rental Details & Summary Card ──
                        _buildRentalDetailsCard(
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusStepperCard({
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required int currentStep,
    required String bookingShortId,
    required bool isAssigned,
    required bool isHeading,
    required bool isInProgress,
    required bool isCompleted,
  }) {
    String headline;
    String subtext;

    if (isCompleted) {
      headline = 'Rental Completed';
      subtext = 'Trip has been successfully finished.';
    } else if (isInProgress) {
      headline = 'Rental In Progress';
      subtext = 'Chauffeur trip currently active with customer.';
    } else if (isHeading) {
      headline = 'Heading to Pickup';
      subtext = 'Go to pickup location to pick up customer.';
    } else {
      headline = 'Assigned Rental';
      subtext = 'Rental booking assigned to you.';
    }

    final steps = ['Assigned', 'En Route', 'In Progress', 'Completed'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row inside Card
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headline,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtext,
                      style: TextStyle(fontSize: 13, color: secondaryTextColor),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Booking ID',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: secondaryTextColor),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bookingShortId,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: primaryTextColor),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Horizontal Stepper
          Row(
            children: List.generate(steps.length, (index) {
              final isReached = index <= currentStep;
              final isCurrent = index == currentStep;
              final isLast = index == steps.length - 1;

              IconData icon;
              if (index == 0) {
                icon = Icons.assignment_turned_in_rounded;
              } else if (index == 1) {
                icon = Icons.directions_car_rounded;
              } else if (index == 2) {
                icon = Icons.navigation_rounded;
              } else {
                icon = Icons.check_circle_rounded;
              }

              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isReached
                                  ? AppColors.brand
                                  : (isDark ? Colors.white10 : const Color(0xFFF3F4F6)),
                              shape: BoxShape.circle,
                              border: isCurrent
                                  ? Border.all(color: AppColors.brand, width: 2)
                                  : null,
                            ),
                            child: Icon(
                              icon,
                              size: 18,
                              color: isReached ? Colors.white : secondaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            steps[index],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isReached ? FontWeight.w700 : FontWeight.w500,
                              color: isReached ? primaryTextColor : secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 16,
                        height: 2,
                        margin: const EdgeInsets.only(bottom: 18),
                        color: index < currentStep
                            ? AppColors.brand
                            : (isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
                      ),
                  ],
                ),
              );
            }),
          ),

          // PIN Input Module when heading to pickup
          if (isHeading) ...[
            const SizedBox(height: 20),
            Divider(height: 1, color: isDark ? AppColors.glassBorderDark : const Color(0xFFF3F4F6)),
            const SizedBox(height: 16),
            Text(
              'Enter the 4-digit PIN from the customer',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: secondaryTextColor),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: 10,
                color: primaryTextColor,
              ),
              decoration: InputDecoration(
                hintText: '• • • •',
                hintStyle: const TextStyle(letterSpacing: 8),
                counterText: '',
                filled: true,
                fillColor: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Primary Action Button (Text-Only, Pill Geometry)
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isCompleted
                    ? (isDark ? AppColors.darkSurfaceVariant : const Color(0xFFE5E7EB))
                    : (isInProgress ? AppColors.error : AppColors.brand),
                foregroundColor: isCompleted
                    ? (isDark ? Colors.white : Colors.black87)
                    : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              onPressed: _isProcessing
                  ? null
                  : (isCompleted
                      ? () => Navigator.pop(context)
                      : (isInProgress
                          ? _showEndRideConfirmation
                          : (isHeading ? _startRideWithPin : _triggerHeadingToPickup))),
              child: _isProcessing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Text(
                      isCompleted
                          ? 'Back to Home'
                          : (isInProgress
                              ? 'End Rental Ride'
                              : (isHeading ? 'Verify PIN & Start Ride' : 'Heading to Pickup Location')),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteCard({
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          // Pickup Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.store_rounded, color: AppColors.brand, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pick Up',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secondaryTextColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _booking.pickupLocation,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primaryTextColor),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.directions_rounded, color: AppColors.brand, size: 20),
                ),
                onPressed: () => _openDirections(_booking.pickupLocation),
              ),
            ],
          ),

          // Vertical Connecting Line
          Padding(
            padding: const EdgeInsets.only(left: 19),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 2,
                height: 24,
                color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
              ),
            ),
          ),

          // Dropoff Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on_rounded, color: AppColors.brand, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Drop Off',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secondaryTextColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _booking.dropoffLocation.isNotEmpty
                          ? _booking.dropoffLocation
                          : 'As directed by customer',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primaryTextColor),
                    ),
                  ],
                ),
              ),
              if (_booking.dropoffLocation.isNotEmpty)
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.directions_rounded, color: AppColors.brand, size: 20),
                  ),
                  onPressed: () => _openDirections(_booking.dropoffLocation),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerInfoCard({
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final customerUid = _booking.customerId.trim();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: customerUid.isNotEmpty
          ? FirebaseFirestore.instance.collection('customers').doc(customerUid).snapshots()
          : null,
      builder: (context, custSnap) {
        final custData = custSnap.data?.data();
        final photoUrl = (custData?['photoUrl'] as String?) ??
            (custData?['profilePhotoUrl'] as String?) ??
            (custData?['photo'] as String?) ??
            _booking.customerPhoto ??
            '';
        final fullName = (custData?['fullName'] as String?)?.trim() ??
            (custData?['name'] as String?)?.trim() ??
            _booking.customerName;
        final phone = (custData?['phone'] as String?) ??
            (custData?['phoneNumber'] as String?) ??
            _booking.customerPhone;

        final cleanPhoto = photoUrl.trim();
        final cleanPhone = phone.trim();

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer Info',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: primaryTextColor),
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: isDark ? AppColors.glassBorderDark : const Color(0xFFF3F4F6)),
              const SizedBox(height: 14),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: cleanPhoto.isNotEmpty
                          ? DiskCachedImage(
                              imageUrl: cleanPhoto,
                              fit: BoxFit.cover,
                              errorWidget: _buildAvatarFallbackIcon(),
                              loadingWidget: _buildAvatarFallbackIcon(),
                            )
                          : _buildAvatarFallbackIcon(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: primaryTextColor),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          cleanPhone.isNotEmpty ? cleanPhone : 'No phone number',
                          style: TextStyle(fontSize: 13, color: secondaryTextColor),
                        ),
                      ],
                    ),
                  ),
                  if (cleanPhone.isNotEmpty)
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phone_rounded, color: AppColors.brand, size: 22),
                      ),
                      onPressed: _callCustomer,
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAvatarFallbackIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person_rounded, color: AppColors.brand, size: 22),
    );
  }

  Widget _buildRentalDetailsCard({
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final dateFormat = DateFormat('EEE, MMM dd • hh:mm a');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Rental Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: primaryTextColor),
              ),
              Text(
                '${_booking.durationDays} Day(s)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: secondaryTextColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: isDark ? AppColors.glassBorderDark : const Color(0xFFF3F4F6)),
          const SizedBox(height: 16),

          // Vehicle Row
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _booking.vehicleImage.isNotEmpty
                    ? SizedBox(
                        width: 60,
                        height: 46,
                        child: DiskCachedImage(
                          imageUrl: _booking.vehicleImage,
                          fit: BoxFit.cover,
                          errorWidget: _carPlaceholder(),
                          loadingWidget: _carPlaceholder(),
                        ),
                      )
                    : _carPlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _booking.vehicleTitle,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: primaryTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_booking.serviceType.label} • ${_booking.vehicleCategory}',
                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(height: 1, color: isDark ? AppColors.glassBorderDark : const Color(0xFFF3F4F6)),
          const SizedBox(height: 14),

          // Schedule Rows
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Start Date', style: TextStyle(fontSize: 13, color: secondaryTextColor)),
              Text(dateFormat.format(_booking.startDate), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryTextColor)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('End Date', style: TextStyle(fontSize: 13, color: secondaryTextColor)),
              Text(dateFormat.format(_booking.endDate), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryTextColor)),
            ],
          ),
          const SizedBox(height: 16),

          // Total Amount Pill Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Amount',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.brand),
                ),
                Text(
                  '${_booking.currency}${_booking.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.brand),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _carPlaceholder() {
    return Container(
      width: 60,
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.directions_car_rounded, color: AppColors.brand, size: 24),
    );
  }
}
