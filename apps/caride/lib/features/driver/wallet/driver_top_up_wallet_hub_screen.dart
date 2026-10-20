import 'package:caride/features/driver/wallet/data/driver_wallet_repository.dart';
import 'package:caride/features/profile/data/wallet_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Dedicated Virtual Account Top-Up Screen for Drivers.
/// Allows drivers to fund their driver wallet anytime via their permanent personal bank account.
class DriverTopUpWalletHubScreen extends StatefulWidget {
  const DriverTopUpWalletHubScreen({super.key});

  @override
  State<DriverTopUpWalletHubScreen> createState() =>
      _DriverTopUpWalletHubScreenState();
}

class _DriverTopUpWalletHubScreenState extends State<DriverTopUpWalletHubScreen> {
  final DriverWalletRepository _driverWalletRepo = DriverWalletRepository();

  bool _isGeneratingAccount = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Auto-trigger dedicated account provisioning if none exists yet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndAutoProvisionAccount();
    });
  }

  Future<void> _checkAndAutoProvisionAccount() async {
    try {
      final existing = await _driverWalletRepo.watchDedicatedAccount().first;
      if (existing == null && mounted) {
        _generateDedicatedAccount(silent: true);
      }
    } catch (_) {}
  }

  Future<void> _generateDedicatedAccount({bool silent = false}) async {
    if (_isGeneratingAccount) return;

    setState(() {
      _isGeneratingAccount = true;
      _errorMessage = null;
    });

    try {
      await _driverWalletRepo.getOrCreateDedicatedAccount();
      if (!mounted) return;
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dedicated driver virtual account created successfully!'),
            backgroundColor: AppColors.brand,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to generate virtual account: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAccount = false);
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

  void _shareAccountDetails(BankTransferDetails details) {
    Share.share(
      'CaRide Driver Dedicated Account Details:\n'
      'Bank: ${details.bankName}\n'
      'Account Number: ${details.accountNumber}\n'
      'Account Name: ${details.accountName}\n\n'
      'Transfer any amount from any bank app to fund your CaRide driver wallet instantly.',
      subject: 'My CaRide Driver Top-Up Account',
    );
  }

  String _formatWithCommas(String amountText) {
    final parts = amountText.split('.');
    final whole = parts.first;
    final decimal = parts.length > 1 ? parts[1] : '00';
    final wholeWithCommas = whole.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$wholeWithCommas.${decimal.padRight(2, '0').substring(0, 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: 8,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: cardBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Top Up Driver Wallet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  StreamBuilder<double>(
                    stream: _driverWalletRepo.streamWalletBalance(),
                    builder: (context, snap) {
                      final bal = snap.data ?? 0.0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.brand.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '₦${_formatWithCommas(bal.toStringAsFixed(2))}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brand,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Main Content: Dedicated Virtual Account Details
            Expanded(
              child: StreamBuilder<BankTransferDetails?>(
                stream: _driverWalletRepo.watchDedicatedAccount(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.brand),
                    );
                  }

                  final details = snapshot.data;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        if (details == null)
                          _buildUnprovisionedView(
                            primaryTextColor,
                            secondaryTextColor,
                            cardBg,
                            borderColor,
                            isDark,
                          )
                        else
                          _buildActiveVirtualAccountView(
                            details,
                            primaryTextColor,
                            secondaryTextColor,
                            cardBg,
                            borderColor,
                            isDark,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnprovisionedView(
    Color primaryTextColor,
    Color secondaryTextColor,
    Color cardBg,
    Color borderColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              color: AppColors.brand,
              size: 36,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Your Driver Top-Up Account',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate your permanent personal virtual account. Transfer money directly from any Nigerian banking app to fund your driver wallet instantly 24/7.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: secondaryTextColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          _buildBenefitItem(
            Icons.flash_on_rounded,
            'Instant Automated Credit',
            'Wallet balance updates automatically within seconds after transfer.',
            primaryTextColor,
            secondaryTextColor,
          ),
          const SizedBox(height: 12),
          _buildBenefitItem(
            Icons.account_tree_outlined,
            'All Nigerian Banks Supported',
            'Transfer from GTB, Zenith, Kuda, OPay, PalmPay, Access, and more.',
            primaryTextColor,
            secondaryTextColor,
          ),
          const SizedBox(height: 12),
          _buildBenefitItem(
            Icons.repeat_rounded,
            'Always Available',
            'Your dedicated account number never changes or expires.',
            primaryTextColor,
            secondaryTextColor,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: _isGeneratingAccount
                ? 'Creating Dedicated Account...'
                : 'Create Virtual Account',
            isLoading: _isGeneratingAccount,
            showShadow: false,
            onPressed: () => _generateDedicatedAccount(),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(
    IconData icon,
    String title,
    String desc,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: AppColors.brand),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActiveVirtualAccountView(
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
        // Dedicated Account Card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.account_balance_rounded,
                          size: 20,
                          color: AppColors.brand,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Dedicated Driver Account',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 13,
                          color: Color(0xFF10B981),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Active',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Bank Name
              Text(
                'BANK NAME',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                details.bankName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),

              const SizedBox(height: 16),

              // Account Number with 1-Tap Copy
              Text(
                'ACCOUNT NUMBER',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      details.accountNumber,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: primaryTextColor,
                      ),
                    ),
                    InkWell(
                      onTap: () => _copyToClipboard(
                        details.accountNumber,
                        'Account Number',
                      ),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.copy_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Copy',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Account Name
              Text(
                'ACCOUNT NAME',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      details.accountName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: secondaryTextColor,
                    ),
                    onPressed: () => _copyToClipboard(
                      details.accountName,
                      'Account Name',
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // How It Works Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.brand.withValues(alpha: 0.08)
                : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? AppColors.brand.withValues(alpha: 0.25)
                  : const Color(0xFFBBF7D0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'How to fund using Virtual Account',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildInstructionStep(
                '1',
                'Open your bank app (GTB, Access, Kuda, Zenith, OPay, PalmPay, etc.)',
                primaryTextColor,
              ),
              const SizedBox(height: 6),
              _buildInstructionStep(
                '2',
                'Transfer any desired amount to your account number above.',
                primaryTextColor,
              ),
              const SizedBox(height: 6),
              _buildInstructionStep(
                '3',
                'Your CaRide driver wallet balance is credited immediately 24/7.',
                primaryTextColor,
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Share button
        OutlinedButton.icon(
          onPressed: () => _shareAccountDetails(details),
          icon: const Icon(Icons.share_rounded, size: 16),
          label: const Text(
            'Share Account Details',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryTextColor,
            side: BorderSide(color: borderColor),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionStep(String number, String text, Color textColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: const BoxDecoration(
            color: AppColors.brand,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
