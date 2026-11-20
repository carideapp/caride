import 'dart:async';

import 'package:caride/core/config/app_config_repository.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/core/driver/models/ride_model.dart';
import 'package:caride/core/driver/notifications/driver_alert_controller.dart';
import 'package:caride/core/driver/state/driver_active_ride_state.dart';
import 'package:caride/core/driver/utils/distance_helper.dart';
import 'package:caride/features/driver/auth/data/driver_profile_repository.dart';
import 'package:caride/features/driver/location/data/driver_presence_repository.dart';
import 'package:caride/features/driver/ride/data/driver_ride_repository.dart';
import 'package:caride/features/driver/widgets/driver_counter_offer_bottom_sheet.dart';
import 'package:caride/features/driver/widgets/driver_debt_prompt_bottom_sheet.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Prominent in-app incoming ride request alert shown while the driver is active
/// in the app. Pairs with [DriverAlertAudioService] and automatically dismisses
/// when accepted, declined, cancelled, expired, or claimed by another driver.
class IncomingRideAlertModal extends StatefulWidget {
  const IncomingRideAlertModal({
    super.key,
    required this.initialRide,
    this.distanceKm,
  });

  final RideModel initialRide;
  final double? distanceKm;

  static Future<void> show(
    BuildContext context, {
    required RideModel initialRide,
    double? distanceKm,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) => IncomingRideAlertModal(
        initialRide: initialRide,
        distanceKm: distanceKm,
      ),
    );
  }

  @override
  State<IncomingRideAlertModal> createState() => _IncomingRideAlertModalState();
}

class _IncomingRideAlertModalState extends State<IncomingRideAlertModal>
    with SingleTickerProviderStateMixin {
  final _rideRepo = DriverRideRepository();
  final _profileRepo = DriverProfileRepository();
  final _presenceRepo = DriverPresenceRepository();

  late final AnimationController _pulseController;
  late final DateTime _deadline;
  Timer? _countdownTimer;
  Duration _remaining = DriverAlertController.alertTtl;
  bool _submitting = false;
  bool _declining = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    final now = DateTime.now();
    final expiresAt = widget.initialRide.expiresAt;
    if (expiresAt != null && expiresAt.isAfter(now)) {
      final diff = expiresAt.difference(now);
      _remaining = diff < DriverAlertController.alertTtl
          ? diff
          : DriverAlertController.alertTtl;
    }
    _deadline = now.add(_remaining);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final left = _deadline.difference(DateTime.now());
      if (left <= Duration.zero) {
        _dismissSafely();
        return;
      }
      setState(() => _remaining = left);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _dismissSafely() {
    if (_closing || !mounted) return;
    _closing = true;
    Navigator.of(context, rootNavigator: true).maybePop();
  }

  Future<bool> _checkDebtLimit() async {
    final uid = driverAuthController.currentUid;
    if (uid == null) return false;
    final profile = await _profileRepo.getDriverProfile(uid);
    final settings = await AppConfigRepository().getDriverSettings();
    final balance = profile?.walletBalance ?? 0.0;
    if (balance <= -settings.maxNegativeBalanceNaira) {
      if (mounted) {
        await DriverDebtPromptBottomSheet.show(
          context,
          currentBalance: balance,
          maxNegativeBalance: settings.maxNegativeBalanceNaira,
        );
      }
      return true;
    }
    return false;
  }

  Future<void> _placeBid(RideModel ride, double amount) async {
    if (_submitting || _declining) return;
    final uid = driverAuthController.currentUid;
    if (uid == null) return;

    final restricted = await _checkDebtLimit();
    if (restricted || !mounted) return;

    setState(() => _submitting = true);
    try {
      final profile = await _profileRepo.getDriverProfile(uid);
      final presence = await _presenceRepo.getPresence();

      int eta = 5;
      if (presence?.latitude != null &&
          presence?.longitude != null &&
          ride.pickupLat != null &&
          ride.pickupLng != null) {
        final dist = calculateDistance(
          presence!.latitude!,
          presence.longitude!,
          ride.pickupLat!,
          ride.pickupLng!,
        );
        eta = estimateEtaMinutes(dist);
      }

      await _rideRepo.placeBid(
        rideId: ride.id,
        driverName: profile?.fullName ?? 'Driver',
        offerNaira: amount,
        etaMinutes: eta,
        driverRating: profile?.rating ?? 0.0,
        driverRides: profile?.completedRides ?? 0,
      );

      DriverAlertController.instance.resolveRide(ride.id);
      if (!mounted) return;

      final rootNav = Navigator.of(context, rootNavigator: true);
      final messenger = ScaffoldMessenger.maybeOf(context);
      _closing = true;
      rootNav.pop();
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Bid sent! Waiting for customer response.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text('Failed to place bid: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openCounterSheet(RideModel ride) async {
    if (_submitting || _declining) return;
    DriverAlertController.instance.silenceAudio(rideId: ride.id);
    final restricted = await _checkDebtLimit();
    if (restricted || !mounted) return;

    await DriverCounterOfferBottomSheet.show(
      context: context,
      customerOffer: ride.customerOffer,
      onSubmit: (amount) => _placeBid(ride, amount),
    );
  }

  Future<void> _declineRide(RideModel ride) async {
    if (_declining || _submitting) return;
    setState(() => _declining = true);
    try {
      await DriverAlertController.instance.declineRide(ride.id);
    } finally {
      _dismissSafely();
    }
  }

  void _openDetails(RideModel ride) {
    DriverAlertController.instance.stopAlert(rideId: ride.id);
    DriverActiveRideState.instance.selectedRide = ride;
    final router = GoRouter.of(context);
    _dismissSafely();
    router.push(DriverRoutePaths.requestDetailFor(ride.id));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF121821) : Colors.white;
    final cardColor = isDark
        ? const Color(0xFF1A222E)
        : const Color(0xFFF6F8FA);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);
    final secondaryText = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF475569);

    return StreamBuilder<RideModel?>(
      stream: _rideRepo.streamRide(widget.initialRide.id),
      initialData: widget.initialRide,
      builder: (context, snapshot) {
        final ride = snapshot.data;
        final bool isExpired =
            ride?.expiresAt != null &&
            !ride!.expiresAt!.isAfter(DateTime.now());
        final bool noLongerOpen =
            ride == null ||
            (ride.status != 'searching' &&
                ride.status != 'requested' &&
                ride.status != 'bidding') ||
            isExpired;

        if (noLongerOpen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            DriverAlertController.instance.stopAlert(
              rideId: widget.initialRide.id,
            );
            _dismissSafely();
          });
          return const SizedBox.shrink();
        }

        final distKm = widget.distanceKm;
        final totalSecs = DriverAlertController.alertTtl.inSeconds;
        final secsLeft = _remaining.inSeconds.clamp(0, totalSecs);
        final progress = (secsLeft / totalSecs).clamp(0.0, 1.0);

        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.lg,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(AppRadius.xxxl),
                border: Border.all(
                  color: AppColors.brand.withValues(alpha: 0.45),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      ScaleTransition(
                        scale: Tween<double>(begin: 0.92, end: 1.08).animate(
                          CurvedAnimation(
                            parent: _pulseController,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_active_rounded,
                            color: AppColors.brand,
                            size: 24,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Incoming ${ride.rideType} Request',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Tap Accept or Counter before time runs out',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: secsLeft <= 10
                              ? AppColors.error.withValues(alpha: 0.14)
                              : AppColors.brand.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${secsLeft}s',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: secsLeft <= 10
                                ? AppColors.error
                                : AppColors.brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: borderColor,
                      color: secsLeft <= 10 ? AppColors.error : AppColors.brand,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Customer Offer',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: secondaryText,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    NgnFormat.whole(ride.customerOffer),
                                    style: theme.textTheme.headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.brand,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: surfaceColor,
                                borderRadius: BorderRadius.circular(
                                  AppRadius.sm,
                                ),
                                border: Border.all(color: borderColor),
                              ),
                              child: Text(
                                ride.paymentMethod.toUpperCase(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (distKm != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              const Icon(
                                Icons.near_me_rounded,
                                size: 14,
                                color: AppColors.brand,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${distKm.toStringAsFixed(1)} km away • ~${estimateEtaMinutes(distKm)} min pickup',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: secondaryText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        _RoutePointRow(
                          dotColor: AppColors.brand,
                          label: 'PICKUP',
                          address: ride.pickupLabel,
                          secondaryText: secondaryText,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _RoutePointRow(
                          dotColor: AppColors.error,
                          label: 'DROPOFF',
                          address: ride.dropoffLabel,
                          secondaryText: secondaryText,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label:
                        'Accept ${ride.customerOffer > 0 ? NgnFormat.whole(ride.customerOffer) : "Offer"}',
                    showShadow: false,
                    isLoading: _submitting,
                    onPressed: _declining
                        ? null
                        : () => _placeBid(ride, ride.customerOffer),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Counter',
                          onPressed: _submitting || _declining
                              ? null
                              : () => _openCounterSheet(ride),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: SecondaryButton(
                          label: 'Details',
                          onPressed: _submitting || _declining
                              ? null
                              : () => _openDetails(ride),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextButton(
                    onPressed: _submitting || _declining
                        ? null
                        : () => _declineRide(ride),
                    child: Text(
                      _declining ? 'Declining...' : 'Decline Request',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoutePointRow extends StatelessWidget {
  const _RoutePointRow({
    required this.dotColor,
    required this.label,
    required this.address,
    required this.secondaryText,
  });

  final Color dotColor;
  final String label;
  final String address;
  final Color secondaryText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: secondaryText,
                  fontSize: 10,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
