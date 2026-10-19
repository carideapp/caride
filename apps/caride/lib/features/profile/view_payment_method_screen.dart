import 'package:caride/features/profile/data/card_repository.dart';
import 'package:caride/features/profile/data/wallet_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

class ViewPaymentMethodScreen extends StatefulWidget {
  const ViewPaymentMethodScreen({super.key});

  @override
  State<ViewPaymentMethodScreen> createState() => _ViewPaymentMethodScreenState();
}

class _ViewPaymentMethodScreenState extends State<ViewPaymentMethodScreen> {
  final _cardRepository = CardRepository();
  final _walletRepo = WalletRepository();
  String? _selectedMethod = 'wallet';
  bool _isDeleting = false;
  bool _isAddingCard = false;

  /// Launches TransactPay checkout to add and save a new card.
  Future<void> _startAddCard() async {
    if (_isAddingCard) return;
    setState(() => _isAddingCard = true);
    try {
      final result = await _walletRepo.initializeTopUp(
        amountNaira: 100.0,
        channels: ['card'],
      );
      if (!mounted) return;
      final success = await context.push<bool>(
        CustomerRoutePaths.topUpWebview,
        extra: {
          'url': result.authorizationUrl,
          'reference': result.reference,
          'amountNaira': 100.0,
          'isSetupCard': true,
        },
      );
      if (success == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card added successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.brand,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add card: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingCard = false);
    }
  }

  void _showDeleteConfirmation(String id, String cardName, String cardNumber) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 28),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.credit_card_off_rounded,
                color: AppColors.error,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Remove Card',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to remove $cardName ($cardNumber) from your payment methods?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  setState(() => _isDeleting = true);
                  try {
                    await _cardRepository.deleteCard(id);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Card removed successfully.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to remove card: $e'),
                        behavior: SnackBarBehavior.floating,
                        backgroundColor: AppColors.error,
                      ),
                    );
                  } finally {
                    if (mounted) setState(() => _isDeleting = false);
                  }
                },
                child: const Text(
                  'Yes, Remove Card',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final iconBg = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF3F4F6);

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
                    'Payment Methods',
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

            // Payment Methods List
            Expanded(
              child: StreamBuilder<List<SavedCard>>(
                stream: _cardRepository.watchSavedCards(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                      ),
                    );
                  }

                  final cards = snapshot.data ?? [];
                  final methods = [
                    ...cards.map((c) => {
                          'id': c.id,
                          'name': c.brand.toUpperCase(),
                          'icon': Icons.credit_card_rounded,
                          'number': '•••• •••• •••• ${c.last4}',
                          'isCard': true,
                        }),
                    {
                      'id': 'wallet',
                      'name': 'CaRide Wallet',
                      'icon': Icons.account_balance_wallet_rounded,
                      'number': 'Primary Balance',
                      'isCard': false,
                    },
                  ];

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: methods.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final method = methods[index];
                      final isSelected = _selectedMethod == method['id'];
                      final isCard = method['isCard'] as bool;
                      final cardId = method['id'] as String;
                      final cardName = method['name'] as String;
                      final cardNumber = method['number'] as String;

                      return GestureDetector(
                        onTap: () => setState(() => _selectedMethod = cardId),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppColors.brand : borderColor,
                              width: isSelected ? 1.8 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.brand.withValues(alpha: 0.12)
                                      : iconBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  method['icon'] as IconData,
                                  color: isSelected ? AppColors.brand : primaryTextColor,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cardName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      cardNumber,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isCard)
                                Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.35)),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: _isDeleting
                                        ? null
                                        : () => _showDeleteConfirmation(cardId, cardName, cardNumber),
                                    child: const Text(
                                      'Remove',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              Icon(
                                isSelected
                                    ? Icons.check_circle_rounded
                                    : Icons.radio_button_off_rounded,
                                color: isSelected ? AppColors.brand : secondaryTextColor.withValues(alpha: 0.5),
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),

            // Add New Card Button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isAddingCard ? null : _startAddCard,
                  icon: _isAddingCard
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  label: Text(
                    _isAddingCard ? 'Setting up...' : 'Add New Card',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    elevation: 0,
                    disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
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
}
