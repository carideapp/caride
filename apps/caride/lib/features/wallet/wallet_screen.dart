import 'package:caride/features/profile/data/account_repository.dart';
import 'package:caride/features/wallet/data/wallet_transaction_repository.dart';
import 'wallet_transaction_details_screen.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer E-Wallet Screen.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accountRepo = AccountRepository();
    final txRepo = WalletTransactionRepository();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              context.go(CustomerRoutePaths.profile);
            }
          },
        ),
        title: 'E-Wallet',
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: StreamBuilder<AccountProfile?>(
            stream: accountRepo.watchProfile(),
            builder: (context, profileSnap) {
              final profile = profileSnap.data;
              final name = profile?.fullName.isNotEmpty == true
                  ? profile!.fullName
                  : 'CaRide User';

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                children: [
                  // Balance card
                  // ── Premium Balance Card ──────────────────────────────
                  Container(
                    height: 142,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                const Color(0xFF0a3d22),
                                const Color(0xFF16A34A),
                                const Color(0xFF0f6630),
                              ]
                            : [
                                const Color(0xFF0f5132),
                                const Color(0xFF16A34A),
                                const Color(0xFF1db954),
                              ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF16A34A,
                          ).withValues(alpha: isDark ? 0.25 : 0.40),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                          spreadRadius: -4,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        children: [
                          // Decorative circles (card pattern)
                          Positioned(
                            right: -30,
                            top: -30,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.07),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 30,
                            bottom: -40,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                          ),
                          // Shine overlay
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.center,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.10),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Card content
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Header row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.18,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.account_balance_wallet_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                    Text(
                                      'CaRide Wallet',
                                      style: AppTextStyles.labelLarge.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.85,
                                        ),
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                                // Balance section (middle)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Available Balance',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: Colors.white.withValues(
                                          alpha: 0.70,
                                        ),
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    // Balance amount
                                    StreamBuilder<double>(
                                      stream: accountRepo.watchWalletBalance(),
                                      builder: (context, balSnap) {
                                        final bal = balSnap.data ?? 0.0;
                                        final formatted =
                                            '₦${bal.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
                                        return Text(
                                          formatted,
                                          style: AppTextStyles.displaySmall
                                              .copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: -0.5,
                                                fontSize: 28,
                                              ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                                // Footer: user name + chip
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: AppTextStyles.labelMedium
                                            .copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.85,
                                              ),
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.2,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.18,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        'ACTIVE',
                                        style: AppTextStyles.labelSmall
                                            .copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.2,
                                              fontSize: 10,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Top Up',
                          icon: Icons.add_rounded,
                          onPressed: () =>
                              context.push(CustomerRoutePaths.typeAmount),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: SecondaryButton(
                          label: 'Withdraw',
                          icon: Icons.remove_rounded,
                          onPressed: () =>
                              context.push(CustomerRoutePaths.withdraw),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Transaction history header
                  Text(
                    'Transaction History',
                    style: AppTextStyles.headlineSmall.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  StreamBuilder<List<WalletTransaction>>(
                    stream: txRepo.watchTransactions(currentUid),
                    builder: (context, txSnap) {
                      if (txSnap.hasError) {
                        return const Center(
                          child: Text('Could not load transactions.'),
                        );
                      }
                      if (!txSnap.hasData) {
                        return const Center(child: AppLoader());
                      }
                      final txns = txSnap.data!;
                      if (txns.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.receipt_long_outlined,
                                  size: 48,
                                  color: isDark
                                      ? AppColors.textTertiaryDark
                                      : AppColors.textTertiaryLight,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'No transactions yet.\nTop up your wallet to get started.',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: txns.map((t) {
                          final isCredit = t.type == WalletTxType.credit;
                          final statusColor = isCredit
                              ? AppColors.brand
                              : AppColors.error;
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.sm,
                            ),
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        WalletTransactionDetailsScreen(
                                          transaction: t,
                                        ),
                                  ),
                                );
                              },
                              child: GlassContainer(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isCredit
                                            ? AppColors.brandGlass
                                            : AppColors.error.withValues(
                                                alpha: 0.1,
                                              ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isCredit
                                            ? Icons.arrow_downward_rounded
                                            : Icons.arrow_upward_rounded,
                                        color: statusColor,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _getTransactionTitle(t),
                                            style: AppTextStyles.titleMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(
                                            height: AppSpacing.xxs,
                                          ),
                                          Text(
                                            '${t.method} • ${_formatDateTime(t.createdAt)}',
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
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${isCredit ? '+' : '-'}₦${t.amountNaira.toStringAsFixed(0)}',
                                          style: AppTextStyles.titleMedium
                                              .copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: statusColor,
                                              ),
                                        ),
                                        const SizedBox(height: AppSpacing.xxs),
                                        Container(
                                          width: 18,
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: statusColor,
                                            borderRadius: BorderRadius.circular(
                                              AppRadius.sm,
                                            ),
                                          ),
                                          child: Icon(
                                            isCredit
                                                ? Icons.arrow_downward_rounded
                                                : Icons.arrow_upward_rounded,
                                            size: 14,
                                            color: isCredit
                                                ? Colors.black
                                                : Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _getTransactionTitle(WalletTransaction t) {
    final desc = t.description.toLowerCase();
    final rawType = t.rawType.toLowerCase();
    if (rawType == 'referral' || desc.contains('referral')) {
      return 'Referral Earnings';
    }
    if (desc.contains('top up') ||
        desc.contains('top-up') ||
        desc.contains('deposit') ||
        t.type == WalletTxType.credit) {
      return 'Wallet Top Up';
    }
    if (desc.contains('transfer to') ||
        desc.contains('withdrawal to') ||
        t.method == 'bank_transfer') {
      if (t.description.startsWith('Transfer to') ||
          t.description.startsWith('Withdrawal to')) {
        return t.description;
      }
      return 'Bank Transfer';
    }
    return 'Ride Payment';
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final day = dt.day;
    final month = months[dt.month - 1];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day $month, $hour:$minute $period';
  }
}
