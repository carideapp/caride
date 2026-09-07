import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

import '../buttons/primary_button.dart';
import '../buttons/ghost_button.dart';

/// A premium empty state with illustration icon, message, and action buttons.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    this.iconWidget,
    required this.title,
    this.message,
    this.primaryAction,
    this.primaryLabel,
    this.secondaryAction,
    this.secondaryLabel,
    this.action, // Legacy parameter fallback
    this.iconSize = 64,
  });

  final IconData icon;
  final Widget? iconWidget;
  final String title;
  final String? message;
  final VoidCallback? primaryAction;
  final String? primaryLabel;
  final VoidCallback? secondaryAction;
  final String? secondaryLabel;
  final Widget? action;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget ?? Container(
              width: iconSize + 32,
              height: iconSize + 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? AppColors.darkSurfaceRaised
                    : AppColors.lightSurfaceInset,
                border: Border.all(
                  color: isDark
                      ? AppColors.darkOutline
                      : AppColors.lightOutline,
                  width: AppGlass.borderThin,
                ),
              ),
              child: Center(
                child: Icon(
                  icon,
                  size: iconSize,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              title,
              style: AppTextStyles.headlineSmall.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (primaryAction != null && primaryLabel != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: 200,
                child: PrimaryButton(
                  label: primaryLabel!,
                  onPressed: primaryAction,
                  fullWidth: false,
                ),
              ),
            ] else if (action != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              action!,
            ],
            if (secondaryAction != null && secondaryLabel != null) ...[
              const SizedBox(height: AppSpacing.sm),
              GhostButton(
                label: secondaryLabel!,
                onPressed: secondaryAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
