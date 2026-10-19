import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import '../skeleton_block.dart';

/// Skeleton loader matching the layout of RentalBooking cards.
class BookingCardSkeleton extends StatelessWidget {
  const BookingCardSkeleton({super.key, this.itemCount = 3});

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
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const SkeletonBlock(width: 64, height: 64, radius: 12),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBlock(width: 160, height: 16, radius: 4),
                        SizedBox(height: 8),
                        SkeletonBlock(width: 110, height: 12, radius: 4),
                        SizedBox(height: 6),
                        SkeletonBlock(width: 80, height: 12, radius: 4),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const SkeletonBlock(width: 72, height: 26, radius: 14),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: borderColor),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  SkeletonBlock(width: 90, height: 14, radius: 4),
                  SkeletonBlock(width: 100, height: 16, radius: 4),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
