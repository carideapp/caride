import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer Booking End State view.
class BookingEndState extends StatelessWidget {
  const BookingEndState({
    super.key,
    required this.status,
    required this.pickupLabel,
    required this.dropoffLabel,
  });

  final String status;
  final String pickupLabel;
  final String dropoffLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (title, subtitle) = _copyForStatus(status);
    final isCancelled = status == 'cancelled';
    final color = isCancelled ? AppColors.error : AppColors.brand;
    final isCompleted = status == 'completed';
    final icon = isCancelled ? Icons.cancel_rounded : Icons.check_circle_rounded;

    if (isCompleted) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(),
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brandGlass,
                border: Border.all(color: color.withValues(alpha: 0.22)),
              ),
              child: Icon(icon, size: 40, color: color),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: SecondaryButton(
              label: 'Close',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AddressRow(iconColor: AppColors.brand, label: pickupLabel),
        const SizedBox(height: AppSpacing.sm),
        _AddressRow(iconColor: AppColors.error, label: dropoffLabel),
        const SizedBox(height: AppSpacing.md),
        Divider(
          height: 1,
          color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
        ),
        const SizedBox(height: AppSpacing.xl),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCancelled ? AppColors.error.withValues(alpha: 0.12) : AppColors.brandGlass,
              border: Border.all(color: color.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, size: 36, color: color),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyLarge.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: SecondaryButton(
            label: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ),
      ],
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.iconColor, required this.label});

  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.location_on_rounded, color: iconColor, size: 18),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label.isEmpty ? '—' : label,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

(String, String) _copyForStatus(String status) {
  return switch (status) {
    'completed' => ('Trip completed', 'Thanks for riding with CaRide.'),
    'cancelled' => ('Ride cancelled', 'This trip has been cancelled.'),
    _ => ('Trip ended', 'This trip is no longer active.'),
  };
}
