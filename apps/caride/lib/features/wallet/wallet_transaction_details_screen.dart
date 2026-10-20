import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'data/wallet_transaction_repository.dart';

class WalletTransactionDetailsScreen extends StatelessWidget {
  const WalletTransactionDetailsScreen({
    super.key,
    required this.transaction,
  });

  final WalletTransaction transaction;

  String _formatDateTime(DateTime dt) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final day = dt.day;
    final month = months[dt.month - 1];
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$month $day, ${dt.year} at $hour:$minute $period';
  }

  String _getTransactionTitle() {
    final desc = transaction.description.toLowerCase();
    final rawType = transaction.rawType.toLowerCase();
    if (rawType == 'first_ride_cashback' || desc.contains('first ride')) {
      return 'First Ride Cashback';
    }
    if (rawType == 'cashback' ||
        rawType == 'trip_cashback' ||
        desc.contains('cashback')) {
      return 'Cashback Earnings';
    }
    if (rawType == 'referral' ||
        rawType.contains('referral') ||
        desc.contains('referral')) {
      return 'Referral Earnings';
    }
    if (desc.contains('top up') ||
        desc.contains('top-up') ||
        desc.contains('deposit') ||
        transaction.type == WalletTxType.credit) {
      return 'Wallet Top Up';
    }
    if (desc.contains('transfer to') ||
        desc.contains('withdrawal to') ||
        transaction.method == 'bank_transfer') {
      if (transaction.description.startsWith('Transfer to') ||
          transaction.description.startsWith('Withdrawal to')) {
        return transaction.description;
      }
      return 'Bank Transfer';
    }
    return 'Ride Payment';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = _getTransactionTitle();
    final isCredit = transaction.type == WalletTxType.credit;
    final amountSign = isCredit ? '+' : '-';
    final amountColor = isCredit ? AppColors.brand : AppColors.error;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: 'Transaction Details',
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
            vertical: AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Main Receipt Card
              GlassSurface(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isCredit ? AppColors.brandGlass : AppColors.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        color: amountColor,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      title,
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Completed successfully',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // Amount Display
                    Text(
                      '$amountSign₦${transaction.amountNaira.toStringAsFixed(2).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (m) => "${m[1]},")}',
                      style: AppTextStyles.displaySmall.copyWith(
                        fontWeight: FontWeight.w900,
                        color: amountColor,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    const Divider(),
                    const SizedBox(height: AppSpacing.md),
                    // Core Details List
                    _buildDetailRow(
                      label: 'Transaction ID',
                      value: transaction.id,
                    ),
                    _buildDetailRow(
                      label: 'Date & Time',
                      value: _formatDateTime(transaction.createdAt),
                    ),
                    _buildDetailRow(
                      label: 'Payment Method',
                      value: transaction.method.isNotEmpty ? transaction.method : 'E-Wallet',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Conditional Extra Details (Ride info, Referral info, or Description)
              if (title == 'Ride Payment' && transaction.reference.isNotEmpty)
                FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance.collection('rides').doc(transaction.reference).get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const GlassSurface(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: Center(child: AppLoader()),
                      );
                    }
                    if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                      return const SizedBox.shrink();
                    }

                    final rideData = snapshot.data!.data() ?? {};
                    final pickup = (rideData['pickupLabel'] as String?) ?? (rideData['pickupName'] as String?) ?? 'Pickup';
                    final dropoff = (rideData['dropoffLabel'] as String?) ?? (rideData['dropoffName'] as String?) ?? 'Dropoff';
                    final driverName = (rideData['driverName'] as String?) ?? 'CaRide Driver';
                    final customerName = (rideData['customerName'] as String?) ?? 'Passenger';

                    return GlassSurface(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ride Summary',
                            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          _buildDetailRow(label: 'Passenger', value: customerName),
                          _buildDetailRow(label: 'Driver', value: driverName),
                          const Divider(height: AppSpacing.lg),
                          Text(
                            'Route Details',
                            style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.circle_outlined, size: 16, color: AppColors.brand),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  pickup,
                                  style: AppTextStyles.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 7),
                            child: SizedBox(
                              height: 16,
                              child: VerticalDivider(width: 2, color: Colors.grey),
                            ),
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.location_on_rounded, size: 16, color: AppColors.error),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  dropoff,
                                  style: AppTextStyles.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                )
              else if (title == 'Cashback Earnings' || title == 'First Ride Cashback')
                GlassSurface(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cashback Reward Details',
                        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildDetailRow(
                        label: 'Reward Type',
                        value: transaction.description.isNotEmpty
                            ? transaction.description
                            : 'Cashback Bonus',
                      ),
                      _buildDetailRow(
                        label: 'Credited To',
                        value: (transaction.method.toLowerCase().contains('subsidy') ||
                                transaction.description.toLowerCase().contains('subsidy'))
                            ? 'CaRide Subsidy Wallet'
                            : 'In-App E-Wallet',
                      ),
                      if (transaction.reference.isNotEmpty)
                        _buildDetailRow(
                          label: 'Ride Reference',
                          value: transaction.reference,
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Congratulations! You received this cashback bonus into your wallet. You can use it towards your ride bookings or in-app transactions.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                )
              else if (title == 'Referral Earnings')
                GlassSurface(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Referral Summary',
                        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildDetailRow(
                        label: 'Description',
                        value: transaction.description.isNotEmpty
                            ? transaction.description
                            : 'Earning credited from referral trip',
                      ),
                    ],
                  ),
                )
              else
                GlassSurface(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transaction Summary',
                        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _buildDetailRow(
                        label: 'Description',
                        value: transaction.description.isNotEmpty
                            ? transaction.description
                            : 'Wallet credit top up',
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.grey,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
