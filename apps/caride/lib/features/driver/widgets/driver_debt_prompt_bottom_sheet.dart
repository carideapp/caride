import 'package:caride/features/wallet/widgets/bank_transfer_bottom_sheet.dart';
import 'package:caride/core/services/pending_bank_transfer_service.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverDebtPromptBottomSheet extends StatelessWidget {
  const DriverDebtPromptBottomSheet({
    super.key,
    required this.currentBalance,
    required this.maxNegativeBalance,
  });

  final double currentBalance;
  final double maxNegativeBalance;

  static Future<void> show(
    BuildContext context, {
    required double currentBalance,
    required double maxNegativeBalance,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DriverDebtPromptBottomSheet(
        currentBalance: currentBalance,
        maxNegativeBalance: maxNegativeBalance,
      ),
    );
  }

  String _formatMoney(double amount) {
    return NumberFormat('#,##0.00', 'en_US').format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final absBalance = currentBalance.abs();
    // Suggested top-up clears debt plus small buffer (or exact debt)
    final suggestedTopUp = currentBalance < 0 ? absBalance : 1000.0;

    return BottomSheetShell(
      title: 'Commission Debt Limit Exceeded',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Alert Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.error,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Outstanding Debt',
                          style: AppTextStyles.caption.copyWith(
                            color: isDark ? Colors.white70 : AppColors.textSecondaryLight,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '-₦${_formatMoney(absBalance)}',
                          style: AppTextStyles.headlineSmall.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            Text(
              'Your wallet balance has fallen below the allowed negative threshold of -₦${_formatMoney(maxNegativeBalance)}. '
              'Because customers pay cash on trips, platform commission is debited from your wallet. '
              'To go online and accept ride requests, please top up your wallet to clear your balance.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Top Up Button
            PrimaryButton(
              label: 'Top Up Wallet (₦${_formatMoney(suggestedTopUp)})',
              onPressed: () async {
                Navigator.pop(context);
                await BankTransferBottomSheet.show(
                  context,
                  amountNaira: suggestedTopUp,
                  transferType: PendingTransferType.walletTopUp,
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),

            Center(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Dismiss',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
