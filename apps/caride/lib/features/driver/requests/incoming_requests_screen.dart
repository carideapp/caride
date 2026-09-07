import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/core/driver/models/driver_presence.dart';
import 'package:caride/core/driver/models/ride_model.dart';
import 'package:caride/core/driver/models/bid_model.dart';
import 'package:caride/core/driver/state/driver_active_ride_state.dart';
import 'package:caride/features/driver/auth/data/driver_profile_repository.dart';
import 'package:caride/features/driver/location/data/driver_presence_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:caride/features/driver/ride/data/driver_ride_repository.dart';
import 'package:caride/features/ride_booking/data/ride_repository.dart' hide RideModel;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:caride/core/driver/notifications/driver_alert_controller.dart';
import 'package:caride/core/driver/utils/distance_helper.dart';

class IncomingRequestsScreen extends StatefulWidget {
  const IncomingRequestsScreen({super.key});

  @override
  State<IncomingRequestsScreen> createState() => _IncomingRequestsScreenState();
}

class _IncomingRequestsScreenState extends State<IncomingRequestsScreen> {
  final Set<String> _declinedRideIds = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final rideRepo = DriverRideRepository();
    final presenceRepo = DriverPresenceRepository();

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.notifications_active_outlined, color: AppColors.primaryGreen),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'New Requests',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<DriverPresence?>(
          stream: presenceRepo.streamPresence(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final presence = snapshot.data;
            if (presence == null || presence.isOffline) {
              return Center(
                child: EmptyState(
                  title: 'You are offline',
                  message:
                      'Go online from the Drive screen before ride requests can reach you.',
                  icon: Icons.wifi_off_rounded,
                  iconWidget: Image.asset(
                    'lib/assets/icons/internet.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            }

            if ((presence.approvalStatusSnapshot ?? '') != 'approved') {
              return const Center(
                child: EmptyState(
                  title: 'Verification required',
                  message:
                      'Your account must be approved before you can receive ride requests.',
                  icon: Icons.verified_user_outlined,
                ),
              );
            }

            if (presence.isOnTrip || presence.currentRideId != null) {
              return Center(
                child: EmptyState(
                  title: 'Ride in progress',
                  message:
                      'Finish your current trip before you can receive another ride request.',
                  icon: Icons.directions_car_filled_outlined,
                  iconWidget: Image.asset(
                    'lib/assets/icons/internet.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            }

            return StreamBuilder<List<RideModel>>(
              stream: rideRepo.streamAvailableRides(
                enabled: presence.isAvailableForRequests,
                vehicleType: presence.vehicleType,
                driverLat: presence.latitude,
                driverLng: presence.longitude,
              ),
              builder: (context, rideSnapshot) {
                if (rideSnapshot.hasError) {
                  debugPrint('IncomingRequestsScreen stream error: ${rideSnapshot.error}');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Text(
                        'Error loading requests: ${rideSnapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  );
                }

                if (rideSnapshot.connectionState == ConnectionState.waiting &&
                    !rideSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final allRides = rideSnapshot.data ?? [];
                _declinedRideIds.removeWhere((id) => !allRides.any((r) => r.id == id));
                final visibleRides =
                    allRides.where((r) => !_declinedRideIds.contains(r.id)).toList();

                DriverAlertController.instance.onRidesUpdated(
                  visibleRides,
                  driverLat: presence.latitude,
                  driverLng: presence.longitude,
                );

                if (visibleRides.isNotEmpty) {
                  final driverUid = FirebaseAuth.instance.currentUser?.uid;
                  if (driverUid != null) {
                    DriverProfileRepository().getDriverProfile(driverUid).then((profile) {
                      if (profile != null) {
                        for (final ride in visibleRides.take(5)) {
                          RideRepository().updateDriverRideViewerPresence(
                            rideId: ride.id,
                            driverUid: profile.uid,
                            driverName: profile.fullName,
                            profilePhotoUrl: profile.profilePhotoUrl,
                          );
                        }
                      }
                    });
                  }
                }
                if (visibleRides.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () async {
                      await Future.delayed(const Duration(milliseconds: 800));
                    },
                    child: Stack(
                      children: [
                        Center(
                          child: Lottie.asset(
                            'lib/assets/lottie/Scan_&_Search_Animation.lottie',
                            width: 260,
                            height: 260,
                            fit: BoxFit.contain,
                            decoder: (bytes) {
                              return LottieComposition.decodeZip(bytes, filePicker: (files) {
                                return files.firstWhere(
                                  (f) => f.name.startsWith('animations/') && f.name.endsWith('.json'),
                                );
                              });
                            },
                          ),
                        ),
                        Positioned(
                          left: AppSpacing.xl,
                          right: AppSpacing.xl,
                          bottom: AppSpacing.xxl + AppSpacing.md,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Searching for rides...',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                  fontWeight: FontWeight.w800,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'New ride requests will appear here.\nKeep the app open and stay online.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.8,
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    await Future.delayed(const Duration(milliseconds: 800));
                  },
                  child: ResponsiveContainer(
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.sm,
                      ),
                      itemCount: visibleRides.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final ride = visibleRides[index];
                        return _IncomingRequestCard(
                          key: ValueKey(ride.id),
                          ride: ride,
                          driverLat: presence.latitude,
                          driverLng: presence.longitude,
                          onDecline: () {
                            setState(() {
                              _declinedRideIds.add(ride.id);
                            });
                          },
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _IncomingRequestCard extends StatefulWidget {
  const _IncomingRequestCard({
    super.key,
    required this.ride,
    this.driverLat,
    this.driverLng,
    this.onDecline,
  });

  final RideModel ride;
  final double? driverLat;
  final double? driverLng;
  final VoidCallback? onDecline;

  @override
  State<_IncomingRequestCard> createState() => _IncomingRequestCardState();
}

class _IncomingRequestCardState extends State<_IncomingRequestCard>
    with TickerProviderStateMixin {
  final _rideRepo = DriverRideRepository();
  final _profileRepo = DriverProfileRepository();
  final _presenceRepo = DriverPresenceRepository();
  Timer? _timer;
  StreamSubscription<BidModel?>? _bidSub;
  double _progress = 1.0;
  int _secondsLeft = 60;
  bool _expired = false;
  bool _hasOffered = false;
  double? _offeredPrice;
  bool _placing = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  void _resetOfferState() {
    _timer?.cancel();
    _bidSub?.cancel();
    if (mounted) {
      setState(() {
        _hasOffered = false;
        _expired = false;
        _offeredPrice = null;
        _secondsLeft = 60;
        _progress = 1.0;
      });
    }
  }

  void _startTimer() {
    _secondsLeft = 60;
    _progress = 1.0;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft > 0) {
        setState(() {
          _secondsLeft--;
          _progress = _secondsLeft / 60;
        });
      } else {
        _resetOfferState();
        widget.onDecline?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bidSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _acceptCustomerPrice() async {
    await _sendBid(widget.ride.customerOffer);
  }

  Future<void> _sendBid(double amount) async {
    final uid = driverAuthController.currentUid;
    if (uid == null) return;

    setState(() => _placing = true);
    try {
      final presence = await _presenceRepo.getPresence();
      if (presence == null || !presence.isAvailableForRequests) {
        throw StateError('Driver is not available for requests.');
      }
      final profile = await _profileRepo.getDriverProfile(uid);
      
      int eta = 5;
      if (presence.latitude != null && presence.longitude != null && widget.ride.pickupLat != null && widget.ride.pickupLng != null) {
        final dist = calculateDistance(
          presence.latitude!,
          presence.longitude!,
          widget.ride.pickupLat!,
          widget.ride.pickupLng!,
        );
        eta = estimateEtaMinutes(dist);
      }

      final bidId = await _rideRepo.placeBid(
        rideId: widget.ride.id,
        driverName: profile?.fullName ?? 'Driver',
        offerNaira: amount,
        etaMinutes: eta,
        driverRating: 5.0,
        driverRides: 0,
      );
      if (!mounted) return;

      _bidSub?.cancel();
      _bidSub = _rideRepo.streamBid(widget.ride.id, bidId).listen((bid) {
        if (bid != null && mounted) {
          if (bid.status == 'rejected' ||
              bid.status == 'expired' ||
              bid.status == 'declined') {
            _resetOfferState();
            widget.onDecline?.call();
          }
        }
      });

      DriverAlertController.instance.resolveRide(widget.ride.id);
      setState(() {
        _hasOffered = true;
        _offeredPrice = amount;
        _startTimer();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to place bid. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  void _showCounterSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : AppColors.slate900;
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final basePrice = widget.ride.customerOffer;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: sheetColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Set Your Fare',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Suggest a higher price to the customer.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: mutedTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  _priceOption(ctx, basePrice + 200),
                  const SizedBox(width: AppSpacing.sm),
                  _priceOption(ctx, basePrice + 500),
                  const SizedBox(width: AppSpacing.sm),
                  _priceOption(ctx, basePrice + 1000),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priceOption(BuildContext ctx, double price) {
    return Expanded(
      child: InkWell(
        onTap: () {
          Navigator.pop(ctx);
          _sendBid(price);
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              NgnFormat.whole(price),
              style: const TextStyle(
                color: AppColors.primaryGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_expired) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0);
    final isUrgent = _secondsLeft < 15;

    final double? distanceKm = (widget.driverLat != null &&
            widget.driverLng != null &&
            widget.ride.pickupLat != null &&
            widget.ride.pickupLng != null)
        ? calculateDistance(
            widget.driverLat!,
            widget.driverLng!,
            widget.ride.pickupLat!,
            widget.ride.pickupLng!,
          )
        : null;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                const BoxShadow(
                  color: Color(0x0F0F172A),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hasOffered ? 'YOUR OFFER' : 'CUSTOMER OFFER',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    NgnFormat.whole(
                      _hasOffered ? _offeredPrice! : widget.ride.customerOffer,
                    ),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
              if (_hasOffered)
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        value: _progress,
                        strokeWidth: 4,
                        backgroundColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F4F7),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isUrgent ? AppColors.error : AppColors.primaryGreen,
                        ),
                      ),
                    ),
                    Text(
                      '$_secondsLeft',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: isUrgent ? AppColors.error : (isDark ? Colors.white : AppColors.slate900),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on_rounded, size: 14, color: AppColors.primaryGreen),
                          const SizedBox(width: 4),
                          Text(
                            'NEW RIDE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (distanceKm != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F4F7),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.navigation_outlined, size: 14, color: AppColors.primaryGreen),
                            const SizedBox(width: 4),
                            Text(
                              '${distanceKm.toStringAsFixed(1)} km away',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: isDark ? Colors.white : AppColors.slate900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  const Icon(Icons.circle, size: 12, color: AppColors.primaryGreen),
                  Container(
                    width: 2,
                    height: 32,
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                  ),
                  const Icon(Icons.location_on_rounded, size: 14, color: AppColors.error),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PICKUP',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[400] : const Color(0xFF8A90A6),
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.ride.pickupLabel,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'DROPOFF',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[400] : const Color(0xFF8A90A6),
                        fontWeight: FontWeight.w800,
                        fontSize: 9,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.ride.dropoffLabel,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F4F7),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  widget.ride.rideType,
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F4F7),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.ride.paymentMethod == 'wallet'
                          ? Icons.account_balance_wallet_outlined
                          : Icons.payments_outlined,
                      size: 14,
                      color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.ride.paymentMethod.toUpperCase(),
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (isUrgent && _hasOffered)
                FadeTransition(
                  opacity: _pulseController,
                  child: Text(
                    'EXPIRING SOON',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!_hasOffered)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Decline',
                        onPressed: () {
                          DriverAlertController.instance.resolveRide(widget.ride.id);
                          widget.onDecline?.call();
                          if (mounted) setState(() => _expired = true);
                        },
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: SecondaryButton(
                        label: 'Counter',
                        onPressed: _showCounterSheet,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Accept',
                        isLoading: _placing,
                        onPressed: _acceptCustomerPrice,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Center(
                  child: TextButton(
                    onPressed: () {
                      DriverActiveRideState.instance.selectedRide = widget.ride;
                      context.push(DriverRoutePaths.requestDetail);
                    },
                    child: Text(
                      'View Full Details',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F4F7),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(AppColors.primaryGreen),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Waiting for customer...',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : AppColors.slate900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Offer expires in $_secondsLeft seconds',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
