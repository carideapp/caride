import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/models/ride_model.dart';
import 'package:caride/features/driver/ride/data/driver_ride_repository.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverRideHistoryScreen extends StatelessWidget {
  const DriverRideHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Ride History',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: StreamBuilder<List<RideModel>>(
            stream: DriverRideRepository().streamRideHistory(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: EmptyState(
                    title: 'Unable to load history',
                    message: 'Please try again.',
                    icon: Icons.error_outline_rounded,
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final all = snapshot.data!;
              final items = all.where((r) => r.status == 'completed').toList();
              if (items.isEmpty) {
                return const EmptyState(
                  title: 'No trips yet',
                  message: 'Completed rides will appear here.',
                  icon: Icons.receipt_long_rounded,
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.sm,
                ),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final ride = items[index];
                  return _RideHistoryCard(
                    ride: ride,
                    onTap: () => context.push(DriverRoutePaths.rideDetail, extra: ride.id),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RideHistoryCard extends StatelessWidget {
  const _RideHistoryCard({required this.ride, required this.onTap});

  final RideModel ride;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0);

    final when = ride.updatedAt ?? ride.createdAt;
    final dateLabel = when == null
        ? '--'
        : '${when.day.toString().padLeft(2, '0')}/${when.month.toString().padLeft(2, '0')}/${when.year}';
    final fare = ride.finalFare ?? ride.amountNaira ?? ride.customerOffer;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: borderColor),
          boxShadow: isDark
              ? null
              : [
                  const BoxShadow(
                    color: Color(0x0F0F172A),
                    blurRadius: 18,
                    offset: Offset(0, 8),
                  ),
                ],
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                  ),
                ),
                Text(
                  NgnFormat.whole(fare),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w800,
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
                    const Icon(Icons.circle, size: 12, color: AppColors.primaryGreen),
                    Container(
                      width: 2,
                      height: 32,
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                    ),
                    const Icon(Icons.location_on_rounded, size: 14, color: AppColors.error),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PICKUP',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[400] : const Color(0xFF8A90A6),
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ride.pickupLabel,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'DROPOFF',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[400] : const Color(0xFF8A90A6),
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ride.dropoffLabel,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Divider(color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0)),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const StatusChip(label: 'Completed', tone: StatusChipTone.success),
                const Spacer(),
                Text(
                  'View Details',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.primaryGreen),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
