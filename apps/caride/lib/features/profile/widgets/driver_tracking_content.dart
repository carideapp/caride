import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class DriverTrackingContent extends StatelessWidget {
  const DriverTrackingContent({
    super.key,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.stageTitle,
    required this.stageSubtitle,
    required this.driverName,
    required this.driverRating,
    required this.callEnabled,
    required this.showWaitingForLocation,
    required this.onChat,
    required this.onCall,
    this.startCode,
    this.vehicleInfo,
  });

  final String pickupLabel;
  final String dropoffLabel;
  final String stageTitle;
  final String stageSubtitle;
  final String driverName;
  final double driverRating;
  final bool callEnabled;
  final bool showWaitingForLocation;
  final VoidCallback onChat;
  final VoidCallback? onCall;
  final String? startCode;
  /// e.g. "Gold Toyota Corolla • AAA83DK"
  final String? vehicleInfo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : AppColors.slate900;
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _AddressRow(iconColor: AppColors.primaryGreen, label: pickupLabel),
        const SizedBox(height: AppSpacing.sm),
        _AddressRow(iconColor: AppColors.error, label: dropoffLabel),
        const SizedBox(height: AppSpacing.md),
        Divider(color: borderColor),
        const SizedBox(height: AppSpacing.md),
        Text(
          stageTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: primaryTextColor,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          stageSubtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: mutedTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (showWaitingForLocation) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Waiting for driver location…',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreen,
            ),
          ),
        ],
        if (startCode != null && startCode!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: borderColor),
              boxShadow: isDark
                  ? null
                  : [
                      const BoxShadow(
                        color: Color(0x060F172A),
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ride Start Code',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: primaryTextColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Share this with the driver to start the trip.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: mutedTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    startCode!,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryGreen,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: borderColor),
            boxShadow: isDark
                ? null
                : [
                    const BoxShadow(
                      color: Color(0x060F172A),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F5F9),
                child: Text(
                  driverName.isEmpty ? '?' : driverName.substring(0, 1),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: primaryTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driverName.isEmpty ? 'Driver' : driverName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: primaryTextColor,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (driverRating > 0) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, size: 16, color: Colors.orange),
                          const SizedBox(width: 2),
                          Text(
                            driverRating.toStringAsFixed(1),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: primaryTextColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (vehicleInfo != null && vehicleInfo!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.directions_car_rounded,
                              size: 13,
                              color: AppColors.primaryGreen,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                vehicleInfo!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.primaryGreen,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onChat,
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.primaryGreen),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                onPressed: callEnabled ? onCall : null,
                icon: const Icon(Icons.call_outlined, color: AppColors.primaryGreen),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
                ),
              ),
            ],
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        Icon(Icons.location_on_rounded, color: iconColor, size: 18),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label.isEmpty ? '—' : label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: isDark ? Colors.white : AppColors.slate900,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
