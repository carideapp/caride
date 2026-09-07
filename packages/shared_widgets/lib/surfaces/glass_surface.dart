import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

/// A frosted-glass surface widget using real [BackdropFilter] blur.
///
/// Wraps its [child] in a clipped, blurred container with configurable
/// tint, border, and radius — the building block for all Liquid Glass UI.
///
/// ```dart
/// GlassSurface(
///   child: Padding(
///     padding: EdgeInsets.all(AppSpacing.lg),
///     child: Text('Hello Glass'),
///   ),
/// );
/// ```
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = AppRadius.xl,
    this.blurSigma = AppGlass.blurMedium,
    this.tint,
    this.borderWidth = AppGlass.borderThin,
    this.borderColor,
    this.padding,
    this.margin,
    this.shadows,
  });

  final Widget child;
  final double radius;
  final double blurSigma;
  final Color? tint;
  final double borderWidth;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = tint ??
        (isDark ? AppColors.glassBackgroundDark : AppColors.glassBackgroundLight);
    final border = borderColor ??
        (isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: border, width: borderWidth),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A non-blurred glass container — uses translucent tint and border without
/// the performance cost of [BackdropFilter]. Use for items in scrolling lists.
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.radius = AppRadius.xl,
    this.tint,
    this.borderWidth = AppGlass.borderThin,
    this.borderColor,
    this.padding,
    this.margin,
    this.shadows,
  });

  final Widget child;
  final double radius;
  final Color? tint;
  final double borderWidth;
  final Color? borderColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final List<BoxShadow>? shadows;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = tint ??
        (isDark ? AppColors.darkSurfaceRaised : AppColors.lightSurfaceRaised);
    final border = borderColor ??
        (isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: borderWidth),
        boxShadow: shadows,
      ),
      padding: padding,
      child: child,
    );
  }
}
