import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer Legacy Ride Track Screen.
class RideTrackScreen extends StatefulWidget {
  const RideTrackScreen({super.key, this.params});

  final Map<String, dynamic>? params;

  @override
  State<RideTrackScreen> createState() => _RideTrackScreenState();
}

class _RideTrackScreenState extends State<RideTrackScreen> {
  final RideRepository _rideRepo = RideRepository();

  String get _rideId => widget.params?['rideId'] as String? ?? '';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final steps = <String>[
      'requested',
      'bidding',
      'driverEnRoute',
      'rideStarted',
      'completed',
    ];

    String label(String s) => switch (s) {
          'requested' => 'Requested',
          'bidding' => 'Bidding',
          'driverEnRoute' => 'Driver en route',
          'rideStarted' => 'Ride started',
          'completed' => 'Completed',
          'cancelled' => 'Cancelled',
          _ => 'Unknown',
        };

    if (_rideId.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: const Center(
          child: Text(
            'Invalid ride ID',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: 'Trip Status',
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: StreamBuilder<RideModel?>(
            stream: _rideRepo.watchRide(_rideId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Error loading ride',
                    style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: AppLoader());
              }

              final ride = snapshot.data!;
              final isCancelled = ride.status == 'cancelled';
              final activeIndex = steps.indexOf(ride.status).clamp(0, steps.length - 1);

              return ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePadding,
                  vertical: AppSpacing.lg,
                ),
                children: [
                  GlassContainer(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Trip',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.route_outlined, color: AppColors.brand, size: 16),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${ride.pickupLabel} → ${ride.dropoffLabel}',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  if (isCancelled)
                    GlassContainer(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          const Icon(Icons.cancel_rounded, color: AppColors.error),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Ride Cancelled',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: AppColors.error,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    GlassContainer(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(steps.length, (i) {
                          final done = i <= activeIndex;
                          return IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Column(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: done
                                            ? AppColors.brandGlass
                                            : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: done ? AppColors.brand : (isDark ? Colors.grey[800]! : const Color(0xFFE2E8F0)),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: done
                                          ? const Icon(
                                              Icons.check_circle_rounded,
                                              color: AppColors.brand,
                                              size: 16,
                                            )
                                          : null,
                                    ),
                                    if (i < steps.length - 1)
                                      Expanded(
                                        child: Container(
                                          width: 2,
                                          color: done
                                              ? AppColors.brand
                                              : (isDark ? Colors.grey[800] : const Color(0xFFE2E8F0)),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          label(steps[i]),
                                          style: AppTextStyles.titleMedium.copyWith(
                                            color: done
                                                ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                                                : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                            fontWeight: done ? FontWeight.w800 : FontWeight.w500,
                                          ),
                                        ),
                                        if (i == activeIndex && i < steps.length - 1) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Current step',
                                            style: AppTextStyles.bodySmall.copyWith(
                                              color: AppColors.brand,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ),
                  if (!isCancelled && ride.status != 'completed') ...[
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(
                      label: 'Chat with Driver',
                      onPressed: () {
                         context.push(CustomerRoutePaths.chat);
                      },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(
                    label: 'Back to home',
                    onPressed: () => context.go(CustomerRoutePaths.home),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
