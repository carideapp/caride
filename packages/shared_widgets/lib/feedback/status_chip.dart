import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

/// Semantic tones for StatusChip to match legacy API.
enum StatusChipTone {
  success,
  warning,
  danger,
  info,
  neutral,
}

/// A glass status chip with semantic colors and optional pulse for active states.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.color,
    this.tone,
    this.icon,
    this.isActive = false,
  });

  final String label;
  final Color? color;
  final StatusChipTone? tone;
  final IconData? icon;
  final bool isActive;

  /// Common presets
  factory StatusChip.online() => const StatusChip(
        label: 'Online',
        tone: StatusChipTone.success,
        isActive: true,
      );

  factory StatusChip.offline() => const StatusChip(
        label: 'Offline',
        tone: StatusChipTone.neutral,
      );

  factory StatusChip.busy() => const StatusChip(
        label: 'Busy',
        tone: StatusChipTone.warning,
        isActive: true,
      );

  Color _getColor(BuildContext context) {
    if (color != null) return color!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (tone ?? StatusChipTone.neutral) {
      case StatusChipTone.success:
        return AppColors.success;
      case StatusChipTone.warning:
        return AppColors.warning;
      case StatusChipTone.danger:
        return AppColors.error;
      case StatusChipTone.info:
        return AppColors.info;
      case StatusChipTone.neutral:
        return isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final chipColor = _getColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: chipColor.withValues(alpha: 0.3),
          width: AppGlass.borderThin,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) ...[
            _PulseDot(color: chipColor),
            const SizedBox(width: AppSpacing.xs),
          ] else if (icon != null) ...[
            Icon(icon, size: 12, color: chipColor),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: chipColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});
  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color.withValues(alpha: 0.6 + _controller.value * 0.4),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.3 * _controller.value),
                blurRadius: 4,
                spreadRadius: _controller.value * 2,
              ),
            ],
          ),
        );
      },
    );
  }
}
