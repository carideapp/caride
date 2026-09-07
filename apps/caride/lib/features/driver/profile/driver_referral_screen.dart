import 'package:caride/core/services/deep_link_service.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_widgets/shared_widgets.dart';

import 'data/driver_referral_repository.dart';

class DriverReferralScreen extends StatefulWidget {
  const DriverReferralScreen({super.key});

  @override
  State<DriverReferralScreen> createState() => _DriverReferralScreenState();
}

class _DriverReferralScreenState extends State<DriverReferralScreen> {
  final _repo = DriverReferralRepository();
  late final Stream<DriverReferralRecord?> _referralStream;
  int _selectedTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _repo.ensureReferralCode();
    _referralStream = _repo.watchReferralData();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Refer & Earn',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<DriverReferralRecord?>(
          stream: _referralStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _ReferralSkeletonLoader();
            }

            final record = snapshot.data;
            final code = record?.referralCode ?? '';
            final earnings = record?.referralEarnings ?? 0.0;
            final referredCount = record?.referredDrivers.length ?? 0;
            final history = record?.earningHistory ?? [];

            return ResponsiveContainer(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeroSection(
                      context,
                      isDark,
                      surfaceColor,
                      borderColor,
                      referralPercent: record?.referralPercent ?? 2.0,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildStatsSummary(context, earnings, referredCount, isDark, surfaceColor, borderColor),
                    const SizedBox(height: AppSpacing.lg),
                    _buildReferralCodeCard(context, code, isDark, surfaceColor, borderColor),
                    const SizedBox(height: AppSpacing.lg),
                    _buildTabSelector(
                      context,
                      referredCount,
                      history.length,
                      isDark,
                      surfaceColor,
                      borderColor,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _selectedTabIndex == 0
                          ? KeyedSubtree(
                              key: const ValueKey('referred_users_tab'),
                              child: _buildReferralHistoryList(
                                context,
                                record?.referredDrivers ?? [],
                                isDark,
                                surfaceColor,
                                borderColor,
                              ),
                            )
                          : KeyedSubtree(
                              key: const ValueKey('earnings_history_tab'),
                              child: _buildEarningsHistoryList(
                                context,
                                history,
                                isDark,
                                surfaceColor,
                                borderColor,
                              ),
                            ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroSection(
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color borderColor, {
    double referralPercent = 2.0,
  }) {
    final theme = Theme.of(context);
    final percentText = referralPercent % 1 == 0
        ? referralPercent.toInt().toString()
        : referralPercent.toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
            width: 110,
            height: 110,
            fit: BoxFit.contain,
            decoder: (bytes) {
              return LottieComposition.decodeZip(
                bytes,
                filePicker: (files) {
                  return files.firstWhere(
                    (f) =>
                        f.name.startsWith('animations/') &&
                        f.name.endsWith('.json'),
                  );
                },
              );
            },
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Refer a Driver',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "Earn $percentText% of company's commission on every trip completed by drivers you refer to CaRide.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[300] : const Color(0xFF4A4D70),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showEditCodeBottomSheet(BuildContext context, String currentCode) {
    final controller = TextEditingController(text: currentCode);
    String? errorMessage;
    bool isLoading = false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: GlassSurface(
                radius: AppRadius.xl,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Edit Referral Code',
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Customize your referral code. Case-insensitive and supports letters and numbers.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppTextField(
                      controller: controller,
                      hint: 'Enter custom referral code',
                      obscureText: false,
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        errorMessage!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'Cancel',
                            onPressed: isLoading ? null : () => Navigator.pop(sheetContext),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: PrimaryButton(
                            label: isLoading ? 'Saving...' : 'Save',
                            isLoading: isLoading,
                            onPressed: isLoading
                                ? null
                                : () async {
                                    final newCode = controller.text.trim();
                                    if (newCode.length < 3 || newCode.length > 12) {
                                      setSheetState(() {
                                        errorMessage = 'Code must be 3-12 characters long.';
                                      });
                                      return;
                                    }
                                    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(newCode)) {
                                      setSheetState(() {
                                        errorMessage = 'Only letters and numbers are allowed.';
                                      });
                                      return;
                                    }

                                    setSheetState(() {
                                      isLoading = true;
                                      errorMessage = null;
                                    });

                                    try {
                                      await _repo.updateCustomReferralCode(newCode);
                                      if (sheetContext.mounted) {
                                        Navigator.pop(sheetContext);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Referral code updated successfully!'),
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      setSheetState(() {
                                        isLoading = false;
                                        errorMessage = e.toString().replaceAll('Exception: ', '');
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
            );
          },
        );
      },
    );
  }

  Widget _buildReferralCodeCard(
    BuildContext context,
    String code,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
  ) {
    final theme = Theme.of(context);
    final hasCode = code.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Your Referral Code',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.slate900,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!hasCode)
            const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: AppColors.primaryGreen.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    code,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      color: isDark ? Colors.white : AppColors.slate900,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.primaryGreen),
                        tooltip: 'Edit Referral Code',
                        onPressed: () => _showEditCodeBottomSheet(context, code),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18, color: AppColors.primaryGreen),
                        tooltip: 'Copy Referral Code',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Referral code copied!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Share my Referral Link',
              onPressed: () {
                final link = DeepLinkService.instance.generateReferralLink(code);
                Clipboard.setData(ClipboardData(text: link));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Your referral has been copied!'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatsSummary(
    BuildContext context,
    double earnings,
    int referredCount,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Row(
      children: [
        _buildStatCard(
          context,
          NgnFormat.whole(earnings),
          'Total Balance',
          Icons.account_balance_wallet_outlined,
          isDark,
          surfaceColor,
          borderColor,
        ),
        const SizedBox(width: AppSpacing.sm),
        _buildStatCard(
          context,
          '$referredCount',
          'People Referred',
          Icons.people_outline_rounded,
          isDark,
          surfaceColor,
          borderColor,
        ),
      ],
    );
  }

  Widget _buildTabSelector(
    BuildContext context,
    int referredCount,
    int earningsCount,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF262626) : const Color(0xFFF1F3F9),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildTabPill(
              context,
              index: 0,
              label: 'Referred Users',
              count: referredCount,
              icon: Icons.people_alt_rounded,
              isSelected: _selectedTabIndex == 0,
              isDark: isDark,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildTabPill(
              context,
              index: 1,
              label: 'Earnings History',
              count: earningsCount,
              icon: Icons.history_edu_rounded,
              isSelected: _selectedTabIndex == 1,
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabPill(
    BuildContext context, {
    required int index,
    required String label,
    required int count,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
  }) {
    const activeColor = AppColors.primaryGreen;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: isSelected && !isDark
              ? [
                  const BoxShadow(
                    color: Color(0x0C0F172A),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? activeColor
                  : (isDark ? Colors.grey[400] : const Color(0xFF6E7191)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : AppColors.slate900)
                    : (isDark ? Colors.grey[400] : const Color(0xFF6E7191)),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.15)
                      : (isDark ? Colors.grey[800] : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? activeColor
                        : (isDark ? Colors.grey[300] : const Color(0xFF4A4D70)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsHistoryList(
    BuildContext context,
    List<ReferralEarningEntry> history,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
  ) {
    if (history.isEmpty) {
      return _buildEmptyHistory(context, isDark, surfaceColor, borderColor);
    }

    return Container(
      decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(AppRadius.lg),
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
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            children: List.generate(history.length, (index) {
              final entry = history[index];
              return _buildHistoryItem(context, entry, isDark);
            }),
          ),
        );
  }

  Widget _buildReferralHistoryList(
    BuildContext context,
    List<ReferredDriver> referredList,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (referredList.isEmpty)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Icon(
                  Icons.person_add_disabled_outlined,
                  size: 48,
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No referrals recorded yet',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isDark ? Colors.white : AppColors.slate900,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Share your referral link with riders and drivers to earn bonuses.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(AppRadius.lg),
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
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: List.generate(referredList.length, (index) {
                final ref = referredList[index];
                return _buildReferredUserItem(context, ref, isDark);
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildReferredUserItem(
    BuildContext context,
    ReferredDriver item,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final isDriver = item.userType.toLowerCase() == 'driver';
    final roleColor = isDriver ? AppColors.brand : const Color(0xFF10B981);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: roleColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDriver ? Icons.drive_eta_rounded : Icons.person_rounded,
              color: roleColor,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.email.isNotEmpty ? item.email : 'User ${item.driverUid.substring(0, 6)}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: roleColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.userType,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: roleColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatDate(item.joinedAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[500] : const Color(0xFF8A90A6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Completed',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF10B981),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String value,
    String label,
    IconData icon,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
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
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryGreen, size: 20),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.slate900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistory(
    BuildContext context,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
  ) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Icon(
            Icons.people_alt_outlined,
            size: 56,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No referral earnings yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: isDark ? Colors.white : AppColors.slate900,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Share your code and start earning when your referred drivers complete trips.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(
    BuildContext context,
    ReferralEarningEntry entry,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.trending_up_rounded,
              color: AppColors.primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Referral Earning',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.description.isNotEmpty
                      ? entry.description
                      : 'Trip by referred driver',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+${NgnFormat.whole(entry.amountNaira)}',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDate(entry.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[500] : const Color(0xFF8A90A6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReferralSkeletonLoader extends StatefulWidget {
  const _ReferralSkeletonLoader();

  @override
  State<_ReferralSkeletonLoader> createState() => _ReferralSkeletonLoaderState();
}

class _ReferralSkeletonLoaderState extends State<_ReferralSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseShimmerColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            children: [
              // Hero Section Skeleton
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE9EAF0),
                  ),
                ),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: baseShimmerColor,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(width: 120, height: 16, color: baseShimmerColor),
                          const SizedBox(height: 12),
                          Container(width: double.infinity, height: 12, color: baseShimmerColor),
                          const SizedBox(height: 6),
                          Container(width: 160, height: 12, color: baseShimmerColor),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Stats Row Skeleton
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 110,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: isDark ? Colors.white10 : const Color(0xFFE9EAF0),
                        ),
                      ),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(radius: 16, backgroundColor: baseShimmerColor),
                          const SizedBox(height: 12),
                          Container(width: 80, height: 20, color: baseShimmerColor),
                          const SizedBox(height: 6),
                          Container(width: 60, height: 12, color: baseShimmerColor),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Container(
                      height: 110,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(
                          color: isDark ? Colors.white10 : const Color(0xFFE9EAF0),
                        ),
                      ),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(radius: 16, backgroundColor: baseShimmerColor),
                          const SizedBox(height: 12),
                          Container(width: 40, height: 20, color: baseShimmerColor),
                          const SizedBox(height: 6),
                          Container(width: 90, height: 12, color: baseShimmerColor),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Referral Code Section Skeleton
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE9EAF0),
                  ),
                ),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 140, height: 14, color: baseShimmerColor),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: baseShimmerColor,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
