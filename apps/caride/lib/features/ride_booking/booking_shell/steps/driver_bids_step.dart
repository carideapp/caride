import 'dart:async';
import 'package:caride/core/models/ride_viewer.dart';
import 'package:caride/features/profile/data/account_repository.dart';
import 'package:caride/features/profile/data/driver_public_profile_repository.dart';
import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:caride/features/ride_booking/booking_shell/models/booking_shell_step.dart';
import 'package:caride/features/ride_booking/booking_shell/widgets/cancel_ride_bottom_sheet.dart';
import 'package:caride/features/ride_booking/booking_shell/widgets/stacked_driver_avatars.dart';
import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer Bids Step displaying incoming bids from nearby drivers.
class DriverBidsStep extends StatefulWidget {
  const DriverBidsStep({super.key, required this.controller});

  final BookingShellController controller;

  @override
  State<DriverBidsStep> createState() => _DriverBidsStepState();
}

class _DriverBidsStepState extends State<DriverBidsStep> {
  Timer? _timer;
  int _secondsRemaining = 120;
  DateTime? _lastTickTime;
  bool _dialogShown = false;
  List<DriverBid> _lastActiveBids = const [];
  double _walletBalance = double.infinity; // default to large so we don't block before load
  double _creditBalance = 0.0;
  StreamSubscription<AccountProfile?>? _profileSub;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _profileSub = AccountRepository().watchProfile().listen((profile) {
      if (mounted && profile != null) {
        setState(() {
          _walletBalance = profile.walletBalance;
          _creditBalance = profile.creditBalance;
        });
      }
    });
  }

  void _startTimer() {
    _lastTickTime = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      final now = DateTime.now();
      final delta = _lastTickTime != null ? now.difference(_lastTickTime!).inSeconds : 1;
      _lastTickTime = now;

      if (_lastActiveBids.isEmpty) {
        if (_secondsRemaining > 0) {
          _secondsRemaining = (_secondsRemaining - delta).clamp(0, 120);
          if (_secondsRemaining == 0 && !_dialogShown) {
            _dialogShown = true;
            _timer?.cancel();
            _showNoDriversDialog();
          }
        }
      }

      setState(() {});
    });
  }

  void _showNoDriversDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassSurface(
            radius: AppRadius.xl,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.no_accounts_rounded,
                    color: AppColors.error,
                    size: 32,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No Drivers Nearby',
                  style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'There are currently no drivers within your region or close to you. Please cancel the ride and try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: 'Okay',
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      if (mounted) {
                        CancelRideBottomSheet.show(
                          context,
                          controller: widget.controller,
                          closeOnCancel: false,
                        ).then((_) {
                          if (mounted && widget.controller.step == BookingShellStep.bids) {
                            setState(() {
                              _secondsRemaining = 120;
                              _dialogShown = false;
                              _startTimer();
                            });
                          }
                        });
                      }
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

  @override
  void dispose() {
    _timer?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stream = widget.controller.bidsStream;
    final ride = widget.controller.ride;
    final driverProfileRepo = DriverPublicProfileRepository();
    final canCancel = ride != null &&
        BookingShellController.customerCanCancelStatus(ride.status);
    if (stream == null) {
      return Center(
        child: Text(
          'No ride request yet.',
          style: AppTextStyles.bodyLarge,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Driver bids',
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: StreamBuilder<List<DriverBid>>(
            stream: stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Text(
                      'Unable to load bids: ${snap.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              }
              if (!snap.hasData) {
                return const Center(child: AppLoader());
              }
              final allBids = snap.data!;
              final bids = allBids.where((b) {
                return !b.isExpired && b.status != 'declined' && b.status != 'expired';
              }).toList();

              _lastActiveBids = bids;

              return StreamBuilder<List<RideViewer>>(
                stream: RideRepository().watchRideViewers(ride!.id),
                builder: (context, viewerSnap) {
                  final viewers = viewerSnap.data ?? [];

                  if (bids.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const _RadarScanAnimation(),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Searching for drivers...',
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (viewers.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.md),
                            StackedDriverAvatars(viewers: viewers, isDark: isDark),
                          ],
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Remaining: ${_secondsRemaining}s',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      if (viewers.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: StackedDriverAvatars(viewers: viewers, isDark: isDark),
                        ),
                      Expanded(
                        child: ListView.separated(
                          itemCount: bids.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, i) {
                            final b = bids[i];
                            return GlassContainer(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  StreamBuilder<DriverPublicProfile?>(
                                    stream: driverProfileRepo.watchDriver(b.driverUid),
                                    builder: (context, driverSnap) {
                                      final profile = driverSnap.data;
                                      final photoUrl = profile?.profilePhotoUrl ?? '';
                                      final completedCount = profile?.completedRides ?? 0;
                                      return Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundImage: photoUrl.isNotEmpty
                                                ? NetworkImage(photoUrl)
                                                : null,
                                            backgroundColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F5F9),
                                            child: photoUrl.isEmpty
                                                ? Text(
                                                    b.driverName.isEmpty ? '?' : b.driverName[0].toUpperCase(),
                                                    style: AppTextStyles.titleMedium.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  b.driverName,
                                                  style: AppTextStyles.bodyLarge.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.star_rounded, size: 16, color: Colors.orange),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      '${b.driverRating.toStringAsFixed(1)} ($completedCount)',
                                                      style: AppTextStyles.bodyMedium.copyWith(
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    const SizedBox(width: AppSpacing.sm),
                                                    Text(
                                                      '·  ${b.etaMinutes} min away',
                                                      style: AppTextStyles.bodySmall.copyWith(
                                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '₦${b.offerNaira.toStringAsFixed(0)}',
                                                  style: AppTextStyles.displaySmall.copyWith(
                                                    fontSize: 26,
                                                    color: AppColors.brand,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: -0.5,
                                                  ),
                                                ),
                                                if (widget.controller.useCreditWallet) ...[
                                                  const SizedBox(height: 4),
                                                  Builder(
                                                    builder: (context) {
                                                      final maxDisc = b.offerNaira * 0.10;
                                                      final disc = _creditBalance < maxDisc ? _creditBalance : maxDisc;
                                                      final payable = (b.offerNaira - disc).clamp(0.0, double.infinity);
                                                      return Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.stars_rounded, size: 13, color: Color(0xFF10B981)),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              '-₦${disc.toStringAsFixed(0)} Credit (Pay ₦${payable.toStringAsFixed(0)})',
                                                              style: const TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.bold,
                                                                color: Color(0xFF10B981),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.only(left: AppSpacing.xs),
                                            child: Image.asset(
                                              'lib/assets/caride_branded/branded_caride_car.png',
                                              width: 90,
                                              height: 65,
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SecondaryButton(
                                          label: 'Decline',
                                          onPressed: () => widget.controller.declineBid(b.id),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: _AcceptBidButton(
                                          bid: b,
                                          walletBalance: _walletBalance,
                                          onAccept: () async {
                                            await widget.controller.acceptBid(b);
                                            HapticFeedback.lightImpact();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
        if (canCancel) ...[
          const SizedBox(height: AppSpacing.sm),
          SecondaryButton(
            label: 'Cancel Ride',
            onPressed: () =>
                CancelRideBottomSheet.show(context, controller: widget.controller, closeOnCancel: true),
          ),
        ],
      ],
    );
  }
}

class _RadarScanAnimation extends StatefulWidget {
  const _RadarScanAnimation();

  @override
  State<_RadarScanAnimation> createState() => _RadarScanAnimationState();
}

class _RadarScanAnimationState extends State<_RadarScanAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const color = AppColors.brand;

    return Center(
      child: SizedBox(
        width: 120,
        height: 120,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final value = _controller.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: (1.0 - value).clamp(0.0, 1.0),
                  child: Container(
                    width: 40 + (80 * value),
                    height: 40 + (80 * value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha: 0.25), width: 2),
                    ),
                  ),
                ),
                Opacity(
                  opacity: (1.0 - ((value + 0.5) % 1.0)).clamp(0.0, 1.0),
                  child: Container(
                    width: 40 + (80 * ((value + 0.5) % 1.0)),
                    height: 40 + (80 * ((value + 0.5) % 1.0)),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
                    ),
                  ),
                ),
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.brandGlass,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.radar_rounded,
                    color: color,
                    size: 26,
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

/// A smart Accept button that is disabled (with a shortfall note) when the
/// driver's bid exceeds the customer's wallet balance.
class _AcceptBidButton extends StatefulWidget {
  const _AcceptBidButton({
    required this.bid,
    required this.walletBalance,
    required this.onAccept,
  });

  final DriverBid bid;
  final double walletBalance;
  final Future<void> Function() onAccept;

  @override
  State<_AcceptBidButton> createState() => _AcceptBidButtonState();
}

class _AcceptBidButtonState extends State<_AcceptBidButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final canAfford = widget.bid.offerNaira <= widget.walletBalance;
    final shortfall = widget.bid.offerNaira - widget.walletBalance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton(
          label: 'Accept',
          isLoading: _loading,
          onPressed: (canAfford && !_loading)
              ? () async {
                  setState(() => _loading = true);
                  try {
                    await widget.onAccept();
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                }
              : null,
        ),
        if (!canAfford) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_balance_wallet_outlined, size: 12, color: AppColors.error),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Need ₦${shortfall.toStringAsFixed(0)} more',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
