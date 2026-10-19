import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

/// A glass-inset container replacing the legacy neumorphic inset style.
///
/// Used for input wells and recessed surfaces.
class NeumorphicInset extends StatelessWidget {
  const NeumorphicInset({
    super.key,
    required this.child,
    this.padding,
    this.radius = AppRadius.md,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceInset : AppColors.lightSurfaceInset,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: isDark
              ? AppColors.darkOutline.withValues(alpha: 0.3)
              : AppColors.lightOutline.withValues(alpha: 0.3),
          width: AppGlass.borderThin,
        ),
      ),
      child: child,
    );
  }
}
