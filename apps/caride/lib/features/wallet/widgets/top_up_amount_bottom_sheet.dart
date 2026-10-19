import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

class TopUpAmountBottomSheet extends StatefulWidget {
  const TopUpAmountBottomSheet({
    super.key,
    this.initialAmount = 2000.0,
  });

  final double initialAmount;

  static Future<double?> show(
    BuildContext context, {
    double initialAmount = 2000.0,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TopUpAmountBottomSheet(initialAmount: initialAmount),
    );
  }

  @override
  State<TopUpAmountBottomSheet> createState() => _TopUpAmountBottomSheetState();
}

class _TopUpAmountBottomSheetState extends State<TopUpAmountBottomSheet> {
  late final TextEditingController _controller;
  String? _errorText;

  static const List<double> _quickAmounts = [1000, 2000, 5000, 10000];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialAmount.toInt().toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onContinue() {
    final parsed = double.tryParse(_controller.text.trim().replaceAll(',', ''));
    if (parsed == null || parsed <= 0) {
      setState(() => _errorText = 'Please enter a valid amount.');
      return;
    }
    if (parsed < 100) {
      setState(() => _errorText = 'Minimum top up amount is ₦100.');
      return;
    }
    Navigator.pop(context, parsed);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: BottomSheetShell(
        title: 'Top Up Wallet',
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the amount you would like to top up:',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              AppTextField(
                controller: _controller,
                hint: 'e.g. 2000',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.payments_rounded,
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 6),
                Text(
                  _errorText!,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.md),

              // Quick Preset Chips
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: _quickAmounts.map((amt) {
                  final formattedChip = '₦${amt.toInt()}';
                  return ActionChip(
                    backgroundColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF1F5F9),
                    side: BorderSide(
                      color: AppColors.brand.withValues(alpha: 0.3),
                    ),
                    label: Text(
                      formattedChip,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                    ),
                    onPressed: () {
                      _controller.text = amt.toInt().toString();
                      setState(() => _errorText = null);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xl),

              PrimaryButton(
                label: 'Continue',
                onPressed: _onContinue,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
