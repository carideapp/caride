// ignore_for_file: deprecated_member_use

import 'package:caride/features/profile/data/card_repository.dart';
import 'package:caride/features/profile/data/wallet_repository.dart';
import 'package:caride/features/wallet/widgets/bank_transfer_bottom_sheet.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// The three methods available for topping up a CaRide Wallet.
enum _TopUpMethod { bankTransfer, card }

class TopUpMethodScreen extends StatefulWidget {
  const TopUpMethodScreen({super.key, required this.amountNaira});

  final double amountNaira;

  @override
  State<TopUpMethodScreen> createState() => _TopUpMethodScreenState();
}

class _TopUpMethodScreenState extends State<TopUpMethodScreen> {
  final CardRepository _cardRepo = CardRepository();
  final WalletRepository _walletRepo = WalletRepository();

  late final Stream<List<SavedCard>> _savedCardsStream;

  @override
  void initState() {
    super.initState();
    _savedCardsStream = _cardRepo.watchSavedCards();
  }

  _TopUpMethod _selected = _TopUpMethod.bankTransfer;
  String? _selectedCardId = 'new_card';
  String? _selectedCardAuth;
  String? _selectedCardEmail;
  bool _loading = false;

  Future<void> _proceed() async {
    if (_loading) return;

    if (_selected == _TopUpMethod.card && _selectedCardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment card option.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      if (_selected == _TopUpMethod.card && _selectedCardId != 'new_card' && _selectedCardAuth != null) {
        final credited = await _walletRepo.chargeWithSavedCard(
          authorizationCode: _selectedCardAuth!,
          email: _selectedCardEmail!,
          amountNaira: widget.amountNaira,
        );
        if (!mounted) return;
        _showSuccessDialog(credited);
      } else if (_selected == _TopUpMethod.bankTransfer) {
        final details = await _walletRepo.initializeBankTransfer(
          amountNaira: widget.amountNaira,
        );
        if (!mounted) return;
        final credited = await BankTransferBottomSheet.show(
          context,
          details: details,
        );
        if (credited != null && mounted) {
          context.go(CustomerRoutePaths.wallet);
        }
      } else {
        final result = await _walletRepo.initializeTopUp(
          amountNaira: widget.amountNaira,
          channels: ['card'],
        );
        if (!mounted) return;
        await context.push(
          CustomerRoutePaths.topUpWebview,
          extra: {
            'url': result.authorizationUrl,
            'reference': result.reference,
            'amountNaira': widget.amountNaira,
          },
        );
      }
    } catch (e) {
      if (!mounted) return;
      final cleanMsg = e.toString()
          .replaceAll(RegExp(r'^(Exception|FirebaseFunctionsException):\s*'), '')
          .replaceAll(RegExp(r'\[.*?\]\s*'), '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment process note: $cleanMsg'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessDialog(double credited) {
    if (!mounted) return;
    final formatted =
        '₦${credited.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
    
    final currentContext = context;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassSurface(
          radius: AppRadius.xl,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.black, size: 40),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Top Up Successful!',
                style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '$formatted has been added to your CaRide Wallet.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: 'Done',
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (currentContext.mounted) {
                    currentContext.go(CustomerRoutePaths.wallet);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addNewCardViaWebview() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final result = await _walletRepo.initializeTopUp(
        amountNaira: 100.0,
        channels: ['card'],
      );
      if (!mounted) return;
      final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      await context.push(
        CustomerRoutePaths.topUpWebview,
        extra: {
          'url': result.authorizationUrl,
          'reference': result.reference,
          'amountNaira': 100.0,
          'isSetupCard': true,
          'email': userEmail,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Card setup failed: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formatted =
        '₦${widget.amountNaira.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: 'Top Up Method',
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.pagePadding),
                  children: [
                    // Amount summary
                    GlassContainer(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Amount to top up', style: AppTextStyles.bodyLarge),
                          Text(
                            formatted,
                            style: AppTextStyles.titleLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.brand,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    Text(
                      'Select payment method',
                      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Bank Transfer
                    _MethodTile(
                      icon: Icons.account_balance_outlined,
                      title: 'Bank Transfer',
                      subtitle: 'Pay via your bank account',
                      selected: _selected == _TopUpMethod.bankTransfer,
                      onTap: () => setState(() {
                        _selected = _TopUpMethod.bankTransfer;
                        _selectedCardId = null;
                      }),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Card
                    _MethodTile(
                      icon: Icons.credit_card_rounded,
                      title: 'Card',
                      subtitle: 'Pay with a saved or new card',
                      selected: _selected == _TopUpMethod.card,
                      onTap: () => setState(() {
                        _selected = _TopUpMethod.card;
                        _selectedCardId ??= 'new_card';
                      }),
                    ),

                    // Saved cards (only shown when Card is selected)
                    if (_selected == _TopUpMethod.card) ...[
                      const SizedBox(height: AppSpacing.md),
                      const SizedBox(height: AppSpacing.md),
                      StreamBuilder<List<SavedCard>>(
                        stream: _savedCardsStream,
                        builder: (context, snap) {
                          final cards = snap.data ?? [];
                          return Column(
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: RadioListTile<String>(
                                  value: 'new_card',
                                  groupValue: _selectedCardId,
                                  onChanged: (v) => setState(() {
                                    _selectedCardId = v;
                                    _selectedCardAuth = null;
                                    _selectedCardEmail = null;
                                  }),
                                  title: const Text('Pay with a new card'),
                                  secondary: const Icon(Icons.add_card_rounded),
                                  activeColor: AppColors.brand,
                                ),
                              ),
                              ...cards.map((card) => Material(
                                    color: Colors.transparent,
                                    child: RadioListTile<String>(
                                      value: card.id,
                                      groupValue: _selectedCardId,
                                      onChanged: (v) => setState(() {
                                        _selectedCardId = v;
                                        _selectedCardAuth = card.authorizationCode;
                                        _selectedCardEmail = card.email;
                                      }),
                                      title: Text('${card.brand} •••• ${card.last4}'),
                                      secondary: const Icon(Icons.credit_card_rounded),
                                      activeColor: AppColors.brand,
                                    ),
                                  )),
                              Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  leading: const Icon(Icons.add_circle_outline, color: AppColors.brand),
                                  title: const Text('Link new card (₦100 setup)'),
                                  onTap: () => _addNewCardViaWebview(),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                child: PrimaryButton(
                  label: _loading ? 'Loading...' : 'Continue',
                  onPressed: _loading ? null : _proceed,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: GlassContainer(
          padding: const EdgeInsets.all(AppSpacing.md),
          borderColor: selected
              ? AppColors.brand
              : (isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight),
          borderWidth: selected ? 2 : 1,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.brandGlass : (isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F5F9)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: selected ? AppColors.brand : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: selected ? AppColors.brand : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
