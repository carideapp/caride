import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import '../skeleton_block.dart';

/// Skeleton loader matching the layout of ratings & reviews screen views.
class ReviewsListSkeleton extends StatelessWidget {
  const ReviewsListSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          // Overall Rating Card Skeleton
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Column(
                  children: const [
                    SkeletonBlock(width: 60, height: 42, radius: 6),
                    SizedBox(height: 8),
                    SkeletonBlock(width: 90, height: 16, radius: 4),
                    SizedBox(height: 6),
                    SkeletonBlock(width: 70, height: 12, radius: 4),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: List.generate(
                      5,
                      (_) => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 3),
                        child: SkeletonBlock(
                          width: double.infinity,
                          height: 8,
                          radius: 4,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Filter chips skeleton
          Row(
            children: const [
              SkeletonBlock(width: 70, height: 36, radius: 18),
              SizedBox(width: 8),
              SkeletonBlock(width: 80, height: 36, radius: 18),
              SizedBox(width: 8),
              SkeletonBlock(width: 80, height: 36, radius: 18),
            ],
          ),
          const SizedBox(height: 20),

          // Review cards list skeleton
          ListView.separated(
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
                        const SkeletonBlock(width: 44, height: 44, radius: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              SkeletonBlock(width: 120, height: 15, radius: 4),
                              SizedBox(height: 6),
                              SkeletonBlock(width: 90, height: 12, radius: 4),
                            ],
                          ),
                        ),
                        const SkeletonBlock(width: 50, height: 24, radius: 12),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const SkeletonBlock(
                      width: double.infinity,
                      height: 14,
                      radius: 4,
                    ),
                    const SizedBox(height: 6),
                    const SkeletonBlock(width: 200, height: 14, radius: 4),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        SkeletonBlock(width: 80, height: 12, radius: 4),
                        SkeletonBlock(width: 40, height: 16, radius: 4),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
