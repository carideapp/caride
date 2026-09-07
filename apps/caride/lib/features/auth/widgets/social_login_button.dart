import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onPressed != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: NeumorphicContainer(
        depth: NeumorphicDepth.raised,
        onTap: enabled ? onPressed : null,
        radius: AppRadius.md,
        padding: EdgeInsets.zero,
        shadowOverride: AppShadows.buttonRaised(theme),
        child: SizedBox(
          height: 52,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(width: AppSpacing.sm),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
