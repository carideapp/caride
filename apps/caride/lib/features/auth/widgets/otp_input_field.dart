import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class OtpInputField extends StatelessWidget {
  const OtpInputField({super.key, required this.code, this.length = 4});

  final String code;
  final int length;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final boxColor = isDark ? AppColors.darkSurfaceVariant : AppColors.slate50;

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = AppSpacing.xs * (length - 1);
        final available = constraints.maxWidth - gap;
        final boxExtent = (available / length).clamp(0.0, 64.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(length, (index) {
            final isActive = index == code.length;
            final hasValue = index < code.length;
            final char = hasValue ? code[index] : '';

            return Container(
              width: boxExtent,
              height: boxExtent,
              margin: EdgeInsets.only(
                right: index == length - 1 ? 0 : AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: boxColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? AppColors.primaryGreen : Colors.transparent,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                char,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            );
          }),
        );
      },
    );
  }
}

