import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

/// A circular frosted-glass icon button with press animation.
class GlassIconButton extends StatefulWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44,
    this.iconSize = 20,
    this.color,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? color;
  final String? semanticLabel;

  @override
  State<GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<GlassIconButton>
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
    _scale = Tween<double>(begin: 1.0, end: 0.9).animate(
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
    final fg = widget.color ??
        (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);

    return Semantics(
      label: widget.semanticLabel,
      button: true,
      child: GestureDetector(
        onTapDown: widget.onPressed != null
            ? (_) => _controller.forward()
            : null,
        onTapUp: widget.onPressed != null
            ? (_) {
                _controller.reverse();
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: () => _controller.reverse(),
        child: ScaleTransition(
          scale: _scale,
          child: ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? AppColors.glassBackgroundDark
                      : AppColors.glassBackgroundLight,
                  border: Border.all(
                    color: isDark
                        ? AppColors.glassBorderDark
                        : AppColors.glassBorderLight,
                    width: AppGlass.borderThin,
                  ),
                ),
                child: Center(
                  child: Icon(widget.icon, size: widget.iconSize, color: fg),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
