import 'package:caride/core/services/pending_bank_transfer_service.dart';
import 'package:caride/features/profile/data/wallet_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class BankTransferBottomSheet extends StatefulWidget {
  const BankTransferBottomSheet({
    super.key,
    this.details,
    this.amountNaira,
    this.showSuccessBottomSheet = true,
    this.transferType = PendingTransferType.walletTopUp,
    this.bookingId,
  });

  final BankTransferDetails? details;
  final double? amountNaira;
  final bool showSuccessBottomSheet;
  final PendingTransferType transferType;
  final String? bookingId;

  static Future<double?> show(
    BuildContext context, {
    BankTransferDetails? details,
    double? amountNaira,
    bool showSuccessBottomSheet = true,
    PendingTransferType transferType = PendingTransferType.walletTopUp,
    String? bookingId,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (context) => BankTransferBottomSheet(
        details: details,
        amountNaira: amountNaira ?? details?.amountNaira,
        showSuccessBottomSheet: showSuccessBottomSheet,
        transferType: transferType,
        bookingId: bookingId,
      ),
    );
  }

  @override
  State<BankTransferBottomSheet> createState() => _BankTransferBottomSheetState();
}

class _BankTransferBottomSheetState extends State<BankTransferBottomSheet> {
  final WalletRepository _walletRepo = WalletRepository();
  BankTransferDetails? _details;
  bool _isLoadingDetails = false;
  String? _detailsError;
  bool _isVerifying = false;
  String? _errorMessage;
  bool _isSuccess = false;
  double _creditedAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _details = widget.details;
    if (_details == null) {
      _fetchTransferDetails();
    } else {
      _persistPendingTransfer(_details!);
    }
  }

  void _persistPendingTransfer(BankTransferDetails details) {
    PendingBankTransferService.instance.save(
      PendingBankTransfer(
        reference: details.reference,
        bankName: details.bankName,
        accountName: details.accountName,
        accountNumber: details.accountNumber,
        amountNaira: details.amountNaira,
        type: widget.transferType,
        bookingId: widget.bookingId,
        createdAt: DateTime.now(),
        expiresAt: details.expiresAt != null
            ? DateTime.tryParse(details.expiresAt!)
            : DateTime.now().add(const Duration(hours: 2)),
      ),
    );
  }

  Future<void> _fetchTransferDetails() async {
    setState(() {
      _isLoadingDetails = true;
      _detailsError = null;
    });

    final targetAmount = widget.amountNaira ?? widget.details?.amountNaira ?? 0.0;
    try {
      BankTransferDetails details;
      try {
        details = await _walletRepo.initializeBankTransfer(amountNaira: targetAmount);
      } catch (_) {
        details = await _walletRepo.getOrCreateDedicatedAccount(amountNaira: targetAmount);
      }

      if (mounted) {
        setState(() {
          _details = details;
          _isLoadingDetails = false;
        });
        _persistPendingTransfer(details);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingDetails = false;
          _detailsError = 'Failed to generate bank transfer details. Please check your internet and tap retry.';
        });
      }
    }
  }

  Future<void> _verifyPayment() async {
    final currentDetails = _details;
    if (currentDetails == null) return;
    if (_isVerifying) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final credited = await _walletRepo.verifyTopUp(
        reference: currentDetails.reference,
        fallbackAmount: currentDetails.amountNaira,
      );

      // Payment verified successfully! Clear pending bank transfer
      await PendingBankTransferService.instance.clear();

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _isVerifying = false;
        _isSuccess = true;
        _creditedAmount = credited;
      });
      return;
    } catch (e) {
      if (!mounted) return;

      final rawMsg = e.toString().replaceAll("Exception: ", "");
      String message;

      if (rawMsg.contains('PAYMENT_PENDING') || rawMsg.toLowerCase().contains('pending')) {
        message = 'Your bank transfer is currently processing. Transfers usually settle within 1 to 3 minutes. Please wait a moment and tap "Check Again".';
      } else if (rawMsg.contains('PAYMENT_FAILED') || rawMsg.toLowerCase().contains('failed')) {
        message = 'The transfer was reported as failed or cancelled by the banking network. If funds were debited, your bank will automatically issue a refund.';
      } else if (rawMsg.contains('PAYMENT_NOT_RECEIVED') || rawMsg.toLowerCase().contains('not found')) {
        message = 'We haven\'t received your transfer from your bank yet. Please ensure you sent funds to the account details displayed above, then tap "Check Again".';
      } else {
        message = 'Could not verify payment status right now. Please check your internet connection and try again.';
      }

      setState(() {
        _errorMessage = message;
      });

      HapticFeedback.lightImpact();
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              '$label copied to clipboard',
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
            ),
          ],
        ),
        backgroundColor: AppColors.brand,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveAmount = _details?.amountNaira ?? widget.amountNaira ?? 0.0;
    final hasAmount = effectiveAmount > 0;
    final formattedAmount = hasAmount
        ? NumberFormat('#,##0').format(effectiveAmount)
        : '0';

    // Exact reference layout with CaRide design tokens
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
          child: _isSuccess
              ? _buildSuccessView(isDark)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Top drag pill
                    Container(
                      width: 48,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Title "Bank Transfer"
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

              // Subtitle paragraph
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

              // Grey / Surface Card containing the details
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 22.0),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: _isLoadingDetails
                    ? _buildLoadingCardContent(isDark)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Bank Name
                          _buildDetailItem(
                            label: 'Bank Name',
                            value: _details?.bankName.isNotEmpty == true
                                ? _details!.bankName
                                : 'Providus Bank',
                            labelColor: labelColor,
                            valueColor: valueColor,
                          ),
                          const SizedBox(height: 20),

                          // Account Name
                          _buildDetailItem(
                            label: 'Account Name',
                            value: _details?.accountName.isNotEmpty == true
                                ? _details!.accountName
                                : 'TransWorld-Pay With Bank Transfer',
                            labelColor: labelColor,
                            valueColor: valueColor,
                          ),
                          const SizedBox(height: 20),

                          // Account Number with copy action
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: _buildDetailItem(
                                  label: 'Account Number',
                                  value: _details?.accountNumber.isNotEmpty == true
                                      ? _details!.accountNumber
                                      : '—',
                                  labelColor: labelColor,
                                  valueColor: valueColor,
                                  valueFontSize: 21,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              if (_details?.accountNumber.isNotEmpty == true)
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => _copyToClipboard(
                                      _details!.accountNumber,
                                      'Account number',
                                    ),
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

                          // Amount
                          _buildDetailItem(
                            label: 'Amount',
                            value: '₦$formattedAmount',
                            labelColor: labelColor,
                            valueColor: valueColor,
                            valueFontSize: 20,
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: 20),

              // Sub-caption
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

              // Error banner if any
              if (_errorMessage != null || _detailsError != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFEF4444), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage ?? _detailsError!,
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 12.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Primary CaRide Brand Rounded Pill Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoadingDetails
                      ? null
                      : (_detailsError != null
                          ? _fetchTransferDetails
                          : (_isVerifying ? null : _verifyPayment)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandButtonColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: brandButtonColor.withValues(alpha: 0.5),
                    disabledForegroundColor: Colors.white70,
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isVerifying
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _detailsError != null
                              ? 'Retry Generating Account'
                              : (_errorMessage != null
                                  ? 'Check Again'
                                  : "I've Made the Transfer"),
                          style: const TextStyle(
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
                  if (context.mounted) Navigator.pop(context);
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

  Widget _buildLoadingCardContent(bool isDark) {
    final shimmer = isDark ? Colors.white10 : const Color(0xFFE5E7EB);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.brand,
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Generating dedicated account...',
              style: TextStyle(
                color: AppColors.brand,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(width: 120, height: 18, decoration: BoxDecoration(color: shimmer, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 18),
        Container(width: 180, height: 18, decoration: BoxDecoration(color: shimmer, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 18),
        Container(width: 150, height: 22, decoration: BoxDecoration(color: shimmer, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 18),
        Container(width: 90, height: 20, decoration: BoxDecoration(color: shimmer, borderRadius: BorderRadius.circular(4))),
      ],
    );
  }

  Widget _buildSuccessView(bool isDark) {
    final effectiveAmount = _creditedAmount > 0
        ? _creditedAmount
        : (_details?.amountNaira ?? widget.amountNaira ?? 0.0);
    final formattedAmount = NumberFormat('#,##0').format(effectiveAmount);

    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF4B5563);
    final cardBg = isDark ? const Color(0xFF1E1F24) : const Color(0xFFF4F4F6);
    final borderColor = isDark ? Colors.white10 : const Color(0xFFE5E7EB);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Top drag pill
        Container(
          width: 48,
          height: 4.5,
          decoration: BoxDecoration(
            color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(height: 28),

        // Glowing Success Icon with CaRide brand token
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.15),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.brand.withValues(alpha: 0.35),
              width: 2,
            ),
          ),
          child: Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
          ),
        ),
        const SizedBox(height: 22),

        // Top Up Successful Title
        Text(
          'Top Up Successful!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 8),

        // Subtitle confirmation
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            'Your transfer has been verified and credited to your CaRide wallet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.4,
              color: subtitleColor,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Amount Credited Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: [
              Text(
                'AMOUNT CREDITED',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '₦$formattedAmount',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  color: titleColor,
                ),
              ),
              if (_details?.reference.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_rounded, size: 14, color: AppColors.brand),
                      const SizedBox(width: 5),
                      Text(
                        'Ref: ${_details!.reference}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brand,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Done Action Pill Button
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop(effectiveAmount);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brand,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: const Text(
              'Done',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
