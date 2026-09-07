import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

/// A premium primary action button with press-scale animation and
/// optional loading shimmer.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.fullWidth = true,
    this.height = 52,
    this.backgroundColor, // Legacy fallback
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;
  final double height;
  final Color? backgroundColor;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton>
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
    final fallbackColor = widget.backgroundColor;

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
            gradient: _enabled && fallbackColor == null
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.brandLight, AppColors.brand],
                  )
                : null,
            color: _enabled
                ? fallbackColor
                : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: _enabled ? AppShadows.glowDark : null,
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisSize:
                        widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, size: 18, color: Colors.white),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: _enabled
                                ? Colors.white
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
