import 'package:caride/features/profile/data/account_repository.dart';
import 'package:caride/features/profile/data/referral_repository.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Production-ready Customer Referral Screen featuring Neumorphism/Glassmorphic design,
/// branded deep link sharing, live analytics cards, copy tools, and custom code editing.
class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final _repo = ReferralRepository();
  final _accountRepo = AccountRepository();
  late Stream<ReferralRecord?> _referralStream;

  final _applyCodeController = TextEditingController();
  bool _isApplyingCode = false;
  String? _applyCodeError;
  double _promoCreditAmount = 1000.0;

  @override
  void initState() {
    super.initState();
    _initData();
    _loadConfig();
  }

  void _initData() {
    _repo.ensureReferralCode();
    _referralStream = _repo.watchReferralData();
  }

  Future<void> _loadConfig() async {
    final cfg = await _accountRepo.fetchReferralCreditConfig();
    if (mounted) {
      setState(() {
        _promoCreditAmount =
            (cfg['creditAmount'] as num?)?.toDouble() ?? 1000.0;
      });
    }
  }

  Future<void> _applyReferralCode() async {
    final code = _applyCodeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      setState(() {
        _applyCodeError = 'Please enter a referral code.';
      });
      return;
    }

    if (code.length < 3 ||
        code.length > 25 ||
        !RegExp(r'^[A-Z0-9_\-]+$').hasMatch(code)) {
      setState(() {
        _applyCodeError = 'Referral code must be 3-25 characters long.';
      });
      return;
    }

    // Client-side check for self-referral
    try {
      final myCode = await _repo.ensureReferralCode();
      if (myCode.trim().toUpperCase() == code) {
        setState(() {
          _applyCodeError = 'You cannot use your own referral code.';
        });
        return;
      }
    } catch (_) {}

    setState(() {
      _isApplyingCode = true;
      _applyCodeError = null;
    });

    try {
      final msg = await _accountRepo.applyReferralCode(code);
      if (!mounted) return;
      _applyCodeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      String userFriendlyMessage =
          'Failed to apply referral code. Please try again.';
      final errStr = e.toString().toLowerCase();

      if (e is FirebaseFunctionsException) {
        switch (e.code) {
          case 'not-found':
            userFriendlyMessage =
                'The referral code entered does not exist. Please check and try again.';
            break;
          case 'invalid-argument':
            if (e.message?.toLowerCase().contains('own') ?? false) {
              userFriendlyMessage = 'You cannot use your own referral code.';
            } else if (e.message?.toLowerCase().contains('not found') ??
                false) {
              userFriendlyMessage =
                  'The referral code entered does not exist. Please check and try again.';
            } else {
              userFriendlyMessage =
                  e.message ?? 'Invalid referral code entered.';
            }
            break;
          case 'already-exists':
          case 'failed-precondition':
            userFriendlyMessage = 'You have already applied a referral code.';
            break;
          case 'unavailable':
          case 'deadline-exceeded':
            userFriendlyMessage =
                'Network error. Please check your internet connection and try again.';
            break;
          default:
            userFriendlyMessage = e.message ?? 'Failed to apply referral code.';
        }
      } else if (errStr.contains('not found') || errStr.contains('not exist')) {
        userFriendlyMessage =
            'The referral code entered does not exist. Please check and try again.';
      } else if (errStr.contains('own code') || errStr.contains('self')) {
        userFriendlyMessage = 'You cannot use your own referral code.';
      } else if (errStr.contains('already applied') ||
          errStr.contains('already claimed')) {
        userFriendlyMessage = 'You have already applied a referral code.';
      } else if (errStr.contains('network') ||
          errStr.contains('socketexception') ||
          errStr.contains('connection')) {
        userFriendlyMessage =
            'Network error. Please check your internet connection and try again.';
      } else {
        userFriendlyMessage = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll(RegExp(r'\[.*?\]'), '')
            .trim();
      }

      setState(() {
        _applyCodeError = userFriendlyMessage;
      });
    } finally {
      if (mounted) setState(() => _isApplyingCode = false);
    }
  }

  @override
  void dispose() {
    _applyCodeController.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    setState(() {
      _initData();
    });
    await Future.delayed(const Duration(milliseconds: 600));
  }

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFE9EAF0);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: 8,
              ),
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
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Referral Program',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: AppColors.brand,
                backgroundColor: surfaceColor,
                child: StreamBuilder<ReferralRecord?>(
                  stream: _referralStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        snapshot.data == null) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.brand,
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: AppColors.error,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                'Unable to load referral data',
                                style: AppTextStyles.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              ElevatedButton(
                                onPressed: _onRefresh,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final record = snapshot.data;
                    final code = record?.referralCode ?? '';
                    final link =
                        record?.referralLink ?? 'https://www.caride.ng/app';
                    final earnings = record?.referralEarnings ?? 0.0;
                    final successfulCount =
                        record?.successfulReferralsCount ?? 0;
                    final referred = record?.referredUsers ?? [];

                    final formattedEarnings =
                        '₦${earnings.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

                    final percent = record?.referralPercent ?? 2.0;
                    final percentText = percent % 1 == 0
                        ? percent.toInt().toString()
                        : percent.toStringAsFixed(1);

                    return SafeArea(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppSpacing.pagePadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Hero Referral Banner Card ─────────────────────
                            Container(
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.lg,
                                ),
                                border: Border.all(color: borderColor),
                                boxShadow: isDark
                                    ? null
                                    : [
                                        const BoxShadow(
                                          color: Color(0x0F0F172A),
                                          blurRadius: 18,
                                          offset: Offset(0, 8),
                                        ),
                                      ],
                              ),
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Lottie.asset(
                                    'lib/assets/lottie/Refer_&_Earn.lottie',
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.contain,
                                    decoder: (bytes) {
                                      return LottieComposition.decodeZip(
                                        bytes,
                                        filePicker: (files) {
                                          return files.firstWhere(
                                            (f) =>
                                                f.name.startsWith(
                                                  'animations/',
                                                ) &&
                                                f.name.endsWith('.json'),
                                          );
                                        },
                                      );
                                    },
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Refer & Earn',
                                          style: theme.textTheme.headlineSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: isDark
                                                    ? Colors.white
                                                    : AppColors.slate900,
                                              ),
                                        ),
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          "Earn $percentText% of company's commission on every trip completed by riders you refer to CaRide.",
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                color: isDark
                                                    ? Colors.grey[300]
                                                    : const Color(0xFF4A4D70),
                                                height: 1.4,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            // ── 2 Summary Stat Cards ─────────────────────────
                            Row(
                              children: [
                                Expanded(
                                  child: _StatSummaryCard(
                                    title: 'Earnings',
                                    value: formattedEarnings,
                                    icon: Icons.account_balance_wallet_rounded,
                                    iconColor: AppColors.brand,
                                    isDark: isDark,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: _StatSummaryCard(
                                    title: 'Successful',
                                    value: '$successfulCount',
                                    icon: Icons.check_circle_rounded,
                                    iconColor: const Color(0xFF10B981),
                                    isDark: isDark,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            // ── Referral Code & Link Details Card ─────────────
                            GlassContainer(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'YOUR REFERRAL CODE',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                  if (code.isEmpty)
                                    const SizedBox(
                                      height: 4,
                                      child: LinearProgressIndicator(
                                        backgroundColor: Colors.white24,
                                        color: AppColors.brand,
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.sm,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF2C2C2C)
                                            : const Color(0xFFF8F9FC),
                                        borderRadius: BorderRadius.circular(
                                          AppRadius.md,
                                        ),
                                        border: Border.all(
                                          color: AppColors.brand.withValues(
                                            alpha: 0.25,
                                          ),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            code,
                                            style: AppTextStyles.titleMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 3.0,
                                                  color: isDark
                                                      ? Colors.white
                                                      : AppColors.slate900,
                                                ),
                                          ),
                                          const Spacer(),
                                          // Edit custom code button
                                          GestureDetector(
                                            onTap: () =>
                                                _showEditCodeBottomSheet(
                                                  context,
                                                  code,
                                                ),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              margin: const EdgeInsets.only(
                                                right: AppSpacing.xs,
                                              ),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? Colors.white10
                                                    : const Color(0xFFE2E8F0),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.edit_rounded,
                                                size: 16,
                                                color: isDark
                                                    ? Colors.white70
                                                    : AppColors.slate900,
                                              ),
                                            ),
                                          ),
                                          // Copy code button
                                          GestureDetector(
                                            onTap: () {
                                              Clipboard.setData(
                                                ClipboardData(text: code),
                                              );
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Referral code copied!',
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: AppColors.brand
                                                    .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.copy_rounded,
                                                size: 16,
                                                color: AppColors.brand,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: AppSpacing.lg),
                                  SizedBox(
                                    width: double.infinity,
                                    child: PrimaryButton(
                                      label: 'Share my Referral Link',
                                      onPressed: () {
                                        Clipboard.setData(
                                          ClipboardData(text: link),
                                        );
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Your referral link has been copied!',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),

                            // ── Apply Referral Code Card ───────────────────────
                            GlassContainer(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              child: StreamBuilder<AccountProfile?>(
                                stream: _accountRepo.watchProfile(),
                                builder: (context, profileSnap) {
                                  final profile = profileSnap.data;
                                  final referredByCode =
                                      profile?.referredByCode;
                                  final creditBalance =
                                      profile?.creditBalance ?? 0.0;
                                  final formattedCredit =
                                      '₦${creditBalance.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.stars_rounded,
                                            color: AppColors.brand,
                                            size: 22,
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
                                          Text(
                                            'CaRide Subsidy Wallet',
                                            style: AppTextStyles.labelSmall
                                                .copyWith(
                                                  color: isDark
                                                      ? AppColors
                                                            .textSecondaryDark
                                                      : AppColors
                                                            .textSecondaryLight,
                                                  fontWeight: FontWeight.w700,
                                                  letterSpacing: 1.5,
                                                ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        formattedCredit,
                                        style: AppTextStyles.displaySmall
                                            .copyWith(
                                              fontSize: 32,
                                              fontWeight: FontWeight.w900,
                                              color: const Color(0xFF10B981),
                                              letterSpacing: -0.5,
                                            ),
                                      ),
                                      const SizedBox(height: AppSpacing.xs),
                                      Text(
                                        'Share your referral code or apply a referral code to get ₦${_promoCreditAmount.toStringAsFixed(0)} credit in your Subsidy Wallet.',
                                        style: AppTextStyles.bodyMedium
                                            .copyWith(
                                              color: isDark
                                                  ? Colors.grey[300]
                                                  : const Color(0xFF4A4D70),
                                              height: 1.4,
                                            ),
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      if (referredByCode != null &&
                                          referredByCode.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFF10B981,
                                            ).withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.md,
                                            ),
                                            border: Border.all(
                                              color: const Color(
                                                0xFF10B981,
                                              ).withValues(alpha: 0.3),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.check_circle_rounded,
                                                color: Color(0xFF10B981),
                                                size: 18,
                                              ),
                                              const SizedBox(
                                                width: AppSpacing.xs,
                                              ),
                                              Expanded(
                                                child: Text(
                                                  'Referral Code Applied: $referredByCode',
                                                  style: AppTextStyles
                                                      .bodyMedium
                                                      .copyWith(
                                                        color: const Color(
                                                          0xFF10B981,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else ...[
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            Expanded(
                                              child: AppTextField(
                                                controller:
                                                    _applyCodeController,
                                                hint: 'Enter referral code',
                                                prefixIcon:
                                                    Icons.card_giftcard_rounded,
                                              ),
                                            ),
                                            const SizedBox(
                                              width: AppSpacing.sm,
                                            ),
                                            PrimaryButton(
                                              label: _isApplyingCode
                                                  ? 'Applying...'
                                                  : 'Apply',
                                              isLoading: _isApplyingCode,
                                              fullWidth: false,
                                              onPressed: _isApplyingCode
                                                  ? null
                                                  : _applyReferralCode,
                                            ),
                                          ],
                                        ),
                                        if (_applyCodeError != null) ...[
                                          const SizedBox(height: 6),
                                          Text(
                                            _applyCodeError!,
                                            style: const TextStyle(
                                              color: AppColors.error,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),

                            // ── Referrals List Title ───────────────────────────
                            Text(
                              'MY REFERRALS',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            if (referred.isEmpty)
                              EmptyState(
                                title: 'No Referrals Yet',
                                message:
                                    'Share your referral link to invite friends and earn bonuses.',
                                icon: Icons.people_alt_outlined,
                                iconWidget: Image.asset(
                                  'lib/assets/icons/tag.png',
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.contain,
                                ),
                              )
                            else
                              Column(
                                children: referred.map((u) {
                                  final isCompleted = u.status == 'completed';
                                  return Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: AppSpacing.sm,
                                    ),
                                    child: GlassContainer(
                                      padding: const EdgeInsets.all(
                                        AppSpacing.md,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: isDark
                                                  ? AppColors.darkSurfaceVariant
                                                  : const Color(0xFFF1F5F9),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.person_rounded,
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.md),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  u.email,
                                                  style:
                                                      AppTextStyles.titleSmall,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  'Joined ${_formatDate(u.joinedAt)}',
                                                  style: AppTextStyles.bodySmall
                                                      .copyWith(
                                                        color: isDark
                                                            ? AppColors
                                                                  .textSecondaryDark
                                                            : AppColors
                                                                  .textSecondaryLight,
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.xs),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isCompleted
                                                  ? const Color(
                                                      0xFF10B981,
                                                    ).withValues(alpha: 0.15)
                                                  : const Color(
                                                      0xFFF59E0B,
                                                    ).withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              isCompleted
                                                  ? 'Completed'
                                                  : 'Pending',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isCompleted
                                                    ? const Color(0xFF10B981)
                                                    : const Color(0xFFF59E0B),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: AppSpacing.xl),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCodeBottomSheet(BuildContext context, String currentCode) {
    final controller = TextEditingController(text: currentCode);
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    String? errorMessage;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: GlassSurface(
                radius: AppRadius.lg,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white30 : Colors.black26,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        'Customize Referral Code',
                        style: AppTextStyles.headlineSmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Enter a custom code (3-12 alphanumeric characters).',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppTextField(
                        controller: controller,
                        hint: 'e.g. CARIDE2026',
                        textCapitalization: TextCapitalization.characters,
                        prefixIcon: Icons.edit_note_rounded,
                      ),
                      if (errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          errorMessage!,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: isLoading
                                  ? null
                                  : () => Navigator.pop(sheetContext),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: PrimaryButton(
                              label: isLoading ? 'Saving...' : 'Save',
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      final newCode = controller.text.trim();
                                      if (newCode.length < 3 ||
                                          newCode.length > 12) {
                                        setSheetState(() {
                                          errorMessage =
                                              'Code must be 3-12 characters long.';
                                        });
                                        return;
                                      }
                                      if (!RegExp(
                                        r'^[a-zA-Z0-9]+$',
                                      ).hasMatch(newCode)) {
                                        setSheetState(() {
                                          errorMessage =
                                              'Only letters and numbers are allowed.';
                                        });
                                        return;
                                      }

                                      setSheetState(() {
                                        isLoading = true;
                                        errorMessage = null;
                                      });

                                      try {
                                        await _repo.updateCustomReferralCode(
                                          newCode,
                                        );
                                        if (sheetContext.mounted) {
                                          Navigator.pop(sheetContext);
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Referral code updated successfully!',
                                              ),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setSheetState(() {
                                          isLoading = false;
                                          errorMessage = e
                                              .toString()
                                              .replaceAll('Exception: ', '');
                                        });
                                      }
                                    },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatSummaryCard extends StatelessWidget {
  const _StatSummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.isDark,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color iconColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.slate900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
