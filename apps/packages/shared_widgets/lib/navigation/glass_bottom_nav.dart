import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

/// A floating frosted glass bottom navigation bar with animated indicators.
///
/// Designed to sit at the bottom of the screen with safe-area padding and
/// float above content for a premium Liquid Glass aesthetic.
class GlassBottomNav extends StatelessWidget {
  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.activeColor,
    this.inactiveColor,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<GlassNavItem> items;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: AppGlass.blurHeavy, sigmaY: AppGlass.blurHeavy),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.darkBackground.withValues(alpha: 0.85)
                : AppColors.lightBackground.withValues(alpha: 0.88),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? AppColors.glassBorderDark
                    : AppColors.glassBorderLight,
                width: AppGlass.borderThin,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 56 + bottomPadding * 0, // SafeArea handles bottom
              child: Row(
                children: List.generate(items.length, (i) {
                  return Expanded(
                    child: _NavBarItem(
                      item: items[i],
                      isSelected: i == currentIndex,
                      onTap: () => onTap(i),
                      isDark: isDark,
                      activeColor: activeColor,
                      inactiveColor: inactiveColor,
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A single navigation item definition.
class GlassNavItem {
  const GlassNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badge,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? badge;
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    this.activeColor,
    this.inactiveColor,
  });

  final GlassNavItem item;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    final effectiveActiveColor = activeColor ?? AppColors.brand;
    final effectiveInactiveColor = inactiveColor ??
        (isDark ? AppColors.textTertiaryDark : AppColors.textPrimaryLight);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedSwitcher(
                duration: AppDurations.fast,
                child: Icon(
                  isSelected ? item.activeIcon : item.icon,
                  key: ValueKey(isSelected),
                  size: 24,
                  color: isSelected ? effectiveActiveColor : effectiveInactiveColor,
                ),
              ),
              if (item.badge != null && item.badge! > 0)
                Positioned(
                  right: -8,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 16),
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Center(
                      child: Text(
                        item.badge! > 99 ? '99+' : '${item.badge}',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: AppTextStyles.labelSmall.copyWith(
              fontSize: 10,
              color: isSelected ? effectiveActiveColor : effectiveInactiveColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
