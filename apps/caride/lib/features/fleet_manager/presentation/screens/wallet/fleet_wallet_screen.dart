import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';

import 'package:caride/features/fleet_manager/auth/controllers/fleet_auth_controller.dart';

class FleetWalletScreen extends StatefulWidget {
  const FleetWalletScreen({super.key});

  @override
  State<FleetWalletScreen> createState() => _FleetWalletScreenState();
}

class _FleetWalletScreenState extends State<FleetWalletScreen> {
  final _firestore = FirebaseFirestore.instance;

  String _formatMoney(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return formatter.format(amount);
  }

  DateTime _parseDateTime(dynamic timestamp) {
    if (timestamp == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (timestamp is Timestamp) return timestamp.toDate();
    if (timestamp is DateTime) return timestamp;
    if (timestamp is String) return DateTime.tryParse(timestamp) ?? DateTime.fromMillisecondsSinceEpoch(0);
    if (timestamp is num) return DateTime.fromMillisecondsSinceEpoch(timestamp.toInt());
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recent';
    final date = _parseDateTime(timestamp);
    if (date.millisecondsSinceEpoch == 0) return 'Recent';
    return DateFormat('MMM d, yyyy | h:mm a').format(date);
  }

  Stream<List<Map<String, dynamic>>> _streamFleetTransactions({
    required String fleetId,
    required String ownerUid,
  }) {
    final controller = StreamController<List<Map<String, dynamic>>>();
    final List<StreamSubscription> subs = [];
    final Map<int, List<Map<String, dynamic>>> streamResults = {};

    void emitMerged() {
      final Map<String, Map<String, dynamic>> deduped = {};

      for (final list in streamResults.values) {
        for (final tx in list) {
          final id = (tx['id'] as String? ?? tx['reference'] as String? ?? '').trim();
          if (id.isEmpty) continue;
          if (!deduped.containsKey(id)) {
            deduped[id] = tx;
          }
        }
      }

      final result = deduped.values.toList();
      result.sort((a, b) {
        final tA = _parseDateTime(a['createdAt']);
        final tB = _parseDateTime(b['createdAt']);
        return tB.compareTo(tA);
      });

      if (!controller.isClosed) {
        controller.add(result);
      }
    }

    final List<Stream<QuerySnapshot<Map<String, dynamic>>>> targets = [];

    // Subcollection 1: fleets/{fleetId}/transactions
    if (fleetId.isNotEmpty) {
      try {
        targets.add(_firestore.collection('fleets').doc(fleetId).collection('transactions').snapshots());
      } catch (_) {}
    }

    // Subcollection 2: fleets/{ownerUid}/transactions
    if (ownerUid.isNotEmpty && ownerUid != fleetId) {
      try {
        targets.add(_firestore.collection('fleets').doc(ownerUid).collection('transactions').snapshots());
      } catch (_) {}
    }

    // Collection 3: walletTransactions where uid == ownerUid
    if (ownerUid.isNotEmpty) {
      try {
        targets.add(_firestore.collection('walletTransactions').where('uid', isEqualTo: ownerUid).snapshots());
      } catch (_) {}
    }

    // Collection 4: walletTransactions where fleetId == fleetId
    if (fleetId.isNotEmpty && fleetId != ownerUid) {
      try {
        targets.add(_firestore.collection('walletTransactions').where('fleetId', isEqualTo: fleetId).snapshots());
      } catch (_) {}
    }

    // Collection 5: rental_bookings where fleetId == fleetId
    if (fleetId.isNotEmpty) {
      try {
        targets.add(_firestore.collection('rental_bookings').where('fleetId', isEqualTo: fleetId).snapshots());
      } catch (_) {}
    }

    // Collection 6: rental_bookings where ownerUid == ownerUid
    if (ownerUid.isNotEmpty && ownerUid != fleetId) {
      try {
        targets.add(_firestore.collection('rental_bookings').where('ownerUid', isEqualTo: ownerUid).snapshots());
      } catch (_) {}
    }

    if (targets.isEmpty) {
      return Stream.value(const []);
    }

    for (int i = 0; i < targets.length; i++) {
      final idx = i;
      subs.add(targets[idx].listen(
        (snap) {
          final List<Map<String, dynamic>> items = [];
          for (final doc in snap.docs) {
            final data = doc.data();
            final docId = doc.id;

            if (doc.reference.path.contains('rental_bookings')) {
              final paymentStatus = (data['paymentStatus'] as String? ?? '').toLowerCase();
              final status = (data['status'] as String? ?? '').toLowerCase();
              final isPaid = paymentStatus == 'paid' ||
                  status == 'confirmed' ||
                  status == 'completed' ||
                  status == 'ongoing' ||
                  status == 'active';

              if (!isPaid) continue;

              final vehicleTitle = data['vehicleTitle'] as String? ?? 'Rental Booking';
              final amount = (data['totalAmount'] as num?)?.toDouble() ??
                  (data['amount'] as num?)?.toDouble() ??
                  0.0;
              final created = data['createdAt'] ?? data['startDate'] ?? data['paidAt'];

              items.add({
                'id': 'booking_$docId',
                'type': 'booking',
                'title': 'Booking Payment: $vehicleTitle',
                'amount': amount,
                'amountNaira': amount,
                'createdAt': created,
                'reference': docId,
                'status': 'completed',
              });
            } else {
              final amount = (data['amount'] as num?)?.toDouble() ??
                  (data['amountNaira'] as num?)?.toDouble() ??
                  (data['totalAmount'] as num?)?.toDouble() ??
                  0.0;
              final created = data['createdAt'] ?? data['timestamp'] ?? data['created_at'] ?? data['date'];
              final rawType = (data['type'] as String? ?? 'booking').toLowerCase();
              final desc = data['description'] as String? ?? '';
              final title = data['title'] as String? ??
                  (desc.isNotEmpty ? desc : (rawType == 'withdrawal' ? 'Wallet Withdrawal' : 'Wallet Payment'));

              items.add({
                ...data,
                'id': docId,
                'type': rawType,
                'title': title,
                'amount': amount,
                'amountNaira': amount,
                'createdAt': created,
                'reference': data['reference'] as String? ?? docId,
              });
            }
          }
          streamResults[idx] = items;
          emitMerged();
        },
        onError: (err) {
          debugPrint('Transaction stream $idx error: $err');
        },
      ));
    }

    controller.onCancel = () {
      for (final s in subs) {
        s.cancel();
      }
    };

    return controller.stream;
  }

  // ── Open Withdrawal Flow ──────────────────────────────────────────────────

  void _startWithdrawalFlow(FleetProfile? profile, double currentBalance, bool isDark) {
    if (currentBalance < 1000) {
      _showSnack(
        'Minimum withdrawal amount is ₦1,000. Your balance is ₦${_formatMoney(currentBalance)}.',
        isError: true,
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WithdrawalFlowModal(
        profile: profile,
        currentBalance: currentBalance,
        isDark: isDark,
        onWithdrawalCompleted: () {
          setState(() {});
        },
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.brand,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return ListenableBuilder(
      listenable: fleetAuthController,
      builder: (context, _) {
        final profile = fleetAuthController.currentProfile;
        final fleetId = profile?.fleetId ?? '';
        final businessName = profile?.businessName.isNotEmpty == true
            ? profile!.businessName
            : (profile?.fullName.isNotEmpty == true ? profile!.fullName : 'Fleet Partner');

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
          body: SafeArea(
            child: Column(
              children: [
                // ── Top Bar (Circular Back Button per AGENTS.md) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: primaryTextColor, size: 18),
                          onPressed: () => context.pop(),
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
                  child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: fleetId.isNotEmpty
                        ? _firestore.collection('fleets').doc(fleetId).snapshots()
                        : null,
                    builder: (context, snapshot) {
                      double liveBalance = profile?.walletBalance ?? 0.0;
                      String? bankName = profile?.bankName;
                      String? accountNumber = profile?.accountNumber;

                      if (snapshot.hasData && snapshot.data!.exists) {
                        final data = snapshot.data!.data() ?? {};
                        liveBalance = (data['walletBalance'] as num?)?.toDouble() ??
                            (data['totalEarnings'] as num?)?.toDouble() ??
                            liveBalance;
                        bankName = data['bankName'] as String? ?? bankName;
                        accountNumber = data['accountNumber'] as String? ?? accountNumber;
                      }

                      return ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: [
                          // ── Hero Wallet Balance Card (UI/wallet_1.jpg Reference) ──
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [const Color(0xFF0F3E22), const Color(0xFF062816)]
                                    : [const Color(0xFF16A34A), const Color(0xFF0D7A36)],
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
                                            color: Colors.white.withValues(alpha: 0.15),
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
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.credit_card_rounded, color: Colors.white, size: 14),
                                          const SizedBox(width: 6),
                                          Text(
                                            accountNumber != null && accountNumber.length >= 4
                                                ? '${bankName ?? 'Bank'} •••• ${accountNumber.substring(accountNumber.length - 4)}'
                                                : 'Direct Payout',
                                            style: const TextStyle(
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

                                // Business / Partner Name
                                Text(
                                  businessName,
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

                          // ── Action Row: Withdrawal Button & Transaction History ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Withdrawal Button (Pill per AGENTS.md)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brand,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  minimumSize: const Size(160, 54),
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                ),
                                icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                                label: const Text(
                                  'Withdraw Funds',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                onPressed: () => _startWithdrawalFlow(profile, liveBalance, isDark),
                              ),

                              // Transaction History Link
                              InkWell(
                                onTap: () => context.push(FleetRoutePaths.transactionHistory),
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  child: Row(
                                    children: [
                                      Text(
                                        'Transaction History',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white70 : const Color(0xFF374151),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        size: 20,
                                        color: isDark ? Colors.white70 : const Color(0xFF374151),
                                      ),
                                    ],
                                  ),
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
                                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // ── Transactions Stream Card (All Transactions without filter chips) ──
                          Container(
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: borderColor),
                            ),
                            child: StreamBuilder<List<Map<String, dynamic>>>(
                              stream: _streamFleetTransactions(
                                fleetId: fleetId,
                                ownerUid: profile?.ownerUid ?? FirebaseAuth.instance.currentUser?.uid ?? '',
                              ),
                              builder: (context, txSnapshot) {
                                if (txSnapshot.connectionState == ConnectionState.waiting) {
                                  return const TransactionListSkeleton(itemCount: 4);
                                }

                                final docs = txSnapshot.data ?? [];

                                if (docs.isEmpty) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
                                    child: Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: AppColors.brand.withValues(alpha: 0.1),
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
                                          'Customer bookings, referral commissions, and wallet withdrawals will appear here in real-time.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
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
                                  itemCount: docs.length,
                                  separatorBuilder: (ctx, i) => Divider(height: 1, color: borderColor),
                                  itemBuilder: (ctx, index) {
                                    final tx = docs[index];
                                    final type = (tx['type'] as String? ?? 'booking').toLowerCase();
                                    final title = tx['title'] as String? ??
                                        (type == 'withdrawal'
                                            ? 'Wallet Withdrawal'
                                            : (type == 'referral'
                                                ? 'Referral Commission'
                                                : 'Order Checkout Payment'));
                                    final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                                    final dateFormatted = _formatDate(tx['createdAt']);
                                    final isDebit = type == 'withdrawal';

                                    Color iconBg;
                                    Color iconColor;
                                    IconData iconData;
                                    String badgeLabel;
                                    Color badgeColor;

                                    if (type == 'withdrawal') {
                                      iconBg = const Color(0xFFFEF2F2);
                                      iconColor = AppColors.error;
                                      iconData = Icons.arrow_outward_rounded;
                                      badgeLabel = '↗ Withdrawal';
                                      badgeColor = AppColors.error;
                                    } else if (type == 'referral') {
                                      iconBg = isDark ? const Color(0xFF14301D) : const Color(0xFFF0FDF4);
                                      iconColor = AppColors.brand;
                                      iconData = Icons.card_giftcard_rounded;
                                      badgeLabel = '↙ Referral';
                                      badgeColor = AppColors.brand;
                                    } else {
                                      iconBg = isDark ? const Color(0xFF14301D) : const Color(0xFFF0FDF4);
                                      iconColor = AppColors.brand;
                                      iconData = Icons.local_taxi_rounded;
                                      badgeLabel = '↙ Booking';
                                      badgeColor = AppColors.brand;
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                      child: Row(
                                        children: [
                                          // Left Round Icon
                                          Container(
                                            width: 46,
                                            height: 46,
                                            decoration: BoxDecoration(
                                              color: isDark ? iconColor.withValues(alpha: 0.15) : iconBg,
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Icon(iconData, color: iconColor, size: 22),
                                          ),
                                          const SizedBox(width: 14),

                                          // Center Title & Timestamp
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  title,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: primaryTextColor,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  dateFormatted,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF9CA3AF),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 10),

                                          // Right Amount & Tag
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                '${isDebit ? '-' : '+'}₦${_formatMoney(amount)}',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                  color: isDebit ? AppColors.error : primaryTextColor,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: badgeColor.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  badgeLabel,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: badgeColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
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
      },
    );
  }
}

// ── Complete Multi-Step Withdrawal Flow Modal ─────────────────────────────────

class _WithdrawalFlowModal extends StatefulWidget {
  const _WithdrawalFlowModal({
    required this.profile,
    required this.currentBalance,
    required this.isDark,
    required this.onWithdrawalCompleted,
  });

  final FleetProfile? profile;
  final double currentBalance;
  final bool isDark;
  final VoidCallback onWithdrawalCompleted;

  @override
  State<_WithdrawalFlowModal> createState() => _WithdrawalFlowModalState();
}

class _WithdrawalFlowModalState extends State<_WithdrawalFlowModal> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  int _step = 1; // 1: Amount, 2: Bank Details, 3: Review, 4: PIN, 5: Success

  // Step 1: Amount State
  final _amountController = TextEditingController();
  double _enteredAmount = 0.0;
  String? _amountError;

  // Step 2: Bank Details State
  String? _selectedBankCode;
  String? _selectedBankName;
  final _accountNumberController = TextEditingController();
  String? _resolvedAccountName;
  bool _isResolvingBank = false;
  String? _bankError;
  bool _saveAsDefaultBank = true;

  // Step 4: Security PIN State
  String _pinInput = '';
  String _confirmNewPin = '';
  String? _pinError;
  bool _isProcessing = false;
  bool _needsPinCreation = false;
  String _createdTxReference = '';

  // Nigerian Commercial Banks List with official TransactPay / NIP bank codes
  final List<Map<String, String>> _nigerianBanks = [
    {'name': 'Access Bank', 'code': '044'},
    {'name': 'Access Bank (Diamond)', 'code': '063'},
    {'name': 'Citibank Nigeria', 'code': '023'},
    {'name': 'Ecobank Nigeria', 'code': '050'},
    {'name': 'Fidelity Bank', 'code': '070'},
    {'name': 'First Bank of Nigeria', 'code': '011'},
    {'name': 'First City Monument Bank (FCMB)', 'code': '214'},
    {'name': 'Globus Bank', 'code': '00103'},
    {'name': 'Guaranty Trust Bank (GTBank)', 'code': '058'},
    {'name': 'Heritage Bank', 'code': '030'},
    {'name': 'Jaiz Bank', 'code': '301'},
    {'name': 'Keystone Bank', 'code': '082'},
    {'name': 'Kuda Microfinance Bank', 'code': '090267'},
    {'name': 'Moniepoint MFB', 'code': '090405'},
    {'name': 'OPay Digital Services', 'code': '999992'},
    {'name': 'PalmPay', 'code': '999991'},
    {'name': 'Parallex Bank', 'code': '526'},
    {'name': 'Polaris Bank', 'code': '076'},
    {'name': 'Premium Trust Bank', 'code': '000031'},
    {'name': 'Providus Bank', 'code': '101'},
    {'name': 'Rubies MFB', 'code': '125'},
    {'name': 'Stanbic IBTC Bank', 'code': '221'},
    {'name': 'Standard Chartered Bank', 'code': '068'},
    {'name': 'Sterling Bank', 'code': '232'},
    {'name': 'Suntrust Bank', 'code': '100'},
    {'name': 'Taj Bank', 'code': '302'},
    {'name': 'Titan Trust Bank', 'code': '102'},
    {'name': 'Union Bank of Nigeria', 'code': '032'},
    {'name': 'United Bank for Africa (UBA)', 'code': '033'},
    {'name': 'Unity Bank', 'code': '215'},
    {'name': 'VFD Microfinance Bank', 'code': '566'},
    {'name': 'Wema Bank', 'code': '035'},
    {'name': 'Zenith Bank', 'code': '057'},
  ];

  @override
  void initState() {
    super.initState();
    _needsPinCreation = !(widget.profile?.hasSecurityPin ?? false);

    // Initialize with saved bank details if present
    if (widget.profile?.accountNumber != null && widget.profile!.accountNumber!.isNotEmpty) {
      _accountNumberController.text = widget.profile!.accountNumber!;
      _selectedBankName = widget.profile!.bankName;
      _resolvedAccountName = widget.profile!.accountName;

      final matched = _nigerianBanks.firstWhere(
        (b) => b['name'] == widget.profile!.bankName,
        orElse: () => {'name': widget.profile!.bankName ?? '', 'code': '058'},
      );
      _selectedBankCode = matched['code'];
    } else {
      _selectedBankCode = '058'; // Default GTBank
      _selectedBankName = 'Guaranty Trust Bank (GTBank)';
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  String _formatMoney(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return formatter.format(amount);
  }

  void _showErrorFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  Widget _buildInViewErrorBanner({
    required String message,
    required VoidCallback onDismiss,
  }) {
    final isDark = widget.isDark;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A1215) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.error,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Action Required',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }

  // ── Step 1 Validation ──
  void _handleStep1Continue() {
    final text = _amountController.text.trim().replaceAll(',', '');
    final amount = double.tryParse(text);

    if (amount == null || amount <= 0) {
      const err = 'Please enter a valid withdrawal amount';
      setState(() => _amountError = err);
      _showErrorFeedback(err);
      return;
    }
    if (amount < 1000) {
      const err = 'Minimum withdrawal amount is ₦1,000';
      setState(() => _amountError = err);
      _showErrorFeedback(err);
      return;
    }
    if (amount > widget.currentBalance) {
      final err = 'Amount exceeds available balance (₦${_formatMoney(widget.currentBalance)})';
      setState(() => _amountError = err);
      _showErrorFeedback(err);
      return;
    }

    setState(() {
      _enteredAmount = amount;
      _amountError = null;
      _step = 2;
    });
  }

  // ── Step 2: Live TransactPay Account Resolution ──
  Future<void> _resolveAccountName() async {
    final accNum = _accountNumberController.text.trim();
    if (accNum.length != 10) {
      setState(() => _bankError = 'Account number must be 10 digits');
      return;
    }
    if (_selectedBankCode == null) {
      setState(() => _bankError = 'Please select a destination bank');
      return;
    }

    setState(() {
      _isResolvingBank = true;
      _bankError = null;
      _resolvedAccountName = null;
    });

    try {
      final res = await FirebaseFunctions.instance
          .httpsCallable('resolveTransactPayBankAccount')
          .call<Map<String, dynamic>>({
        'accountNumber': accNum,
        'bankCode': _selectedBankCode,
      }).timeout(const Duration(seconds: 15));

      final resolved = res.data['accountName'] as String?;
      if (resolved != null && resolved.isNotEmpty) {
        setState(() {
          _resolvedAccountName = resolved;
          _isResolvingBank = false;
        });
        return;
      }

      setState(() {
        _bankError = 'Could not verify account name. Please check your account number and bank.';
        _isResolvingBank = false;
      });
    } catch (e) {
      setState(() {
        _bankError = 'Verification failed: ${e.toString().replaceAll("Exception:", "").trim()}';
        _isResolvingBank = false;
      });
    }
  }

  void _handleStep2Continue() {
    if (_accountNumberController.text.trim().length != 10) {
      const err = 'Enter a valid 10-digit NUBAN account number';
      setState(() => _bankError = err);
      _showErrorFeedback(err);
      return;
    }
    if (_resolvedAccountName == null || _resolvedAccountName!.isEmpty) {
      const err = 'Please verify beneficiary account name first';
      setState(() => _bankError = err);
      _showErrorFeedback(err);
      return;
    }

    setState(() {
      _bankError = null;
      _step = 3; // Go to Review
    });
  }

  // ── Step 4: PIN Authorization & Final Execution ──

  void _handleKeypadInput(String digit) {
    setState(() {
      _pinError = null;
      if (_needsPinCreation) {
        if (_pinInput.length < 4) {
          _pinInput += digit;
        } else if (_confirmNewPin.length < 4) {
          _confirmNewPin += digit;
        }
      } else {
        if (_pinInput.length < 4) {
          _pinInput += digit;
        }
      }
    });

    if (!_needsPinCreation && _pinInput.length == 4) {
      _executeWithdrawal();
    }
  }

  void _handleKeypadBackspace() {
    setState(() {
      _pinError = null;
      if (_needsPinCreation) {
        if (_confirmNewPin.isNotEmpty) {
          _confirmNewPin = _confirmNewPin.substring(0, _confirmNewPin.length - 1);
        } else if (_pinInput.isNotEmpty) {
          _pinInput = _pinInput.substring(0, _pinInput.length - 1);
        }
      } else {
        if (_pinInput.isNotEmpty) {
          _pinInput = _pinInput.substring(0, _pinInput.length - 1);
        }
      }
    });
  }

  Future<void> _executeWithdrawal() async {
    final uid = _auth.currentUser?.uid;
    final fleetId = widget.profile?.fleetId;
    if (uid == null || fleetId == null || fleetId.isEmpty) return;

    // PIN Validation
    if (_needsPinCreation) {
      if (_pinInput.length != 4) {
        const err = 'Please enter a 4-digit security PIN';
        setState(() => _pinError = err);
        _showErrorFeedback(err);
        return;
      }
      if (_pinInput != _confirmNewPin) {
        const err = 'Security PINs do not match. Please re-enter.';
        setState(() {
          _pinError = err;
          _confirmNewPin = '';
        });
        _showErrorFeedback(err);
        return;
      }
    } else {
      final savedPin = widget.profile?.securityPin;
      if (savedPin != null && savedPin != _pinInput) {
        const err = 'Incorrect security PIN. Please try again.';
        setState(() {
          _pinError = err;
          _pinInput = '';
        });
        _showErrorFeedback(err);
        return;
      }
    }

    setState(() => _isProcessing = true);

    try {
      final now = DateTime.now();
      final nowIso = now.toIso8601String();
      final txRef = 'CR-WD-${now.millisecondsSinceEpoch.toString().substring(5)}';
      final newBalance = widget.currentBalance - _enteredAmount;

      final batch = _firestore.batch();
      final fleetRef = _firestore.collection('fleets').doc(fleetId);

      // 1. Update wallet balance and bank details on fleet
      final Map<String, dynamic> updateData = {
        'walletBalance': newBalance,
        'updatedAt': nowIso,
      };

      if (_needsPinCreation) {
        updateData['securityPin'] = _pinInput;
      }
      if (_saveAsDefaultBank) {
        updateData['bankName'] = _selectedBankName;
        updateData['accountNumber'] = _accountNumberController.text.trim();
        updateData['accountName'] = _resolvedAccountName;
      }

      batch.set(fleetRef, updateData, SetOptions(merge: true));

      // 2. Also sync to manager doc
      final managerRef = _firestore.collection('fleet_managers').doc(uid);
      batch.set(managerRef, updateData, SetOptions(merge: true));

      // 3. Write transaction to fleets/{fleetId}/transactions
      final txDocRef = fleetRef.collection('transactions').doc(txRef);
      batch.set(txDocRef, {
        'id': txRef,
        'type': 'withdrawal',
        'title': 'Withdrawal to ${_selectedBankName ?? 'Bank'}',
        'amount': _enteredAmount,
        'balanceAfter': newBalance,
        'status': 'completed',
        'bankName': _selectedBankName,
        'accountNumber': _accountNumberController.text.trim(),
        'accountName': _resolvedAccountName,
        'reference': txRef,
        'createdAt': nowIso,
      });

      // 4. Record global payout request for admin tracking
      final payoutRef = _firestore.collection('payout_requests').doc(txRef);
      batch.set(payoutRef, {
        'id': txRef,
        'fleetId': fleetId,
        'partnerName': widget.profile?.businessName ?? widget.profile?.fullName ?? 'Fleet Partner',
        'amount': _enteredAmount,
        'bankName': _selectedBankName,
        'accountNumber': _accountNumberController.text.trim(),
        'accountName': _resolvedAccountName,
        'status': 'successful',
        'reference': txRef,
        'createdAt': nowIso,
        'processedAt': nowIso,
      });

      await batch.commit();

      widget.onWithdrawalCompleted();

      setState(() {
        _createdTxReference = txRef;
        _isProcessing = false;
        _step = 5; // Success Step
      });
    } catch (_) {
      if (!mounted) return;
      const err = 'Withdrawal could not be processed. Please check your internet connection and try again.';
      setState(() {
        _pinError = err;
        _isProcessing = false;
      });
      _showErrorFeedback(err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark ? AppColors.darkSurface : Colors.white;
    final primaryTextColor = widget.isDark ? Colors.white : const Color(0xFF111827);
    final borderColor = widget.isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final inputFill = widget.isDark ? AppColors.darkBackground : const Color(0xFFF3F4F6);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Drag Handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── STEP 1: Enter Amount ──
            if (_step == 1) ...[
              Text(
                'Withdraw Funds',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: primaryTextColor),
              ),
              const SizedBox(height: 6),
              Text(
                'Available Balance: ₦${_formatMoney(widget.currentBalance)}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.brand),
              ),
              const SizedBox(height: 16),

              if (_amountError != null)
                _buildInViewErrorBanner(
                  message: _amountError!,
                  onDismiss: () => setState(() => _amountError = null),
                ),

              // Amount Input Field (Pill per AGENTS.md)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                decoration: BoxDecoration(
                  color: inputFill,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: _amountError != null ? AppColors.error : borderColor),
                ),
                child: Row(
                  children: [
                    const Text(
                      '₦',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.brand),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: primaryTextColor),
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onChanged: (_) {
                          if (_amountError != null) setState(() => _amountError = null);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Quick Amount Chips (Pill per AGENTS.md)
              const Text('Quick Amount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickAmountChip('₦5,000', 5000, isDark: widget.isDark),
                  _buildQuickAmountChip('₦10,000', 10000, isDark: widget.isDark),
                  _buildQuickAmountChip('₦25,000', 25000, isDark: widget.isDark),
                  _buildQuickAmountChip('₦50,000', 50000, isDark: widget.isDark),
                  _buildQuickAmountChip('100% All', widget.currentBalance, isDark: widget.isDark),
                ],
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: _handleStep1Continue,
                  child: const Text('Continue to Bank Details', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],

            // ── STEP 2: Destination Bank & TransactPay Resolution ──
            if (_step == 2) ...[
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cardBg,
                      border: Border.all(color: borderColor),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: primaryTextColor),
                      onPressed: () => setState(() {
                        _bankError = null;
                        _step = 1;
                      }),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Destination Bank',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: primaryTextColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Select your Nigerian commercial bank and enter account number for instant settlement.',
                style: TextStyle(fontSize: 13, color: widget.isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),

              if (_bankError != null)
                _buildInViewErrorBanner(
                  message: _bankError!,
                  onDismiss: () => setState(() => _bankError = null),
                ),

              // Bank Dropdown (Pill per AGENTS.md)
              const Text('Select Bank', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
                decoration: BoxDecoration(
                  color: inputFill,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedBankCode,
                    isExpanded: true,
                    dropdownColor: cardBg,
                    items: _nigerianBanks
                        .map((b) => DropdownMenuItem(
                              value: b['code'],
                              child: Text(b['name']!, style: TextStyle(color: primaryTextColor, fontSize: 14)),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        final found = _nigerianBanks.firstWhere((b) => b['code'] == val);
                        setState(() {
                          _selectedBankCode = val;
                          _selectedBankName = found['name'];
                          _resolvedAccountName = null;
                          _bankError = null;
                        });
                        if (_accountNumberController.text.length == 10) {
                          _resolveAccountName();
                        }
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Account Number Input (Pill per AGENTS.md)
              const Text('10-Digit NUBAN Account Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
                decoration: BoxDecoration(
                  color: inputFill,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: _bankError != null ? AppColors.error : borderColor),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _accountNumberController,
                        keyboardType: TextInputType.number,
                        maxLength: 10,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.w700, fontSize: 16),
                        decoration: const InputDecoration(
                          hintText: '0123456789',
                          border: InputBorder.none,
                          counterText: '',
                        ),
                        onChanged: (val) {
                          if (_bankError != null) setState(() => _bankError = null);
                          if (val.length == 10) {
                            _resolveAccountName();
                          } else {
                            setState(() => _resolvedAccountName = null);
                          }
                        },
                      ),
                    ),
                    if (_isResolvingBank)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
                      )
                    else
                      TextButton(
                        onPressed: _resolveAccountName,
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.brand,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: const Text('Verify', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
              ),

              // Verified Account Name Badge
              if (_resolvedAccountName != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.brand, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _resolvedAccountName!,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),

              // Save as default checkbox
              Row(
                children: [
                  Checkbox(
                    value: _saveAsDefaultBank,
                    activeColor: AppColors.brand,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (v) => setState(() => _saveAsDefaultBank = v ?? true),
                  ),
                  const Text('Save as default settlement account', style: TextStyle(fontSize: 13)),
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: _handleStep2Continue,
                  child: const Text('Review Withdrawal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],

            // ── STEP 3: Summary Review ──
            if (_step == 3) ...[
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cardBg,
                      border: Border.all(color: borderColor),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: primaryTextColor),
                      onPressed: () => setState(() => _step = 2),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Review Withdrawal',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: primaryTextColor),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: inputFill,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Withdrawal Amount', '₦${_formatMoney(_enteredAmount)}', isBold: true),
                    const Divider(height: 20),
                    _buildSummaryRow('Processing Fee', '₦0.00 (Free)'),
                    const Divider(height: 20),
                    _buildSummaryRow('Net Payout', '₦${_formatMoney(_enteredAmount)}', isBold: true, valueColor: AppColors.brand),
                    const Divider(height: 20),
                    _buildSummaryRow('Destination Bank', _selectedBankName ?? 'Commercial Bank'),
                    const Divider(height: 20),
                    _buildSummaryRow('Account Number', _accountNumberController.text.trim()),
                    const Divider(height: 20),
                    _buildSummaryRow('Beneficiary', _resolvedAccountName ?? 'Fleet Partner'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: () {
                    setState(() {
                      _step = 4;
                      _pinInput = '';
                      _confirmNewPin = '';
                      _pinError = null;
                    });
                  },
                  child: Text(
                    _needsPinCreation ? 'Create PIN & Authorize' : 'Authorize with Security PIN',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ),
            ],

            // ── STEP 4: Security PIN Authorization ──
            if (_step == 4) ...[
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cardBg,
                      border: Border.all(color: borderColor),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: primaryTextColor),
                      onPressed: () => setState(() {
                        _pinError = null;
                        _step = 3;
                      }),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _needsPinCreation
                          ? (_pinInput.length < 4 ? 'Create 4-Digit PIN' : 'Confirm New PIN')
                          : 'Enter Security PIN',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: primaryTextColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _needsPinCreation
                    ? 'Set a 4-digit security PIN to protect and authorize your withdrawals'
                    : 'Enter your 4-digit security PIN to authorize ₦${_formatMoney(_enteredAmount)} payout',
                style: TextStyle(fontSize: 13, color: widget.isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),

              if (_pinError != null)
                _buildInViewErrorBanner(
                  message: _pinError!,
                  onDismiss: () => setState(() => _pinError = null),
                ),

              // PIN Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final activeLen = _needsPinCreation
                      ? (_pinInput.length < 4 ? _pinInput.length : _confirmNewPin.length)
                      : _pinInput.length;
                  final filled = index < activeLen;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? AppColors.brand : Colors.transparent,
                      border: Border.all(
                        color: filled
                            ? AppColors.brand
                            : (widget.isDark ? Colors.white38 : const Color(0xFFD1D5DB)),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 20),

              if (_isProcessing)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.brand),
                  ),
                )
              else ...[
                _buildModalKeypad(primaryTextColor),
                if (_needsPinCreation && _pinInput.length == 4 && _confirmNewPin.length == 4) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                      onPressed: _executeWithdrawal,
                      child: const Text('Confirm & Authorize Payout', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                    ),
                  ),
                ],
              ],
            ],

            // ── STEP 5: Withdrawal Success ──
            if (_step == 5) ...[
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.brand, size: 48),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Withdrawal Initiated!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: primaryTextColor),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  '₦${_formatMoney(_enteredAmount)} has been debited and queued for immediate settlement to $_selectedBankName.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: inputFill,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Reference ID', _createdTxReference, isBold: true),
                    const Divider(height: 16),
                    _buildSummaryRow('Destination', '$_selectedBankName (${_accountNumberController.text})'),
                    const Divider(height: 16),
                    _buildSummaryRow('Status', 'Processing Instant Payout', valueColor: AppColors.brand),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done & Return to Wallet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAmountChip(String label, double amount, {required bool isDark}) {
    final currentInput = double.tryParse(_amountController.text.trim().replaceAll(',', ''));
    final isSelected = currentInput != null && (currentInput - amount).abs() < 0.01;

    return InkWell(
      onTap: () {
        setState(() {
          _amountController.text = amount.toInt().toString();
          _amountError = null;
        });
      },
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brand
              : (isDark ? Colors.white10 : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? AppColors.brand
                : (isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white : const Color(0xFF374151)),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildModalKeypad(Color primaryTextColor) {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', 'backspace'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((key) {
                if (key.isEmpty) {
                  return const SizedBox(width: 72, height: 50);
                }
                if (key == 'backspace') {
                  return SizedBox(
                    width: 72,
                    height: 50,
                    child: IconButton(
                      onPressed: _handleKeypadBackspace,
                      icon: Icon(Icons.backspace_outlined, color: primaryTextColor, size: 22),
                    ),
                  );
                }
                return SizedBox(
                  width: 72,
                  height: 50,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _handleKeypadInput(key);
                    },
                    borderRadius: BorderRadius.circular(25),
                    child: Center(
                      child: Text(
                        key,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
