import 'package:caride/core/config/app_config_repository.dart';
import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

/// Redesigned Customer Cancel Ride Screen.
class CancelRideScreen extends StatefulWidget {
  const CancelRideScreen({super.key, this.rideId});

  /// The Firestore ride document ID. If null the cancellation is local-only.
  final String? rideId;

  @override
  State<CancelRideScreen> createState() => _CancelRideScreenState();
}

class _CancelRideScreenState extends State<CancelRideScreen> {
  final RideRepository _rideRepository = RideRepository();
  final AppConfigRepository _configRepository = AppConfigRepository();

  String? _selectedReason;
  bool _cancelling = false;

  Future<void> _cancelRide() async {
    final reason = _selectedReason;
    if (reason == null) return;
    setState(() => _cancelling = true);
    try {
      final rideId = widget.rideId;
      if (rideId != null) {
        await _rideRepository.cancelRide(rideId, reason: reason);
      }
      if (!mounted) return;
      await _showCancelledBottomSheet();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _showCancelledBottomSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
        final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
        final cardBg = isDark ? AppColors.darkSurface : Colors.white;
        final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: borderColor)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(sheetContext).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Image.asset(
                'lib/assets/emoji/sad.png',
                width: 84,
                height: 84,
              ),
              const SizedBox(height: 18),
              Text(
                'Ride Cancelled',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We apologize for any inconvenience. We will continue to improve our service for your next trip.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryTextColor,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    context.go(CustomerRoutePaths.rideHistory);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: StreamBuilder<List<String>>(
          stream: _configRepository.watchCancelRideReasons(),
          initialData: AppConfigRepository.fallbackCancelReasons,
          builder: (context, snapshot) {
            final reasons = (snapshot.data == null || snapshot.data!.isEmpty)
                ? AppConfigRepository.fallbackCancelReasons
                : snapshot.data!;
            final hasReasons = reasons.isNotEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        'Cancel Ride',
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

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Please select the reason for cancellation:',
                        style: TextStyle(
                          fontSize: 14,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: !hasReasons
                      ? Center(
                          child: Text(
                            'No cancellation reasons configured.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: secondaryTextColor),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          itemCount: reasons.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final reason = reasons[index];
                            final selected = _selectedReason == reason;

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => setState(() => _selectedReason = reason),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: cardBg,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: selected ? AppColors.error : borderColor,
                                      width: selected ? 1.5 : 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: selected ? AppColors.error : secondaryTextColor.withValues(alpha: 0.5),
                                            width: 2,
                                          ),
                                        ),
                                        child: selected
                                            ? Center(
                                                child: Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: const BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: AppColors.error,
                                                  ),
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          reason,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                            color: primaryTextColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),

                // Confirm Cancellation Button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (!hasReasons || _selectedReason == null || _cancelling)
                          ? null
                          : _cancelRide,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        elevation: 0,
                        disabledBackgroundColor: AppColors.error.withValues(alpha: 0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: _cancelling
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              'Cancel Ride',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
