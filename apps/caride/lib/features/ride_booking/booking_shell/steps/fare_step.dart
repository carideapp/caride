import 'package:caride/features/profile/data/account_repository.dart';
import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:caride/features/ride_booking/booking_shell/widgets/payment_methods_bottom_sheet.dart';
import 'package:caride/features/ride_booking/booking_shell/widgets/promos_bottom_sheet.dart';
import 'package:caride/features/wallet/widgets/dedicated_account_bottom_sheet.dart';
import 'package:caride/features/wallet/widgets/pending_bank_transfer_widgets.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer Fare Bidding Input Step.
class FareStep extends StatefulWidget {
  const FareStep({super.key, required this.controller});

  final BookingShellController controller;

  @override
  State<FareStep> createState() => _FareStepState();
}

class _FareStepState extends State<FareStep> {
  static const double _step = 50;
  bool _requesting = false;

  String _paymentMethod = 'wallet';
  String _paymentMethodLabel = 'CaRide Wallet';
  String? _selectedCardId;
  String? _selectedAuthCode;
  double _walletBalance = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchInitialBalance();
  }

  Future<void> _fetchInitialBalance() async {
    try {
      final balance = await AccountRepository().watchWalletBalance().first;
      if (mounted) {
        setState(() {
          _walletBalance = balance;
        });
      }
    } catch (_) {}
  }

  Future<void> _selectPaymentMethod() async {
    final choice = await PaymentMethodsBottomSheet.show(
      context,
      selectedMethod: _paymentMethod,
      selectedCardId: _selectedCardId,
    );
    if (choice != null) {
      setState(() {
        _paymentMethod = choice.method;
        _paymentMethodLabel = choice.label;
        _selectedCardId = choice.cardId;
        _selectedAuthCode = choice.authorizationCode;
        _walletBalance = choice.walletBalance;
      });
    }
  }

  Future<void> _selectPromo() async {
    final promo = await PromosBottomSheet.show(
      context,
      currentOffer: widget.controller.offerNaira,
      selectedPromoId: widget.controller.selectedPromo?.id,
    );
    if (promo != null) {
      if (promo.id.isEmpty) {
        widget.controller.setPromo(null);
      } else {
        widget.controller.setPromo(promo);
      }
    }
  }

  Future<void> _editOffer() async {
    final initial = widget.controller.offerNaira.round().toString();
    final ctrl = TextEditingController(text: initial);

    final v = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: GlassSurface(
            radius: AppRadius.lg,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Set your offer',
                  style: AppTextStyles.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: ctrl,
                  hint: 'Offer amount',
                  obscureText: false,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Cancel',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Save',
                        onPressed: () {
                          final parsed = double.tryParse(
                            ctrl.text.trim().replaceAll(',', ''),
                          );
                          Navigator.pop(context, parsed);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (v != null) widget.controller.setOffer(v);
  }

  Future<void> _requestRide() async {
    if (_paymentMethod == 'wallet' &&
        _walletBalance < widget.controller.offerNaira) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Insufficient wallet balance. Please top up or choose another payment method.',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _requesting = true);
    try {
      await widget.controller.requestRide(
        paymentMethod: _paymentMethod == 'card' && _selectedAuthCode != null
            ? _selectedAuthCode!
            : _paymentMethod,
      );
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request ride: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = widget.controller;

    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final offer = c.offerNaira;
        final isWallet = _paymentMethod == 'wallet';
        final isInsufficient = isWallet && _walletBalance < offer;

        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set your fare',
                style: AppTextStyles.headlineSmall.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              GlassContainer(
                padding: EdgeInsets.zero,
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => c.decrementOffer(step: _step),
                      icon: const Icon(Icons.remove_rounded),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: _editOffer,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          child: Column(
                            children: [
                              Text(
                                NgnFormat.whole(offer),
                                style: AppTextStyles.headlineMedium.copyWith(
                                  color: AppColors.brand,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tap to edit',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => c.incrementOffer(step: _step),
                      icon: const Icon(Icons.add_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Pending Bank Transfer Banner (if active)
              const PendingBankTransferBanner(
                margin: EdgeInsets.only(bottom: AppSpacing.sm),
              ),

              // Payment method row selector
              InkWell(
                onTap: _selectPaymentMethod,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: GlassContainer(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.brandGlass,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _paymentMethod == 'wallet'
                              ? Icons.account_balance_wallet_outlined
                              : Icons.credit_card_rounded,
                          color: AppColors.brand,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Method',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _paymentMethodLabel,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Promo code row selector
              InkWell(
                onTap: _selectPromo,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: GlassContainer(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.brandGlass,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.local_offer_outlined,
                          color: AppColors.brand,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Special Offer / Promo',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              c.selectedPromo != null
                                  ? c.selectedPromo!.code
                                  : 'Apply Promo Code',
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w800,
                                color: c.selectedPromo != null
                                    ? AppColors.brand
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Credit Wallet row selector
              StreamBuilder<AccountProfile?>(
                stream: AccountRepository().watchProfile(),
                builder: (context, profileSnap) {
                  final profile = profileSnap.data;
                  final creditBalance = profile?.creditBalance ?? 0.0;
                  final maxCoverageDiscount =
                      (offer * 0.10); // 10% default max fare coverage
                  final calculatedDiscount = creditBalance < maxCoverageDiscount
                      ? creditBalance
                      : maxCoverageDiscount;
                  final estPayable = (offer - calculatedDiscount).clamp(
                    0.0,
                    double.infinity,
                  );

                  return GlassContainer(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.stars_rounded,
                            color: Color(0xFF10B981),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Use Subsidy Wallet (Avail: ₦${creditBalance.toStringAsFixed(0)})',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                c.useCreditWallet
                                    ? '-₦${calculatedDiscount.toStringAsFixed(0)} Discount (You Pay ₦${estPayable.toStringAsFixed(0)})'
                                    : 'Cover up to 10% of fare',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: c.useCreditWallet
                                      ? const Color(0xFF10B981)
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: c.useCreditWallet,
                          activeThumbColor: const Color(0xFF10B981),
                          onChanged: (val) {
                            c.setUseCreditWallet(val);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (isInsufficient) ...[
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Insufficient wallet balance (Available: ₦${_walletBalance.toStringAsFixed(2)})',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor: AppColors.brand.withValues(
                            alpha: 0.12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () =>
                            DedicatedAccountBottomSheet.show(context),
                        child: Text(
                          'Top Up',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.brand,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: _requesting ? 'Requesting...' : 'Request Ride',
                onPressed: (_requesting || isInsufficient)
                    ? null
                    : _requestRide,
              ),
            ],
          ),
        );
      },
    );
  }
}
