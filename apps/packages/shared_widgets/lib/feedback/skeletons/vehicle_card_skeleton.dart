import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import '../skeleton_block.dart';

/// Skeleton loader matching the layout of RentalVehicle inventory cards.
class VehicleCardSkeleton extends StatelessWidget {
  const VehicleCardSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Vehicle Image Placeholder
              const SkeletonBlock(
                width: double.infinity,
                height: 160,
                radius: 16,
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        SkeletonBlock(width: 180, height: 18, radius: 4),
                        SkeletonBlock(width: 50, height: 22, radius: 12),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: const [
                        SkeletonBlock(width: 70, height: 14, radius: 4),
                        SizedBox(width: 12),
                        SkeletonBlock(width: 80, height: 14, radius: 4),
                        SizedBox(width: 12),
                        SkeletonBlock(width: 60, height: 14, radius: 4),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(height: 1, color: borderColor),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        SkeletonBlock(width: 120, height: 18, radius: 4),
                        SkeletonBlock(width: 90, height: 36, radius: 18),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
