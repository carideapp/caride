import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Redesigned Customer Trip Receipt Screen adhering to CaRide Profile standards.
class ShareReceiptScreen extends StatelessWidget {
  const ShareReceiptScreen({super.key, this.rideId});

  final String? rideId;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final rid = rideId;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 14, bottom: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Trip Receipt',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: rid == null || rid.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.receipt_long_rounded, size: 48, color: AppColors.brand),
                            const SizedBox(height: 16),
                            Text(
                              'No Ride Selected',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Open a trip first to view its detailed receipt.',
                              style: TextStyle(fontSize: 14, color: secondaryTextColor),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : StreamBuilder<RideModel?>(
                      stream: RideRepository().watchRide(rid),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Unable to load receipt right now.',
                              style: TextStyle(color: primaryTextColor),
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator(color: AppColors.brand));
                        }
                        final ride = snapshot.data;
                        if (ride == null) {
                          return Center(
                            child: Text(
                              'Ride not found.',
                              style: TextStyle(color: primaryTextColor),
                            ),
                          );
                        }

                        final createdAt = ride.createdAt;
                        final dateLabel = createdAt == null ? '--' : _formatDate(createdAt);
                        final timeLabel = createdAt == null ? '--' : _formatTime(createdAt);
                        final driverName = (ride.driverName ?? '').trim().isEmpty
                            ? 'Driver'
                            : ride.driverName!.trim();
                        final displayFare =
                            ride.finalFare ?? ride.amountNaira ?? ride.customerOffer;
                        final isPaid = (ride.paymentStatus ?? '').toLowerCase() == 'paid';

                        return ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          children: [
                            // Summary Card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Ride Summary',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w800,
                                      color: primaryTextColor,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _summaryRow('Pickup', ride.pickupLabel.isEmpty ? 'Pickup' : ride.pickupLabel, primaryTextColor, secondaryTextColor),
                                  const SizedBox(height: 12),
                                  _summaryRow('Dropoff', ride.dropoffLabel.isEmpty ? 'Dropoff' : ride.dropoffLabel, primaryTextColor, secondaryTextColor),
                                  const SizedBox(height: 12),
                                  _summaryRow('Date', dateLabel, primaryTextColor, secondaryTextColor),
                                  const SizedBox(height: 12),
                                  _summaryRow('Time', timeLabel, primaryTextColor, secondaryTextColor),
                                  const SizedBox(height: 12),
                                  _summaryRow('Driver', driverName, primaryTextColor, secondaryTextColor),
                                  const SizedBox(height: 12),
                                  _summaryRow('Payment', _paymentMethodLabel(ride.paymentMethod), primaryTextColor, secondaryTextColor),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Fare Card
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Fare Breakdown',
                                          style: TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: primaryTextColor,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isPaid
                                              ? AppColors.brand.withValues(alpha: 0.12)
                                              : (isDark ? Colors.white10 : const Color(0xFFF3F4F6)),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          isPaid ? 'PAID' : (ride.paymentStatus ?? 'PENDING').toUpperCase(),
                                          style: TextStyle(
                                            color: isPaid ? AppColors.brand : secondaryTextColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _summaryRow('Trip Fare', _formatNaira(displayFare), primaryTextColor, secondaryTextColor),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Divider(height: 1, color: borderColor),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Total Paid',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                      Text(
                                        _formatNaira(displayFare),
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.brand,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color primaryTextColor, Color secondaryTextColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: secondaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primaryTextColor,
            ),
          ),
        ),
      ],
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
