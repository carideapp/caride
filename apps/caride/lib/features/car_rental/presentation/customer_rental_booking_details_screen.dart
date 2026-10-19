import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:caride/features/car_rental/data/customer_rental_repository.dart';
import 'package:caride/features/car_rental/presentation/customer_rental_bookings_screen.dart';
import 'package:caride/features/chat/conversation_screen.dart';
import 'package:caride/features/chat/data/chat_repository.dart';
import 'package:caride/features/driver/profile/driver_fleet_profile_view_screen.dart';
import 'package:caride/features/profile/data/driver_public_profile_repository.dart';

/// Full-screen Customer Rental Booking Details screen.
class CustomerRentalBookingDetailsScreen extends StatefulWidget {
  const CustomerRentalBookingDetailsScreen({
    super.key,
    required this.booking,
  });

  final RentalBooking booking;

  @override
  State<CustomerRentalBookingDetailsScreen> createState() =>
      _CustomerRentalBookingDetailsScreenState();
}

class _CustomerRentalBookingDetailsScreenState
    extends State<CustomerRentalBookingDetailsScreen> {
  late RentalBooking _booking;
  FleetProfile? _fleetProfile;

  // Pickup PIN Entry State
  final _pickupPinController = TextEditingController();
  bool _isPickupSubmitting = false;
  String? _pickupError;

  // Return PIN Entry State
  final _returnPinController = TextEditingController();
  bool _isReturnSubmitting = false;
  String? _returnError;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _loadFleetProfile();
  }

  Future<void> _loadFleetProfile() async {
    if (_booking.fleetId.isEmpty) return;
    try {
      final profile = await customerRentalRepository.getFleetProfile(
        fleetId: _booking.fleetId,
      );
      if (mounted && profile != null) {
        setState(() => _fleetProfile = profile);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _pickupPinController.dispose();
    _returnPinController.dispose();
    super.dispose();
  }

  void _showPinError(String message, {required bool isPickup}) {
    setState(() {
      if (isPickup) {
        _pickupError = message;
      } else {
        _returnError = message;
      }
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  String _parsePinErrorMessage(dynamic error, {required bool isPickup}) {
    String errorCode = '';
    String raw = '';

    if (error is FirebaseFunctionsException) {
      errorCode = error.code.toLowerCase();
      raw = (error.message ?? '').toLowerCase();
    } else {
      raw = error.toString().toLowerCase();
    }

    // 1. Incorrect / Mismatched PIN
    if (errorCode == 'invalid-argument' ||
        raw.contains('invalid-argument') ||
        raw.contains('incorrect') ||
        raw.contains('wrong pin') ||
        raw.contains('invalid pin') ||
        raw.contains('mismatch') ||
        raw.contains('does not match')) {
      return isPickup
          ? 'Incorrect Pickup PIN. Please check the 4-digit code provided by the fleet manager and try again.'
          : 'Incorrect Return PIN. Please confirm the 4-digit return code with the fleet manager and try again.';
    }

    // 2. Already Used / Consumed PIN
    if (raw.contains('already-used') ||
        raw.contains('already used') ||
        raw.contains('already consumed') ||
        raw.contains('already-confirmed') ||
        raw.contains('already confirmed')) {
      return isPickup
          ? 'This Pickup PIN has already been verified and the rental trip is in progress.'
          : 'This Return PIN has already been used and the rental is completed.';
    }

    // 3. Invalid Booking State / Precondition Conflict
    if (errorCode == 'failed-precondition' ||
        raw.contains('failed-precondition') ||
        raw.contains('not-in-progress') ||
        raw.contains('not-confirmed') ||
        raw.contains('invalid status')) {
      return isPickup
          ? 'Vehicle pickup cannot be confirmed right now. Booking status is not ready for vehicle handover.'
          : 'Vehicle return cannot be confirmed right now. Rental trip is not currently active or in progress.';
    }

    // 4. Permission / Unauthorized
    if (errorCode == 'permission-denied' ||
        errorCode == 'unauthenticated' ||
        raw.contains('permission-denied') ||
        raw.contains('unauthenticated') ||
        raw.contains('unauthorized')) {
      return 'You do not have permission to verify this PIN. Please ensure you are logged into your CaRide customer account.';
    }

    // 5. Booking Record Not Found
    if (errorCode == 'not-found' ||
        raw.contains('not-found') ||
        raw.contains('not found') ||
        raw.contains('does not exist')) {
      return 'Booking record was not found. Please refresh or contact CaRide customer support.';
    }

    // 6. Rate Limiting / Too Many Attempts
    if (errorCode == 'resource-exhausted' ||
        raw.contains('resource-exhausted') ||
        raw.contains('too-many-requests') ||
        raw.contains('quota') ||
        raw.contains('rate limit')) {
      return 'Too many verification attempts. Please wait 60 seconds before trying again.';
    }

    // 7. Network / Connection Timeout
    if (errorCode == 'unavailable' ||
        errorCode == 'deadline-exceeded' ||
        raw.contains('network') ||
        raw.contains('unavailable') ||
        raw.contains('timeout') ||
        raw.contains('connection') ||
        raw.contains('socket') ||
        raw.contains('offline')) {
      return 'Network connection issue. Please check your internet connection and try again.';
    }

    // 8. Server / Internal Error
    if (errorCode == 'internal' || raw.contains('internal')) {
      return 'Verification service temporarily encountered an error. Please try again in a few moments.';
    }

    return 'Unable to verify ${isPickup ? "Pickup" : "Return"} PIN. Please confirm the 4-digit code with the fleet manager and try again.';
  }

  Future<void> _handleConfirmPickup() async {
    final pin = _pickupPinController.text.trim();

    // 1. Pre-validation: Empty input
    if (pin.isEmpty) {
      _showPinError(
        'Please enter the 4-digit Pickup PIN provided by the fleet manager.',
        isPickup: true,
      );
      return;
    }

    // 2. Pre-validation: Non-numeric
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      _showPinError(
        'PIN must contain numbers only. Please enter a valid 4-digit numeric code.',
        isPickup: true,
      );
      return;
    }

    // 3. Pre-validation: Incomplete length
    if (pin.length != 4) {
      _showPinError(
        'Incomplete PIN. Please enter all 4 digits (actual: ${pin.length}/4 digits).',
        isPickup: true,
      );
      return;
    }

    // 4. Pre-validation: Booking Status Conflict
    if (_booking.pickupPinUsed || _booking.status == RentalBookingStatus.inProgress) {
      _showPinError(
        'This vehicle pickup has already been verified and your rental trip is active.',
        isPickup: true,
      );
      return;
    }

    if (_booking.status != RentalBookingStatus.confirmed) {
      _showPinError(
        'Vehicle pickup cannot be confirmed because this booking is ${_booking.status.label}.',
        isPickup: true,
      );
      return;
    }

    setState(() {
      _isPickupSubmitting = true;
      _pickupError = null;
    });

    try {
      await CustomerRentalRepository().confirmSelfDrivePickup(
        bookingId: _booking.id,
        enteredPin: pin,
      );

      if (!mounted) return;
      setState(() {
        _isPickupSubmitting = false;
        _booking = _booking.copyWith(
          status: RentalBookingStatus.inProgress,
          pickupPinUsed: true,
        );
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text('Pickup confirmed! Your self-drive trip has started.'),
              ),
            ],
          ),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPickupSubmitting = false);
      final errorMsg = _parsePinErrorMessage(e, isPickup: true);
      _showPinError(errorMsg, isPickup: true);
    }
  }

  Future<void> _handleConfirmReturn() async {
    final pin = _returnPinController.text.trim();

    // 1. Pre-validation: Empty input
    if (pin.isEmpty) {
      _showPinError(
        'Please enter the 4-digit Return PIN provided by the fleet manager.',
        isPickup: false,
      );
      return;
    }

    // 2. Pre-validation: Non-numeric
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      _showPinError(
        'PIN must contain numbers only. Please enter a valid 4-digit numeric code.',
        isPickup: false,
      );
      return;
    }

    // 3. Pre-validation: Incomplete length
    if (pin.length != 4) {
      _showPinError(
        'Incomplete PIN. Please enter all 4 digits (actual: ${pin.length}/4 digits).',
        isPickup: false,
      );
      return;
    }

    // 4. Pre-validation: Booking Status Conflict
    if (_booking.returnPinUsed || _booking.status == RentalBookingStatus.completed) {
      _showPinError(
        'This vehicle return has already been confirmed and completed.',
        isPickup: false,
      );
      return;
    }

    if (_booking.status != RentalBookingStatus.inProgress) {
      _showPinError(
        'Vehicle return cannot be processed because this rental trip is not currently in progress.',
        isPickup: false,
      );
      return;
    }

    setState(() {
      _isReturnSubmitting = true;
      _returnError = null;
    });

    try {
      await CustomerRentalRepository().confirmSelfDriveReturn(
        bookingId: _booking.id,
        enteredPin: pin,
      );

      if (!mounted) return;
      setState(() {
        _isReturnSubmitting = false;
        _booking = _booking.copyWith(
          status: RentalBookingStatus.completed,
          returnPinUsed: true,
        );
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text('Vehicle return confirmed! Thank you for using CaRide.'),
              ),
            ],
          ),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isReturnSubmitting = false);
      final errorMsg = _parsePinErrorMessage(e, isPickup: false);
      _showPinError(errorMsg, isPickup: false);
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanPhone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Phone number is not available.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    final uri = Uri.parse('tel:$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not open phone dialer.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    }
  }

  Future<void> _handleChatFleet({
    required FleetProfile? fleetProfile,
    required String fleetName,
    required String ownerUid,
    required String? fleetLogo,
  }) async {
    try {
      await ChatRepository().startOrGetRentalThread(
        bookingId: _booking.id,
        fleetId: _booking.fleetId,
        fleetName: fleetName,
        customerUid: _booking.customerId,
        customerName: _booking.customerName,
        vehicleTitle: _booking.vehicleTitle,
        customerPhoto: _booking.customerPhoto,
        vehicleImage: _booking.vehicleImage,
        fleetOwnerUid: ownerUid,
        fleetLogo: fleetLogo,
      );
    } catch (e) {
      debugPrint('[CustomerRentalDetails] Start rental thread error: $e');
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          driverName: fleetName,
          rideId: 'rental_${_booking.id}',
          driverUid: ownerUid.isNotEmpty ? ownerUid : _booking.fleetId,
          isFleet: true,
          vehicleTitle: _booking.vehicleTitle,
          peerPhoto: fleetLogo,
        ),
      ),
    );
  }

  Future<void> _handleChatDriver({
    required String driverName,
    required String? profilePhotoUrl,
  }) async {
    final driverUid = _booking.assignedDriverId;
    if (driverUid == null || driverUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Assigned driver information is not available.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    final rideId = 'rental_driver_${_booking.id}_$driverUid';
    try {
      await FirebaseFirestore.instance.collection('rideMessages').doc(rideId).set({
        'type': 'rental_driver',
        'bookingId': _booking.id,
        'driverUid': driverUid,
        'driverName': driverName,
        'peerPhoto': profilePhotoUrl,
        'customerUid': _booking.customerId,
        'customerName': _booking.customerName,
        'customerPhoto': _booking.customerPhoto,
        'vehicleTitle': _booking.vehicleTitle,
        'participantUids': [_booking.customerId, driverUid],
        'lastMessage': 'Chat started with assigned driver',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCounts': {
          _booking.customerId: 0,
          driverUid: 0,
        },
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[CustomerRentalDetails] Start driver chat thread error: $e');
    }

    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(
          driverName: driverName,
          rideId: rideId,
          driverUid: driverUid,
          isFleet: false,
          vehicleTitle: _booking.vehicleTitle,
          peerPhoto: profilePhotoUrl,
        ),
      ),
    );
  }

  Widget _buildFleetProfileCard({
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final isPaid = _booking.isPaid ||
        _booking.paymentStatus.trim().toLowerCase() == 'paid' ||
        _booking.status == RentalBookingStatus.confirmed ||
        _booking.status == RentalBookingStatus.inProgress ||
        _booking.status == RentalBookingStatus.completed;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
      stream: _booking.fleetId.isNotEmpty
          ? FirebaseFirestore.instance
              .collection('fleets')
              .doc(_booking.fleetId)
              .snapshots()
          : null,
      builder: (context, fleetSnap) {
        FleetProfile? profile = _fleetProfile;
        if (fleetSnap.hasData && fleetSnap.data != null && fleetSnap.data!.exists) {
          final data = fleetSnap.data!.data();
          if (data != null) {
            profile = FleetProfile.fromMap(data, fleetSnap.data!.id);
            _fleetProfile = profile;
          }
        }

        final businessName = profile?.businessName.isNotEmpty == true
            ? profile!.businessName
            : 'Verified Fleet Host';
        final phone = profile?.phone.trim() ?? '';
        final logoUrl = profile?.logoUrl ?? profile?.profilePictureUrl ?? '';
        final city = profile?.city.trim().isNotEmpty == true
            ? profile!.city.trim()
            : (profile?.state.trim().isNotEmpty == true ? profile!.state.trim() : '');
        final isVerified = profile?.isVerified ?? false;
        final ownerUid = profile?.ownerUid.isNotEmpty == true
            ? profile!.ownerUid
            : _booking.fleetId;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            children: [
              // Fleet Logo / Avatar
              InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: profile != null
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                DriverFleetProfileViewScreen(fleet: profile!),
                          ),
                        )
                    : null,
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.brand.withValues(alpha: 0.1),
                  backgroundImage:
                      logoUrl.isNotEmpty ? NetworkImage(logoUrl) : null,
                  child: logoUrl.isEmpty
                      ? const Icon(Icons.apartment_rounded,
                          color: AppColors.brand, size: 24)
                      : null,
                ),
              ),
              const SizedBox(width: 14),
              // Name and City/Verification info
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: profile != null
                      ? () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  DriverFleetProfileViewScreen(fleet: profile!),
                            ),
                          )
                      : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              businessName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                              ),
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.verified_rounded,
                              color: AppColors.brand,
                              size: 16,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        city.isNotEmpty
                            ? 'Fleet Partner • $city'
                            : 'Fleet Partner',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Call and Chat icons displayed when booking is paid
              if (isPaid) ...[
                IconButton(
                  tooltip: 'Call Fleet Manager',
                  icon: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.phone_rounded,
                      color: AppColors.brand,
                      size: 19,
                    ),
                  ),
                  onPressed: () => _makePhoneCall(phone),
                ),
                IconButton(
                  tooltip: 'Chat with Fleet Manager',
                  icon: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: AppColors.brand,
                      size: 19,
                    ),
                  ),
                  onPressed: () => _handleChatFleet(
                    fleetProfile: profile,
                    fleetName: businessName,
                    ownerUid: ownerUid,
                    fleetLogo: logoUrl.isNotEmpty ? logoUrl : null,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final dateFormat = DateFormat('EEE, MMM dd, yyyy');

    Color statusColor;
    Color statusBg;
    switch (_booking.status) {
      case RentalBookingStatus.confirmed:
      case RentalBookingStatus.inProgress:
        statusColor = AppColors.brand;
        statusBg = const Color(0xFFDCFCE7);
        break;
      case RentalBookingStatus.awaitingPayment:
      case RentalBookingStatus.pendingApproval:
        statusColor = const Color(0xFFD97706);
        statusBg = const Color(0xFFFEF3C7);
        break;
      case RentalBookingStatus.completed:
        statusColor = const Color(0xFF2563EB);
        statusBg = const Color(0xFFDBEAFE);
        break;
      case RentalBookingStatus.cancelled:
      case RentalBookingStatus.rejected:
        statusColor = AppColors.error;
        statusBg = const Color(0xFFFEE2E2);
        break;
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('rental_bookings')
          .doc(_booking.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.exists) {
          final liveData = snapshot.data!.data();
          if (liveData != null) {
            _booking = RentalBooking.fromMap(liveData, _booking.id);
          }
        }

        final isChauffeurOrDropOff =
            _booking.serviceType == RentalServiceType.withDriver ||
            _booking.serviceType == RentalServiceType.dropOff;
        final hasStartPin =
            (_booking.startPin?.isNotEmpty ?? false) && isChauffeurOrDropOff;
        final startPinDigits = (_booking.startPin ?? '').split('');

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0B0F19) : const Color(0xFFF9FAFB),
          body: SafeArea(
            child: Column(
              children: [
                // ── Top Header Bar ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // Back Button (44x44px circular)
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.glassBorderDark
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            size: 20,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Booking Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'ID: ${_booking.id.substring(0, _booking.id.length > 8 ? 8 : _booking.id.length).toUpperCase()}',
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status Badge Capsule
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _booking.status.label,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // ── Scrollable Body Content ─────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Rental Schedule Window Header Banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.brand.withValues(alpha: 0.12)
                                : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.brand.withValues(alpha: 0.25)
                                  : const Color(0xFFDCFCE7),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.calendar_today_rounded,
                                  color: AppColors.brand,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${dateFormat.format(_booking.startDate)} → ${dateFormat.format(_booking.endDate)}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF111827),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${_booking.durationDays} Day(s) • ${_booking.serviceType.label}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 2. Vehicle Summary Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.glassBorderDark
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: _booking.vehicleImage.isNotEmpty
                                    ? Image.network(
                                        _booking.vehicleImage,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _placeholderVehicle(),
                                      )
                                    : _placeholderVehicle(),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _booking.vehicleTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Total Fare: ${NgnFormat.currency(_booking.totalAmount)}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.brand,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Fleet Profile Section (Always Displayed)
                        _buildFleetProfileCard(
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                        ),

                        // 3. Start PIN Card for Chauffeur / Transfer Rides
                        if (hasStartPin) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurface
                                  : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.glassBorderDark
                                    : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.pin_rounded,
                                        size: 18, color: AppColors.brand),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Start Ride PIN',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                    ),
                                    if (_booking.startPinUsed ||
                                        _booking.status ==
                                            RentalBookingStatus.inProgress)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.brand
                                              .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.check_circle_rounded,
                                                size: 12,
                                                color: AppColors.brand),
                                            SizedBox(width: 4),
                                            Text(
                                              'PIN Verified',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.brand,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    else
                                      IconButton(
                                        icon: const Icon(Icons.copy_rounded,
                                            size: 18, color: AppColors.brand),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        tooltip: 'Copy Start PIN',
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(
                                              text: _booking.startPin!));
                                          ScaffoldMessenger.of(context)
                                              .hideCurrentSnackBar();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                  'Start PIN copied to clipboard'),
                                              backgroundColor: AppColors.brand,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _booking.startPinUsed ||
                                          _booking.status ==
                                              RentalBookingStatus.inProgress
                                      ? 'This PIN was verified by your driver and your rental trip has officially started.'
                                      : 'Share this 4-digit code with your assigned driver when they arrive.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: secondaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: startPinDigits.map((digit) {
                                    return Container(
                                      width: 44,
                                      height: 48,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 5),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white12
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isDark
                                              ? AppColors.brand
                                                  .withValues(alpha: 0.4)
                                              : const Color(0xFFBBF7D0),
                                          width: 1.2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          digit,
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w800,
                                            color: primaryTextColor,
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        ] else if (isChauffeurOrDropOff &&
                            _booking.status == RentalBookingStatus.confirmed) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF451A03)
                                      .withValues(alpha: 0.3)
                                  : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFF59E0B)
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline_rounded,
                                    size: 20, color: Color(0xFFD97706)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Generating Start Ride PIN... Your code will appear here shortly.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark
                                          ? Colors.white70
                                          : const Color(0xFF92400E),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // 4. Assigned Driver Profile Card
                        if (_booking.isDriverAssigned) ...[
                          const SizedBox(height: 16),
                          StreamBuilder<DriverPublicProfile?>(
                            stream: _booking.assignedDriverId != null
                                ? DriverPublicProfileRepository().watchDriver(_booking.assignedDriverId!)
                                : Stream.value(null),
                            builder: (context, driverSnap) {
                              final profilePhotoUrl = driverSnap.data?.profilePhotoUrl ?? '';
                              final driverName = _booking.assignedDriverName ??
                                  driverSnap.data?.fullName ??
                                  'Assigned Chauffeur';
                              final driverPhone = _booking.assignedDriverPhone ??
                                  driverSnap.data?.phone ??
                                  '';

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurface : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.glassBorderDark
                                        : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 24,
                                      backgroundColor: AppColors.brand.withValues(alpha: 0.1),
                                      backgroundImage: profilePhotoUrl.isNotEmpty
                                          ? NetworkImage(profilePhotoUrl)
                                          : null,
                                      child: profilePhotoUrl.isEmpty
                                          ? const Icon(Icons.person_rounded,
                                              color: AppColors.brand, size: 24)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            driverName,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: primaryTextColor,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Assigned Chauffeur',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: secondaryTextColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Call Driver',
                                      icon: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: AppColors.brand.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.phone_rounded,
                                            color: AppColors.brand, size: 19),
                                      ),
                                      onPressed: () => _makePhoneCall(driverPhone),
                                    ),
                                    IconButton(
                                      tooltip: 'Chat with Driver',
                                      icon: Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: AppColors.brand.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.chat_bubble_outline_rounded,
                                            color: AppColors.brand, size: 19),
                                      ),
                                      onPressed: () => _handleChatDriver(
                                        driverName: driverName,
                                        profilePhotoUrl: profilePhotoUrl.isNotEmpty ? profilePhotoUrl : null,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],

                        const SizedBox(height: 20),

                        // 5. Route Card (Pickup & Dropoff)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.glassBorderDark
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  const SizedBox(height: 2),
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.brand, width: 2),
                                    ),
                                    child: Center(
                                      child: Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: AppColors.brand,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 1.5,
                                    height: 32,
                                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                                  ),
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 16,
                                    color: AppColors.brand,
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Pickup Location',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      _booking.pickupLocation.isNotEmpty
                                          ? _booking.pickupLocation
                                          : 'Rental Start',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      'Drop Off / Return Location',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      _booking.dropoffLocation.isNotEmpty
                                          ? _booking.dropoffLocation
                                          : 'Rental Concludes',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // 6. Self-Drive Pickup PIN Entry Section
                        if (_booking.serviceType == RentalServiceType.selfDrive &&
                            _booking.status == RentalBookingStatus.confirmed) ...[
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.brand.withValues(alpha: 0.08)
                                  : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.brand.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.brand.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.key_rounded, color: AppColors.brand, size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Collect Your Vehicle',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: primaryTextColor,
                                            ),
                                          ),
                                          Text(
                                            'Enter the Pickup PIN provided by the fleet manager',
                                            style: TextStyle(fontSize: 11.5, color: secondaryTextColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                if (_pickupError != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.error.withValues(alpha: 0.15) : const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Action Required',
                                                style: TextStyle(
                                                  color: AppColors.error,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _pickupError!,
                                                style: TextStyle(
                                                  color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF991B1B),
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w500,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () => setState(() => _pickupError = null),
                                          child: const Padding(
                                            padding: EdgeInsets.only(top: 2),
                                            child: Icon(Icons.close_rounded, color: AppColors.error, size: 18),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _pickupPinController,
                                        keyboardType: TextInputType.number,
                                        maxLength: 4,
                                        onChanged: (_) {
                                          if (_pickupError != null) {
                                            setState(() => _pickupError = null);
                                          }
                                        },
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 6, color: primaryTextColor),
                                        decoration: InputDecoration(
                                          hintText: 'PIN',
                                          hintStyle: TextStyle(fontSize: 14, letterSpacing: 2, color: secondaryTextColor),
                                          counterText: '',
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          filled: true,
                                          fillColor: isDark ? AppColors.darkSurface : Colors.white,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      height: 50,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.brand,
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          minimumSize: const Size(0, 46),
                                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                        onPressed: _isPickupSubmitting ? null : _handleConfirmPickup,
                                        child: _isPickupSubmitting
                                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                            : const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // 7. Self-Drive Return PIN Entry Section
                        if (_booking.serviceType == RentalServiceType.selfDrive &&
                            _booking.status == RentalBookingStatus.inProgress) ...[
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                                  : const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.directions_car_rounded, color: Color(0xFFD97706), size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Return Vehicle Confirmation',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: primaryTextColor,
                                            ),
                                          ),
                                          Text(
                                            'Enter Return PIN provided by fleet manager',
                                            style: TextStyle(fontSize: 11.5, color: secondaryTextColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                if (_returnError != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.error.withValues(alpha: 0.15) : const Color(0xFFFEF2F2),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: AppColors.error.withValues(alpha: 0.45)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text(
                                                'Action Required',
                                                style: TextStyle(
                                                  color: AppColors.error,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 0.2,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _returnError!,
                                                style: TextStyle(
                                                  color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF991B1B),
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w500,
                                                  height: 1.3,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        GestureDetector(
                                          onTap: () => setState(() => _returnError = null),
                                          child: const Padding(
                                            padding: EdgeInsets.only(top: 2),
                                            child: Icon(Icons.close_rounded, color: AppColors.error, size: 18),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _returnPinController,
                                        keyboardType: TextInputType.number,
                                        maxLength: 4,
                                        onChanged: (_) {
                                          if (_returnError != null) {
                                            setState(() => _returnError = null);
                                          }
                                        },
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 6, color: primaryTextColor),
                                        decoration: InputDecoration(
                                          hintText: 'PIN',
                                          hintStyle: TextStyle(fontSize: 14, letterSpacing: 2, color: secondaryTextColor),
                                          counterText: '',
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          filled: true,
                                          fillColor: isDark ? AppColors.darkSurface : Colors.white,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    SizedBox(
                                       height: 50,
                                       child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFD97706),
                                           foregroundColor: Colors.white,
                                           elevation: 0,
                                           minimumSize: const Size(0, 46),
                                           tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                        ),
                                        onPressed: _isReturnSubmitting ? null : _handleConfirmReturn,
                                        child: _isReturnSubmitting
                                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                            : const Text('Complete Return', style: TextStyle(fontWeight: FontWeight.w700)),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // 8. Rate Ride Button (for completed bookings)
                        if (_booking.status == RentalBookingStatus.completed) ...[
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.brand,
                                disabledForegroundColor: isDark
                                    ? Colors.white38
                                    : const Color(0xFF9CA3AF),
                                side: BorderSide(
                                  color: _booking.isRated
                                      ? (isDark
                                          ? Colors.white12
                                          : const Color(0xFFE5E7EB))
                                      : AppColors.brand.withValues(alpha: 0.4),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              onPressed: _booking.isRated
                                  ? null
                                  : () => showRateRentalBottomSheet(context, _booking),
                              child: Text(
                                _booking.isRated
                                    ? 'Rated'
                                    : 'Rate Ride',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // 9. Main Action Button (Pay Now or Browse More)
                        if (_booking.status == RentalBookingStatus.awaitingPayment)
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              onPressed: () => context.push(
                                CustomerRoutePaths.rentalPayment,
                                extra: _booking,
                              ),
                              child: Text(
                                'Pay Now — ${NgnFormat.currency(_booking.totalAmount)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              onPressed: () => context.push(CustomerRoutePaths.rentalBrowse),
                              child: const Text(
                                'Browse More Vehicles',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
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

  Widget _placeholderVehicle() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.directions_car_rounded, color: AppColors.brand, size: 28),
    );
  }
}
