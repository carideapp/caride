import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

/// Legacy depth aliases to prevent compilation breaks.
enum NeumorphicDepth {
  neutral,
  raised,
  pressed,
}

/// A glass-morphism container replacing the legacy neumorphic style.
///
/// Uses translucent background with subtle border for a premium glass look.
/// For real backdrop blur, use [GlassSurface] from `glass_surface.dart`.
class NeumorphicContainer extends StatelessWidget {
  const NeumorphicContainer({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius = AppRadius.xl,
    this.color,
    this.onTap,
    this.depth,
    this.backgroundColor,
    this.gradient,
    this.shadowOverride,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;
  final NeumorphicDepth? depth;
  final Color? backgroundColor;
  final Gradient? gradient;
  final List<BoxShadow>? shadowOverride;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = color ?? backgroundColor ??
        (isDark ? AppColors.darkSurfaceRaised : AppColors.lightSurfaceRaised);
    final border = isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight;
    final shadows = shadowOverride ?? (isDark ? AppShadows.cardDark : AppShadows.cardLight);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: margin,
        padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: gradient == null ? bg : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: border, width: AppGlass.borderThin),
          boxShadow: shadows,
        ),
        child: child,
      ),
    );
  }
}
