import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverRentalBookingsScreen extends StatefulWidget {
  const DriverRentalBookingsScreen({super.key});

  @override
  State<DriverRentalBookingsScreen> createState() => _DriverRentalBookingsScreenState();
}

class _DriverRentalBookingsScreenState extends State<DriverRentalBookingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<RentalBooking>> _streamDriverBookings() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(const []);

    return FirebaseFirestore.instance
        .collection('rental_bookings')
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => RentalBooking.fromMap(doc.data(), doc.id))
          .where((b) => b.assignedDriverId != null && b.assignedDriverId!.isNotEmpty && (b.assignedDriverId == uid))
          .toList();
      list.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
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
            // Top Bar
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
                    'Assigned Rentals',
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
              child: StreamBuilder<List<RentalBooking>>(
                stream: _streamDriverBookings(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const BookingCardSkeleton(itemCount: 4);
                  }

                  final all = snapshot.data ?? [];
                  final active = all
                      .where((b) =>
                          b.status != RentalBookingStatus.completed &&
                          b.status != RentalBookingStatus.cancelled &&
                          b.status != RentalBookingStatus.rejected)
                      .toList();
                  final completed = all
                      .where((b) => b.status == RentalBookingStatus.completed)
                      .toList();

                  return Column(
                    children: [
                      // Tab Bar
                      Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                              width: 1,
                            ),
                          ),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicatorColor: AppColors.brand,
                          indicatorWeight: 3,
                          indicatorSize: TabBarIndicatorSize.tab,
                          labelColor: AppColors.brand,
                          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          unselectedLabelColor: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                          tabs: const [
                            Tab(text: 'Active'),
                            Tab(text: 'Completed'),
                          ],
                        ),
                      ),

                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildList(active, isDark, isEmptyActive: true),
                            _buildList(completed, isDark, isEmptyActive: false),
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

  Widget _buildList(List<RentalBooking> bookings, bool isDark, {required bool isEmptyActive}) {
    if (bookings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.car_rental_rounded, size: 36, color: AppColors.brand),
              ),
              const SizedBox(height: 16),
              Text(
                isEmptyActive ? 'No Assigned Rentals' : 'No Completed Rentals',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isEmptyActive
                    ? 'When a fleet manager assigns you a rental booking, it will appear here.'
                    : 'Your completed rental trips will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: bookings.length,
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return _DriverBookingCard(booking: booking, isDark: isDark);
      },
    );
  }
}

class _DriverBookingCard extends StatelessWidget {
  const _DriverBookingCard({required this.booking, required this.isDark});

  final RentalBooking booking;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final dateFormat = DateFormat('EEE, MMM dd • hh:mm a');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vehicle Info
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: booking.vehicleImage.isNotEmpty
                    ? Image.network(
                        booking.vehicleImage,
                        width: 64,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _carPlaceholder(),
                      )
                    : _carPlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.vehicleTitle,
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: primaryTextColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${booking.serviceType.label} • ${booking.durationDays} Day(s)',
                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: isDark ? AppColors.glassBorderDark : const Color(0xFFF3F4F6)),
          const SizedBox(height: 12),

          // Customer & Location
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.brand),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  booking.customerName,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: primaryTextColor),
                ),
              ),
              if (booking.customerPhone.isNotEmpty)
                Text(
                  booking.customerPhone,
                  style: TextStyle(fontSize: 12, color: secondaryTextColor),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on_outlined, size: 16, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  booking.pickupLocation,
                  style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 8),
              Text(
                dateFormat.format(booking.startDate),
                style: TextStyle(fontSize: 12, color: secondaryTextColor),
              ),
            ],
          ),

          if (booking.status != RentalBookingStatus.completed) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () {
                  context.push(DriverRoutePaths.rentalTrip, extra: booking);
                },
                child: Text(
                  booking.rentalTripStatus == RentalTripStatus.inProgress
                      ? 'Resume Rental Trip'
                      : (booking.rentalTripStatus == RentalTripStatus.headingToPickup
                          ? 'Continue to Pickup'
                          : 'Open Rental Trip'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _carPlaceholder() {
    return Container(
      width: 64,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(Icons.directions_car, color: AppColors.brand, size: 24),
    );
  }
}
