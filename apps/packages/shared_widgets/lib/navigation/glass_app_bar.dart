import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

/// A transparent/glass app bar with large title support and backdrop blur.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.useBlur = true,
    this.showBorder = true,
    this.backgroundColor,
    this.automaticallyImplyLeading = true,
    this.bottom,
  });

  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool useBlur;
  final bool showBorder;
  final Color? backgroundColor;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget appBar = AppBar(
      title: title != null ? Text(title!) : null,
      leading: leading,
      automaticallyImplyLeading: automaticallyImplyLeading,
      actions: actions,
      backgroundColor: backgroundColor ??
          (isDark
              ? AppColors.darkBackground.withValues(alpha: useBlur ? 0.7 : 1.0)
              : AppColors.lightBackground.withValues(alpha: useBlur ? 0.75 : 1.0)),
      bottom: bottom ?? (showBorder
          ? PreferredSize(
              preferredSize: const Size.fromHeight(0.5),
              child: Container(
                height: 0.5,
                color: isDark
                    ? AppColors.glassBorderDark
                    : AppColors.glassBorderLight,
              ),
            )
          : null),
    );

    if (useBlur) {
      appBar = ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: AppGlass.blurMedium, sigmaY: AppGlass.blurMedium),
          child: appBar,
        ),
      );
    }

    return appBar;
  }
}
