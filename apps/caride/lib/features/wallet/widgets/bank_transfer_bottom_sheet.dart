import 'package:caride/features/profile/data/wallet_repository.dart';
import 'package:caride/features/wallet/widgets/top_up_success_bottom_sheet.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_widgets/shared_widgets.dart';

class BankTransferBottomSheet extends StatefulWidget {
  const BankTransferBottomSheet({
    super.key,
    required this.details,
  });

  final BankTransferDetails details;

  static Future<double?> show(
    BuildContext context, {
    required BankTransferDetails details,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BankTransferBottomSheet(details: details),
    );
  }

  @override
  State<BankTransferBottomSheet> createState() => _BankTransferBottomSheetState();
}

class _BankTransferBottomSheetState extends State<BankTransferBottomSheet> {
  final WalletRepository _walletRepo = WalletRepository();
  bool _isVerifying = false;
  String? _errorTitle;
  String? _errorMessage;
  bool _showHelpInfo = false;

  Future<void> _verifyPayment() async {
    if (_isVerifying) return;
    setState(() {
      _isVerifying = true;
      _errorTitle = null;
      _errorMessage = null;
    });

    try {
      final credited = await _walletRepo.verifyTopUp(
        reference: widget.details.reference,
        fallbackAmount: widget.details.amountNaira,
      );

      if (!mounted) return;
      Navigator.pop(context, credited);

      // Show success bottom sheet
      await TopUpSuccessBottomSheet.show(
        context,
        creditedAmount: credited,
      );
    } catch (e) {
      if (!mounted) return;
      
      final rawMsg = e.toString().replaceAll("Exception: ", "");
      String title;
      String message;

      if (rawMsg.contains('PAYMENT_PENDING') || rawMsg.toLowerCase().contains('pending')) {
        title = 'Transfer Pending';
        message = 'Your bank transfer is currently processing. Transfers usually settle within 1 to 3 minutes. Please wait a moment and tap "Check Again".';
      } else if (rawMsg.contains('PAYMENT_FAILED') || rawMsg.toLowerCase().contains('failed')) {
        title = 'Payment Failed';
        message = 'The transfer was reported as failed or cancelled by the banking network. If funds were debited, your bank will automatically issue a refund.';
      } else if (rawMsg.contains('PAYMENT_NOT_RECEIVED') || rawMsg.toLowerCase().contains('not found')) {
        title = 'Transfer Not Received Yet';
        message = 'We haven\'t received your transfer from your bank yet. Please ensure you sent funds to the account details displayed above, then tap "Check Again".';
      } else {
        title = 'Verification Error';
        message = 'Could not verify payment status right now. Please check your internet connection and try again.';
      }

      setState(() {
        _errorTitle = title;
        _errorMessage = message;
      });

      HapticFeedback.lightImpact();
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasAmount = widget.details.amountNaira > 0;
    final formattedAmount = hasAmount
        ? '₦${widget.details.amountNaira.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}'
        : null;

    return BottomSheetShell(
      title: 'Bank Transfer',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasAmount) ...[
                // Amount Banner
                GlassContainer(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount to Pay',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      Text(
                        formattedAmount!,
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.brand,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Bank Details Card
              GlassContainer(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'BANK NAME',
                      value: widget.details.bankName,
                      isDark: isDark,
                    ),
                    const Divider(height: AppSpacing.lg),
                    _DetailRow(
                      label: 'ACCOUNT NAME',
                      value: widget.details.accountName,
                      isDark: isDark,
                    ),
                    const Divider(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ACCOUNT NUMBER',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.details.accountNumber,
                                style: AppTextStyles.headlineMedium.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2.0,
                                  color: AppColors.brand,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: widget.details.accountNumber));
                              HapticFeedback.mediumImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: const [
                                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text('Account number copied'),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF10B981),
                                  behavior: SnackBarBehavior.floating,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.copy_rounded, size: 16, color: Colors.black),
                                  SizedBox(width: 6),
                                  Text(
                                    'Copy',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Error / Status Alert Banner
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.error,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _errorTitle ?? 'Verification Status',
                              style: AppTextStyles.titleSmall.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _errorMessage!,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.slate900,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Helpful Transfer Guidelines Accordion
              InkWell(
                onTap: () => setState(() => _showHelpInfo = !_showHelpInfo),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.help_outline_rounded,
                        size: 16,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Transfer tips & response times',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Icon(
                        _showHelpInfo ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ],
                  ),
                ),
              ),

              if (_showHelpInfo) ...[
                const SizedBox(height: AppSpacing.xs),
                GlassContainer(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _helpTip('Transfers usually settle in 30s to 3 minutes depending on your bank.'),
                      const SizedBox(height: 6),
                      _helpTip('Ensure you send funds from a mobile banking app in Nigeria.'),
                      const SizedBox(height: 6),
                      _helpTip('If money was debited but not reflected, tap "Check Again" or contact support.'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ] else
                const SizedBox(height: AppSpacing.sm),

              // Action Buttons
              PrimaryButton(
                label: _isVerifying
                    ? 'Verifying payment...'
                    : (_errorMessage != null ? 'Check Again' : 'I have made the transfer'),
                onPressed: _isVerifying ? null : _verifyPayment,
              ),
              const SizedBox(height: AppSpacing.xs),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }

  Widget _helpTip(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_outline_rounded, size: 14, color: AppColors.brand),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.labelSmall.copyWith(
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.isDark,
  });

  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
