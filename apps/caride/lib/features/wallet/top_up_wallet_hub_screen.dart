import 'package:caride/core/config/app_config_repository.dart';
import 'package:caride/features/profile/data/account_repository.dart';
import 'package:caride/features/profile/data/wallet_repository.dart';
import 'package:caride/features/wallet/top_up_method_screen.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Unified Wallet Top Up Screen providing both:
/// 1. Dedicated Virtual Account (Fixed personal bank account for instant transfers).
/// 2. Standard Top-Up (Dynamic amount input + checkout).
class TopUpWalletHubScreen extends StatefulWidget {
  const TopUpWalletHubScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  final int initialTabIndex;

  @override
  State<TopUpWalletHubScreen> createState() => _TopUpWalletHubScreenState();
}

class _TopUpWalletHubScreenState extends State<TopUpWalletHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final AccountRepository _accountRepo = AccountRepository();
  final AppConfigRepository _configRepo = AppConfigRepository();
  final WalletRepository _walletRepo = WalletRepository();

  // Tab 2 (Standard Top-Up) State
  String _amountText = '0.00';
  String? _errorMessage;

  // Tab 1 (Dedicated Account) State
  bool _isGeneratingAccount = false;
  String? _dedicatedError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ────────────────────────── Tab 2 (Keypad Logic) ──────────────────────────

  void _onKeyTap(String key) {
    setState(() {
      _errorMessage = null;
      if (key == '<') {
        if (_amountText.length > 4) {
          _amountText = _amountText.substring(0, _amountText.length - 1);
          if (_amountText.endsWith('.')) {
            _amountText = _amountText.substring(0, _amountText.length - 1);
          }
          if (!_amountText.contains('.')) {
            _amountText = '0.00';
          }
        } else {
          _amountText = '0.00';
        }
      } else if (key == '*') {
        // no-op
      } else {
        if (_amountText == '0.00') {
          _amountText = '$key.00';
        } else {
          final parts = _amountText.split('.');
          _amountText = '${parts[0]}$key.${parts[1]}';
        }
      }
    });
  }

  void _selectAmount(double amount) {
    setState(() {
      _errorMessage = null;
      _amountText = amount.toStringAsFixed(2);
    });
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

  // ────────────────────────── Tab 1 (DVA Actions) ──────────────────────────

  Future<void> _generateDedicatedAccount() async {
    if (_isGeneratingAccount) return;

    setState(() {
      _isGeneratingAccount = true;
      _dedicatedError = null;
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
        _dedicatedError = 'Failed to generate virtual account: $e';
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
      'CaRide Wallet Dedicated Account Details:\n'
      'Bank: ${details.bankName}\n'
      'Account Number: ${details.accountNumber}\n'
      'Account Name: ${details.accountName}\n\n'
      'Transfer any amount from any bank app to fund my CaRide wallet instantly.',
      subject: 'My CaRide Top-Up Account',
    );
  }

  // ────────────────────────── Build ──────────────────────────

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
                  left: 20, right: 20, top: 14, bottom: 8),
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
                      'Top Up Wallet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  StreamBuilder<double>(
                    stream: _accountRepo.watchWalletBalance(),
                    builder: (context, snap) {
                      final bal = snap.data ?? 0.0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
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

            // Tab switcher hidden - displaying only virtual static account as requested
            /*
            // Segmented Tab Switcher
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
                height: 48,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: TabBar(
                  controller: _tabController,
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: isDark ? AppColors.brand : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  labelColor: isDark ? Colors.white : AppColors.brand,
                  unselectedLabelColor: secondaryTextColor,
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Virtual Account'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.dialpad_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Normal Top-Up'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            */

            // Display only Virtual Account
            Expanded(
              child: _buildVirtualAccountTab(
                primaryTextColor,
                secondaryTextColor,
                cardBg,
                borderColor,
                isDark,
              ),
              /*
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildVirtualAccountTab(
                      primaryTextColor, secondaryTextColor, cardBg, borderColor, isDark),
                  _buildNormalTopUpTab(
                      primaryTextColor, secondaryTextColor, cardBg, borderColor, isDark),
                ],
              ),
              */
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────── Tab 1: Virtual Account View ──────────────────────────

  Widget _buildVirtualAccountTab(
    Color primaryTextColor,
    Color secondaryTextColor,
    Color cardBg,
    Color borderColor,
    bool isDark,
  ) {
    return StreamBuilder<BankTransferDetails?>(
      stream: _walletRepo.watchDedicatedAccount(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.brand),
          );
        }

        final details = snapshot.data;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_dedicatedError != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.error, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _dedicatedError!,
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
                _buildUnprovisionedView(primaryTextColor, secondaryTextColor,
                    cardBg, borderColor, isDark)
              else
                _buildActiveVirtualAccountView(details, primaryTextColor,
                    secondaryTextColor, cardBg, borderColor, isDark),
            ],
          ),
        );
      },
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
            'Your Dedicated Top-Up Account',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate a permanent personal virtual account. Transfer money directly from any Nigerian banking app anytime to fund your CaRide wallet instantly.',
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
            'Instant Credit',
            'Wallet updates automatically within seconds 24/7.',
            primaryTextColor,
            secondaryTextColor,
          ),
          const SizedBox(height: 12),
          _buildBenefitItem(
            Icons.account_tree_outlined,
            'All Banks Supported',
            'Transfer from GTB, Zenith, Kuda, OPay, Palmpay, and more.',
            primaryTextColor,
            secondaryTextColor,
          ),
          const SizedBox(height: 12),
          _buildBenefitItem(
            Icons.repeat_rounded,
            'No Need to Re-enter Amount',
            'Transfer any amount at your convenience.',
            primaryTextColor,
            secondaryTextColor,
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: _isGeneratingAccount
                ? 'Creating Account...'
                : 'Create Virtual Account',
            isLoading: _isGeneratingAccount,
            showShadow: false,
            onPressed: _generateDedicatedAccount,
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
                        'Dedicated Account',
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
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            size: 13, color: Color(0xFF10B981)),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                          details.accountNumber, 'Account Number'),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.brand,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded,
                                size: 14, color: Colors.white),
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
                    icon: Icon(Icons.copy_rounded,
                        size: 16, color: secondaryTextColor),
                    onPressed: () => _copyToClipboard(
                        details.accountName, 'Account Name'),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 18),

        // How it works card
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
                  const Icon(Icons.info_outline_rounded,
                      size: 18, color: AppColors.brand),
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
                  '1', 'Open your banking app (GTB, Kuda, Zenith, OPay, etc.)', primaryTextColor),
              const SizedBox(height: 6),
              _buildInstructionStep(
                  '2', 'Transfer any amount to your account number above.', primaryTextColor),
              const SizedBox(height: 6),
              _buildInstructionStep(
                  '3', 'Your CaRide wallet balance is credited immediately.', primaryTextColor),
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

  // ────────────────────────── Tab 2: Normal Top-Up View ──────────────────────────

  // ignore: unused_element
  Widget _buildNormalTopUpTab(
    Color primaryTextColor,
    Color secondaryTextColor,
    Color cardBg,
    Color borderColor,
    bool isDark,
  ) {
    return StreamBuilder<WalletTopUpConfig>(
      stream: _configRepo.watchWalletTopUpConfig(),
      initialData: WalletTopUpConfig.defaults,
      builder: (context, topUpSnap) {
        final topUpConfig = topUpSnap.data ?? WalletTopUpConfig.defaults;
        final quick =
            topUpConfig.quickAmountsNaira.take(3).toList(growable: false);

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              // Error Banner
              if (_errorMessage != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.error, size: 20),
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
                const SizedBox(height: 14),
              ],

              // Amount Card
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Text(
                      'Enter Top-Up Amount',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            '₦',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _formatWithCommas(_amountText),
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            color: primaryTextColor,
                            letterSpacing: -1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 2.5,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Quick Select Chips
              Row(
                children: [
                  for (int i = 0; i < quick.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectAmount(quick[i]),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _amountText ==
                                      quick[i].toStringAsFixed(2)
                                  ? AppColors.brand
                                  : borderColor,
                              width: _amountText ==
                                      quick[i].toStringAsFixed(2)
                                  ? 1.5
                                  : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '₦${_formatWithCommas(quick[i].toStringAsFixed(0))}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _amountText ==
                                      quick[i].toStringAsFixed(2)
                                  ? AppColors.brand
                                  : primaryTextColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 18),

              // Numeric Keypad
              _buildKeypad(primaryTextColor, isDark),

              const SizedBox(height: 20),

              // Continue Button
              PrimaryButton(
                label: 'Continue',
                showShadow: false,
                onPressed: () {
                  final amount = double.tryParse(_amountText) ?? 0.0;
                  if (amount < topUpConfig.minAmountNaira) {
                    final minFormatted = _formatWithCommas(
                        topUpConfig.minAmountNaira.toStringAsFixed(2));
                    setState(() {
                      _errorMessage =
                          'Minimum top-up is ₦$minFormatted.';
                    });
                    return;
                  }
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          TopUpMethodScreen(amountNaira: amount),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKeypad(Color primaryTextColor, bool isDark) {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3'], primaryTextColor),
        const SizedBox(height: 8),
        _buildKeypadRow(['4', '5', '6'], primaryTextColor),
        const SizedBox(height: 8),
        _buildKeypadRow(['7', '8', '9'], primaryTextColor),
        const SizedBox(height: 8),
        _buildKeypadRow(['*', '0', '<'], primaryTextColor),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> keys, Color primaryTextColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onKeyTap(key),
            borderRadius: BorderRadius.circular(40),
            child: SizedBox(
              width: 76,
              height: 56,
              child: Center(
                child: key == '<'
                    ? Icon(Icons.backspace_outlined,
                        size: 22, color: primaryTextColor)
                    : key == '*'
                        ? Text(
                            '•',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: primaryTextColor.withValues(alpha: 0.3),
                            ),
                          )
                        : Text(
                            key,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
