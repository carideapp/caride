import 'package:caride/features/profile/data/driver_public_profile_repository.dart';
import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class RateDriverScreen extends StatefulWidget {
  const RateDriverScreen({super.key, required this.rideId});

  /// The Firestore ride document ID.
  final String rideId;

  @override
  State<RateDriverScreen> createState() => _RateDriverScreenState();
}

class _RateDriverScreenState extends State<RateDriverScreen> {
  final RideRepository _rideRepository = RideRepository();
  final DriverPublicProfileRepository _driverProfileRepository = DriverPublicProfileRepository();
  final _commentController = TextEditingController();
  int _rating = 5;
  bool _submitting = false;

  Stream<DriverPublicProfile?>? _driverProfStream;
  String? _cachedDriverUid;

  void _updateDriverStream(String driverUid) {
    if (_cachedDriverUid != driverUid) {
      _cachedDriverUid = driverUid;
      _driverProfStream = driverUid.isEmpty
          ? Stream<DriverPublicProfile?>.value(null)
          : _driverProfileRepository.watchDriver(driverUid);
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await _rideRepository.rateDriver(
        rideId: widget.rideId,
        rating: _rating,
        comment: _commentController.text.trim(),
      );
      if (!mounted) return;
      await _showRateSuccessPopup();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit rating: ${e.toString()}'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showRateSuccessPopup() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(sheetContext).padding.bottom + 28),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 120,
                height: 120,
                child: Lottie.asset(
                  'lib/assets/lottie/Success.lottie',
                  fit: BoxFit.contain,
                  animate: true,
                  repeat: true,
                  decoder: (bytes) {
                    return LottieComposition.decodeZip(
                      bytes,
                      filePicker: (files) {
                        return files.firstWhere(
                          (f) => f.name.startsWith('animations/') && f.name.endsWith('.json'),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Thanks for your rating!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your honest feedback keeps the CaRide community safe and reliable for everyone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryTextColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 15,
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
    final inputBg = isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6);

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
                    'Rate Driver',
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
              child: StreamBuilder<RideModel?>(
                stream: _rideRepository.watchRide(widget.rideId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Unable to load ride right now.', style: TextStyle(color: secondaryTextColor)),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                      ),
                    );
                  }
                  final ride = snapshot.data;
                  if (ride == null) {
                    return Center(
                      child: Text('Ride not found.', style: TextStyle(color: secondaryTextColor)),
                    );
                  }

                  final driverName = (ride.driverName ?? '').trim();
                  final effectiveDriverName = driverName.isEmpty ? 'Driver' : driverName;
                  final avatarInitial =
                      effectiveDriverName.isEmpty ? '?' : effectiveDriverName.substring(0, 1).toUpperCase();

                  final alreadyRated = ride.driverRating != null || ride.ratedAt != null;
                  final displayFare = ride.finalFare ?? ride.amountNaira ?? ride.customerOffer;

                  final ratingValue = alreadyRated
                      ? ((ride.driverRating ?? _rating).clamp(1, 5))
                      : _rating;

                  final driverUid = ride.driverUid ?? '';
                  _updateDriverStream(driverUid);

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    children: [
                      const SizedBox(height: 10),
                      StreamBuilder<DriverPublicProfile?>(
                        stream: _driverProfStream,
                        builder: (context, driverSnap) {
                          final profile = driverSnap.data;
                          final photoUrl = profile?.profilePhotoUrl ?? '';
                          return Center(
                            child: CircleAvatar(
                              radius: 48,
                              backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                              backgroundColor: isDark ? Colors.white12 : const Color(0xFFF3F4F6),
                              child: photoUrl.isEmpty
                                  ? Text(
                                      avatarInitial,
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.w800,
                                        color: primaryTextColor,
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'How was your ride?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        alreadyRated
                            ? 'You already rated this trip.'
                            : 'Rate your journey with $effectiveDriverName',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Stars Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final value = index + 1;
                          final filled = value <= ratingValue;
                          return GestureDetector(
                            onTap: alreadyRated ? null : () => setState(() => _rating = value),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(
                                Icons.star_rounded,
                                size: 44,
                                color: filled ? const Color(0xFFF59E0B) : (isDark ? Colors.white12 : const Color(0xFFE5E7EB)),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),

                      if (!alreadyRated) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: inputBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                          ),
                          child: TextField(
                            controller: _commentController,
                            maxLines: 3,
                            style: TextStyle(fontSize: 14, color: primaryTextColor),
                            decoration: InputDecoration(
                              hintText: 'Leave a note about your experience (optional)',
                              hintStyle: TextStyle(fontSize: 13, color: secondaryTextColor),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ] else if (ride.driverRatingComment?.isNotEmpty ?? false) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                          ),
                          child: Text(
                            ride.driverRatingComment!,
                            style: TextStyle(fontSize: 14, color: primaryTextColor),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      _buildSummaryCard(
                        cardBg: cardBg,
                        borderColor: borderColor,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                        lines: [
                          ('Driver', effectiveDriverName),
                          ('Payment Method', _paymentMethodLabel(ride.paymentMethod)),
                          ('Trip Fare', _formatNaira(displayFare)),
                        ],
                      ),
                      const SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: (alreadyRated || _submitting) ? null : _submitRating,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            elevation: 0,
                            disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  alreadyRated ? 'Already Rated' : 'Submit Rating',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
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

  Widget _buildSummaryCard({
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required List<(String, String)> lines,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: lines.map((line) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  line.$1,
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryTextColor,
                  ),
                ),
                Text(
                  line.$2,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  String _paymentMethodLabel(String raw) {
    final cleaned = raw.trim().toLowerCase();
    return switch (cleaned) {
      'wallet' => 'CaRide Wallet',
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
}
