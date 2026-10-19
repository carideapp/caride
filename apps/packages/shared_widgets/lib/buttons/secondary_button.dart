import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

/// A frosted-glass secondary button with subtle border and press animation.
class SecondaryButton extends StatefulWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.fullWidth = true,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;
  final double height;

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: AppDurations.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _scaleController, curve: AppCurves.spring),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final border = isDark ? AppColors.darkOutline : AppColors.lightOutline;
    final bg = isDark
        ? AppColors.darkSurfaceRaised.withValues(alpha: 0.6)
        : AppColors.lightSurface.withValues(alpha: 0.8);

    return GestureDetector(
      onTapDown: _enabled ? (_) => _scaleController.forward() : null,
      onTapUp: _enabled
          ? (_) {
              _scaleController.reverse();
              widget.onPressed?.call();
            }
          : null,
      onTapCancel: _enabled ? () => _scaleController.reverse() : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          curve: AppCurves.easeOut,
          height: widget.height,
          width: widget.fullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: widget.fullWidth ? AppSpacing.md : AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: _enabled
                ? bg
                : (isDark ? AppColors.darkSurfaceInset : AppColors.lightSurfaceInset),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: _enabled ? border : border.withValues(alpha: 0.3),
              width: AppGlass.borderThin,
            ),
          ),
          child: Center(
            child: widget.isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(fg),
                    ),
                  )
                : Row(
                    mainAxisSize:
                        widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18, color: fg),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: _enabled
                                ? fg
                                : (isDark
                                    ? AppColors.textDisabledDark
                                    : AppColors.textDisabledLight),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
