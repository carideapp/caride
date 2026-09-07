import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/models/ride_model.dart';
import 'package:caride/features/driver/ride/data/driver_ride_repository.dart';
import 'package:caride/core/driver/widgets/customer_avatar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Driver Rides list view (activity history) with GlassContainers, Tabs, and AppScaffold.
class DriverRidesScreen extends StatelessWidget {
  const DriverRidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rideRepo = DriverRideRepository();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: GlassAppBar(
          title: 'My Rides',
          automaticallyImplyLeading: false,
          bottom: TabBar(
            indicatorColor: AppColors.brand,
            labelColor: AppColors.brand,
            unselectedLabelColor: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            labelStyle: AppTextStyles.titleMedium.copyWith(fontSize: 14),
            unselectedLabelStyle: AppTextStyles.bodyMedium.copyWith(fontSize: 14),
            tabs: const [
              Tab(text: 'Active'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ActiveRidesTab(rideRepo: rideRepo),
            _HistoryTab(rideRepo: rideRepo),
          ],
        ),
      ),
    );
  }
}

class _ActiveRidesTab extends StatelessWidget {
  const _ActiveRidesTab({required this.rideRepo});
  final DriverRideRepository rideRepo;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<RideModel?>(
      stream: rideRepo.streamAssignedRide(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppLoader());
        }
        final ride = snapshot.data;
        if (ride == null) {
          return Center(
            child: EmptyState(
              title: 'No active ride',
              message: 'Accept a ride request to see it here.',
              icon: Icons.directions_car_outlined,
              iconWidget: Image.asset(
                'lib/assets/icons/order.png',
                width: 96,
                height: 96,
                fit: BoxFit.contain,
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          children: [_RideCard(ride: ride, isActive: true)],
        );
      },
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.rideRepo});
  final DriverRideRepository rideRepo;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<RideModel>>(
      stream: rideRepo.streamRideHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppLoader());
        }
        final rides = snapshot.data ?? [];
        if (rides.isEmpty) {
          return Center(
            child: EmptyState(
              title: 'No ride history',
              message: 'Your completed trips will appear here.',
              icon: Icons.history_rounded,
              iconWidget: Image.asset(
                'lib/assets/icons/history.png',
                width: 96,
                height: 96,
                fit: BoxFit.contain,
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          itemCount: rides.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (ctx, i) => _RideCard(ride: rides[i], isActive: false),
        );
      },
    );
  }
}

class _RideCard extends StatelessWidget {
  const _RideCard({required this.ride, required this.isActive});

  final RideModel ride;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fare = ride.finalFare ?? ride.customerOffer;
    final statusLabel = _statusLabel(ride.status);
    final tone = _statusTone(ride.status);

    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                ride.id.substring(0, 8).toUpperCase(),
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.brand,
                  letterSpacing: 1,
                ),
              ),
              StatusChip(
                label: statusLabel,
                tone: tone,
                isActive: ride.status == 'rideStarted' || ride.status == 'driverEnRoute' || ride.status == 'driverArrived',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              CustomerAvatar(
                customerUid: ride.customerUid,
                fallbackLetter: 'C',
                radius: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('customers')
                      .doc(ride.customerUid)
                      .get(),
                  builder: (context, userSnap) {
                    final fullName = userSnap.data?.data()?['fullName'] as String? ?? 'Customer';
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: AppTextStyles.titleMedium,
                        ),
                        if (ride.createdAt != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('dd MMM, hh:mm a').format(ride.createdAt!),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              Text(
                NgnFormat.whole(fare),
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.circle, size: 12, color: AppColors.brand),
                  Container(
                    width: 2,
                    height: 32,
                    color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
                  ),
                  const Icon(Icons.location_on_rounded, size: 14, color: AppColors.error),
                ],
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PICKUP',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ride.pickupLabel,
                      style: AppTextStyles.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'DROPOFF',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ride.dropoffLabel,
                      style: AppTextStyles.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (isActive)
            PrimaryButton(
              label: (ride.status == 'driverEnRoute' || ride.status == 'driverArrived')
                  ? (ride.status == 'driverArrived' ? 'At Pickup — Start Ride' : 'Go to Pickup')
                  : 'View Active Ride',
              onPressed: () => context.push(
                (ride.status == 'driverEnRoute' || ride.status == 'driverArrived')
                    ? DriverRoutePaths.tripPickup
                    : DriverRoutePaths.tripActive,
              ),
            )
          else
            SecondaryButton(
              label: 'View Details',
              onPressed: () => context.push(DriverRoutePaths.rideDetail, extra: ride.id),
              icon: Icons.receipt_long_outlined,
            ),
        ],
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'driverEnRoute' => 'En Route',
    'driverArrived' => 'Arrived',
    'rideStarted' => 'Active',
    'completed' => 'Completed',
    'cancelled' => 'Cancelled',
    _ => status,
  };

  StatusChipTone _statusTone(String status) => switch (status) {
    'driverEnRoute' => StatusChipTone.warning,
    'driverArrived' => StatusChipTone.success,
    'rideStarted' => StatusChipTone.success,
    'completed' => StatusChipTone.success,
    'cancelled' => StatusChipTone.warning,
    _ => StatusChipTone.neutral,
  };
}
