import 'package:cloud_functions/cloud_functions.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:caride/features/car_rental/data/customer_rental_repository.dart';
import 'package:caride/features/profile/data/account_repository.dart';
import 'package:caride/features/wallet/widgets/top_up_amount_bottom_sheet.dart';
import 'package:caride/features/wallet/widgets/top_up_method_bottom_sheet.dart';
import 'package:caride/core/services/pending_bank_transfer_service.dart';
import 'package:caride/features/wallet/widgets/pending_bank_transfer_widgets.dart';
import 'package:caride/features/wallet/widgets/bank_transfer_bottom_sheet.dart';
import 'package:caride/features/car_rental/presentation/widgets/rental_payment_success_bottom_sheet.dart';

enum _PaymentMethodOption { wallet, card, bankTransfer }

class RentalPaymentScreen extends StatefulWidget {
  const RentalPaymentScreen({super.key, required this.booking});

  final RentalBooking booking;

  @override
  State<RentalPaymentScreen> createState() => _RentalPaymentScreenState();
}

class _RentalPaymentScreenState extends State<RentalPaymentScreen> {
  final AccountRepository _accountRepo = AccountRepository();
  _PaymentMethodOption _selectedMethod = _PaymentMethodOption.wallet;

  bool _isProcessing = false;
  String? _errorMessage;

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  void _setError(String msg) {
    setState(() => _errorMessage = msg);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Future<void> _handleTopUp() async {
    final amount = await TopUpAmountBottomSheet.show(context);
    if (amount == null || amount <= 0 || !mounted) return;

    final method = await TopUpMethodBottomSheet.show(
      context,
      amountNaira: amount,
    );
    if (method == null || !mounted) return;

    if (method == TopUpMethodOption.bankTransfer) {
      await BankTransferBottomSheet.show(
        context,
        amountNaira: amount,
        transferType: PendingTransferType.walletTopUp,
      );
    } else if (method == TopUpMethodOption.card) {
      if (!mounted) return;
      context.push(CustomerRoutePaths.typeAmount);
    }
  }

  Future<void> _showPaymentSuccessBottomSheet(String pin) async {
    if (!mounted) return;
    await RentalPaymentSuccessBottomSheet.show(
      context,
      booking: widget.booking,
      pin: pin,
      onViewBookings: () {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
        context.go(CustomerRoutePaths.rentalBookings);
      },
    );

    if (mounted) {
      Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
      context.go(CustomerRoutePaths.rentalBookings);
    }
  }

  void _handlePaymentError(Object e) {
    String errorMessage = 'Payment could not be processed. Please try again.';
    if (e is FirebaseFunctionsException) {
      errorMessage = e.message ?? e.details?.toString() ?? 'Payment service error. Please try again.';
    } else {
      final raw = e.toString().replaceAll(RegExp(r'\[.*?\]'), '').split('\n').first.trim();
      if (raw.isNotEmpty && !raw.contains('Exception') && !raw.contains('Instance of')) {
        errorMessage = raw;
      }
    }
    _setError(errorMessage);
  }

  Future<void> _processPayment(double currentBalance) async {
    _clearError();

    if (widget.booking.isPaymentExpired) {
      _setError('The 3-hour payment window for this rental has expired. The vehicle hold has been released.');
      return;
    }

    if (_selectedMethod == _PaymentMethodOption.wallet) {
      if (currentBalance < widget.booking.totalAmount) {
        _setError('Insufficient wallet balance. Please top up your wallet or select another payment method.');
        return;
      }
    }

    if (_selectedMethod == _PaymentMethodOption.bankTransfer) {
      final credited = await BankTransferBottomSheet.show(
        context,
        amountNaira: widget.booking.totalAmount,
        showSuccessBottomSheet: false,
        transferType: PendingTransferType.carRental,
        bookingId: widget.booking.id,
      );

      if (credited == null || credited <= 0 || !mounted) {
        // User closed the bottom sheet without completing verification
        return;
      }

      // Bank transfer was verified! Finalize the rental booking payment.
      setState(() => _isProcessing = true);
      try {
        final result = await customerRentalRepository.payBooking(
          bookingId: widget.booking.id,
          paymentMethod: 'bank_transfer',
        );

        final isSelfDrive = widget.booking.serviceType == RentalServiceType.selfDrive;
        final pin = isSelfDrive
            ? (result['pickupPin'] as String?) ?? ''
            : (result['startPin'] as String?) ?? '';

        if (!mounted) return;
        setState(() => _isProcessing = false);

        await _showPaymentSuccessBottomSheet(pin);
      } catch (e) {
        if (!mounted) return;
        setState(() => _isProcessing = false);
        _handlePaymentError(e);
      }
      return;
    }

    // Wallet or Card payment
    setState(() => _isProcessing = true);

    try {
      final methodString = switch (_selectedMethod) {
        _PaymentMethodOption.wallet => 'wallet',
        _PaymentMethodOption.card => 'card',
        _PaymentMethodOption.bankTransfer => 'bank_transfer',
      };

      final result = await customerRentalRepository.payBooking(
        bookingId: widget.booking.id,
        paymentMethod: methodString,
      );

      final isSelfDrive = widget.booking.serviceType == RentalServiceType.selfDrive;
      final pin = isSelfDrive
          ? (result['pickupPin'] as String?) ?? ''
          : (result['startPin'] as String?) ?? '';

      if (!mounted) return;
      setState(() => _isProcessing = false);

      await _showPaymentSuccessBottomSheet(pin);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      _handlePaymentError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final dateFormat = DateFormat('EEE, MMM dd, yyyy');

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: primaryTextColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Complete Payment',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: primaryTextColor),
                  ),
                ],
              ),
            ),

            // Pending Bank Transfer Banner (if active for this booking)
            PendingBankTransferBanner(
              bookingId: widget.booking.id,
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            ),

            Expanded(
              child: StreamBuilder<double>(
                stream: _accountRepo.watchWalletBalance(),
                builder: (context, balanceSnapshot) {
                  final walletBalance = balanceSnapshot.data ?? 0.0;
                  final isWalletInsufficient = walletBalance < widget.booking.totalAmount;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // In-View Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.error),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Action Required',
                                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.error, fontSize: 13),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _errorMessage!,
                                        style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B)),
                                      ),
                                    ],
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _clearError,
                                  child: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                                ),
                              ],
                            ),
                          ),
                        ],

                        // 3-Hour Payment Window Countdown Banner
                        Builder(
                          builder: (context) {
                            final isExpired = widget.booking.isPaymentExpired;
                            final expiresAt = widget.booking.paymentExpiresAt ??
                                (widget.booking.updatedAt ?? DateTime.now()).add(const Duration(hours: 3));
                            final diff = expiresAt.difference(DateTime.now());
                            final remainingText = diff.isNegative
                                ? 'expiring now'
                                : '${diff.inHours > 0 ? '${diff.inHours}h ' : ''}${diff.inMinutes.remainder(60)}m';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: isExpired
                                    ? (isDark ? const Color(0xFF3B1215) : const Color(0xFFFEF2F2))
                                    : (isDark ? const Color(0xFF2E2208) : const Color(0xFFFFFBEB)),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isExpired
                                      ? AppColors.error.withValues(alpha: 0.35)
                                      : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isExpired ? Icons.timer_off_outlined : Icons.alarm_rounded,
                                    color: isExpired ? AppColors.error : const Color(0xFFF59E0B),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      isExpired
                                          ? 'Payment window expired (3 hrs). The vehicle hold has been released.'
                                          : 'Complete payment within $remainingText. Unpaid bookings expire automatically after 3 hours.',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        color: isExpired
                                            ? (isDark ? const Color(0xFFFCA5A5) : AppColors.error)
                                            : (isDark ? const Color(0xFFFDE68A) : const Color(0xFFB45309)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // Vehicle Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: widget.booking.vehicleImage.isNotEmpty
                                    ? Image.network(
                                        widget.booking.vehicleImage,
                                        width: 72,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _carPlaceholder(),
                                      )
                                    : _carPlaceholder(),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.booking.vehicleTitle,
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: primaryTextColor),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${widget.booking.serviceType.label} • ${widget.booking.durationDays} Day(s)',
                                      style: TextStyle(fontSize: 13, color: secondaryTextColor),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${dateFormat.format(widget.booking.startDate)} – ${dateFormat.format(widget.booking.endDate)}',
                                      style: const TextStyle(fontSize: 12, color: AppColors.brand, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Pricing Breakdown Card
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Rental Cost Breakdown', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: primaryTextColor)),
                              Divider(height: 20, color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
                              _priceRow('Rental Rate', NgnFormat.currency(widget.booking.totalAmount - widget.booking.cautionDeposit - widget.booking.driverAllowance), secondaryTextColor, primaryTextColor),
                              if (widget.booking.driverAllowance > 0)
                                _priceRow('Driver Allowance', NgnFormat.currency(widget.booking.driverAllowance), secondaryTextColor, primaryTextColor),
                              if (widget.booking.cautionDeposit > 0)
                                _priceRow('Refundable Caution Deposit', NgnFormat.currency(widget.booking.cautionDeposit), secondaryTextColor, primaryTextColor),
                              Divider(height: 20, color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Total Payable', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: primaryTextColor)),
                                  Text(NgnFormat.currency(widget.booking.totalAmount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.brand)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Payment Methods
                        Text('Select Payment Method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: primaryTextColor)),
                        const SizedBox(height: 12),

                        // Option 1: CaRide Wallet
                        _buildPaymentOption(
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                          option: _PaymentMethodOption.wallet,
                          icon: Icons.account_balance_wallet_rounded,
                          title: 'CaRide Wallet',
                          subtitle: 'Balance: ${NgnFormat.currency(walletBalance)}',
                          trailing: isWalletInsufficient
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                                      child: const Text('Low Balance', style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w600)),
                                    ),
                                    const SizedBox(width: 8),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      onPressed: _handleTopUp,
                                      child: const Text('Top Up', style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w700, fontSize: 12)),
                                    ),
                                  ],
                                )
                              : null,
                        ),
                        const SizedBox(height: 10),

                        // Option 2: Card
                        _buildPaymentOption(
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                          option: _PaymentMethodOption.card,
                          icon: Icons.credit_card_rounded,
                          title: 'Debit / Credit Card',
                          subtitle: 'Pay securely with Mastercard, Visa, or Verve',
                        ),
                        const SizedBox(height: 10),

                        // Option 3: Bank Transfer
                        _buildPaymentOption(
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                          option: _PaymentMethodOption.bankTransfer,
                          icon: Icons.account_balance_rounded,
                          title: 'Bank Transfer',
                          subtitle: 'Transfer directly to a dedicated CaRide account',
                        ),
                        const SizedBox(height: 32),

                        // Pay Button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                            ),
                            onPressed: _isProcessing ? null : () => _processPayment(walletBalance),
                            child: _isProcessing
                                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : Text(
                                    'Pay ${NgnFormat.currency(widget.booking.totalAmount)}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
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

  Widget _buildPaymentOption({
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required _PaymentMethodOption option,
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
  }) {
    final isSelected = _selectedMethod == option;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = option;
          _clearError();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.brand : (isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.brand.withValues(alpha: 0.1) : (isDark ? Colors.white10 : const Color(0xFFF3F4F6)),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: isSelected ? AppColors.brand : (isDark ? Colors.white70 : const Color(0xFF6B7280)), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: primaryTextColor)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: secondaryTextColor)),
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (trailing == null)
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: isSelected ? AppColors.brand : (isDark ? Colors.white30 : const Color(0xFFD1D5DB)),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _priceRow(String label, String value, Color labelColor, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: labelColor)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }

  Widget _carPlaceholder() {
    return Container(
      width: 72,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.directions_car, color: AppColors.brand, size: 28),
    );
  }
}
