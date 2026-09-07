import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Constrains content width on tablets / large screens; keeps full width on phones.
class ResponsiveContainer extends StatelessWidget {
  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = 720,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final pad = width >= 900 ? AppSpacing.xl : AppSpacing.md;
        final effectiveMax = width >= 900 ? maxWidth + AppSpacing.xl * 2 : maxWidth;
        return Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: pad),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: effectiveMax),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
