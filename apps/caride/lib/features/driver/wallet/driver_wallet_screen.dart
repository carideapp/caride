import 'package:design_system/design_system.dart';
import 'package:caride/features/driver/wallet/data/driver_wallet_repository.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:caride/features/driver/earnings/withdrawal/driver_withdraw_bank_details_screen.dart';
import 'package:caride/features/driver/wallet/driver_manage_bank_accounts_screen.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Wallet Screen with frosted GlassAppBar, GlassContainers, AppLoader, and clean Activity History lists.
class DriverWalletScreen extends StatelessWidget {
  const DriverWalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = DriverWalletRepository();

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: 'Wallet',
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Premium Balance Card ──────────────────────────────
                Container(
                  height: 144,
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
                        ).withValues(alpha: isDark ? 0.20 : 0.30),
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
                          bottom: -50,
                          child: Container(
                            width: 150,
                            height: 150,
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
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
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
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.18,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_wallet_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    'Driver Wallet',
                                    style: AppTextStyles.labelMedium.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              // Balance section
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
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  StreamBuilder<double>(
                                    stream: repo.streamWalletBalance(),
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
                                              fontSize: 32,
                                              letterSpacing: -0.5,
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
                                      FirebaseAuth
                                              .instance
                                              .currentUser
                                              ?.displayName ??
                                          'Driver',
                                      style: AppTextStyles.titleSmall.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.18,
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      'ACTIVE',
                                      style: AppTextStyles.labelSmall.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 9,
                                        letterSpacing: 1.0,
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
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Withdraw',
                        icon: Icons.account_balance_wallet_rounded,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const DriverWithdrawBankDetailsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                GlassContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 0,
                      ),
                      dense: true,
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.brandGlass,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.account_balance,
                          color: AppColors.brand,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        'Manage Payout Accounts',
                        style: AppTextStyles.titleSmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        'Add or update your bank accounts',
                        style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const DriverManageBankAccountsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // ── Payout Info Banner ──
                GlassContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.brandGlass,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(
                          Icons.event_repeat,
                          color: AppColors.brand,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Automatic Payouts',
                              style: AppTextStyles.titleSmall.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Your verified bank account will be used for wallet withdrawals and payout settlements.',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // ── Transaction History ──
                Text(
                  'Recent Activity',
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                StreamBuilder<List<DriverWalletTransaction>>(
                  stream: repo.streamTransactions(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: AppLoader());
                    }
                    final txns = snapshot.data ?? [];
                    if (txns.isEmpty) {
                      return const EmptyState(
                        title: 'No transactions yet',
                        message: 'Your earnings and payments will appear here.',
                        icon: Icons.receipt_long_outlined,
                      );
                    }
                    return Column(
                      children: txns
                          .map((t) => _TransactionTile(txn: t))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.txn});

  final DriverWalletTransaction txn;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCredit = txn.isCredit;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: GlassContainer(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: (isCredit ? AppColors.brand : AppColors.error)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCredit ? Icons.add : Icons.remove,
                color: isCredit ? AppColors.brand : AppColors.error,
                size: 14,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    txn.description.isEmpty ? 'Transaction' : txn.description,
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    txn.method ?? 'Wallet',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isCredit ? "+" : "-"}${NgnFormat.whole(txn.amountNaira)}',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isCredit
                    ? AppColors.brand
                    : (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
