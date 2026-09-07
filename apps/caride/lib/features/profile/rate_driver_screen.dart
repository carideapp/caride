import 'package:caride/features/profile/data/driver_public_profile_repository.dart';
import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_widgets/shared_widgets.dart';

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
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showRateSuccessPopup() async {
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: AppCard(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 130,
                  height: 130,
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
                            (f) =>
                                f.name.startsWith('animations/') &&
                                f.name.endsWith('.json'),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Thanks for your rating',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your feedback helps us improve every ride experience.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'OK',
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: StreamBuilder<RideModel?>(
          stream: _rideRepository.watchRide(widget.rideId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Unable to load ride right now.',
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
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                StreamBuilder<DriverPublicProfile?>(
                  stream: _driverProfStream,
                  builder: (context, driverSnap) {
                    final profile = driverSnap.data;
                    final photoUrl = profile?.profilePhotoUrl ?? '';
                    return Center(
                      child: CircleAvatar(
                        radius: 56,
                        backgroundImage: photoUrl.isNotEmpty
                            ? NetworkImage(photoUrl)
                            : null,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        child: photoUrl.isEmpty
                            ? Text(
                                avatarInitial,
                                style: theme.textTheme.displayLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'How was your driver?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  alreadyRated
                      ? 'You already rated this driver.'
                      : 'Rate your trip with $effectiveDriverName.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(5, (index) {
                    final value = index + 1;
                    final filled = value <= ratingValue;
                    return GestureDetector(
                      onTap: alreadyRated ? null : () => setState(() => _rating = value),
                      child: Icon(
                        Icons.star_rounded,
                        size: 46,
                        color: filled ? Colors.orange : const Color(0xFFE7E9EC),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: AppSpacing.md),
                if (!alreadyRated) ...[
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: TextField(
                      controller: _commentController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment (optional)',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ] else if (ride.driverRatingComment?.isNotEmpty ?? false) ...[
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        ride.driverRatingComment!,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                _SimpleSummaryCard(
                  lines: [
                    ('Driver', effectiveDriverName),
                    ('Payment', _paymentMethodLabel(ride.paymentMethod)),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _SimpleSummaryCard(
                  lines: [
                    ('Trip Fare', _formatNaira(displayFare)),
                    ('Total Paid', _formatNaira(displayFare)),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: alreadyRated
                      ? 'Rated'
                      : _submitting
                          ? 'Submitting...'
                          : 'Submit Rating',
                  onPressed: (alreadyRated || _submitting) ? null : _submitRating,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SimpleSummaryCard extends StatelessWidget {
  const _SimpleSummaryCard({required this.lines});

  final List<(String, String)> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: lines
            .map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        line.$1,
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    Text(
                      line.$2,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
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

String _formatNaira(double value) {
  final rounded = value.round().toString();
  final withCommas = rounded.replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return '₦$withCommas';
}
