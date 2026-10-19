import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:caride/features/car_rental/data/customer_rental_repository.dart';

/// Customer screen displaying the user's rental bookings categorized by status into tabs.
class CustomerRentalBookingsScreen extends StatefulWidget {
  const CustomerRentalBookingsScreen({super.key});

  @override
  State<CustomerRentalBookingsScreen> createState() =>
      _CustomerRentalBookingsScreenState();
}

class _CustomerRentalBookingsScreenState
    extends State<CustomerRentalBookingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final CustomerRentalRepository _rentalRepository = CustomerRentalRepository();

  static const List<String> _tabLabels = [
    'Ongoing',
    'History',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Rental Bookings',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),

            // Stream Builder for Real-Time Rental Bookings
            Expanded(
              child: StreamBuilder<List<RentalBooking>>(
                stream: _rentalRepository.streamCustomerBookings(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const BookingCardSkeleton(itemCount: 4);
                  }

                  final allBookings = snapshot.data ?? [];

                  // Ongoing: Active, Awaiting Payment, Pending Approval (Awaiting Payment prioritized at top)
                  final ongoing = allBookings.where((b) =>
                      b.status == RentalBookingStatus.awaitingPayment ||
                      b.status == RentalBookingStatus.confirmed ||
                      b.status == RentalBookingStatus.inProgress ||
                      b.status == RentalBookingStatus.pendingApproval).toList();

                  // Sort Ongoing: Awaiting Payment first, then In Progress / Confirmed, then Pending Approval
                  ongoing.sort((a, b) {
                    int rank(RentalBooking item) {
                      if (item.status == RentalBookingStatus.awaitingPayment) return 0;
                      if (item.status == RentalBookingStatus.inProgress) return 1;
                      if (item.status == RentalBookingStatus.confirmed) return 2;
                      return 3;
                    }
                    final rA = rank(a);
                    final rB = rank(b);
                    if (rA != rB) return rA.compareTo(rB);
                    return (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now());
                  });

                  // History: Completed, Cancelled, Rejected
                  final history = allBookings.where((b) =>
                      b.status == RentalBookingStatus.completed ||
                      b.status == RentalBookingStatus.cancelled ||
                      b.status == RentalBookingStatus.rejected).toList();

                  return Column(
                    children: [
                      // Modern 2-Segment Pill Tab Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                        child: Container(
                          height: 48,
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: isDark ? Colors.white12 : Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: isDark ? null : Border.all(color: const Color(0xFFE5E7EB)),
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            labelColor: AppColors.brand,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            unselectedLabelColor: isDark
                                ? AppColors.textSecondaryDark
                                : const Color(0xFF6B7280),
                            unselectedLabelStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            tabs: const [
                              Tab(text: 'Ongoing'),
                              Tab(text: 'History'),
                            ],
                          ),
                        ),
                      ),

                      // Tab Views
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _CustomerBookingsListView(
                              bookings: ongoing,
                              emptyTitle: 'No Ongoing Rentals',
                              emptySubtitle: 'Your active trips, pending approvals, and bookings awaiting payment will appear here.',
                              onBrowse: () => context.push(CustomerRoutePaths.rentalBrowse),
                            ),
                            _CustomerBookingsListView(
                              bookings: history,
                              emptyTitle: 'No Rental History',
                              emptySubtitle: 'Your completed or cancelled rental bookings will be archived here.',
                              onBrowse: () => context.push(CustomerRoutePaths.rentalBrowse),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomerBookingsListView extends StatelessWidget {
  const _CustomerBookingsListView({
    required this.bookings,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onBrowse,
  });

  final List<RentalBooking> bookings;
  final String emptyTitle;
  final String emptySubtitle;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (bookings.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.car_rental_rounded,
                  size: 40,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                emptyTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                emptySubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
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
                  onPressed: onBrowse,
                  child: const Text(
                    'Browse Available Cars',
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
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return _CustomerBookingCard(booking: booking);
      },
    );
  }
}

class _CustomerBookingCard extends StatelessWidget {
  const _CustomerBookingCard({required this.booking});

  final RentalBooking booking;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final dateFormat = DateFormat('MMM dd, yyyy');

    return GestureDetector(
      onTap: () {
        if (booking.status == RentalBookingStatus.awaitingPayment) {
          context.push(CustomerRoutePaths.rentalPayment, extra: booking);
        } else {
          context.push(CustomerRoutePaths.rentalBookingDetails, extra: booking);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top: Vehicle Thumbnail + Title + Service Chip
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: booking.vehicleImage.isNotEmpty
                        ? Image.network(
                            booking.vehicleImage,
                            width: 58,
                            height: 58,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          booking.vehicleTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: primaryTextColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              booking.isChauffeur
                                  ? Icons.airline_seat_recline_normal_rounded
                                  : Icons.drive_eta_rounded,
                              size: 14,
                              color: AppColors.brand,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                '${booking.serviceType.label} • ${booking.durationDays} ${booking.durationDays == 1 ? 'day' : 'days'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Route / Schedule Indicator
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 2),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.brand, width: 2.5),
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
                          width: 2,
                          height: 28,
                          margin: const EdgeInsets.symmetric(vertical: 2),
                          color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                        ),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF6B7280), width: 2.5),
                          ),
                          child: Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF6B7280),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pick Up',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: secondaryTextColor,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            booking.pickupLocation.isNotEmpty
                                ? booking.pickupLocation
                                : 'Rental Start (${dateFormat.format(booking.startDate)})',
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
                            'Drop Off / Return',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: secondaryTextColor,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            booking.dropoffLocation.isNotEmpty
                                ? booking.dropoffLocation
                                : 'Rental Concludes (${dateFormat.format(booking.endDate)})',
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

              const SizedBox(height: 16),

              // Soft Tinted Earnings / Fare Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
                child: Column(
                  children: [
                    Text(
                      NgnFormat.currency(booking.totalAmount),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: AppColors.brand,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      booking.status == RentalBookingStatus.awaitingPayment
                          ? 'Total amount due for payment'
                          : 'Total rental booking cost',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF15803D),
                      ),
                    ),
                  ],
                ),
              ),

              // 3-Hour Payment Window Expiration Notice for awaitingPayment
              if (booking.status == RentalBookingStatus.awaitingPayment) ...[
                const SizedBox(height: 12),
                if (booking.isPaymentExpired)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF3B1215) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.timer_off_outlined, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Payment window expired (3 hrs). The vehicle hold has been released.',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFFCA5A5) : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  Builder(
                    builder: (context) {
                      final expiresAt = booking.paymentExpiresAt ??
                          (booking.updatedAt ?? DateTime.now()).add(const Duration(hours: 3));
                      final diff = expiresAt.difference(DateTime.now());
                      final remainingText = diff.isNegative
                          ? 'expiring now'
                          : '${diff.inHours > 0 ? '${diff.inHours}h ' : ''}${diff.inMinutes.remainder(60)}m';

                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2E2208) : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.alarm_rounded, color: Color(0xFFF59E0B), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pay within $remainingText to secure this car. Vehicle holds expire after 3 hours.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],

              const SizedBox(height: 14),

              // Primary Full-Pill Action Button (View Details / Pay Now)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (booking.status == RentalBookingStatus.awaitingPayment && booking.isPaymentExpired)
                        ? (isDark ? Colors.white24 : const Color(0xFFD1D5DB))
                        : AppColors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () {
                    if (booking.status == RentalBookingStatus.awaitingPayment) {
                      if (booking.isPaymentExpired) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'The 3-hour payment window for this booking has expired. Please cancel and book again.',
                            ),
                            backgroundColor: AppColors.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        );
                        return;
                      }
                      context.push(CustomerRoutePaths.rentalPayment, extra: booking);
                    } else {
                      context.push(CustomerRoutePaths.rentalBookingDetails, extra: booking);
                    }
                  },
                  child: Text(
                    booking.status == RentalBookingStatus.awaitingPayment
                        ? (booking.isPaymentExpired ? 'Booking Expired' : 'Pay Now')
                        : 'View Details',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: (booking.status == RentalBookingStatus.awaitingPayment && booking.isPaymentExpired)
                          ? (isDark ? Colors.white60 : const Color(0xFF6B7280))
                          : Colors.white,
                    ),
                  ),
                ),
              ),

              // Cancel Booking Button for awaitingPayment and pendingApproval
              if (booking.status == RentalBookingStatus.awaitingPayment ||
                  booking.status == RentalBookingStatus.pendingApproval ||
                  booking.rentalTripStatus?.name == 'awaitingPayment' ||
                  booking.rentalTripStatus?.name == 'pendingApproval') ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                        side: BorderSide(
                          color: AppColors.error.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => showCancelRentalBookingBottomSheet(context, booking),
                    child: Text(
                      booking.isPaymentExpired ? 'Cancel / Remove Booking' : 'Cancel Booking',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(Icons.directions_car, color: AppColors.brand, size: 26),
    );
  }
}

/// Modal bottom sheet confirming cancellation of a pending or awaiting-payment rental booking.
void showCancelRentalBookingBottomSheet(BuildContext context, RentalBooking booking) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CancelRentalBookingBottomSheet(booking: booking, isDark: isDark),
  );
}

class _CancelRentalBookingBottomSheet extends StatefulWidget {
  const _CancelRentalBookingBottomSheet({
    required this.booking,
    required this.isDark,
  });

  final RentalBooking booking;
  final bool isDark;

  @override
  State<_CancelRentalBookingBottomSheet> createState() =>
      _CancelRentalBookingBottomSheetState();
}

class _CancelRentalBookingBottomSheetState
    extends State<_CancelRentalBookingBottomSheet> {
  bool _isCancelling = false;

  Future<void> _handleCancel() async {
    setState(() => _isCancelling = true);

    try {
      await customerRentalRepository.cancelBooking(
        widget.booking.id,
        reason: 'Cancelled by customer',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Rental booking cancelled successfully.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1F2937),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCancelling = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel booking: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryTextColor = widget.isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        widget.isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    final isAwaitingPayment =
        widget.booking.status == RentalBookingStatus.awaitingPayment ||
        widget.booking.rentalTripStatus?.name == 'awaitingPayment';

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          MediaQuery.of(context).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Warning Icon Badge
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                size: 36,
                color: AppColors.error,
              ),
            ),
            const SizedBox(height: 18),

            // Title
            Text(
              'Cancel Rental Booking?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),

            // Description
            Text(
              isAwaitingPayment
                  ? 'Are you sure you want to cancel this booking for ${widget.booking.vehicleTitle}? This will immediately release the vehicle for other customers and cannot be undone.'
                  : 'Are you sure you want to cancel your booking request for ${widget.booking.vehicleTitle}? Your request will be withdrawn immediately.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextColor,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 28),

            // Destructive Confirm Action Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                onPressed: _isCancelling ? null : _handleCancel,
                child: _isCancelling
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Yes, Cancel Booking',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Full-width Keep Booking Cancel Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: secondaryTextColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                onPressed: _isCancelling ? null : () => Navigator.pop(context),
                child: const Text(
                  'Keep Booking',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showRateRentalBottomSheet(BuildContext context, RentalBooking booking) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _RateRentalBottomSheet(booking: booking, isDark: isDark),
  );
}

class _RateRentalBottomSheet extends StatefulWidget {
  const _RateRentalBottomSheet({required this.booking, required this.isDark});

  final RentalBooking booking;
  final bool isDark;

  @override
  State<_RateRentalBottomSheet> createState() => _RateRentalBottomSheetState();
}

class _RateRentalBottomSheetState extends State<_RateRentalBottomSheet> {
  int _selectedRating = 5;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.booking.rating != null && widget.booking.rating! > 0) {
      _selectedRating = widget.booking.rating!.round();
    }
    if (widget.booking.reviewComment != null) {
      _commentController.text = widget.booking.reviewComment!;
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;
      final reviewId = firestore.collection('rental_reviews').doc().id;

      final review = RentalReview(
        id: reviewId,
        bookingId: widget.booking.id,
        vehicleId: widget.booking.vehicleId,
        vehicleTitle: widget.booking.vehicleTitle,
        customerId: widget.booking.customerId,
        customerName: widget.booking.customerName,
        customerPhoto: widget.booking.customerPhoto,
        fleetId: widget.booking.fleetId,
        rating: _selectedRating.toDouble(),
        comment: _commentController.text.trim(),
        createdAt: DateTime.now(),
      );

      // Save to rental_reviews
      await firestore.collection('rental_reviews').doc(reviewId).set(review.toMap());

      // Update booking
      await firestore.collection('rental_bookings').doc(widget.booking.id).update({
        'isRated': true,
        'rating': _selectedRating.toDouble(),
        'reviewComment': _commentController.text.trim(),
        'updatedAt': DateTime.now().toIso8601String(),
      });

      // Recalculate vehicle rating
      final vehicleRef = firestore.collection('rental_vehicles').doc(widget.booking.vehicleId);
      final vehicleDoc = await vehicleRef.get();
      if (vehicleDoc.exists) {
        final data = vehicleDoc.data() ?? {};
        final oldRating = (data['rating'] as num?)?.toDouble() ?? 0.0;
        final oldReviewCount = (data['reviewCount'] as num?)?.toInt() ?? 0;
        final newCount = oldReviewCount + 1;
        final newRating = ((oldRating * oldReviewCount) + _selectedRating) / newCount;

        await vehicleRef.update({
          'rating': newRating,
          'reviewCount': newCount,
        });
      }

      if (mounted) {
        Navigator.pop(context);
        _showReviewSubmittedSuccessBottomSheet(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryTextColor = widget.isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        widget.isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: widget.isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Drag Handle
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Text(
                'Rate Your Ride',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'How was your trip with ${widget.booking.vehicleTitle}?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 20),

              // Star Rating Picker
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starIndex = index + 1;
                  return IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedRating = starIndex;
                      });
                    },
                    icon: Icon(
                      starIndex <= _selectedRating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: const Color(0xFFF59E0B),
                      size: 38,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 16),

              // Feedback Text Field
              TextField(
                controller: _commentController,
                maxLines: 3,
                style: TextStyle(color: primaryTextColor, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Share your experience (optional)...',
                  hintStyle: TextStyle(color: secondaryTextColor, fontSize: 14),
                  filled: true,
                  fillColor: widget.isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF9FAFB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: widget.isDark
                          ? AppColors.glassBorderDark
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.brand),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Submit Button
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
                  onPressed: _isSubmitting ? null : _submitReview,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Submit Review',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _showReviewSubmittedSuccessBottomSheet(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
  final secondaryTextColor =
      isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

  showModalBottomSheet(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Success Circle Badge
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 48,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Review Submitted!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thank you for rating your ride! Your feedback helps us maintain top quality service and safety across CaRide.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),

            // Primary Done Action Button
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
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
