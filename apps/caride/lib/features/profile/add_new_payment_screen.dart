import 'package:caride/features/profile/data/wallet_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

class AddNewPaymentScreen extends StatefulWidget {
  const AddNewPaymentScreen({super.key});

  @override
  State<AddNewPaymentScreen> createState() => _AddNewPaymentScreenState();
}

class _AddNewPaymentScreenState extends State<AddNewPaymentScreen> {
  final _walletRepo = WalletRepository();
  bool _loading = false;

  Future<void> _startCardSetup() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      // ₦100 setup verification fee to validate and save card details.
      final result = await _walletRepo.initializeTopUp(
        amountNaira: 100.0,
        channels: ['card'],
      );
      if (!mounted) return;

      final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      final success = await context.push<bool>(
        CustomerRoutePaths.topUpWebview,
        extra: {
          'url': result.authorizationUrl,
          'reference': result.reference,
          'amountNaira': 100.0,
          'isSetupCard': true,
          'email': userEmail,
        },
      );

      if (success == true && mounted) {
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Card verification failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

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
                        Icons.close_rounded,
                        size: 20,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Link Payment Card',
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.credit_card_rounded,
                        size: 44,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Link Your Debit or Credit Card',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'To securely verify and tokenize your card, a small refundable verification of ₦100 will be made. The full amount is instantly credited to your CaRide Wallet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: secondaryTextColor,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Security Info Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.lock_outline_rounded,
                              color: AppColors.brand,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Bank-Grade Security',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Your card credentials are tokenized with 256-bit encryption through TransactPay. CaRide does not store your full card number or CVV.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: secondaryTextColor,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Supported Card Channels
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Accepted Card Networks',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildNetworkBadge(
                          isDark: isDark,
                          borderColor: borderColor,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEB001B),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Transform.translate(
                                offset: const Offset(-4, 0),
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF79E1B).withValues(alpha: 0.9),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Mastercard',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: primaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildNetworkBadge(
                          isDark: isDark,
                          borderColor: borderColor,
                          child: Text(
                            'VISA',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildNetworkBadge(
                          isDark: isDark,
                          borderColor: borderColor,
                          child: Text(
                            'Verve',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom CTA Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _startCardSetup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    elevation: 0,
                    disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Proceed to Verify Card',
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
  }

  Widget _buildNetworkBadge({
    required bool isDark,
    required Color borderColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }
}
