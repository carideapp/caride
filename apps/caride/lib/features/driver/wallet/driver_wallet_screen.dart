import 'package:caride/features/driver/earnings/withdrawal/driver_withdraw_bank_details_screen.dart';
import 'package:caride/features/driver/wallet/data/driver_wallet_repository.dart';
import 'package:caride/features/driver/wallet/driver_manage_bank_accounts_screen.dart';
import 'package:caride/features/driver/wallet/driver_transaction_details_screen.dart';
import 'package:caride/features/driver/wallet/driver_top_up_wallet_hub_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Redesigned Driver Wallet Screen matching FleetWalletScreen design system standards.
/// Features high-contrast emerald hero card (zero shadow), pill action buttons, and rounded transactions card.
class DriverWalletScreen extends StatelessWidget {
  const DriverWalletScreen({super.key});

  String _formatMoney(double amount) {
    return NumberFormat('#,##0.00', 'en_US').format(amount);
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    if (timestamp is Timestamp) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());
    }
    if (timestamp is DateTime) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp);
    }
    return 'Recently';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final repo = DriverWalletRepository();
    final user = FirebaseAuth.instance.currentUser;
    final driverName = (user?.displayName != null && user!.displayName!.isNotEmpty)
        ? user.displayName!
        : 'CaRide Driver';

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar (Circular Back Button per AGENTS.md) ──
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      border: Border.all(color: borderColor),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: primaryTextColor,
                        size: 18,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Wallet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
            ),

            // ── Main Scrollable Body ──
            Expanded(
              child: StreamBuilder<double>(
                stream: repo.streamWalletBalance(),
                builder: (context, balSnap) {
                  final liveBalance = balSnap.data ?? 0.0;

                  return ListView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    children: [
                      // ── Hero Wallet Balance Card (Zero Drop-Shadow) ──
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? [
                                    const Color(0xFF0F3E22),
                                    const Color(0xFF062816)
                                  ]
                                : [
                                    const Color(0xFF16A34A),
                                    const Color(0xFF0D7A36)
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.account_balance_wallet_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Wallet Balance',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                                // Settlement Account Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.credit_card_rounded,
                                          color: Colors.white, size: 14),
                                      SizedBox(width: 6),
                                      Text(
                                        'Direct Payout',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // Large Naira Amount
                            Text(
                              '₦${_formatMoney(liveBalance)}',
                              style: const TextStyle(
                                fontSize: 34,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Driver Name
                            Text(
                              driverName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Action Row: Top Up, Withdrawal & Bank Details (Pill Geometry) ──
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size(0, 50),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              icon: const Icon(Icons.add_rounded,
                                  size: 18),
                              label: const Text(
                                'Top Up',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const DriverTopUpWalletHubScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isDark ? AppColors.darkSurface : Colors.white,
                                foregroundColor: primaryTextColor,
                                elevation: 0,
                                minimumSize: const Size(0, 50),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                side: BorderSide(color: borderColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              icon: const Icon(Icons.arrow_upward_rounded,
                                  size: 16),
                              label: const Text(
                                'Withdraw',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13),
                              ),
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
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isDark ? AppColors.darkSurface : Colors.white,
                                foregroundColor: primaryTextColor,
                                elevation: 0,
                                minimumSize: const Size(0, 50),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 14),
                                side: BorderSide(color: borderColor),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              icon: const Icon(Icons.account_balance_rounded,
                                  size: 16),
                              label: const Text(
                                'Banks',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const DriverManageBankAccountsScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // ── Section Title: Recent Transactions ──
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent transactions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Latest wallet movements & payouts',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── Transactions Stream Card ──
                      Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: borderColor),
                        ),
                        child: StreamBuilder<List<DriverWalletTransaction>>(
                          stream: repo.streamTransactions(),
                          builder: (context, txSnapshot) {
                            if (txSnapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(
                                  child: CircularProgressIndicator(
                                      color: AppColors.brand, strokeWidth: 2.5),
                                ),
                              );
                            }

                            final txns = txSnapshot.data ?? [];

                            if (txns.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 48),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppColors.brand
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.receipt_long_rounded,
                                        size: 36,
                                        color: AppColors.brand,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No Transactions Recorded',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Trip earnings, tips, bonuses, and wallet withdrawals will appear here in real-time.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : const Color(0xFF6B7280),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: txns.length,
                              separatorBuilder: (ctx, i) =>
                                  Divider(height: 1, color: borderColor),
                              itemBuilder: (ctx, index) {
                                final tx = txns[index];
                                final isCredit = tx.isCredit;
                                final title = tx.description.isNotEmpty
                                    ? tx.description
                                    : (isCredit ? 'Trip Earnings' : 'Wallet Withdrawal');
                                final dateFormatted = _formatDate(tx.createdAt);
                                final amountFormatted =
                                    '${isCredit ? "+" : "-"}₦${_formatMoney(tx.amountNaira)}';

                                final iconBg = isCredit
                                    ? (isDark
                                        ? const Color(0xFF14301D)
                                        : const Color(0xFFF0FDF4))
                                    : const Color(0xFFFEF2F2);
                                final iconColor =
                                    isCredit ? AppColors.brand : AppColors.error;
                                final iconData = isCredit
                                    ? Icons.local_taxi_rounded
                                    : Icons.arrow_outward_rounded;
                                final badgeLabel =
                                    isCredit ? '↙ Credit' : '↗ Payout';

                                return InkWell(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            DriverTransactionDetailsScreen(
                                          transaction: tx,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: iconBg,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(iconData,
                                            color: iconColor, size: 20),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title,
                                              style: TextStyle(
                                                fontSize: 14.5,
                                                fontWeight: FontWeight.w700,
                                                color: primaryTextColor,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              dateFormatted,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: isDark
                                                    ? AppColors.textSecondaryDark
                                                    : const Color(0xFF6B7280),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            amountFormatted,
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: isCredit
                                                  ? AppColors.brand
                                                  : AppColors.error,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isCredit
                                                  ? AppColors.brand
                                                      .withValues(alpha: 0.1)
                                                  : AppColors.error
                                                      .withValues(alpha: 0.1),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              badgeLabel,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: isCredit
                                                  ? AppColors.brand
                                                  : AppColors.error,
                                              ),
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
                      ),
                    ),
                    const SizedBox(height: 32),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
