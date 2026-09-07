import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:design_system/design_system.dart';

/// A premium glass-inset text field with animated focus border and
/// floating label support.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefix,
    this.suffix,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.minLines,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.validator,
    this.errorText,
    this.inputFormatters,
    this.autofillHints,
    this.focusNode,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final Widget? prefix;
  final Widget? suffix;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int maxLines;
  final int? minLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final String? errorText;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final FocusNode? focusNode;
  final TextCapitalization textCapitalization;
  final bool autocorrect;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      enabled: enabled,
      readOnly: readOnly,
      maxLines: maxLines,
      minLines: minLines,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      onTap: onTap,
      validator: validator,
      inputFormatters: inputFormatters,
      autofillHints: autofillHints,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      style: AppTextStyles.bodyLarge.copyWith(
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
      cursorColor: AppColors.brand,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        prefix: (prefixIcon == null && prefix != null && prefix is! Icon) ? prefix : null,
        suffix: suffix,
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 20)
            : prefix,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
