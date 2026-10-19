import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:design_system/design_system.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// A bottom sheet that allows passengers in Step 4 (DriverBidsStep) to update
/// their live broadcast fare offer without canceling and recreating the ride.
class PassengerUpdateOfferBottomSheet extends StatefulWidget {
  const PassengerUpdateOfferBottomSheet({
    super.key,
    required this.currentOffer,
    required this.onConfirm,
  });

  final double currentOffer;
  final ValueChanged<double> onConfirm;

  static Future<void> show({
    required BuildContext context,
    required double currentOffer,
    required ValueChanged<double> onConfirm,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PassengerUpdateOfferBottomSheet(
        currentOffer: currentOffer,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<PassengerUpdateOfferBottomSheet> createState() =>
      _PassengerUpdateOfferBottomSheetState();
}

class _PassengerUpdateOfferBottomSheetState
    extends State<PassengerUpdateOfferBottomSheet> {
  static const double _step = 100.0;
  static const double _minOffer = 200.0;

  late final TextEditingController _controller;
  String? _errorText;
  double _amount = 0.0;

  @override
  void initState() {
    super.initState();
    _amount = widget.currentOffer > 0 ? widget.currentOffer : _minOffer;
    _controller = TextEditingController(text: _amount.round().toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _decrement() {
    final next = (_amount - _step).clamp(_minOffer, 1000000.0);
    setState(() {
      _amount = next;
      _controller.text = next.round().toString();
      _errorText = null;
    });
    HapticFeedback.selectionClick();
  }

  void _increment() {
    final next = (_amount + _step).clamp(_minOffer, 1000000.0);
    setState(() {
      _amount = next;
      _controller.text = next.round().toString();
      _errorText = null;
    });
    HapticFeedback.selectionClick();
  }

  void _onTextChanged(String value) {
    final clean = value.replaceAll(RegExp(r'[^0-9.]'), '');
    final val = double.tryParse(clean);
    if (val != null) {
      _amount = val;
    }
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
  }

  void _confirm() {
    final clean = _controller.text.replaceAll(RegExp(r'[^0-9.]'), '');
    final amount = double.tryParse(clean);
    if (amount == null || amount < _minOffer) {
      setState(() => _errorText = 'Minimum offer is ${NgnFormat.whole(_minOffer)}');
      return;
    }

    Navigator.of(context).pop();
    widget.onConfirm(amount);
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
              // Top drag handle
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

              // Title
              Text(
                'Increase or decrease fare offer',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Adjust your price to attract more drivers or counter active bids.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: mutedTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Current Broadcast Context
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: isDark ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.brand.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.campaign_rounded,
                      color: AppColors.brand,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Current Broadcast: ${NgnFormat.whole(widget.currentOffer)}',
                        style: const TextStyle(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Minus / Plus Stepper with Direct Input
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black26 : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Row(
                  children: [
                    // Minus Button
                    Material(
                      color: isDark ? Colors.white12 : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: InkWell(
                        onTap: _decrement,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Icon(
                            Icons.remove_rounded,
                            size: 24,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),

                    // Editable Numeric Input Field
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: false,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        textAlign: TextAlign.center,
                        onChanged: _onTextChanged,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: AppColors.brand,
                          letterSpacing: -0.5,
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Padding(
                            padding: EdgeInsets.only(left: 12, right: 4),
                            child: Center(
                              widthFactor: 0.0,
                              child: Text(
                                '₦',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.brand,
                                ),
                              ),
                            ),
                          ),
                          border: InputBorder.none,
                          hintText: '0',
                          hintStyle: TextStyle(
                            color: mutedTextColor.withValues(alpha: 0.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),

                    // Plus Button
                    Material(
                      color: isDark ? Colors.white12 : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: InkWell(
                        onTap: _increment,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            size: 24,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _errorText!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),

              // Confirm Button
              PrimaryButton(
                label: 'Confirm New Offer',
                onPressed: _confirm,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
