import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:caride/features/wallet/data/withdraw_repository.dart';

/// Bottom sheet displayed upon successful withdrawal completion.
/// Conforms strictly to CaRide Design System & AGENTS.md:
/// - Top rounded corners (28px) with drag handle
/// - Clean flat aesthetic (no heavy shadows or neon glows)
/// - CaRide Brand Emerald Green (#16A34A)
/// - Full-pill action button (BorderRadius.circular(28), height 54px)
/// - "Okay" action button pops the sheet and navigates to WalletScreen.
class WithdrawSuccessBottomSheet extends StatelessWidget {
  const WithdrawSuccessBottomSheet({
    super.key,
    required this.resolved,
    required this.amountNaira,
    required this.reference,
    required this.onOkay,
  });

  final ResolvedAccount resolved;
  final double amountNaira;
  final String reference;
  final VoidCallback onOkay;

  String _formatNaira(double value) {
    final rounded = value.round().toString();
    return '₦${rounded.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final cardBg = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF9FAFB);
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBackground : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, -4),
                  ),
                ],
        ),
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag Handle ──
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.20)
                      : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── Animated Checkmark Circle (Clean Emerald Badge) ──
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.brand.withValues(alpha: 0.12),
                border: Border.all(
                  color: AppColors.brand.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.check_rounded,
                  color: AppColors.brand,
                  size: 46,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Title & Subtitle ──
            Text(
              'Withdrawal Successful! 🎉',
              style: AppTextStyles.headlineSmall.copyWith(
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your withdrawal has been processed successfully.\nYou will receive your funds within few mins.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: secondaryTextColor,
                height: 1.45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),

            // ── Transfer Summary Card ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  _SummaryRow(
                    label: 'Amount',
                    value: _formatNaira(amountNaira),
                    valueColor: AppColors.brand,
                    valueBold: true,
                    isDark: isDark,
                  ),
                  Divider(height: 20, color: borderColor),
                  _SummaryRow(
                    label: 'Account Name',
                    value: resolved.accountName,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _SummaryRow(
                    label: 'Bank',
                    value: resolved.bankName,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _SummaryRow(
                    label: 'Account Number',
                    value: resolved.accountNumber,
                    isDark: isDark,
                  ),
                  Divider(height: 20, color: borderColor),
                  _SummaryRow(
                    label: 'Reference',
                    value: reference,
                    mono: true,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 10),
                  _SummaryRow(
                    label: 'Status',
                    value: 'Processing',
                    valueColor: const Color(0xFFD97706),
                    valueBold: true,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Action Button (Full Pill Geometry per AGENTS.md) ──
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                onPressed: onOkay,
                child: const Text(
                  'Okay',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.isDark,
    this.valueColor,
    this.valueBold = false,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool isDark;
  final Color? valueColor;
  final bool valueBold;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: secondaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: valueBold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor ?? primaryTextColor,
              fontFamily: mono ? 'monospace' : null,
            ),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
