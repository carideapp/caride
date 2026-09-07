import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

class ShareReceiptScreen extends StatelessWidget {
  const ShareReceiptScreen({super.key, this.rideId});

  final String? rideId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rid = rideId;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip Receipt'),
      ),
      body: SafeArea(
        child: rid == null || rid.isEmpty
            ? const Center(
                child: EmptyState(
                  title: 'No ride selected',
                  message: 'Open a trip first to view its receipt.',
                  icon: Icons.receipt_long_rounded,
                ),
              )
            : StreamBuilder<RideModel?>(
                stream: RideRepository().watchRide(rid),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Unable to load receipt right now.',
                  style: theme.textTheme.bodyLarge,
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final ride = snapshot.data;
            if (ride == null) {
              return Center(
                child: Text(
                  'Ride not found.',
                  style: theme.textTheme.bodyLarge,
                ),
              );
            }

            final createdAt = ride.createdAt;
            final dateLabel = createdAt == null ? '--' : _formatDate(createdAt);
            final timeLabel = createdAt == null ? '--' : _formatTime(createdAt);
            final driverName = (ride.driverName ?? '').trim().isEmpty
                ? 'Driver'
                : ride.driverName!.trim();
            final displayFare = ride.finalFare ?? ride.amountNaira ?? ride.customerOffer;
            final paidChip = _paymentStatusLabel(ride.paymentStatus);

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ride Summary',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _summaryRow(
                              context,
                              'Pickup',
                              ride.pickupLabel.isEmpty ? 'Pickup' : ride.pickupLabel,
                            ),
                            _summaryRow(
                              context,
                              'Dropoff',
                              ride.dropoffLabel.isEmpty ? 'Dropoff' : ride.dropoffLabel,
                            ),
                            _summaryRow(context, 'Date', dateLabel),
                            _summaryRow(context, 'Time', timeLabel),
                            _summaryRow(context, 'Driver', driverName),
                            _summaryRow(
                              context,
                              'Payment',
                              _paymentMethodLabel(ride.paymentMethod),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Fare',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (paidChip != null)
                                  StatusChip(
                                    label: paidChip.$1,
                                    tone: paidChip.$2,
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _summaryRow(
                              context,
                              'Trip Fare',
                              _formatNaira(displayFare),
                            ),
                            const Divider(height: AppSpacing.lg),
                            _summaryRow(
                              context,
                              'Total Paid',
                              _formatNaira(displayFare),
                              emphasize: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
              ),
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context,
    String label,
    String value, {
    bool emphasize = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
                color: emphasize ? AppColors.primaryGreen : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _paymentMethodLabel(String raw) {
  final cleaned = raw.trim().toLowerCase();
  return switch (cleaned) {
    'wallet' => 'Wallet',
    'cash' => 'Cash',
    _ => raw.trim().isEmpty ? 'Payment' : raw.trim(),
  };
}

(String, StatusChipTone)? _paymentStatusLabel(String? raw) {
  final cleaned = raw?.trim().toLowerCase();
  if (cleaned == null || cleaned.isEmpty) return null;
  return switch (cleaned) {
    'paid' => ('Paid', StatusChipTone.success),
    'pending' => ('Pending', StatusChipTone.warning),
    _ => (cleaned, StatusChipTone.neutral),
  };
}

String _formatNaira(double value) {
  final rounded = value.round().toString();
  final withCommas = rounded.replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return '₦$withCommas';
}

String _formatDate(DateTime dt) {
  const months = <String>[
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
  final m = (dt.month >= 1 && dt.month <= 12) ? months[dt.month - 1] : '';
  return '$m ${dt.day}, ${dt.year}';
}

String _formatTime(DateTime dt) {
  final h = dt.hour;
  final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  final mm = dt.minute.toString().padLeft(2, '0');
  final ampm = h >= 12 ? 'PM' : 'AM';
  return '$hour12:$mm $ampm';
}
