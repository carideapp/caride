import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:design_system/design_system.dart';
import 'package:shared_widgets/shared_widgets.dart';

class SuccessDialog extends StatelessWidget {
  const SuccessDialog({
    super.key,
    required this.title,
    required this.description,
    this.buttonLabel = 'Done',
    this.onButtonPressed,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback? onButtonPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: GlassSurface(
        radius: AppRadius.xxl,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reusable Lottie Asset Player
            SizedBox(
              width: 130,
              height: 130,
              child: Lottie.asset(
                'lib/assets/lottie/Success.lottie',
                fit: BoxFit.contain,
                animate: true,
                repeat: true,
                decoder: (bytes) {
                  return LottieComposition.decodeZip(
                    bytes,
                    filePicker: (files) {
                      return files.firstWhere(
                        (f) =>
                            f.name.startsWith('animations/') &&
                            f.name.endsWith('.json'),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: AppTextStyles.headlineSmall.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.slate900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              description,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? Colors.grey[300] : const Color(0xFF4A4D70),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: buttonLabel,
                onPressed: () {
                  Navigator.of(context).pop();
                  if (onButtonPressed != null) {
                    onButtonPressed!();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper utility static method to show the success dialog easily from any build context.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String description,
    String buttonLabel = 'Done',
    VoidCallback? onButtonPressed,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return SuccessDialog(
          title: title,
          description: description,
          buttonLabel: buttonLabel,
          onButtonPressed: onButtonPressed,
        );
      },
    );
  }
}
