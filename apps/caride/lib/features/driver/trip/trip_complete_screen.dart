import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/state/driver_active_ride_state.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Trip Complete screen featuring premium Liquid Glass status icons, details cards, and clear calls to action.
class TripCompleteScreen extends StatelessWidget {
  const TripCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final ride = DriverActiveRideState.instance.lastCompletedRide;
    final fare = ride?.finalFare ?? ride?.amountNaira ?? ride?.customerOffer ?? 0.0;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: ResponsiveContainer(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.brandGlass,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 80,
                      color: AppColors.brand,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                Text(
                  'Trip Complete!',
                  style: AppTextStyles.headlineLarge.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Great job! You have successfully completed the ride.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                GlassContainer(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Text(
                        'YOU EARNED',
                        style: AppTextStyles.caption.copyWith(
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        NgnFormat.whole(fare),
                        style: AppTextStyles.statLarge.copyWith(
                          color: AppColors.brand,
                        ),
                      ),
                      if (ride != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        const Divider(),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Expanded(
                              child: _MetricColumn(
                                label: 'Pickup',
                                value: ride.pickupLabel.split(',').first,
                              ),
                            ),
                            Expanded(
                              child: _MetricColumn(
                                label: 'Dropoff',
                                value: ride.dropoffLabel.split(',').first,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(),

                PrimaryButton(
                  label: 'Rate your Customer',
                  onPressed: () => context.push(DriverRoutePaths.rateCustomer),
                ),
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: TextButton(
                    onPressed: () {
                      DriverActiveRideState.instance.lastCompletedRide = null;
                      context.go(DriverRoutePaths.home);
                    },
                    child: Text(
                      'Back to Dashboard',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.titleMedium.copyWith(
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          label,
          style: AppTextStyles.caption,
        ),
      ],
    );
  }
}
