import 'package:caride/features/profile/data/account_repository.dart';
import 'package:caride/features/profile/data/card_repository.dart';
import 'package:caride/features/profile/data/wallet_repository.dart';
import 'package:caride/features/wallet/widgets/bank_transfer_bottom_sheet.dart';
import 'package:caride/features/wallet/widgets/top_up_amount_bottom_sheet.dart';
import 'package:caride/features/wallet/widgets/top_up_method_bottom_sheet.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

class PaymentMethodChoice {
  const PaymentMethodChoice({
    required this.method,
    required this.label,
    this.cardId,
    this.authorizationCode,
    required this.walletBalance,
  });

  final String method; // 'cash', 'wallet', 'card'
  final String label;
  final String? cardId;
  final String? authorizationCode;
  final double walletBalance;
}

class PaymentMethodsBottomSheet extends StatefulWidget {
  const PaymentMethodsBottomSheet({
    super.key,
    required this.selectedMethod,
    required this.selectedCardId,
  });

  final String selectedMethod;
  final String? selectedCardId;

  static Future<PaymentMethodChoice?> show(
    BuildContext context, {
    required String selectedMethod,
    String? selectedCardId,
  }) {
    return showModalBottomSheet<PaymentMethodChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PaymentMethodsBottomSheet(
        selectedMethod: selectedMethod,
        selectedCardId: selectedCardId,
      ),
    );
  }

  @override
  State<PaymentMethodsBottomSheet> createState() =>
      _PaymentMethodsBottomSheetState();
}

class _PaymentMethodsBottomSheetState extends State<PaymentMethodsBottomSheet> {
  final AccountRepository _accountRepo = AccountRepository();
  final CardRepository _cardRepo = CardRepository();

  late String _currentMethod;
  String? _currentCardId;
  String? _currentAuthCode;
  String _currentLabel = 'CaRide Wallet';
  double _lastBalance = 0.0;
  bool _isLoadingBankTransfer = false;

  @override
  void initState() {
    super.initState();
    _currentMethod = widget.selectedMethod;
    _currentCardId = widget.selectedCardId;
  }

  Future<void> _handleTopUpFlow(BuildContext context) async {
    final amount = await TopUpAmountBottomSheet.show(context);
    if (amount == null || amount <= 0 || !mounted) return;

    if (!context.mounted) return;
    final method = await TopUpMethodBottomSheet.show(
      context,
      amountNaira: amount,
    );
    if (method == null || !mounted || !context.mounted) return;

    if (method == TopUpMethodOption.bankTransfer) {
      await _openBankTransfer(context, amount: amount);
    } else if (method == TopUpMethodOption.card) {
      if (!context.mounted) return;
      Navigator.pop(context);
      if (context.mounted) {
        context.push(CustomerRoutePaths.typeAmount);
      }
    }
  }

  Future<void> _openBankTransfer(BuildContext context, {double? amount}) async {
    if (_isLoadingBankTransfer) return;
    setState(() => _isLoadingBankTransfer = true);
    try {
      final details = await WalletRepository().initializeBankTransfer(
        amountNaira: amount ?? 0,
      );
      if (!mounted || !context.mounted) return;

      final credited = await BankTransferBottomSheet.show(
        context,
        details: details,
      );
      if (credited != null && mounted) {
        setState(() {
          _lastBalance += credited;
        });
      }
    } catch (e) {
      debugPrint('[PaymentMethodsBottomSheet BankTransfer ERROR] $e');
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Bank transfer failed: ${e.toString().replaceAll("Exception: ", "")}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingBankTransfer = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BottomSheetShell(
      title: 'Select Payment Method',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
        child: Container(
          constraints: BoxConstraints(
            minHeight: 230,
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Wallet Option
                StreamBuilder<double>(
                  stream: _accountRepo.watchWalletBalance(),
                  builder: (context, balanceSnap) {
                    final balance = balanceSnap.data ?? 0.0;
                    _lastBalance = balance;
                    final isSelected = _currentMethod == 'wallet';

                    return InkWell(
                      onTap: () {
                        setState(() {
                          _currentMethod = 'wallet';
                          _currentCardId = null;
                          _currentAuthCode = null;
                          _currentLabel = 'CaRide Wallet';
                        });
                      },
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: GlassContainer(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              color: isSelected
                                  ? AppColors.brand
                                  : (isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'CaRide Wallet',
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'Balance: ₦${balance.toStringAsFixed(2)}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => _handleTopUpFlow(context),
                              icon: const Icon(
                                Icons.add,
                                size: 16,
                                color: AppColors.brand,
                              ),
                              label: Text(
                                'Top Up',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.brand,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Icon(
                              isSelected
                                  ? Icons.radio_button_checked_rounded
                                  : Icons.radio_button_off_rounded,
                              color: isSelected ? AppColors.brand : Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

                // TODO: Uncomment to re-enable Cash payment option
                // const SizedBox(height: AppSpacing.md),
                // // Cash Option
                // InkWell(
                //   onTap: () {
                //     setState(() {
                //       _currentMethod = 'cash';
                //       _currentCardId = null;
                //       _currentAuthCode = null;
                //       _currentLabel = 'Cash';
                //     });
                //   },
                //   borderRadius: BorderRadius.circular(AppRadius.lg),
                //   child: GlassContainer(
                //     padding: const EdgeInsets.all(AppSpacing.md),
                //     child: Row(
                //       children: [
                //         Icon(
                //           Icons.payments_outlined,
                //           color: _currentMethod == 'cash'
                //               ? AppColors.brand
                //               : (isDark
                //                     ? AppColors.textPrimaryDark
                //                     : AppColors.textPrimaryLight),
                //         ),
                //         const SizedBox(width: AppSpacing.md),
                //         Expanded(
                //           child: Text(
                //             'Cash',
                //             style: AppTextStyles.bodyLarge.copyWith(
                //               fontWeight: FontWeight.bold,
                //             ),
                //           ),
                //         ),
                //         Icon(
                //           _currentMethod == 'cash'
                //               ? Icons.radio_button_checked_rounded
                //               : Icons.radio_button_off_rounded,
                //           color: _currentMethod == 'cash' ? AppColors.brand : Colors.grey,
                //         ),
                //       ],
                //     ),
                //   ),
                // ),

                const SizedBox(height: AppSpacing.md),

                Text(
                  'Saved Cards',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Saved Cards List
                StreamBuilder<List<SavedCard>>(
                  stream: _cardRepo.watchSavedCards(),
                  builder: (context, cardsSnap) {
                    final cards = cardsSnap.data ?? [];
                    if (cards.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        child: Text(
                          'No saved cards available.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: List.generate(cards.length, (index) {
                        final card = cards[index];
                        final isSelected =
                            _currentMethod == 'card' &&
                            _currentCardId == card.id;

                        return Padding(
                          padding: EdgeInsets.only(
                            bottom: index < cards.length - 1 ? AppSpacing.sm : 0,
                          ),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _currentMethod = 'card';
                                _currentCardId = card.id;
                                _currentAuthCode = card.authorizationCode;
                                _currentLabel =
                                    '${card.brand} **** ${card.last4}';
                              });
                            },
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            child: GlassContainer(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.credit_card_rounded,
                                    color: isSelected
                                        ? AppColors.brand
                                        : (isDark
                                              ? AppColors.textPrimaryDark
                                              : AppColors.textPrimaryLight),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      '${card.brand} ending in ${card.last4}',
                                      style: AppTextStyles.titleMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_off_rounded,
                                    color: isSelected
                                        ? AppColors.brand
                                        : Colors.grey,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    );
                  },
                ),

                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Confirm Selection',
                  onPressed: () {
                    Navigator.pop(
                      context,
                      PaymentMethodChoice(
                        method: _currentMethod,
                        label: _currentLabel,
                        cardId: _currentCardId,
                        authorizationCode: _currentAuthCode,
                        walletBalance: _lastBalance,
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
