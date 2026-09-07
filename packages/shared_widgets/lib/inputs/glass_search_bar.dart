import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

/// A frosted-glass search bar with animated icon and clear button.
class GlassSearchBar extends StatefulWidget {
  const GlassSearchBar({
    super.key,
    this.controller,
    this.hint = 'Search',
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController? controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  State<GlassSearchBar> createState() => _GlassSearchBarState();
}

class _GlassSearchBarState extends State<GlassSearchBar> {
  late final TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(() {
      final hasText = _controller.text.isNotEmpty;
      if (hasText != _hasText) setState(() => _hasText = hasText);
    });
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.glassBackgroundDark
                : AppColors.lightSurfaceInset,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isDark
                  ? AppColors.glassBorderDark
                  : AppColors.lightOutline.withValues(alpha: 0.3),
              width: AppGlass.borderThin,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: AppSpacing.md),
              Icon(
                CupertinoIcons.search,
                size: 18,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: widget.autofocus,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  cursorColor: AppColors.brand,
                  decoration: InputDecoration(
                    hintText: widget.hint,
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (_hasText) ...[
                GestureDetector(
                  onTap: () {
                    _controller.clear();
                    widget.onChanged?.call('');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Icon(
                      CupertinoIcons.clear_circled_solid,
                      size: 18,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ),
              ] else
                const SizedBox(width: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
