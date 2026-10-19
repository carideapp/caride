import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:caride/features/driver/wallet/data/driver_wallet_repository.dart';

class DriverTransactionDetailsScreen extends StatelessWidget {
  const DriverTransactionDetailsScreen({
    super.key,
    required this.transaction,
  });

  final DriverWalletTransaction transaction;

  String _formatDateTime(DateTime dt) {
    return DateFormat('MMMM dd, yyyy • hh:mm a').format(dt);
  }

  String _formatMoney(double amount) {
    return NumberFormat('#,##0.00', 'en_US').format(amount);
  }

  String _getTransactionTitle() {
    final desc = transaction.description.toLowerCase();
    final type = transaction.type.toLowerCase();

    if (desc.contains('referral') || type.contains('referral')) {
      return 'Referral Commission';
    }
    if (desc.contains('cashback') || type.contains('cashback')) {
      return 'Cashback Reward';
    }
    if (desc.contains('top up') ||
        desc.contains('top-up') ||
        desc.contains('deposit') ||
        type == 'wallet_topup') {
      return 'Wallet Top Up';
    }
    if (desc.contains('withdrawal') ||
        desc.contains('payout') ||
        type == 'payout' ||
        type == 'debit') {
      return 'Wallet Withdrawal';
    }
    if (desc.contains('commission') || type.contains('commission')) {
      return 'Platform Commission';
    }
    return transaction.isCredit ? 'Trip Earnings' : 'Wallet Debit';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = _getTransactionTitle();
    final isCredit = transaction.isCredit;
    final amountSign = isCredit ? '+' : '-';
    final amountColor = isCredit ? AppColors.brand : AppColors.error;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
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
                    // Status Icon Badge
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isCredit
                            ? AppColors.brandGlass
                            : AppColors.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isCredit
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
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
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Completed successfully',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // Amount Display
                    Text(
                      '$amountSign₦${_formatMoney(transaction.amountNaira)}',
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
                      label: 'Payment Type',
                      value: isCredit ? 'Credit' : 'Debit',
                    ),
                    if (transaction.method != null &&
                        transaction.method!.isNotEmpty)
                      _buildDetailRow(
                        label: 'Payment Method',
                        value: transaction.method!,
                      ),
                    if (transaction.reference != null &&
                        transaction.reference!.isNotEmpty)
                      _buildDetailRow(
                        label: 'Reference',
                        value: transaction.reference!,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Transaction Description & Context Card
              GlassSurface(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transaction Summary',
                      style: AppTextStyles.titleMedium
                          .copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildDetailRow(
                      label: 'Description',
                      value: transaction.description.isNotEmpty
                          ? transaction.description
                          : (isCredit
                              ? 'Trip Earnings / Wallet Credit'
                              : 'Wallet Payout / Debit'),
                    ),
                  ],
                ),
              ),

              // Ride reference lookup if available
              if (transaction.reference != null &&
                  transaction.reference!.isNotEmpty)
                FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  future: FirebaseFirestore.instance
                      .collection('rides')
                      .doc(transaction.reference)
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }
                    if (snapshot.hasError ||
                        !snapshot.hasData ||
                        !snapshot.data!.exists) {
                      return const SizedBox.shrink();
                    }

                    final rideData = snapshot.data!.data() ?? {};
                    final pickup = (rideData['pickupLabel'] as String?) ??
                        (rideData['pickupName'] as String?) ??
                        'Pickup';
                    final dropoff = (rideData['dropoffLabel'] as String?) ??
                        (rideData['dropoffName'] as String?) ??
                        'Dropoff';
                    final customerName =
                        (rideData['customerName'] as String?) ?? 'Passenger';

                    return Column(
                      children: [
                        const SizedBox(height: AppSpacing.lg),
                        GlassSurface(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ride Information',
                                style: AppTextStyles.titleMedium
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _buildDetailRow(
                                  label: 'Passenger', value: customerName),
                              const Divider(height: AppSpacing.lg),
                              Text(
                                'Route Details',
                                style: AppTextStyles.bodyMedium
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.circle_outlined,
                                      size: 16, color: AppColors.brand),
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
                                  child: VerticalDivider(
                                      width: 2, color: Colors.grey),
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.location_on_rounded,
                                      size: 16, color: AppColors.error),
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
                        ),
                      ],
                    );
                  },
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
