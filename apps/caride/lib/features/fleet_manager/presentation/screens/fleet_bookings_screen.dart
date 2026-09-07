import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';
import '../../controllers/fleet_manager_controller.dart';
import '../widgets/fleet_bottom_nav.dart';

/// Redesigned Fleet Bookings List Screen matching CaRide design system.
class FleetBookingsScreen extends StatefulWidget {
  const FleetBookingsScreen({super.key});

  @override
  State<FleetBookingsScreen> createState() => _FleetBookingsScreenState();
}

class _FleetBookingsScreenState extends State<FleetBookingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      extendBody: true,
      bottomNavigationBar: FleetBottomNav(currentIndex: 1),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Circular Back Button & Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: primaryTextColor,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Rental Orders',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.brand,
              indicatorWeight: 3,
              labelColor: AppColors.brand,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelColor: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              tabs: const [
                Tab(text: 'Pending'),
                Tab(text: 'Active'),
                Tab(text: 'Done'),
                Tab(text: 'Declined'),
              ],
            ),

            // Tab Content
            Expanded(
              child: ListenableBuilder(
                listenable: fleetManagerController,
                builder: (context, _) {
                  final bookings = fleetManagerController.bookings;

                  final pending = bookings
                      .where((b) => b.status == RentalBookingStatus.pendingApproval)
                      .toList();
                  final active = bookings
                      .where((b) =>
                          b.status == RentalBookingStatus.confirmed ||
                          b.status == RentalBookingStatus.inProgress)
                      .toList();
                  final completed = bookings
                      .where((b) => b.status == RentalBookingStatus.completed)
                      .toList();
                  final cancelled = bookings
                      .where((b) =>
                          b.status == RentalBookingStatus.cancelled ||
                          b.status == RentalBookingStatus.rejected)
                      .toList();

                  return TabBarView(
                    controller: _tabController,
                    children: [
                      _BookingsListView(
                        bookings: pending,
                        emptyMessage: 'No pending rental orders.',
                      ),
                      _BookingsListView(
                        bookings: active,
                        emptyMessage: 'No active rental orders on the road.',
                      ),
                      _BookingsListView(
                        bookings: completed,
                        emptyMessage: 'No completed orders yet.',
                      ),
                      _BookingsListView(
                        bookings: cancelled,
                        emptyMessage: 'No declined or cancelled orders.',
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

class _BookingsListView extends StatelessWidget {
  const _BookingsListView({
    required this.bookings,
    required this.emptyMessage,
  });

  final List<RentalBooking> bookings;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_outlined,
                size: 48,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 14.0, bottom: 96.0),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return _BookingTile(booking: booking);
      },
    );
  }
}

class _BookingTile extends StatelessWidget {
  const _BookingTile({required this.booking});

  final RentalBooking booking;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateFormat = DateFormat('MMM dd, yyyy');

    Color statusColor;
    Color statusBg;
    switch (booking.status) {
      case RentalBookingStatus.confirmed:
      case RentalBookingStatus.inProgress:
      case RentalBookingStatus.completed:
        statusColor = AppColors.brand;
        statusBg = const Color(0xFFDCFCE7);
        break;
      case RentalBookingStatus.pendingApproval:
        statusColor = const Color(0xFFF59E0B);
        statusBg = const Color(0xFFFEF3C7);
        break;
      case RentalBookingStatus.cancelled:
      case RentalBookingStatus.rejected:
        statusColor = AppColors.error;
        statusBg = const Color(0xFFFEE2E2);
        break;
    }

    return GestureDetector(
      onTap: () => context.push(
        FleetRoutePaths.bookingDetail,
        extra: booking,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: booking.vehicleImage.isNotEmpty
                      ? Image.network(
                          booking.vehicleImage,
                          width: 64,
                          height: 52,
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
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? Colors.white : const Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${dateFormat.format(booking.startDate)} (${booking.durationDays}d)',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    booking.status.label,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            Divider(height: 24, color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 16, color: AppColors.brand),
                    const SizedBox(width: 4),
                    Text(
                      booking.customerName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
                Text(
                  NgnFormat.currency(booking.totalAmount),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.brand,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 64,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.directions_car, color: AppColors.brand, size: 24),
    );
  }
}
