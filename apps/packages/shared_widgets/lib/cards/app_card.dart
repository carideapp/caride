import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

/// A Liquid Glass card with backdrop blur, translucent tint, and soft border.
///
/// Press animation scales the card on tap for tactile feedback.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.radius = AppRadius.xl,
    this.useBlur = false,
    this.blurSigma = AppGlass.blurMedium,
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double radius;

  /// Whether to use real BackdropFilter blur. Set to false for list items
  /// to avoid performance issues.
  final bool useBlur;
  final double blurSigma;
  final Color? color;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.fast,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: AppCurves.spring),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.color ??
        (isDark ? AppColors.darkSurfaceRaised : AppColors.lightSurfaceRaised);
    final border = isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight;
    final shadows = isDark ? AppShadows.cardDark : AppShadows.cardLight;

    Widget card = Container(
      padding: widget.padding ?? const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: widget.useBlur
            ? (isDark ? AppColors.glassBackgroundDark : AppColors.glassBackgroundLight)
            : bg,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: border, width: AppGlass.borderThin),
        boxShadow: widget.useBlur ? null : shadows,
      ),
      child: widget.child,
    );

    if (widget.useBlur) {
      card = ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: widget.blurSigma,
            sigmaY: widget.blurSigma,
          ),
          child: card,
        ),
      );
    }

    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => _controller.forward() : null,
      onTapUp: widget.onTap != null
          ? (_) {
              _controller.reverse();
              widget.onTap?.call();
            }
          : null,
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          margin: widget.margin,
          child: card,
        ),
      ),
    );
  }
}
