import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class FleetStepProgressBar extends StatelessWidget {
  const FleetStepProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.stepTitles,
    this.onStepTapped,
  });

  final int currentStep;
  final int totalSteps;
  final List<String> stepTitles;
  final ValueChanged<int>? onStepTapped;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = (currentStep + 1) / totalSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top step counter text & current step title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Step ${currentStep + 1} of $totalSteps',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.brand,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            if (currentStep < stepTitles.length)
              Text(
                stepTitles[currentStep],
                style: AppTextStyles.labelSmall.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),

        // Progress line track
        Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF16A34A),
                      Color(0xFF22C55E),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF16A34A).withValues(alpha: 0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
