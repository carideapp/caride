import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:navigation/navigation.dart';

import '../../auth/controllers/fleet_auth_controller.dart';

/// Full Transaction History Screen for Fleet Manager
/// Strictly adhering to AGENTS.md:
/// - Circular 44x44 back button
/// - Flat minimalist cards without heavy glows
/// - Clean single-line transaction tiles
/// - Displays ALL transactions without filter chips
class FleetTransactionHistoryScreen extends StatefulWidget {
  const FleetTransactionHistoryScreen({super.key});

  @override
  State<FleetTransactionHistoryScreen> createState() => _FleetTransactionHistoryScreenState();
}

class _FleetTransactionHistoryScreenState extends State<FleetTransactionHistoryScreen> {
  final _firestore = FirebaseFirestore.instance;

  String _formatMoney(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return formatter.format(amount);
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recent';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      date = DateTime.tryParse(timestamp) ?? DateTime.now();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return 'Recent';
    }
    return DateFormat('MMM d, yyyy | h:mm a').format(date);
  }

  void _showTransactionDetailsSheet(Map<String, dynamic> tx, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cardBg = isDark ? AppColors.darkSurface : Colors.white;
        final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
        final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
        final inputFill = isDark ? AppColors.darkBackground : const Color(0xFFF3F4F6);

        final type = (tx['type'] as String? ?? 'booking').toLowerCase();
        final isDebit = type == 'withdrawal';
        final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
        final title = tx['title'] as String? ?? 'Transaction';
        final dateFormatted = _formatDate(tx['createdAt']);
        final reference = tx['reference'] as String? ?? (tx['id'] as String? ?? 'N/A');
        final bankName = tx['bankName'] as String?;
        final accountNumber = tx['accountNumber'] as String?;
        final accountName = tx['accountName'] as String?;

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag indicator (AGENTS.md Rule 2)
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Status Icon Badge
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isDebit
                      ? AppColors.error.withValues(alpha: 0.12)
                      : (type == 'referral'
                          ? const Color(0xFF3B82F6).withValues(alpha: 0.12)
                          : AppColors.brand.withValues(alpha: 0.12)),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDebit
                      ? Icons.arrow_outward_rounded
                      : (type == 'referral' ? Icons.card_giftcard_rounded : Icons.local_taxi_rounded),
                  color: isDebit
                      ? AppColors.error
                      : (type == 'referral' ? const Color(0xFF3B82F6) : AppColors.brand),
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),

              Text(
                '${isDebit ? '-' : '+'}₦${_formatMoney(amount)}',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: isDebit ? AppColors.error : primaryTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),

              // Detail Key-Value container
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: inputFill,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Reference', reference, primaryTextColor),
                    Divider(height: 20, color: borderColor),
                    _buildDetailRow('Date & Time', dateFormatted, primaryTextColor),
                    Divider(height: 20, color: borderColor),
                    _buildDetailRow('Status', 'Completed', AppColors.brand),
                    if (bankName != null && bankName.isNotEmpty) ...[
                      Divider(height: 20, color: borderColor),
                      _buildDetailRow('Bank Name', bankName, primaryTextColor),
                    ],
                    if (accountNumber != null && accountNumber.isNotEmpty) ...[
                      Divider(height: 20, color: borderColor),
                      _buildDetailRow('Account Number', accountNumber, primaryTextColor),
                    ],
                    if (accountName != null && accountName.isNotEmpty) ...[
                      Divider(height: 20, color: borderColor),
                      _buildDetailRow('Account Name', accountName, primaryTextColor),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                    foregroundColor: primaryTextColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor),
        ),
      ],
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

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
          body: SafeArea(
            child: Column(
              children: [
                // ── Top Bar with Circular Back Button (AGENTS.md Rule 2) ──
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
                          icon: Icon(Icons.arrow_back, color: primaryTextColor, size: 20),
                          onPressed: () => context.pop(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Transaction History',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── All Transactions List (No Filters per User Directive) ──
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: fleetId.isNotEmpty
                        ? _firestore
                            .collection('fleets')
                            .doc(fleetId)
                            .collection('transactions')
                            .orderBy('createdAt', descending: true)
                            .limit(100)
                            .snapshots()
                        : null,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: AppColors.brand, strokeWidth: 2.5),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];

                      if (docs.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 64),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.receipt_long_rounded,
                                  size: 40,
                                  color: AppColors.brand,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'No Transactions Yet',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'All your booking payments, referral earnings, and fund withdrawals will appear here.',
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: docs.length,
                        separatorBuilder: (ctx, i) => const SizedBox(height: 10),
                        itemBuilder: (ctx, index) {
                          final tx = docs[index].data();
                          final type = (tx['type'] as String? ?? 'booking').toLowerCase();
                          final isDebit = type == 'withdrawal';
                          final title = tx['title'] as String? ??
                              (type == 'withdrawal'
                                  ? 'Wallet Withdrawal'
                                  : (type == 'referral'
                                      ? 'Referral Commission'
                                      : 'Booking Payment'));
                          final amount = (tx['amount'] as num?)?.toDouble() ?? 0.0;
                          final dateFormatted = _formatDate(tx['createdAt']);

                          Color iconColor;
                          Color iconBg;
                          IconData iconData;
                          String badgeLabel;
                          Color badgeColor;

                          if (type == 'withdrawal') {
                            iconBg = const Color(0xFFFEF2F2);
                            iconColor = AppColors.error;
                            iconData = Icons.arrow_outward_rounded;
                            badgeLabel = 'Withdrawal';
                            badgeColor = AppColors.error;
                          } else if (type == 'referral') {
                            iconBg = const Color(0xFFEFF6FF);
                            iconColor = const Color(0xFF3B82F6);
                            iconData = Icons.card_giftcard_rounded;
                            badgeLabel = 'Referral';
                            badgeColor = const Color(0xFF3B82F6);
                          } else {
                            iconBg = isDark ? const Color(0xFF14301D) : const Color(0xFFF0FDF4);
                            iconColor = AppColors.brand;
                            iconData = Icons.local_taxi_rounded;
                            badgeLabel = 'Booking';
                            badgeColor = AppColors.brand;
                          }

                          return InkWell(
                            onTap: () => _showTransactionDetailsSheet(tx, isDark),
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: isDark ? iconColor.withValues(alpha: 0.15) : iconBg,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(iconData, color: iconColor, size: 20),
                                  ),
                                  const SizedBox(width: 14),
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
                            ),
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
      },
    );
  }
}
