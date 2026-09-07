import 'package:caride/features/ride_booking/booking_shell/models/booking_shell_step.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class BookingStepIndicator extends StatelessWidget {
  const BookingStepIndicator({super.key, required this.step});

  final BookingShellStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final idx = BookingShellStep.values.indexOf(step);

    return Row(
      children: List.generate(BookingShellStep.values.length, (i) {
        final active = i <= idx;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: i == BookingShellStep.values.length - 1 ? 0 : AppSpacing.xs,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 6,
              decoration: BoxDecoration(
                color: active
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        );
      }),
    );
  }
}

