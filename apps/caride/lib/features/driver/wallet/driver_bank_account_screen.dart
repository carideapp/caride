import 'package:design_system/design_system.dart';
import 'package:caride/features/driver/wallet/data/driver_bank_account_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Add Bank Account screen with OPay-style smart bank detection.
/// Types 10-digit account number → detected bank chips appear → tap to verify → save.
class DriverBankAccountScreen extends StatefulWidget {
  const DriverBankAccountScreen({super.key});

  @override
  State<DriverBankAccountScreen> createState() =>
      _DriverBankAccountScreenState();
}

class _DriverBankAccountScreenState extends State<DriverBankAccountScreen> {
  final _repo = DriverBankAccountRepository();
  final _accountNumberController = TextEditingController();

  List<BankOption> _banks = const <BankOption>[];
  bool _isLoadingBanks = true;

  // Smart detection state
  List<BankOption> _detectedBanks = [];
  String? _verifyingBankCode;
  final Set<String> _failedBankCodes = {};

  // After successful resolve we track both the preview and which bank matched
  VerifiedBankAccountPreview? _verifiedPreview;
  BankOption? _resolvedBank;

  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadBanks();
    _accountNumberController.addListener(_onAccountChanged);
  }

  @override
  void dispose() {
    _accountNumberController.removeListener(_onAccountChanged);
    _accountNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadBanks() async {
    try {
      final banks = await _repo.fetchBanks();
      if (!mounted) return;
      setState(() {
        _banks = banks;
        _isLoadingBanks = false;
      });
      // Re-run detection if already typed
      final current = _accountNumberController.text.trim();
      if (current.length == 10) _updateChips();
    } catch (_) {
      if (mounted) setState(() => _isLoadingBanks = false);
    }
  }

  void _onAccountChanged() {
    final number = _accountNumberController.text.trim();
    setState(() {
      _verifiedPreview = null;
      _resolvedBank = null;
      _errorText = null;
      _failedBankCodes.clear();
      _verifyingBankCode = null;
    });
    if (number.length == 10) {
      _updateChips();
    } else {
      setState(() => _detectedBanks = []);
    }
  }

  /// Surfaces the most-used Nigerian banks as quick-tap chips.
  /// Account numbers in Nigeria do NOT reliably start with the bank sort
  /// code (especially OPay, Kuda, PalmPay, Fidelity, Moniepoint), so
  /// prefix matching fails in practice. We instead show a curated
  /// popularity list — the same approach used by OPay.
  void _updateChips() {
    if (_banks.isEmpty) {
      setState(() => _detectedBanks = []);
      return;
    }

    // Ordered by how common they are among Nigerian users.
    const popularPatterns = [
      'opay',
      'kuda',
      'palmpay',
      'moniepoint',
      'gtbank', 'guaranty trust',
      'access bank',
      'zenith',
      'first bank',
      'uba', 'united bank',
      'fidelity',
      'sterling',
      'wema',
      'union bank',
      'stanbic',
      'polaris',
      'fcmb',
      'ecobank',
      'providus',
    ];

    final seen = <String>{};
    final chips = <BankOption>[];

    for (final pattern in popularPatterns) {
      for (final bank in _banks) {
        if (seen.contains(bank.code)) continue;
        if (bank.name.toLowerCase().contains(pattern)) {
          seen.add(bank.code);
          chips.add(bank);
          break;
        }
      }
      if (chips.length >= 8) break;
    }

    setState(() => _detectedBanks = chips);
  }

  Future<void> _verifyWithBank(BankOption bank) async {
    if (_verifyingBankCode != null) return;
    final accountNumber = _accountNumberController.text.trim();
    setState(() {
      _verifyingBankCode = bank.code;
      _errorText = null;
      _verifiedPreview = null;
      _resolvedBank = null;
    });
    try {
      final preview = await _repo.resolveAccount(
        bankCode: bank.code,
        accountNumber: accountNumber,
      );
      if (!mounted) return;
      setState(() {
        _verifiedPreview = preview;
        _resolvedBank = bank;
        _verifyingBankCode = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failedBankCodes.add(bank.code);
        _verifyingBankCode = null;
        _errorText =
            'No account found at ${bank.name}. Try another bank or select manually.';
      });
    }
  }

  Future<void> _showManualBankPicker() async {
    if (_verifyingBankCode != null) return;
    final bank = await showModalBottomSheet<BankOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _BankPickerSheet(banks: _banks),
    );
    if (bank == null || !mounted) return;
    await _verifyWithBank(bank);
  }

  Future<void> _saveAccount() async {
    if (_resolvedBank == null || _verifiedPreview == null) return;
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      await _repo.saveVerifiedAccount(
        bankCode: _resolvedBank!.code,
        bankName: _resolvedBank!.name,
        accountNumber: _accountNumberController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bank account saved successfully.')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Unable to save this bank account right now. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typed = _accountNumberController.text.trim();
    final isComplete = typed.length == 10;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: 'Add Bank Account',
      ),
      body: SafeArea(
        child: _isLoadingBanks
            ? const Center(child: AppLoader())
            : ResponsiveContainer(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.pagePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Info banner ──────────────────────────────────
                      GlassContainer(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.account_balance_outlined,
                              color: AppColors.brand,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Verify your payout account securely with Paystack before it is saved for wallet withdrawals.',
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
                      const SizedBox(height: AppSpacing.xl),

                      // ── Account number label ─────────────────────────
                      Text(
                        'ACCOUNT NUMBER',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),

                      // ── Account number field ─────────────────────────
                      TextField(
                        controller: _accountNumberController,
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '0123456789',
                          hintStyle: AppTextStyles.titleLarge.copyWith(
                            color: isDark ? Colors.white24 : Colors.black26,
                            letterSpacing: 2,
                          ),
                          filled: true,
                          fillColor:
                              isDark ? AppColors.darkSurfaceRaised : Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.glassBorderDark
                                  : AppColors.glassBorderLight,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.glassBorderDark
                                  : AppColors.glassBorderLight,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: AppColors.brand,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                          suffixIcon: isComplete
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppColors.brand)
                              : null,
                        ),
                      ),

                      // ── Smart detection area ─────────────────────────
                      if (isComplete && _verifiedPreview == null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        if (_detectedBanks.isNotEmpty) ...[
                          Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome_rounded,
                                size: 13,
                                color: AppColors.brand,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Tap your bank to verify',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.brand,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Wrap(
                            spacing: AppSpacing.sm,
                            runSpacing: AppSpacing.sm,
                            children: _detectedBanks.map((bank) {
                              return _BankChip(
                                bank: bank,
                                isVerifying: _verifyingBankCode == bank.code,
                                hasFailed:
                                    _failedBankCodes.contains(bank.code),
                                onTap: _verifyingBankCode != null
                                    ? null
                                    : () => _verifyWithBank(bank),
                                isDark: isDark,
                              );
                            }).toList(),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xs),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _verifyingBankCode != null
                                ? null
                                : _showManualBankPicker,
                            icon: Icon(
                              Icons.account_balance_outlined,
                              size: 15,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                            label: Text(
                              _detectedBanks.isEmpty
                                  ? 'Bank not detected — select manually'
                                  : 'Use a different bank',
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                              padding: EdgeInsets.zero,
                              textStyle: AppTextStyles.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],

                      // ── Error ──────────────────────────────────────
                      if (_errorText != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.25)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  color: AppColors.error, size: 18),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _errorText!,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ── Verified preview card ──────────────────────
                      if (_verifiedPreview != null && _resolvedBank != null) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _VerifiedAccountCard(
                          preview: _verifiedPreview!,
                          bankName: _resolvedBank!.name,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => setState(() {
                              _verifiedPreview = null;
                              _resolvedBank = null;
                              _failedBankCodes.clear();
                              _errorText = null;
                            }),
                            style: TextButton.styleFrom(
                              foregroundColor: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                              padding: EdgeInsets.zero,
                            ),
                            child: Text(
                              'Wrong account? Try another bank',
                              style: AppTextStyles.bodySmall
                                  .copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.xl),

                      // ── Save button ────────────────────────────────
                      PrimaryButton(
                        label: 'Save Bank Account',
                        isLoading: _isSaving,
                        onPressed:
                            _verifiedPreview == null ? null : _saveAccount,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

// ── Bank Chip ─────────────────────────────────────────────────────────────────

class _BankChip extends StatelessWidget {
  const _BankChip({
    required this.bank,
    required this.isVerifying,
    required this.hasFailed,
    required this.onTap,
    required this.isDark,
  });

  final BankOption bank;
  final bool isVerifying;
  final bool hasFailed;
  final VoidCallback? onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final Color borderColor;
    final Color bgColor;
    final Color textColor;

    if (hasFailed) {
      borderColor = AppColors.error.withValues(alpha: 0.35);
      bgColor = AppColors.error.withValues(alpha: 0.06);
      textColor = AppColors.error;
    } else if (isVerifying) {
      borderColor = AppColors.brand.withValues(alpha: 0.6);
      bgColor = AppColors.brand.withValues(alpha: 0.10);
      textColor = AppColors.brand;
    } else {
      borderColor = isDark ? Colors.white24 : const Color(0xFFD1D5DB);
      bgColor = isDark ? AppColors.darkSurfaceRaised : Colors.white;
      textColor = isDark ? Colors.white : const Color(0xFF111827);
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isVerifying)
              const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppColors.brand),
                ),
              )
            else if (hasFailed)
              const Icon(Icons.close_rounded, size: 13, color: AppColors.error)
            else
              Icon(Icons.account_balance_rounded, size: 13, color: textColor),
            const SizedBox(width: 6),
            Text(
              bank.name,
              style: AppTextStyles.bodySmall.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Searchable Bank Picker Bottom Sheet ───────────────────────────────────────

class _BankPickerSheet extends StatefulWidget {
  const _BankPickerSheet({required this.banks});
  final List<BankOption> banks;

  @override
  State<_BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<_BankPickerSheet> {
  final _searchController = TextEditingController();
  late List<BankOption> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.banks;
    _searchController.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.banks
          : widget.banks
              .where((b) =>
                  b.name.toLowerCase().contains(q) || b.code.contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle bar
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePadding),
            child: Text(
              'Select Bank',
              style: AppTextStyles.titleLarge
                  .copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePadding),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search banks…',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: isDark
                    ? AppColors.darkSurfaceRaised
                    : const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Bank list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePadding, vertical: 4),
              itemCount: _filtered.length,
              itemBuilder: (ctx, i) {
                final bank = _filtered[i];
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.account_balance_rounded,
                          size: 18, color: AppColors.brand),
                    ),
                    title: Text(
                      bank.name,
                      style: AppTextStyles.bodyMedium
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      bank.code,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    onTap: () => Navigator.of(ctx).pop(bank),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Verified Account Card ─────────────────────────────────────────────────────

class _VerifiedAccountCard extends StatelessWidget {
  const _VerifiedAccountCard({
    required this.preview,
    required this.bankName,
  });

  final VerifiedBankAccountPreview preview;
  final String bankName;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brand.withValues(alpha: 0.12),
            AppColors.brand.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.brand.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: AppColors.brand, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preview.accountName,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${preview.accountNumber} · $bankName',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.brand.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
