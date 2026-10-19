import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

/// A premium slide-to-action widget (Uber-style).
///
/// Used for critical actions like accepting rides and completing trips.
/// The user drags a thumb across a track to confirm the action.
class SlideToAction extends StatefulWidget {
  const SlideToAction({
    super.key,
    required this.label,
    required this.onCompleted,
    this.height = 64,
    this.thumbSize = 56,
    this.color,
    this.icon,
  });

  final String label;
  final VoidCallback onCompleted;
  final double height;
  final double thumbSize;
  final Color? color;
  final IconData? icon;

  @override
  State<SlideToAction> createState() => _SlideToActionState();
}

class _SlideToActionState extends State<SlideToAction>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0;
  bool _completed = false;
  late final AnimationController _resetController;
  late final Animation<double> _resetAnimation;

  @override
  void initState() {
    super.initState();
    _resetController = AnimationController(
      vsync: this,
      duration: AppDurations.normal,
    );
    _resetAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _resetController, curve: AppCurves.spring),
    );
    _resetController.addListener(() {
      if (mounted) {
        setState(() => _dragPosition = _resetAnimation.value * _dragPosition);
      }
    });
  }

  @override
  void dispose() {
    _resetController.dispose();
    super.dispose();
  }

  double get _maxDrag {
    return (context.size?.width ?? 300) - widget.thumbSize - 8;
  }

  double get _progress => (_dragPosition / _maxDrag).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.color ?? AppColors.brand;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceRaised
            : AppColors.lightSurfaceInset,
        borderRadius: BorderRadius.circular(widget.height / 2),
        border: Border.all(
          color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
          width: AppGlass.borderThin,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxDrag = constraints.maxWidth - widget.thumbSize - 8;

          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Label
              Center(
                child: AnimatedOpacity(
                  duration: AppDurations.fast,
                  opacity: _completed ? 0.0 : (1.0 - _progress * 1.5).clamp(0.0, 1.0),
                  child: Text(
                    widget.label,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // Filled track
              AnimatedContainer(
                duration: AppDurations.instant,
                width: _dragPosition + widget.thumbSize + 4,
                height: widget.height,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.3),
                      accentColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(widget.height / 2),
                ),
              ),
              // Thumb
              Positioned(
                left: 4 + _dragPosition,
                child: GestureDetector(
                  onHorizontalDragUpdate: _completed
                      ? null
                      : (details) {
                          setState(() {
                            _dragPosition = (_dragPosition + details.delta.dx)
                                .clamp(0.0, maxDrag);
                          });
                        },
                  onHorizontalDragEnd: _completed
                      ? null
                      : (details) {
                          if (_dragPosition >= maxDrag * 0.85) {
                            setState(() {
                              _completed = true;
                              _dragPosition = maxDrag;
                            });
                            widget.onCompleted();
                          } else {
                            final startPos = _dragPosition;
                            _resetController.reset();
                            _resetController.addListener(() {
                              if (mounted) {
                                setState(() {
                                  _dragPosition =
                                      startPos * (1 - _resetController.value);
                                });
                              }
                            });
                            _resetController.forward();
                          }
                        },
                  child: AnimatedContainer(
                    duration: AppDurations.instant,
                    width: widget.thumbSize,
                    height: widget.thumbSize - 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: _completed
                            ? [accentColor, accentColor]
                            : [AppColors.brandLight, accentColor],
                      ),
                      borderRadius:
                          BorderRadius.circular((widget.thumbSize - 8) / 2),
                      boxShadow: AppShadows.glowDark,
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: AppDurations.fast,
                        child: _completed
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 24, key: ValueKey('check'))
                            : Icon(
                                widget.icon ?? Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 20,
                                key: const ValueKey('arrow'),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
