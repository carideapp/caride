import 'package:caride/core/config/app_config_repository.dart';
import 'package:caride/features/profile/data/account_repository.dart';
import 'package:caride/features/wallet/top_up_method_screen.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Redesigned Customer Wallet Top Up Amount Input Screen.
class TypeAmountScreen extends StatefulWidget {
  const TypeAmountScreen({super.key});

  @override
  State<TypeAmountScreen> createState() => _TypeAmountScreenState();
}

class _TypeAmountScreenState extends State<TypeAmountScreen> {
  final AccountRepository _accountRepo = AccountRepository();
  final AppConfigRepository _configRepo = AppConfigRepository();
  String _amountText = '0.00';
  String? _errorMessage;

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return StreamBuilder<WalletTopUpConfig>(
      stream: _configRepo.watchWalletTopUpConfig(),
      initialData: WalletTopUpConfig.defaults,
      builder: (context, topUpSnap) {
        final topUpConfig = topUpSnap.data ?? WalletTopUpConfig.defaults;
        final quick = topUpConfig.quickAmountsNaira.take(3).toList(growable: false);

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
          body: SafeArea(
            child: Column(
              children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20, top: 14, bottom: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
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
                      Text(
                        'Top Up Wallet',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Column(
                      children: [
                        // In-View Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
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

                        // Amount Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            children: [
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
                                      fontSize: 40,
                                      fontWeight: FontWeight.w900,
                                      color: primaryTextColor,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    width: 2.5,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: AppColors.brand,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              StreamBuilder<double>(
                                stream: _accountRepo.watchWalletBalance(),
                                builder: (context, snap) {
                                  final bal = snap.data ?? 0.0;
                                  final formatted = _formatWithCommas(bal.toStringAsFixed(2));
                                  return Text(
                                    'Available balance: ₦$formatted',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: secondaryTextColor,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

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
                                      color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF3F4F6),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: _amountText == quick[i].toStringAsFixed(2)
                                            ? AppColors.brand
                                            : borderColor,
                                        width: _amountText == quick[i].toStringAsFixed(2) ? 1.5 : 1,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '₦${_formatWithCommas(quick[i].toStringAsFixed(0))}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _amountText == quick[i].toStringAsFixed(2)
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
                        const SizedBox(height: 24),

                        // Keypad
                        _buildKeypad(primaryTextColor, isDark),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        final amount = double.tryParse(_amountText) ?? 0.0;
                        if (amount < topUpConfig.minAmountNaira) {
                          final minFormatted =
                              _formatWithCommas(topUpConfig.minAmountNaira.toStringAsFixed(2));
                          setState(() {
                            _errorMessage = 'Minimum top-up is ₦$minFormatted.';
                          });
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TopUpMethodScreen(amountNaira: amount),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
              height: 64,
              child: Center(
                child: key == '<'
                    ? Icon(Icons.backspace_outlined, size: 22, color: primaryTextColor)
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
