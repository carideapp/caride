import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

/// A transparent text-only button with hover/press tint animation.
class GhostButton extends StatefulWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;

  @override
  State<GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<GhostButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = widget.color ?? AppColors.brand;

    return GestureDetector(
      onTapDown: widget.onPressed != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.onPressed != null
          ? (_) {
              setState(() => _pressed = false);
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        curve: AppCurves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: _pressed
              ? fg.withValues(alpha: isDark ? 0.12 : 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, size: 16, color: fg),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              widget.label,
              style: AppTextStyles.titleMedium.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
