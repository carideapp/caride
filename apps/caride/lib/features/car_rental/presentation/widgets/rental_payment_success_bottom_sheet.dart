import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';

/// Modal bottom sheet presented upon successful payment of a rental booking.
/// Follows CaRide brand guidelines: emerald brand colors, pill geometry, zero heavy glows,
/// clean card borders, and clear PIN presentation.
class RentalPaymentSuccessBottomSheet extends StatefulWidget {
  const RentalPaymentSuccessBottomSheet({
    super.key,
    required this.booking,
    required this.pin,
    this.onViewBookings,
  });

  final RentalBooking booking;
  final String pin;
  final VoidCallback? onViewBookings;

  static Future<void> show(
    BuildContext context, {
    required RentalBooking booking,
    required String pin,
    VoidCallback? onViewBookings,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => RentalPaymentSuccessBottomSheet(
        booking: booking,
        pin: pin,
        onViewBookings: onViewBookings,
      ),
    );
  }

  @override
  State<RentalPaymentSuccessBottomSheet> createState() =>
      _RentalPaymentSuccessBottomSheetState();
}

class _RentalPaymentSuccessBottomSheetState
    extends State<RentalPaymentSuccessBottomSheet> {
  bool _showPin = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag pill handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Success check circle badge
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.brand,
                  size: 44,
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'Payment Confirmed!',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Your rental reservation for ${widget.booking.vehicleTitle} is now booked and confirmed.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: secondaryTextColor,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),

              // Ride Start PIN Card
              if (widget.pin.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBackground
                        : const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.brand.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.vpn_key_rounded,
                              color: AppColors.brand, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Ride Start PIN',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isDark ? Colors.white : AppColors.brand,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () {
                          setState(() => _showPin = !_showPin);
                          HapticFeedback.lightImpact();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white12
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _showPin ? widget.pin : '• • • •',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: _showPin ? 8 : 4,
                                  color: primaryTextColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                _showPin
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: secondaryTextColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Provide this 4-digit PIN to your chauffeur driver when they arrive to begin your rental trip.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: secondaryTextColor,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Action button - View Rental Bookings
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context, rootNavigator: true).pop();
                    if (widget.onViewBookings != null) {
                      widget.onViewBookings!();
                    } else {
                      context.go(CustomerRoutePaths.rentalBookings);
                    }
                  },
                  child: const Text(
                    'View Rental Bookings',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
