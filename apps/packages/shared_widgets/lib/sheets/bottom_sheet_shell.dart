import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

/// An iOS-style glass bottom sheet with drag handle, blur backdrop,
/// rounded top corners, and smooth dismiss animation.
class BottomSheetShell extends StatelessWidget {
  const BottomSheetShell({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.showDragHandle = true,
    this.useBlur = true,
    this.maxHeightFraction = 0.9,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final bool showDragHandle;
  final bool useBlur;
  final double maxHeightFraction;

  /// Show this bottom sheet modally.
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    Widget? trailing,
    bool isDismissible = true,
    bool enableDrag = true,
    bool useBlur = true,
    double maxHeightFraction = 0.9,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.transparent,
      builder: (context) => BottomSheetShell(
        title: title,
        trailing: trailing,
        useBlur: useBlur,
        maxHeightFraction: maxHeightFraction,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxHeight =
        MediaQuery.of(context).size.height * maxHeightFraction;

    Widget content = Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: AppGlass.sheetDecoration(isDark: isDark),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDragHandle)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Container(
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkOutline
                      : AppColors.lightOutlineVariant,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          if (title != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!,
                      style: AppTextStyles.headlineSmall.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            Divider(
              height: 0.5,
              color: isDark ? AppColors.darkOutline : AppColors.lightOutline,
            ),
          ],
          Flexible(child: child),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );

    if (useBlur) {
      content = ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: AppGlass.blurHeavy, sigmaY: AppGlass.blurHeavy),
          child: content,
        ),
      );
    }

    return content;
  }
}
