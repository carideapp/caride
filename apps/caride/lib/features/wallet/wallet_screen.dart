import 'package:caride/core/services/cashback_service.dart';
import 'package:caride/features/profile/data/account_repository.dart';
import 'package:caride/features/wallet/data/wallet_transaction_repository.dart';
import 'package:caride/features/wallet/wallet_transaction_details_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:caride/features/wallet/widgets/pending_bank_transfer_widgets.dart';

/// Redesigned Customer E-Wallet Screen matching FleetWalletScreen design system standards.
/// Features high-contrast emerald hero card (zero shadow), pill action buttons, and rounded transactions card.
class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  String _formatMoney(double amount) {
    return NumberFormat('#,##0.00', 'en_US').format(amount);
  }

  String _formatDateTime(DateTime dt) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  String _getTransactionTitle(WalletTransaction t) {
    final desc = t.description.toLowerCase();
    final rawType = t.rawType.toLowerCase();
    if (rawType == 'cashback' || desc.contains('cashback')) {
      return 'First Ride Cashback';
    }
    if (rawType == 'referral' || desc.contains('referral')) {
      return 'Referral Earnings';
    }
    if (desc.contains('rental payment') || rawType == 'rental_payment') {
      return t.description;
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
      return 'Bank Withdrawal';
    }
    return 'Ride Payment';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final borderColor = isDark
        ? AppColors.glassBorderDark
        : const Color(0xFFE5E7EB);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final accountRepo = AccountRepository();
    final txRepo = WalletTransactionRepository();
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar (Circular Back Button per AGENTS.md) ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
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
                      onPressed: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          context.go(CustomerRoutePaths.profile);
                        }
                      },
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
              child: StreamBuilder<AccountProfile?>(
                stream: accountRepo.watchProfile(),
                builder: (context, profileSnap) {
                  final profile = profileSnap.data;
                  final name = profile?.fullName.isNotEmpty == true
                      ? profile!.fullName
                      : 'CaRide User';

                  return StreamBuilder<double>(
                    stream: accountRepo.watchWalletBalance(),
                    builder: (context, balSnap) {
                      final liveBalance = balSnap.data ?? 0.0;

                      return ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        children: [
                          // ── Pending Bank Transfer Banner ──
                          const PendingBankTransferBanner(
                            margin: EdgeInsets.only(bottom: 12),
                          ),

                          // ── Hero Wallet Balance Card (Zero Drop-Shadow) ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [
                                        const Color(0xFF0F3E22),
                                        const Color(0xFF062816),
                                      ]
                                    : [
                                        const Color(0xFF16A34A),
                                        const Color(0xFF0D7A36),
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
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(
                                              alpha: 0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons
                                                .account_balance_wallet_rounded,
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
                                    // Status Pill
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.check_circle_rounded,
                                            color: Colors.white,
                                            size: 14,
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            'Active Account',
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

                                // User Name
                                Text(
                                  name,
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

                          // ── Action Row: Top Up & Withdraw (Pill Geometry) ──
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brand,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    minimumSize: const Size(0, 54),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 15,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add_rounded, size: 18),
                                  label: const Text(
                                    'Top Up',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  onPressed: () => context.push(
                                    CustomerRoutePaths.typeAmount,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark
                                        ? AppColors.darkSurface
                                        : Colors.white,
                                    foregroundColor: primaryTextColor,
                                    elevation: 0,
                                    minimumSize: const Size(0, 54),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 15,
                                    ),
                                    side: BorderSide(color: borderColor),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'Withdraw',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  onPressed: () =>
                                      context.push(CustomerRoutePaths.withdraw),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // ── First Ride Cashback Promo / Claimed Banner (Collapsible) ──
                          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('customers')
                                .doc(currentUid)
                                .snapshots(),
                            builder: (context, custSnap) {
                              final custData = custSnap.data?.data() ?? {};
                              final hasReceived =
                                  custData['hasReceivedFirstRideCashback'] ==
                                  true;
                              final receivedAmount =
                                  (custData['firstRideCashbackAmount'] as num?)
                                      ?.toDouble();

                              return StreamBuilder<
                                ({bool isActive, double amount})
                              >(
                                stream: CashbackService.instance
                                    .watchCashbackConfig(),
                                builder: (context, configSnap) {
                                  final config =
                                      configSnap.data ??
                                      (isActive: true, amount: 500.0);
                                  if (!config.isActive && !hasReceived) {
                                    return const SizedBox.shrink();
                                  }

                                  if (hasReceived) {
                                    return _CollapsibleCashbackCard(
                                      title: 'First Ride Cashback Claimed! 🎉',
                                      badgeText: 'CLAIMED',
                                      description:
                                          '₦${_formatMoney(receivedAmount ?? config.amount)} bonus was successfully credited to your wallet upon your first completed ride.',
                                      icon: Icons.redeem_rounded,
                                      accentColor: const Color(0xFF10B981),
                                      lightBgColors: const [
                                        Color(0xFFECFDF5),
                                        Color(0xFFD1FAE5),
                                      ],
                                      darkBgColors: const [
                                        Color(0xFF064E3B),
                                        Color(0xFF042F2E),
                                      ],
                                      isDark: isDark,
                                    );
                                  }

                                  return _CollapsibleCashbackCard(
                                    title: 'First Ride Cashback',
                                    badgeText:
                                        '₦${_formatMoney(config.amount)} REWARD',
                                    description:
                                        'Complete your very 1st ride booking to receive ₦${_formatMoney(config.amount)} bonus directly in your wallet.',
                                    icon: Icons.card_giftcard_rounded,
                                    accentColor: AppColors.brand,
                                    lightBgColors: const [
                                      Color(0xFFF0FDF4),
                                      Color(0xFFDCFCE7),
                                    ],
                                    darkBgColors: const [
                                      Color(0xFF1E293B),
                                      Color(0xFF0F172A),
                                    ],
                                    isDark: isDark,
                                  );
                                },
                              );
                            },
                          ),

                          // ── % Trip Cashback Promo Banner (₦5,000+ Trips, Collapsible) ──
                          StreamBuilder<TripCashbackConfig>(
                            stream: CashbackService.instance
                                .watchTripCashbackConfig(),
                            builder: (context, tripConfigSnap) {
                              final tripConfig = tripConfigSnap.data;
                              if (tripConfig == null ||
                                  !tripConfig.isActive ||
                                  tripConfig.percent <= 0) {
                                return const SizedBox.shrink();
                              }

                              final pctText = tripConfig.percent % 1 == 0
                                  ? '${tripConfig.percent.toInt()}%'
                                  : '${tripConfig.percent}%';
                              final minFareFormatted =
                                  '₦${_formatMoney(tripConfig.minFare > 0 ? tripConfig.minFare : 5000.0)}';
                              final destLabel = tripConfig.isSubsidyWallet
                                  ? 'Subsidy Wallet'
                                  : 'Main Wallet';

                              return _CollapsibleCashbackCard(
                                title: '$pctText Trip Cashback',
                                badgeText: 'TRIPS ≥ $minFareFormatted',
                                description:
                                    'Earn $pctText automatic cashback on every completed trip with fare from $minFareFormatted and above, credited directly to your $destLabel.',
                                icon: Icons.percent_rounded,
                                accentColor: const Color(0xFF0284C7),
                                lightBgColors: const [
                                  Color(0xFFF0FDF4),
                                  Color(0xFFE0F2FE),
                                ],
                                darkBgColors: const [
                                  Color(0xFF1B2E3C),
                                  Color(0xFF0F1E29),
                                ],
                                isDark: isDark,
                              );
                            },
                          ),

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
                                'Latest wallet movements & payments',
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
                            child: StreamBuilder<List<WalletTransaction>>(
                              stream: txRepo.watchTransactions(currentUid),
                              builder: (context, txSnap) {
                                if (txSnap.connectionState ==
                                    ConnectionState.waiting) {
                                  return const TransactionListSkeleton(
                                    itemCount: 5,
                                  );
                                }

                                final txns = txSnap.data ?? [];

                                if (txns.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 48,
                                    ),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: AppColors.brand.withValues(
                                              alpha: 0.1,
                                            ),
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
                                          'Ride payments, wallet top-ups, and withdrawals will appear here in real-time.',
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
                                    final t = txns[index];
                                    final isCredit =
                                        t.type == WalletTxType.credit;
                                    final title = _getTransactionTitle(t);
                                    final dateFormatted = _formatDateTime(
                                      t.createdAt,
                                    );
                                    final amountFormatted =
                                        '${isCredit ? "+" : "-"}₦${_formatMoney(t.amountNaira)}';

                                    final isCashback =
                                        t.rawType == 'cashback' ||
                                        t.description.toLowerCase().contains(
                                          'cashback',
                                        );
                                    final iconBg = isCashback
                                        ? (isDark
                                              ? const Color(0xFF14301D)
                                              : const Color(0xFFECFDF5))
                                        : (isCredit
                                              ? (isDark
                                                    ? const Color(0xFF14301D)
                                                    : const Color(0xFFF0FDF4))
                                              : const Color(0xFFFEF2F2));
                                    final iconColor = (isCredit || isCashback)
                                        ? AppColors.brand
                                        : AppColors.error;
                                    final iconData = isCashback
                                        ? Icons.redeem_rounded
                                        : (isCredit
                                              ? Icons.arrow_downward_rounded
                                              : Icons.arrow_outward_rounded);
                                    final badgeLabel = isCashback
                                        ? '🎁 Cashback'
                                        : (isCredit
                                              ? (t.rawType == 'referral'
                                                    ? '↙ Referral'
                                                    : '↙ Top Up')
                                              : (title.contains('Withdrawal')
                                                    ? '↗ Payout'
                                                    : '↗ Payment'));

                                    return InkWell(
                                      borderRadius: BorderRadius.circular(20),
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
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 14,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 44,
                                              height: 44,
                                              decoration: BoxDecoration(
                                                color: iconBg,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                iconData,
                                                color: iconColor,
                                                size: 20,
                                              ),
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
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: primaryTextColor,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Text(
                                                    '${t.method} • $dateFormatted',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: isDark
                                                          ? AppColors
                                                                .textSecondaryDark
                                                          : const Color(
                                                              0xFF6B7280,
                                                            ),
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
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: isCredit
                                                        ? AppColors.brand
                                                              .withValues(
                                                                alpha: 0.1,
                                                              )
                                                        : AppColors.error
                                                              .withValues(
                                                                alpha: 0.1,
                                                              ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    badgeLabel,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w700,
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

/// A sleek, expandable promotional card that displays a concise header with badge and dropdown arrow,
/// and smoothly expands/collapses the full offer details and description.
class _CollapsibleCashbackCard extends StatefulWidget {
  const _CollapsibleCashbackCard({
    required this.title,
    required this.badgeText,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.lightBgColors,
    required this.darkBgColors,
    required this.isDark,
  });

  final String title;
  final String badgeText;
  final String description;
  final IconData icon;
  final Color accentColor;
  final List<Color> lightBgColors;
  final List<Color> darkBgColors;
  final bool isDark;

  @override
  State<_CollapsibleCashbackCard> createState() =>
      _CollapsibleCashbackCardState();
}

class _CollapsibleCashbackCardState extends State<_CollapsibleCashbackCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final gradientColors = widget.isDark
        ? widget.darkBgColors
        : widget.lightBgColors;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.accentColor.withValues(
            alpha: widget.isDark ? 0.35 : 0.28,
          ),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            setState(() {
              _isExpanded = !_isExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header Row ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: widget.accentColor.withValues(
                          alpha: widget.isDark ? 0.2 : 0.12,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.accentColor,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: widget.isDark
                                    ? Colors.white
                                    : widget.accentColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: widget.accentColor.withValues(
                                alpha: widget.isDark ? 0.25 : 0.15,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.badgeText,
                              style: TextStyle(
                                fontSize: 9.0,
                                fontWeight: FontWeight.w800,
                                color: widget.accentColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: widget.isDark
                            ? Colors.white70
                            : widget.accentColor,
                        size: 22,
                      ),
                    ),
                  ],
                ),

                // ── Animated Expandable Description ──
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 8, left: 35, right: 4),
                    child: Text(
                      widget.description,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: widget.isDark
                            ? Colors.white70
                            : const Color(0xFF374151),
                      ),
                    ),
                  ),
                  crossFadeState: _isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
