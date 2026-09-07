import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:design_system/design_system.dart';

/// A premium PIN/OTP input with individual glass cells and auto-focus animation.
class PinInput extends StatefulWidget {
  const PinInput({
    super.key,
    required this.length,
    required this.onCompleted,
    this.obscureText = false,
    this.onChanged,
    this.errorText,
  });

  final int length;
  final ValueChanged<String> onCompleted;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final String? errorText;

  @override
  State<PinInput> createState() => _PinInputState();
}

class _PinInputState extends State<PinInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers =
        List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _value => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    if (value.length == 1 && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    widget.onChanged?.call(_value);
    if (_value.length == widget.length) {
      widget.onCompleted(_value);
    }
  }

  void _onBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return Material(
      type: MaterialType.transparency,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(widget.length, (i) {
            return Padding(
              padding: EdgeInsets.only(
                right: i < widget.length - 1 ? AppSpacing.sm : 0,
              ),
              child: SizedBox(
                width: 48,
                height: 56,
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  curve: AppCurves.easeOut,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceInset
                        : AppColors.lightSurfaceInset,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: hasError
                          ? AppColors.error
                          : _focusNodes[i].hasFocus
                              ? AppColors.brand
                              : (isDark
                                  ? AppColors.darkOutline
                                  : AppColors.lightOutline),
                      width: _focusNodes[i].hasFocus ? 1.5 : 0.5,
                    ),
                  ),
                  child: Center(
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: (event) {
                        if (event is KeyDownEvent &&
                            event.logicalKey == LogicalKeyboardKey.backspace) {
                          _onBackspace(i);
                        }
                      },
                      child: TextField(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        obscureText: widget.obscureText,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (v) => _onChanged(i, v),
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        cursorColor: AppColors.brand,
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        if (hasError) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            widget.errorText!,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
          ),
        ],
      ],
    ),
  );
}
}
