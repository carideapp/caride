import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:design_system/design_system.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// A custom counter-offer bottom sheet for drivers.
///
/// It allows drivers to enter their own numeric fare offer with no hardcoded
/// or auto pre-suggested fare prices.
class DriverCounterOfferBottomSheet extends StatefulWidget {
  const DriverCounterOfferBottomSheet({
    super.key,
    required this.customerOffer,
    required this.onSubmit,
  });

  final double customerOffer;
  final ValueChanged<double> onSubmit;

  /// Displays this bottom sheet above the bottom navigation bar and any navigation chrome.
  static Future<void> show({
    required BuildContext context,
    required double customerOffer,
    required ValueChanged<double> onSubmit,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DriverCounterOfferBottomSheet(
        customerOffer: customerOffer,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<DriverCounterOfferBottomSheet> createState() =>
      _DriverCounterOfferBottomSheetState();
}

class _DriverCounterOfferBottomSheetState
    extends State<DriverCounterOfferBottomSheet> {
  late final TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    // Intentionally blank - no hardcoded or auto pre-suggested fare price
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final clean = _controller.text.replaceAll(RegExp(r'[^0-9.]'), '');
    final amount = double.tryParse(clean);
    if (amount == null || amount <= 0) {
      setState(() => _errorText = 'Please enter a valid amount');
      return;
    }
    Navigator.of(context).pop();
    widget.onSubmit(amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : AppColors.slate900;
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: sheetColor,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xl),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Enter your fare offer',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Customer\'s current offer: ${NgnFormat.whole(widget.customerOffer)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: mutedTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppTextField(
                controller: _controller,
                label: 'Your Counter Fare (₦)',
                hint: 'Enter your amount',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                prefix: const Text(
                  '₦ ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                errorText: _errorText,
                onChanged: (_) {
                  if (_errorText != null) setState(() => _errorText = null);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Submit Counter Offer',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
