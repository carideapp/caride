import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Bottom sheet explaining how the 4-digit delivery PIN confirmation works.
/// Matches the `pin_info.jpeg` UI design.
class PinInfoBottomSheet extends StatelessWidget {
  const PinInfoBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PinInfoBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePadding,
                AppSpacing.md,
                AppSpacing.pagePadding,
                AppSpacing.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with close button
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(40, 40),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'PIN info',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40), // balance the close button
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Info rows
                  _PinInfoRow(
                    icon: Icons.pin_outlined,
                    title: 'Recipient will receive a 4-digit PIN',
                    subtitle: "We'll send it once the package is on its way.",
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _PinInfoRow(
                    icon: Icons.grid_view_rounded,
                    title: 'Driver will confirm the PIN',
                    subtitle:
                        'The recipient will share the PIN when the package arrives.',
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _PinInfoRow(
                    icon: Icons.check_circle_outline_rounded,
                    title: "We'll send a confirmation",
                    subtitle:
                        "We'll let you know once the delivery is completed.",
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: 'OK',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PinInfoRow extends StatelessWidget {
  const _PinInfoRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor =
        isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.brandGlass,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 22, color: AppColors.brand),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: mutedColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
