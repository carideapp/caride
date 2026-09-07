import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/models/ride_model.dart';
import 'package:caride/features/driver/ride/data/driver_ride_repository.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Driver Ride Detail view built using GlassAppBar, GlassContainers, AppLoader, and updated tokens.
class DriverRideDetailScreen extends StatelessWidget {
  const DriverRideDetailScreen({super.key, this.rideId});

  final String? rideId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (rideId == null || rideId!.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: GlassAppBar(title: 'Ride Details'),
        body: const Center(
          child: EmptyState(
            title: 'No ride selected',
            message: 'Please navigate here from a ride card.',
            icon: Icons.receipt_long_rounded,
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('rides')
          .doc(rideId)
          .snapshots()
          .cast<DocumentSnapshot<Map<String, dynamic>>>(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
            appBar: GlassAppBar(title: 'Ride Details'),
            body: const Center(child: AppLoader()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
            appBar: GlassAppBar(title: 'Ride Details'),
            body: Center(
              child: EmptyState(
                title: 'Something went wrong',
                message: snapshot.error.toString(),
                icon: Icons.error_outline_rounded,
              ),
            ),
          );
        }
        final doc = snapshot.data;
        if (doc == null || !doc.exists) {
          return Scaffold(
            backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
            appBar: GlassAppBar(title: 'Ride Details'),
            body: const Center(
              child: EmptyState(
                title: 'Ride not found',
                message: 'This ride may have been removed.',
                icon: Icons.receipt_long_rounded,
              ),
            ),
          );
        }
        final ride = RideModel.fromDoc(doc);
        return _RideDetailBody(ride: ride);
      },
    );
  }
}

class _RideDetailBody extends StatelessWidget {
  const _RideDetailBody({required this.ride});

  final RideModel ride;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final displayFare = ride.finalFare ?? ride.amountNaira ?? ride.customerOffer;
    final statusLabel = _statusLabel(ride.status);
    final tone = _statusTone(ride.status);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? Colors.white : AppColors.slate900,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: 'Ride #${ride.id.substring(0, 8).toUpperCase()}',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: StatusChip(
              label: statusLabel,
              tone: tone,
              isActive: ride.status == 'rideStarted' || ride.status == 'driverEnRoute' || ride.status == 'driverArrived',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            children: [
              _SectionLabel(label: 'ROUTE'),
              const SizedBox(height: AppSpacing.sm),
              GlassContainer(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  children: [
                    _LocationItem(
                      icon: Icons.circle,
                      iconColor: AppColors.brand,
                      title: 'Pickup',
                      subtitle: ride.pickupLabel.isNotEmpty
                          ? ride.pickupLabel
                          : ride.pickupName ?? 'Unknown',
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 11, top: 4, bottom: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          height: 20,
                          child: VerticalDivider(
                            thickness: 2,
                            color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
                          ),
                        ),
                      ),
                    ),
                    _LocationItem(
                      icon: Icons.location_on_rounded,
                      iconColor: AppColors.error,
                      title: 'Dropoff',
                      subtitle: ride.dropoffLabel.isNotEmpty
                          ? ride.dropoffLabel
                          : ride.dropoffName ?? 'Unknown',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              _SectionLabel(label: 'DETAILS'),
              const SizedBox(height: AppSpacing.sm),
              GlassContainer(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'Ride Type',
                      value: ride.rideType,
                    ),
                    Divider(color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight),
                    _DetailRow(
                      label: 'Payment Method',
                      value: _paymentLabel(ride.paymentMethod),
                    ),
                    if (ride.createdAt != null) ...[
                      Divider(color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight),
                      _DetailRow(
                        label: 'Date',
                        value: DateFormat('dd MMM yyyy, hh:mm a').format(ride.createdAt!),
                      ),
                    ],
                    if (ride.acceptedAt != null) ...[
                      Divider(color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight),
                      _DetailRow(
                        label: 'Accepted At',
                        value: DateFormat('dd MMM yyyy, hh:mm a').format(ride.acceptedAt!),
                      ),
                    ],
                    if (ride.rideType.toLowerCase() == 'courier') ...[
                      Divider(color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight),
                      _DetailRow(
                        label: 'Receiver Name',
                        value: ride.receiverName ?? '—',
                      ),
                      Divider(color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight),
                      _DetailRow(
                        label: 'Receiver Phone',
                        value: ride.receiverPhone ?? '—',
                      ),
                      if (ride.deliveryPin != null && ride.deliveryPin!.isNotEmpty) ...[
                        Divider(color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight),
                        _DetailRow(
                          label: 'Delivery PIN',
                          value: ride.deliveryPin!,
                        ),
                      ],
                      if (ride.startCode != null && ride.startCode!.isNotEmpty) ...[
                        Divider(color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight),
                        _DetailRow(
                          label: 'Start Code',
                          value: ride.startCode!,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              _SectionLabel(label: 'PAYMENT'),
              const SizedBox(height: AppSpacing.sm),
              GlassContainer(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.finalFare != null ? 'Final Fare' : 'Agreed Fare',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          NgnFormat.whole(displayFare),
                          style: AppTextStyles.titleLarge.copyWith(
                            color: AppColors.brand,
                          ),
                        ),
                      ],
                    ),
                    if (ride.paymentStatus != null)
                      StatusChip(
                        label: _paymentStatusLabel(ride.paymentStatus!),
                        tone: ride.paymentStatus == 'paid'
                            ? StatusChipTone.success
                            : StatusChipTone.warning,
                        isActive: ride.paymentStatus == 'paid',
                      ),
                  ],
                ),
              ),

              if (ride.customerRating != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _SectionLabel(label: 'CUSTOMER RATING'),
                const SizedBox(height: AppSpacing.sm),
                GlassContainer(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      ...List.generate(5, (i) {
                        return Icon(
                          i < (ride.customerRating ?? 0).clamp(0, 5)
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          color: const Color(0xFFFFB100),
                          size: 24,
                        );
                      }),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        ride.customerRating!.toString(),
                        style: AppTextStyles.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xl),

              if (ride.status == 'driverEnRoute') ...[
                PrimaryButton(
                  label: "I've Arrived",
                  icon: Icons.pin_drop_rounded,
                  onPressed: () async {
                    try {
                      await DriverRideRepository().markDriverArrived(ride.id);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Marked as arrived at pickup!")),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
                      );
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                SecondaryButton(
                  label: 'Go to Pickup',
                  onPressed: () => context.push(DriverRoutePaths.tripPickup),
                  icon: Icons.directions_car_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
              ] else if (ride.status == 'driverArrived') ...[
                PrimaryButton(
                  label: 'At Pickup — Start Ride',
                  onPressed: () => context.push(DriverRoutePaths.tripPickup),
                  icon: Icons.play_arrow_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
              ] else if (ride.status == 'rideStarted') ...[
                PrimaryButton(
                  label: 'View Active Ride',
                  onPressed: () => context.push(DriverRoutePaths.tripActive),
                  icon: Icons.navigation_rounded,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(String status) => switch (status) {
    'driverEnRoute' => 'En Route',
    'driverArrived' => 'Arrived',
    'rideStarted' => 'Active',
    'completed' => 'Completed',
    'cancelled' => 'Cancelled',
    'bidding' => 'Bidding',
    'requested' => 'Requested',
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

  String _paymentLabel(String method) => switch (method) {
    'cash' => 'Cash',
    'card' => 'Card',
    'wallet' => 'Wallet',
    _ => method,
  };

  String _paymentStatusLabel(String status) => switch (status) {
    'paid' => 'Paid',
    'pending' => 'Pending',
    'failed' => 'Failed',
    _ => status,
  };
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Text(
      label,
      style: AppTextStyles.caption.copyWith(
        letterSpacing: 1.5,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: AppTextStyles.titleMedium,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationItem extends StatelessWidget {
  const _LocationItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.toUpperCase(),
                style: AppTextStyles.caption.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: AppTextStyles.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
