import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modal bottom sheet to collect customer BVN in compliance with CBN KYC regulations
/// before provisioning a Dedicated Virtual Account.
class BvnPromptBottomSheet extends StatefulWidget {
  const BvnPromptBottomSheet({super.key});

  /// Displays the BVN prompt modal sheet and returns the validated 11-digit BVN or null if dismissed.
  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => const BvnPromptBottomSheet(),
    );
  }

  @override
  State<BvnPromptBottomSheet> createState() => _BvnPromptBottomSheetState();
}

class _BvnPromptBottomSheetState extends State<BvnPromptBottomSheet> {
  final TextEditingController _bvnController = TextEditingController();
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _bvnController.dispose();
    super.dispose();
  }

  void _validateAndSubmit() {
    final bvn = _bvnController.text.trim();
    if (bvn.length != 11 || !RegExp(r'^\d{11}$').hasMatch(bvn)) {
      setState(() {
        _errorText = 'Please enter a valid 11-digit BVN';
      });
      HapticFeedback.lightImpact();
      return;
    }

    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });

    HapticFeedback.mediumImpact();
    Navigator.of(context).pop(bvn);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF141416) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1F1F1F);
    final subtitleColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF6B7280);
    final cardBg = isDark ? const Color(0xFF1E1F24) : const Color(0xFFF4F4F6);
    final borderColor = isDark ? Colors.white12 : const Color(0xFFE5E7EB);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 14.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Drag handle
              Container(
                width: 48,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 24),

              // Shield Icon in brand circle
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.verified_user_rounded,
                    color: AppColors.brand,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'Identity Verification',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: Text(
                  'In accordance with Central Bank of Nigeria (CBN) regulations, please provide your Bank Verification Number (BVN) to create your dedicated account.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: subtitleColor,
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // BVN Input field
              Container(
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _errorText != null
                        ? AppColors.error
                        : borderColor,
                    width: _errorText != null ? 1.5 : 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                child: TextField(
                  controller: _bvnController,
                  keyboardType: TextInputType.number,
                  maxLength: 11,
                  obscureText: false,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3.0,
                    color: titleColor,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(11),
                  ],
                  decoration: InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    hintText: 'Enter 11-digit BVN',
                    hintStyle: TextStyle(
                      fontSize: 15,
                      letterSpacing: 0,
                      fontWeight: FontWeight.w500,
                      color: subtitleColor.withValues(alpha: 0.6),
                    ),
                    icon: Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.brand,
                      size: 22,
                    ),
                  ),
                  onChanged: (val) {
                    if (_errorText != null) {
                      setState(() => _errorText = null);
                    }
                  },
                ),
              ),

              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6.0),
                    child: Text(
                      _errorText!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // Security notice badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined, size: 16, color: AppColors.brand),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your BVN is encrypted and securely stored strictly for regulatory identity compliance. Dial *565*0# to check your BVN.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.35,
                          color: subtitleColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Submit Pill Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _validateAndSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.5),
                    disabledForegroundColor: Colors.white70,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Continue & Create Account',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 12),

              // Cancel button
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: subtitleColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
