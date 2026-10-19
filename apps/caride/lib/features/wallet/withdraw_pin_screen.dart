import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:caride/features/profile/security_pin_screen.dart';
import 'package:caride/features/wallet/data/withdraw_repository.dart';
import 'package:caride/features/wallet/withdraw_success_bottom_sheet.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

class WithdrawPinScreen extends StatefulWidget {
  const WithdrawPinScreen({
    super.key,
    required this.resolved,
    required this.amountNaira,
  });

  final ResolvedAccount resolved;
  final double amountNaira;

  @override
  State<WithdrawPinScreen> createState() => _WithdrawPinScreenState();
}

class _WithdrawPinScreenState extends State<WithdrawPinScreen> {
  final _repo = WithdrawRepository();
  String _pin = '';
  bool _loading = false;
  bool _checkingPin = true;
  String? _error;
  String? _debugDetails;

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  Future<void> _checkPinStatus() async {
    final hasPin = await _repo.hasPinSet();
    if (!mounted) return;
    if (!hasPin) {
      // Redirect to create PIN
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SecurityPinScreen(mode: SecurityPinMode.create),
        ),
      );
      // After creating PIN, re-check
      if (!mounted) return;
      final hasNow = await _repo.hasPinSet();
      if (!hasNow) {
        if (mounted) Navigator.of(context).pop(); // Still no PIN, go back
        return;
      }
    }
    setState(() => _checkingPin = false);
  }

  void _onKey(String digit) {
    if (_pin.length < 4 && !_loading) {
      setState(() {
        _pin += digit;
        _error = null;
        _debugDetails = null;
      });
      if (_pin.length == 4) {
        _onPinComplete();
      }
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty && !_loading) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  Future<void> _onPinComplete() async {
    final pin = _pin;
    await Future.delayed(const Duration(milliseconds: 150));
    setState(() => _loading = true);

    try {
      final reference = await _repo.processWithdrawal(
        accountNumber: widget.resolved.accountNumber,
        bankCode: widget.resolved.bankCode,
        bankName: widget.resolved.bankName,
        accountName: widget.resolved.accountName,
        amountNaira: widget.amountNaira,
        pin: pin,
      );

      if (!mounted) return;

      setState(() => _loading = false);

      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: Colors.transparent,
        isDismissible: false,
        enableDrag: false,
        builder: (sheetContext) => PopScope(
          canPop: false,
          child: WithdrawSuccessBottomSheet(
            resolved: widget.resolved,
            amountNaira: widget.amountNaira,
            reference: reference,
            onOkay: () {
              Navigator.of(sheetContext).pop();
            },
          ),
        ),
      );

      if (mounted) {
        try {
          context.go(CustomerRoutePaths.wallet);
        } catch (_) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      }
    } catch (e) {
      final readableError = parseWithdrawError(e);
      dynamic debugDetails;
      String? errorCode;

      if (e is WithdrawException) {
        debugDetails = e.details;
        errorCode = e.code;
      }

      // Print very prominent, structured TransactPay diagnostic block directly to the terminal console
      debugPrint('\n'
          '╔═══════════════════════════════════════════════════════════════════════════\n'
          '║ 🛑 [TERMINAL CONSOLE DEBUG] WITHDRAWAL ATTEMPT FAILED\n'
          '╠═══════════════════════════════════════════════════════════════════════════\n'
          '║ Target Account: ${widget.resolved.accountNumber} (${widget.resolved.bankName})\n'
          '║ Account Holder: ${widget.resolved.accountName}\n'
          '║ Amount: ₦${widget.amountNaira}\n'
          '║ User-Facing Message: $readableError\n'
          '║ Error Code: ${errorCode ?? 'None'}\n'
          '║ TransactPay API Response / Details: $debugDetails\n'
          '║ Raw Underlying Exception: $e\n'
          '╚═══════════════════════════════════════════════════════════════════════════\n');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              readableError,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      setState(() {
        _loading = false;
        _pin = '';
        _error = readableError;
        _debugDetails = debugDetails?.toString();
      });
    }
  }

  String _formatNaira(double value) {
    final rounded = value.round().toString();
    return '₦${rounded.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_checkingPin) {
      return const Scaffold(
        body: Center(child: AppLoader()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
        ),
        title: 'Confirm Withdrawal',
      ),
      body: SafeArea(
        child: _loading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const AppLoader(),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Processing withdrawal...',
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Please wait, do not close the app.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.md),

                    // Transaction summary card
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.pagePadding),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    const Color(0xFF0a3d22),
                                    const Color(0xFF16A34A),
                                  ]
                                : [
                                    const Color(0xFF0f5132),
                                    const Color(0xFF16A34A),
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.brand.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              'You are withdrawing',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatNaira(widget.amountNaira),
                              style: AppTextStyles.displaySmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Divider(color: Colors.white.withValues(alpha: 0.2)),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.account_balance_rounded,
                                    color: Colors.white70, size: 16),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '${widget.resolved.accountName} · ${widget.resolved.bankName}',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // PIN prompt
                    Text(
                      'Enter Security PIN',
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Authorize this withdrawal with your 4-digit PIN',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // PIN dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (i) {
                        final isFilled = i < _pin.length;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled ? AppColors.brand : Colors.transparent,
                            border: Border.all(
                              color: isFilled
                                  ? AppColors.brand
                                  : (isDark ? Colors.white38 : Colors.black26),
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),

                    // Error
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.pagePadding),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: AppColors.error, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_debugDetails != null && kDebugMode) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.pagePadding),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.bug_report_rounded, size: 14, color: Color(0xFFDC2626)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'TransactPay Debug Details (Console logged)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white70 : const Color(0xFF374151),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                SelectableText(
                                  _debugDetails!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],

                    const SizedBox(height: AppSpacing.md),

                    // Keypad
                    _buildKeypad(isDark),
                    const SizedBox(height: AppSpacing.sm),

                    // Forgot PIN
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SecurityPinScreen(
                                mode: SecurityPinMode.reset),
                          ),
                        );
                      },
                      child: Text(
                        'Forgot PIN?',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildKeypad(bool isDark) {
    Widget key(String label, {VoidCallback? onTap, Widget? child}) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap ?? () => _onKey(label),
          child: Container(
            margin: const EdgeInsets.all(6),
            height: 72,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark
                  ? null
                  : [
                      const BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
            ),
            child: Center(
              child: child ??
                  Text(
                    label,
                    style: AppTextStyles.headlineMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          Row(children: [key('1'), key('2'), key('3')]),
          Row(children: [key('4'), key('5'), key('6')]),
          Row(children: [key('7'), key('8'), key('9')]),
          Row(
            children: [
              const Expanded(child: SizedBox()),
              key('0'),
              key('', onTap: _onDelete,
                  child: const Icon(Icons.backspace_outlined, size: 22)),
            ],
          ),
        ],
      ),
    );
  }
}
