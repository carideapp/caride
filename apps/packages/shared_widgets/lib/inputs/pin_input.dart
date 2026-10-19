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
    _focusNodes = List.generate(widget.length, (i) {
      final node = FocusNode(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace) {
            _onBackspace(i);
          }
          return KeyEventResult.ignored;
        },
      );
      node.addListener(_onFocusChange);
      return node;
    });
  }

  void _onFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.removeListener(_onFocusChange);
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
          LayoutBuilder(
            builder: (context, constraints) {
              const double maxCellWidth = 48.0;
              const double defaultSpacing = AppSpacing.sm;

              double spacing = defaultSpacing;
              double cellWidth = maxCellWidth;

              if (constraints.maxWidth.isFinite && widget.length > 0) {
                final double totalSpacing = spacing * (widget.length - 1);
                final double neededWidth =
                    (maxCellWidth * widget.length) + totalSpacing;

                if (neededWidth > constraints.maxWidth) {
                  final double available = constraints.maxWidth;
                  double availableForCells = available - totalSpacing;
                  if (availableForCells / widget.length < 38.0 &&
                      widget.length > 1) {
                    spacing = ((available - (38.0 * widget.length)) /
                            (widget.length - 1))
                        .clamp(4.0, defaultSpacing);
                    availableForCells =
                        available - (spacing * (widget.length - 1));
                  }
                  cellWidth = (availableForCells / widget.length)
                      .clamp(28.0, maxCellWidth);
                }
              }

              final double cellHeight =
                  (cellWidth * (56.0 / 48.0)).clamp(44.0, 56.0);
              final double fontSize = (cellWidth * 0.46).clamp(16.0, 22.0);

              return FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(widget.length, (i) {
                    return Padding(
                      padding: EdgeInsets.only(
                        right: i < widget.length - 1 ? spacing : 0,
                      ),
                      child: SizedBox(
                        width: cellWidth,
                        height: cellHeight,
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
                                fontSize: fontSize,
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
                    );
                  }),
                ),
              );
            },
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
