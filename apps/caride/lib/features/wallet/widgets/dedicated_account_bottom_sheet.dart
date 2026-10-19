import 'package:caride/features/profile/data/wallet_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Modal bottom sheet displaying the user's permanent virtual static account for top-up.
/// If not yet generated, allows generating directly within the sheet.
class DedicatedAccountBottomSheet extends StatefulWidget {
  const DedicatedAccountBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => const DedicatedAccountBottomSheet(),
    );
  }

  @override
  State<DedicatedAccountBottomSheet> createState() =>
      _DedicatedAccountBottomSheetState();
}

class _DedicatedAccountBottomSheetState
    extends State<DedicatedAccountBottomSheet> {
  final WalletRepository _walletRepo = WalletRepository();
  bool _isGenerating = false;
  String? _errorMessage;

  Future<void> _generateAccount() async {
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      await _walletRepo.getOrCreateDedicatedAccount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dedicated account created successfully!'),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to generate account: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    HapticFeedback.lightImpact();
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _shareAccount(BankTransferDetails details) {
    Share.share(
      'CaRide Dedicated Account Details:\n'
      'Bank: ${details.bankName}\n'
      'Account Number: ${details.accountNumber}\n'
      'Account Name: ${details.accountName}\n\n'
      'Transfer any amount to top up your wallet automatically within seconds.',
      subject: 'CaRide Dedicated Top-Up Account',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardBg =
        isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB);
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle Bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
                      size: 22,
                      color: AppColors.brand,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Top Up via Bank Transfer',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                          ),
                        ),
                        Text(
                          'Instant wallet funding 24/7',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: secondaryTextColor,
                      size: 22,
                    ),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: StreamBuilder<BankTransferDetails?>(
                  stream: _walletRepo.watchDedicatedAccount(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.brand),
                        ),
                      );
                    }

                    final details = snapshot.data;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded,
                                    color: AppColors.error, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (details == null)
                          _buildGenerateState(
                            primaryTextColor,
                            secondaryTextColor,
                            cardBg,
                            borderColor,
                          )
                        else
                          _buildAccountDetails(
                            details,
                            primaryTextColor,
                            secondaryTextColor,
                            cardBg,
                            borderColor,
                            isDark,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateState(
    Color primaryTextColor,
    Color secondaryTextColor,
    Color cardBg,
    Color borderColor,
  ) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.account_balance_wallet_outlined,
            color: AppColors.brand,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'No Virtual Account Yet',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: primaryTextColor,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Generate your personal static bank account. Any funds transferred to it will instantly credit your CaRide wallet so you can complete your booking.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: secondaryTextColor,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: _isGenerating
              ? 'Generating Account...'
              : 'Generate Virtual Account',
          isLoading: _isGenerating,
          showShadow: false,
          onPressed: _generateAccount,
        ),
      ],
    );
  }

  Widget _buildAccountDetails(
    BankTransferDetails details,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color cardBg,
    Color borderColor,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Account Box
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              _buildDetailRow(
                'Bank Name',
                details.bankName,
                primaryTextColor,
                secondaryTextColor,
                canCopy: true,
                onCopy: () => _copyToClipboard(details.bankName, 'Bank Name'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              _buildDetailRow(
                'Account Number',
                details.accountNumber,
                primaryTextColor,
                secondaryTextColor,
                highlight: true,
                canCopy: true,
                onCopy: () =>
                    _copyToClipboard(details.accountNumber, 'Account Number'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1),
              ),
              _buildDetailRow(
                'Account Name',
                details.accountName,
                primaryTextColor,
                secondaryTextColor,
                canCopy: true,
                onCopy: () => _copyToClipboard(details.accountName, 'Account Name'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Quick tip banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.25),
            ),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.bolt_rounded,
                color: Color(0xFF10B981),
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Transfers are credited automatically within seconds. Once sent, your wallet balance will update immediately.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF047857),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Action Buttons Row
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _shareAccount(details),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  side: BorderSide(color: borderColor),
                ),
                icon: Icon(Icons.share_rounded, size: 18, color: primaryTextColor),
                label: Text(
                  'Share Details',
                  style: TextStyle(
                    color: primaryTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(
                label: 'Copy Number',
                icon: Icons.copy_rounded,
                showShadow: false,
                onPressed: () =>
                    _copyToClipboard(details.accountNumber, 'Account Number'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    String label,
    String value,
    Color primaryTextColor,
    Color secondaryTextColor, {
    bool highlight = false,
    bool canCopy = false,
    VoidCallback? onCopy,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextColor,
                  textBaseline: TextBaseline.alphabetic,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: highlight ? 20 : 14,
                  fontWeight: highlight ? FontWeight.w800 : FontWeight.w700,
                  color: highlight ? AppColors.brand : primaryTextColor,
                  letterSpacing: highlight ? 1.0 : 0,
                ),
              ),
            ],
          ),
        ),
        if (canCopy && onCopy != null)
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy_rounded, size: 14, color: AppColors.brand),
                  SizedBox(width: 4),
                  Text(
                    'Copy',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
