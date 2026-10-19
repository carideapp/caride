import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import '../skeleton_block.dart';

/// Skeleton loader matching the layout of wallet & fleet transaction history items.
class TransactionListSkeleton extends StatelessWidget {
  const TransactionListSkeleton({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: itemCount,
        separatorBuilder: (_, __) => Divider(height: 1, color: borderColor),
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const SkeletonBlock(width: 44, height: 44, radius: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      SkeletonBlock(width: 140, height: 15, radius: 4),
                      SizedBox(height: 6),
                      SkeletonBlock(width: 90, height: 12, radius: 4),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: const [
                    SkeletonBlock(width: 75, height: 16, radius: 4),
                    SizedBox(height: 6),
                    SkeletonBlock(width: 55, height: 12, radius: 4),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
