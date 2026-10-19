import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:caride/features/car_rental/customer_rental_controller.dart';

/// Final booking summary & confirmation screen.
/// Inspired by Payment Review.png — itemised cost breakdown + confirm CTA.
class RentalBookingSummaryScreen extends StatefulWidget {
  const RentalBookingSummaryScreen({
    super.key,
    required this.vehicle,
    required this.booking,
  });

  final RentalVehicle vehicle;
  final RentalBooking booking;

  @override
  State<RentalBookingSummaryScreen> createState() =>
      _RentalBookingSummaryScreenState();
}

class _RentalBookingSummaryScreenState
    extends State<RentalBookingSummaryScreen> {
  final _scrollController = ScrollController();
  String? _error;
  bool _termsAccepted = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    setState(() => _error = message);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _confirmBooking() async {
    if (!_termsAccepted) {
      _showError(
          'Please accept the rental terms and conditions to proceed.');
      return;
    }

    setState(() => _error = null);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('You must be signed in to submit a booking.');
      return;
    }

    String customerName = user.displayName ?? 'Customer';
    String customerPhone = user.phoneNumber ?? '';
    // Try to enrich from Firestore customers/users doc if display name or phone isn't set
    if (customerName == 'Customer' || customerPhone.isEmpty) {
      try {
        final custDoc = await FirebaseFirestore.instance
            .collection('customers')
            .doc(user.uid)
            .get();
        if (custDoc.exists) {
          final data = custDoc.data()!;
          customerName = data['fullName'] as String? ??
              data['displayName'] as String? ??
              customerName;
          customerPhone = data['phone'] as String? ??
              data['phoneNumber'] as String? ??
              customerPhone;
        }

        if (customerName == 'Customer' || customerPhone.isEmpty) {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
          if (doc.exists) {
            final data = doc.data()!;
            customerName = data['fullName'] as String? ??
                data['displayName'] as String? ??
                customerName;
            customerPhone = data['phone'] as String? ??
                data['phoneNumber'] as String? ??
                customerPhone;
          }
        }
      } catch (_) {
        // Proceed with available values
      }
    }

    // Build finalised booking with customer identity
    final finalBooking = widget.booking.copyWith(
      customerId: user.uid,
      customerName: customerName,
      customerPhone: customerPhone,
      customerPhoto: user.photoURL,
    );

    final success =
        await customerRentalController.submitBooking(finalBooking);

    if (!mounted) return;

    if (success) {
      _showSuccessBottomSheet();
    } else {
      final err = customerRentalController.bookingError ??
          'Booking could not be submitted. Please try again.';
      _showError(err);
    }
  }

  void _showSuccessBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.check_circle_rounded,
                      size: 56, color: AppColors.brand),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Booking Requested!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your booking request has been sent to the fleet. You\'ll receive a confirmation once they approve it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : const Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_rounded,
                        color: AppColors.brand, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Status: Pending Approval',
                      style: TextStyle(
                        color: AppColors.brand,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
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
                  onPressed: () {
                    Navigator.of(sheetCtx).pop();
                    // Pop back to home screen
                    context.go(CustomerRoutePaths.home);
                  },
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showRentalTermsModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryText = isDark ? const Color(0xFFD1D5DB) : const Color(0xFF6B7280);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.description_rounded,
                        color: AppColors.brand, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Rental Terms & Conditions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTermItem(
                        '1. Caution Deposit & Refund',
                        'Caution deposits are held securely and refunded in full upon safe return and physical inspection of the vehicle, provided no damages, fines, or fuel shortages are incurred.',
                        primaryText,
                        secondaryText,
                      ),
                      _buildTermItem(
                        '2. Fuel Policy',
                        'Vehicles operate under a dry-lease policy unless specified otherwise. The renter is responsible for returning the vehicle with the same fuel level as received.',
                        primaryText,
                        secondaryText,
                      ),
                      _buildTermItem(
                        '3. Travel Scope & Interstate Restrictions',
                        'Vehicles may only be operated within permitted boundaries. Interstate travel requires prior approval and is subject to the stated daily interstate surcharge.',
                        primaryText,
                        secondaryText,
                      ),
                      _buildTermItem(
                        '4. Vehicle Handover & Identification',
                        'Renters must present a valid government-issued ID and a valid driver\'s license (for self-drive reservations) at handover.',
                        primaryText,
                        secondaryText,
                      ),
                      _buildTermItem(
                        '5. Cancellation Policy',
                        'Cancellations made at least 24 hours prior to scheduled pickup are eligible for a full refund. Late cancellations may incur a one-day rental fee.',
                        primaryText,
                        secondaryText,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    setState(() {
                      _termsAccepted = true;
                      if (_error != null) _error = null;
                    });
                  },
                  child: const Text(
                    'I Understand & Accept Terms',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTermItem(
    String title,
    String body,
    Color primaryText,
    Color secondaryText,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              fontSize: 12.5,
              color: secondaryText,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final b = widget.booking;
    final v = widget.vehicle;
    final primaryText =
        isDark ? Colors.white : const Color(0xFF111827);
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : const Color(0xFF6B7280);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final divider = isDark
        ? AppColors.glassBorderDark
        : const Color(0xFFE5E7EB);
    final hasTermsError = _error != null && !_termsAccepted;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor:
            isDark ? AppColors.darkBackground : Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark
                    ? AppColors.glassBorderDark
                    : const Color(0xFFE5E7EB),
              ),
              color: isDark ? AppColors.darkSurface : Colors.white,
            ),
            child: Icon(Icons.arrow_back_rounded,
                color: primaryText, size: 20),
          ),
        ),
        title: Text(
          'Booking Summary',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: primaryText,
          ),
        ),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: customerRentalController,
        builder: (context, _) {
          final isLoading =
              customerRentalController.isSubmittingBooking;

          return Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Error Banner ─────────────────────
                          if (_error != null) ...[
                            _ErrorBanner(
                              message: _error!,
                              onDismiss: () =>
                                  setState(() => _error = null),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // ── Vehicle Card ─────────────────────
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: divider),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius:
                                      BorderRadius.circular(12),
                                  child: () {
                                    if (v.images.isEmpty) return _imgPlaceholder();
                                    final url = v.images.first.trim();
                                    if (url.isEmpty) return _imgPlaceholder();
                                    if (url.startsWith('http://') || url.startsWith('https://')) {
                                      return Image.network(
                                        url,
                                        width: 80,
                                        height: 62,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _imgPlaceholder(),
                                      );
                                    } else {
                                      return Image.asset(
                                        url,
                                        width: 80,
                                        height: 62,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _imgPlaceholder(),
                                      );
                                    }
                                  }(),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        v.displayName,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: primaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      _InfoChip(
                                        label: b.serviceType.label,
                                        icon: b.serviceType ==
                                                RentalServiceType.selfDrive
                                            ? Icons.car_rental_rounded
                                            : (b.serviceType ==
                                                    RentalServiceType.dropOff
                                                ? Icons.flight_land_rounded
                                                : Icons.person_rounded),
                                        color: AppColors.brand,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Booking Details ──────────────────
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: divider),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Booking Details',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: primaryText,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (b.serviceType ==
                                    RentalServiceType.dropOff) ...[
                                  _DetailRow(
                                    icon: Icons.calendar_today_rounded,
                                    label: 'Trip Date',
                                    value: DateFormat('EEEE, MMM d yyyy')
                                        .format(b.startDate),
                                    secondaryText: secondaryText,
                                    primaryText: primaryText,
                                  ),
                                  const SizedBox(height: 12),
                                  _DetailRow(
                                    icon: Icons.route_rounded,
                                    label: 'Trip Type',
                                    value: 'Direct One-Way Transfer',
                                    secondaryText: secondaryText,
                                    primaryText: primaryText,
                                  ),
                                ] else ...[
                                  _DetailRow(
                                    icon: Icons.calendar_today_rounded,
                                    label: 'Start Date',
                                    value: DateFormat('EEEE, MMM d yyyy')
                                        .format(b.startDate),
                                    secondaryText: secondaryText,
                                    primaryText: primaryText,
                                  ),
                                  const SizedBox(height: 12),
                                  _DetailRow(
                                    icon:
                                        Icons.calendar_month_rounded,
                                    label: 'End Date',
                                    value: DateFormat('EEEE, MMM d yyyy')
                                        .format(b.endDate),
                                    secondaryText: secondaryText,
                                    primaryText: primaryText,
                                  ),
                                  const SizedBox(height: 12),
                                  _DetailRow(
                                    icon: Icons.timelapse_rounded,
                                    label: 'Duration',
                                    value:
                                        '${b.durationDays} day${b.durationDays == 1 ? '' : 's'}',
                                    secondaryText: secondaryText,
                                    primaryText: primaryText,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                _DetailRow(
                                  icon: Icons.access_time_rounded,
                                  label: 'Pickup Time',
                                  value: b.pickupTime?.isNotEmpty == true
                                      ? b.pickupTime!
                                      : DateFormat('hh:mm a').format(b.startDate),
                                  secondaryText: secondaryText,
                                  primaryText: primaryText,
                                ),
                                const SizedBox(height: 12),
                                _DetailRow(
                                  icon: Icons.location_on_rounded,
                                  label: 'Pickup Location',
                                  value: b.pickupLocation,
                                  secondaryText: secondaryText,
                                  primaryText: primaryText,
                                ),
                                if (b.dropoffLocation.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _DetailRow(
                                    icon: Icons.flag_rounded,
                                    label: 'Drop-off',
                                    value: b.dropoffLocation,
                                    secondaryText: secondaryText,
                                    primaryText: primaryText,
                                  ),
                                ],
                                if (b.notes != null &&
                                    b.notes!.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  _DetailRow(
                                    icon: Icons.notes_rounded,
                                    label: 'Notes',
                                    value: b.notes!,
                                    secondaryText: secondaryText,
                                    primaryText: primaryText,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Payment Summary ──────────────────
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: divider),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Payment Summary',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: primaryText,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _PaymentRow(
                                  label: b.serviceType ==
                                          RentalServiceType.dropOff
                                      ? 'Drop-Off / Transfer Flat Fare'
                                      : '${b.serviceType.label} × ${b.durationDays} day${b.durationDays == 1 ? '' : 's'}',
                                  value: NgnFormat.currency(b.totalAmount -
                                      b.cautionDeposit -
                                      b.driverAllowance),
                                  secondaryText: secondaryText,
                                  primaryText: primaryText,
                                  divider: divider,
                                ),
                                if (b.cautionDeposit > 0)
                                  _PaymentRow(
                                    label:
                                        'Caution Deposit (refundable)',
                                    value: NgnFormat.currency(
                                        b.cautionDeposit),
                                    secondaryText: secondaryText,
                                    primaryText: primaryText,
                                    divider: divider,
                                  ),
                                if (b.driverAllowance > 0)
                                  _PaymentRow(
                                    label: 'Driver Overnight Allowance',
                                    value: NgnFormat.currency(
                                        b.driverAllowance),
                                    secondaryText: secondaryText,
                                    primaryText: primaryText,
                                    divider: divider,
                                  ),
                                Divider(height: 24, color: divider),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: primaryText,
                                      ),
                                    ),
                                    Text(
                                      NgnFormat.currency(b.totalAmount),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.brand,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.brand
                                        .withValues(alpha: 0.06),
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    border: Border.all(
                                      color: AppColors.brand
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                          Icons
                                              .info_outline_rounded,
                                          color: AppColors.brand,
                                          size: 14),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Payment is collected by the fleet upon vehicle handover. Your booking is confirmed once the fleet accepts.',
                                          style: TextStyle(
                                            color: AppColors.brand,
                                            fontSize: 11,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Terms Checkbox ───────────────────
                          GestureDetector(
                            onTap: () => setState(() {
                              _termsAccepted = !_termsAccepted;
                              if (_termsAccepted && _error != null) {
                                _error = null;
                              }
                            }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: hasTermsError
                                    ? (isDark
                                        ? const Color(0xFF2A1215)
                                        : const Color(0xFFFEF2F2))
                                    : cardBg,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: hasTermsError
                                      ? AppColors.error
                                      : (_termsAccepted
                                          ? AppColors.brand
                                              .withValues(alpha: 0.5)
                                          : divider),
                                  width: hasTermsError ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: AnimatedContainer(
                                      duration: const Duration(
                                          milliseconds: 200),
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: _termsAccepted
                                            ? AppColors.brand
                                            : Colors.transparent,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                        border: Border.all(
                                          color: hasTermsError
                                              ? AppColors.error
                                              : (_termsAccepted
                                                  ? AppColors.brand
                                                  : (isDark
                                                      ? AppColors
                                                          .glassBorderDark
                                                      : const Color(
                                                          0xFFD1D5DB))),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: _termsAccepted
                                          ? const Icon(Icons.check_rounded,
                                              color: Colors.white,
                                              size: 14)
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              'I agree to the ',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: hasTermsError
                                                    ? AppColors.error
                                                    : primaryText,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: _showRentalTermsModal,
                                              child: const Text(
                                                'Rental Terms & Conditions',
                                                style: TextStyle(
                                                  fontSize: 12.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: AppColors.brand,
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'I understand that the caution deposit is refundable upon safe vehicle return with no damages.',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: secondaryText,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),

                  // ── Bottom CTA ───────────────────────────────
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      16,
                      20,
                      MediaQuery.of(context).padding.bottom + 16,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isDark ? AppColors.darkSurface : Colors.white,
                      border: Border(
                        top: BorderSide(color: divider),
                      ),
                    ),
                    child: SizedBox(
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
                        onPressed: isLoading ? null : _confirmBooking,
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Confirm & Request Booking',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),

              // ── Full-screen Loading Overlay ──────────────────
              if (isLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.brand),
                        SizedBox(height: 16),
                        Text(
                          'Submitting your booking...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
        width: 80,
        height: 62,
        decoration: BoxDecoration(
          color: AppColors.brand.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.directions_car_rounded,
            color: AppColors.brand, size: 30),
      );
}

// ── Sub-Widgets ───────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.secondaryText,
    required this.primaryText,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color secondaryText;
  final Color primaryText;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.brand, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: secondaryText,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: primaryText)),
              ],
            ),
          ),
        ],
      );
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.label,
    required this.value,
    required this.secondaryText,
    required this.primaryText,
    required this.divider,
  });

  final String label;
  final String value;
  final Color secondaryText;
  final Color primaryText;
  final Color divider;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 13, color: secondaryText)),
                ),
                const SizedBox(width: 12),
                Text(value,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: primaryText)),
              ],
            ),
          ),
          Divider(height: 1, color: divider),
        ],
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AppColors.error, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Action Required',
                    style: TextStyle(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: const TextStyle(
                        color: AppColors.error, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              child: const Icon(Icons.close_rounded,
                  color: AppColors.error, size: 18),
            ),
          ],
        ),
      );
}
