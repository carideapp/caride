import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caride/features/wallet/data/withdraw_repository.dart';
import 'package:caride/features/wallet/withdraw_pin_screen.dart';
import 'package:shared_widgets/shared_widgets.dart';

class WithdrawAmountScreen extends StatefulWidget {
  const WithdrawAmountScreen({super.key, required this.resolved});
  final ResolvedAccount resolved;

  @override
  State<WithdrawAmountScreen> createState() => _WithdrawAmountScreenState();
}

class _WithdrawAmountScreenState extends State<WithdrawAmountScreen> {
  final _controller = TextEditingController();
  String? _error;

  static const double _minAmount = 100;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatNaira(double value) {
    final rounded = value.round().toString();
    return '₦${rounded.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  Future<double> _fetchBalance() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return 0;
    final doc = await FirebaseFirestore.instance
        .collection('customers')
        .doc(uid)
        .get();
    return (doc.data()?['walletBalance'] as num?)?.toDouble() ?? 0;
  }

  void _onContinue(double balance) {
    final text = _controller.text.trim().replaceAll(',', '');
    final amount = double.tryParse(text);

    if (amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a valid amount.');
      return;
    }
    if (amount < _minAmount) {
      setState(() => _error = 'Minimum withdrawal is ₦${_minAmount.toInt()}.');
      return;
    }
    if (amount > balance) {
      setState(() => _error = 'Amount exceeds your wallet balance.');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WithdrawPinScreen(
          resolved: widget.resolved,
          amountNaira: amount,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: 'Withdraw',
      ),
      body: SafeArea(
        child: FutureBuilder<double>(
          future: _fetchBalance(),
          builder: (context, snap) {
            final balance = snap.data ?? 0.0;
            final hasData = snap.connectionState == ConnectionState.done;

            return Padding(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recipient card
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white12
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.account_balance_rounded,
                              color: AppColors.brand, size: 22),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.resolved.accountName,
                                style: AppTextStyles.titleSmall.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '${widget.resolved.accountNumber} · ${widget.resolved.bankName}',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Amount label
                  Text(
                    'AMOUNT',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),

                  // Big amount input
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        '₦',
                        style: AppTextStyles.displaySmall.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.brand,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[\d,.]')),
                          ],
                          onChanged: (_) => setState(() => _error = null),
                          autofocus: true,
                          style: AppTextStyles.displaySmall.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                          decoration: InputDecoration(
                            hintText: '0.00',
                            hintStyle: AppTextStyles.displaySmall.copyWith(
                              color: isDark ? Colors.white24 : Colors.black26,
                              fontWeight: FontWeight.w900,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 1),

                  // Balance info
                  const SizedBox(height: AppSpacing.sm),
                  if (hasData)
                    Row(
                      children: [
                        Text(
                          'Available balance: ',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        Text(
                          _formatNaira(balance),
                          style: AppTextStyles.bodySmall.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.brand,
                          ),
                        ),
                      ],
                    )
                  else
                    const SizedBox(
                        height: 4,
                        child: LinearProgressIndicator(color: AppColors.brand)),

                  // Quick amount chips
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: 8,
                    children: [500, 1000, 2000, 5000, 10000].map((amt) {
                      final enabled = hasData && amt <= balance;
                      return ActionChip(
                        label: Text('₦${amt >= 1000 ? '${amt ~/ 1000}k' : amt}'),
                        onPressed: enabled
                            ? () {
                                _controller.text = amt.toString();
                                setState(() => _error = null);
                              }
                            : null,
                        backgroundColor: enabled
                            ? AppColors.brand.withValues(alpha: 0.10)
                            : (isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                        labelStyle: AppTextStyles.bodySmall.copyWith(
                          color: enabled
                              ? AppColors.brand
                              : (isDark
                                  ? Colors.white38
                                  : Colors.black38),
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide(
                          color: enabled
                              ? AppColors.brand.withValues(alpha: 0.30)
                              : Colors.transparent,
                        ),
                      );
                    }).toList(),
                  ),

                  // Error
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _error!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Fee notice
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 16,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Funds are sent instantly. You will receive your money within 24 hours.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: 'Continue',
                    icon: Icons.lock_outline_rounded,
                    onPressed: hasData ? () => _onContinue(balance) : null,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
