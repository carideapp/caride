import 'package:caride/core/models/ride_viewer.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Overlapping driver profile photo avatars stack with live viewer count text.
class StackedDriverAvatars extends StatelessWidget {
  const StackedDriverAvatars({
    super.key,
    required this.viewers,
    required this.isDark,
  });

  final List<RideViewer> viewers;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (viewers.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayViewers = viewers.take(4).toList();
    final count = viewers.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkSurface : Colors.white).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Overlapping avatar stack
          SizedBox(
            height: 32,
            width: 32.0 + (displayViewers.length - 1) * 20.0,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (int i = 0; i < displayViewers.length; i++)
                  Positioned(
                    left: i * 20.0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          width: 2.0,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: AppColors.brand.withValues(alpha: 0.15),
                        backgroundImage: (displayViewers[i].profilePhotoUrl != null &&
                                displayViewers[i].profilePhotoUrl!.isNotEmpty)
                            ? NetworkImage(displayViewers[i].profilePhotoUrl!)
                            : null,
                        child: (displayViewers[i].profilePhotoUrl == null ||
                                displayViewers[i].profilePhotoUrl!.isEmpty)
                            ? Text(
                                displayViewers[i].driverName.isNotEmpty
                                    ? displayViewers[i].driverName[0].toUpperCase()
                                    : 'D',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.brand,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              count == 1
                  ? '1 driver is viewing your request'
                  : '$count drivers are viewing your request',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
