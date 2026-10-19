import 'package:caride/core/services/pending_bank_transfer_service.dart';
import 'package:caride/features/profile/data/wallet_repository.dart';
import 'package:caride/features/wallet/widgets/bank_transfer_bottom_sheet.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Reusable banner displayed on Home, Wallet, Ride Booking, or Rental screen
/// when an unverified bank transfer is active.
class PendingBankTransferBanner extends StatelessWidget {
  const PendingBankTransferBanner({
    super.key,
    this.bookingId,
    this.typeFilter,
    this.margin = const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  });

  final String? bookingId;
  final PendingTransferType? typeFilter;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PendingBankTransfer?>(
      valueListenable: PendingBankTransferService.instance.pendingTransferNotifier,
      builder: (context, pending, _) {
        if (pending == null) return const SizedBox.shrink();

        // If a bookingId is specified, only show if this matches
        if (bookingId != null && pending.bookingId != bookingId) {
          return const SizedBox.shrink();
        }

        // If a typeFilter is specified, only show if this matches
        if (typeFilter != null && pending.type != typeFilter) {
          return const SizedBox.shrink();
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final amountFormatted = NumberFormat('#,##0.00').format(pending.amountNaira);

        return Container(
          margin: margin,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.brand.withValues(alpha: 0.15)
                : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? AppColors.brand.withValues(alpha: 0.3)
                  : const Color(0xFFBBF7D0),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.hourglass_top_rounded,
                  color: AppColors.brand,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Pending Transfer: ₦$amountFormatted',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF166534),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pending.typeLabel} • Tap to verify payment',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : const Color(0xFF15803D),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _openDetails(context, pending),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Verify',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openDetails(BuildContext context, PendingBankTransfer pending) {
    BankTransferBottomSheet.show(
      context,
      details: BankTransferDetails(
        bankName: pending.bankName,
        accountName: pending.accountName,
        accountNumber: pending.accountNumber,
        amountNaira: pending.amountNaira,
        reference: pending.reference,
        expiresAt: pending.expiresAt?.toIso8601String(),
      ),
      amountNaira: pending.amountNaira,
      transferType: pending.type,
      bookingId: pending.bookingId,
      showSuccessBottomSheet: pending.type != PendingTransferType.carRental,
    );
  }
}

/// Modal bottom sheet shown automatically on app startup / resume when
/// a pending bank transfer is awaiting verification.
class PendingBankTransferPromptSheet extends StatelessWidget {
  const PendingBankTransferPromptSheet({
    super.key,
    required this.pending,
  });

  final PendingBankTransfer pending;

  static Future<void> show(
    BuildContext context, {
    required PendingBankTransfer pending,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PendingBankTransferPromptSheet(pending: pending),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amountFormatted = NumberFormat('#,##0').format(pending.amountNaira);
    final sheetBg = isDark ? const Color(0xFF141416) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E1F24) : const Color(0xFFF4F4F6);
    final titleColor = isDark ? Colors.white : const Color(0xFF1F1F1F);
    final subtitleColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF6B7280);
    final labelColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF555555);
    final valueColor = isDark ? Colors.white : const Color(0xFF111827);
    const brandButtonColor = AppColors.brand;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 24.0,
            right: 24.0,
            top: 14.0,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Top drag indicator
              Container(
                width: 48,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Bank Transfer',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 14),

              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Complete your payment by transferring the exact amount to the account below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                    color: subtitleColor,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Bank Details Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 22.0),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailItem(
                      label: 'Bank Name',
                      value: pending.bankName.isNotEmpty ? pending.bankName : 'Providus Bank',
                      labelColor: labelColor,
                      valueColor: valueColor,
                    ),
                    const SizedBox(height: 20),
                    _buildDetailItem(
                      label: 'Account Name',
                      value: pending.accountName.isNotEmpty ? pending.accountName : 'CaRide Technologies Ltd.',
                      labelColor: labelColor,
                      valueColor: valueColor,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _buildDetailItem(
                            label: 'Account Number',
                            value: pending.accountNumber,
                            labelColor: labelColor,
                            valueColor: valueColor,
                            valueFontSize: 21,
                            letterSpacing: 0.6,
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: pending.accountNumber));
                              HapticFeedback.mediumImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: const [
                                      Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        'Account number copied to clipboard',
                                        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: brandButtonColor,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Icon(
                                Icons.copy_rounded,
                                size: 19,
                                color: isDark ? const Color(0xFFA1A1AA) : const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildDetailItem(
                      label: 'Amount',
                      value: '₦$amountFormatted',
                      labelColor: labelColor,
                      valueColor: valueColor,
                      valueFontSize: 20,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Payments confirmation note
              Text(
                'Payments are usually confirmed within a few minutes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 22),

              // Primary Action: "I've Made the Transfer"
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    BankTransferBottomSheet.show(
                      context,
                      details: BankTransferDetails(
                        bankName: pending.bankName,
                        accountName: pending.accountName,
                        accountNumber: pending.accountNumber,
                        amountNaira: pending.amountNaira,
                        reference: pending.reference,
                        expiresAt: pending.expiresAt?.toIso8601String(),
                      ),
                      amountNaira: pending.amountNaira,
                      transferType: pending.type,
                      bookingId: pending.bookingId,
                      showSuccessBottomSheet: pending.type != PendingTransferType.carRental,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandButtonColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    "I've Made the Transfer",
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Cancel Payment with circle close icon
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () async {
                  await PendingBankTransferService.instance.clear();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cancel_outlined,
                        size: 22,
                        color: subtitleColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Cancel Payment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem({
    required String label,
    required String value,
    required Color labelColor,
    required Color valueColor,
    double valueFontSize = 17,
    double letterSpacing = -0.1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: valueFontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: letterSpacing,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
