import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

Future<void> showVehicleInfoRequiredDialog(BuildContext context) {
  final theme = Theme.of(context);
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: const Icon(
                Icons.drive_eta_rounded,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            const Expanded(child: Text('Vehicle Info Required')),
          ],
        ),
        content: Text(
          'Please fill in and submit your vehicle information before you can continue to driver documents.',
          style: theme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      );
    },
  );
}
