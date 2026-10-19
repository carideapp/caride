import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:design_system/design_system.dart';
import 'package:navigation/navigation.dart';
import 'package:caride/core/utils/disk_cache_manager.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/core/driver/models/ride_model.dart';
import 'package:caride/core/driver/utils/maps_launcher.dart';
import 'package:caride/features/driver/auth/data/driver_profile_repository.dart';
import 'package:caride/features/driver/earnings/data/earnings_repository.dart';
import 'package:caride/features/driver/location/driver_presence_controller.dart';
import 'package:caride/features/driver/profile/data/driver_tier_repository.dart';
import 'package:caride/core/services/app_update_service.dart';
import 'package:caride/features/driver/ride/data/driver_ride_repository.dart';
import 'package:caride/core/config/app_config_repository.dart';
import 'package:caride/features/driver/widgets/driver_debt_prompt_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned map-centric Home Screen with Apple Liquid Glass overlay bottom sheet and cards.
class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  final _profileRepo = DriverProfileRepository();
  final _rideRepo = DriverRideRepository();
  final _earningsRepo = EarningsRepository();
  final _tierRepo = DriverTierRepository();
  final _presenceController = driverPresenceController;
  String? _dismissedCancelledRideId;

  StreamSubscription? _profileSubscription;
  StreamSubscription? _driverSettingsSub;
  bool _promptedCompleteProfile = false;
  double _walletBalance = 0.0;
  double _maxNegativeBalance = 3000.0;

  @override
  void initState() {
    super.initState();
    _presenceController.initialize();
    _presenceController.addListener(_handlePresenceChanged);
    _listenToProfile();
    _listenToDriverSettings();
    unawaited(_checkPopupAnnouncements());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(AppUpdateService.checkAndShowUpdateDialog(context));
      }
    });
  }

  Future<void> _checkPopupAnnouncements() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snap = await FirebaseFirestore.instance
          .collection('popups')
          .where('target', isEqualTo: 'drivers')
          .where('isActive', isEqualTo: true)
          .get();

      if (snap.docs.isEmpty) return;

      final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(snap.docs);
      docs.sort((a, b) {
        final aTime = a.data()['createdAt'] as Timestamp?;
        final bTime = b.data()['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      final docRef = docs.first;
      final popupId = docRef.id;
      final data = docRef.data();
      final imageUrl = data['imageUrl'] as String?;
      final audience = data['audience'] as String?;
      final specificUids = List<String>.from(data['specificUids'] ?? []);

      if (imageUrl == null || imageUrl.isEmpty) return;

      if (audience == 'specific' && !specificUids.contains(uid)) {
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final dismissedPopups = prefs.getStringList('dismissed_popup_announcements') ?? [];
      if (dismissedPopups.contains(popupId)) {
        return;
      }

      // Mark as dismissed immediately when we show it so it doesn't reappear on barrier tap dismissal
      await prefs.setStringList(
        'dismissed_popup_announcements',
        [...dismissedPopups, popupId],
      );

      if (!mounted) return;
      unawaited(showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: DiskCachedImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      loadingWidget: Container(
                        color: Colors.black12,
                        child: const Center(
                          child: CircularProgressIndicator(color: AppColors.brand),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -12,
                  right: -12,
                  child: GestureDetector(
                    onTap: () async {
                      final currentDismissed = prefs.getStringList('dismissed_popup_announcements') ?? [];
                      if (!currentDismissed.contains(popupId)) {
                        await prefs.setStringList(
                          'dismissed_popup_announcements',
                          [...currentDismissed, popupId],
                        );
                      }
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ));
    } catch (e) {
      debugPrint('Error checking popup announcements: $e');
    }
  }

  void _listenToProfile() {
    final uid = driverAuthController.currentUid;
    if (uid != null) {
      _profileSubscription = _profileRepo.streamDriverProfile(uid).listen((profile) {
        if (profile != null) {
          _walletBalance = profile.walletBalance;
          if (!profile.profileCompleted && !_promptedCompleteProfile) {
            _promptedCompleteProfile = true;
            _showCompleteProfileDialog();
          }
        }
      });
    }
  }

  void _listenToDriverSettings() {
    _driverSettingsSub = AppConfigRepository().watchDriverSettings().listen((settings) {
      if (mounted) {
        setState(() {
          _maxNegativeBalance = settings.maxNegativeBalanceNaira;
        });
      }
    });
  }

  void _showCompleteProfileDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.transparent,
          contentPadding: EdgeInsets.zero,
          content: GlassSurface(
            radius: AppRadius.lg,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.brandGlass,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.assignment_ind_outlined,
                    color: AppColors.brand,
                    size: 40,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Complete Your Profile',
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'To start accepting ride requests and earning with CaRide, please complete your driver registration profile details.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Later',
                        onPressed: () => Navigator.pop(dialogContext),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Go to Profile',
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          // GoRouter redirects to driver profile page branch
                          context.go(DriverRoutePaths.profile);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _presenceController.removeListener(_handlePresenceChanged);
    _profileSubscription?.cancel();
    _driverSettingsSub?.cancel();
    super.dispose();
  }

  void _handlePresenceChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _openRouteDirections(RideModel ride) async {
    final isGoingToPickup = ride.status == 'driverEnRoute';
    final destinationLat = isGoingToPickup ? ride.pickupLat : ride.dropoffLat;
    final destinationLng = isGoingToPickup ? ride.pickupLng : ride.dropoffLng;
    final destinationLabel = isGoingToPickup ? ride.pickupLabel : ride.dropoffLabel;

    final currentPosition = _presenceController.currentPosition;
    final originLat = currentPosition?.latitude;
    final originLng = currentPosition?.longitude;

    await MapsLauncher.openGoogleMaps(
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      destinationLabel: destinationLabel,
      originLat: originLat,
      originLng: originLng,
    );
  }

  Stream<RentalBooking?> _streamActiveRentalTrip(String? uid) {
    if (uid == null) return Stream.value(null);
    return FirebaseFirestore.instance
        .collection('rental_bookings')
        .where('assignedDriverId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      for (final doc in snap.docs) {
        final b = RentalBooking.fromMap(doc.data(), doc.id);
        if (b.status == RentalBookingStatus.confirmed ||
            b.status == RentalBookingStatus.inProgress) {
          return b;
        }
      }
      return null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = driverAuthController.currentUid;
    final isOnline = _presenceController.isOnline;
    final presenceError = _presenceController.errorMessage;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // ── Plain Background ──
          Positioned.fill(
            child: Container(
              color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
            ),
          ),

          // ── Top Floating Glass Header ──
          Positioned(
            top: MediaQuery.of(context).padding.top + AppSpacing.md,
            left: AppSpacing.pagePadding,
            right: AppSpacing.pagePadding,
            child: GlassSurface(
              radius: AppRadius.xl,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  if (uid != null)
                    StreamBuilder(
                      stream: _profileRepo.streamDriverProfile(uid),
                      builder: (context, snapshot) {
                        final profilePhotoUrl = snapshot.data?.profilePhotoUrl ?? '';
                        if (profilePhotoUrl.isNotEmpty) {
                          return Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              image: DecorationImage(
                                image: NetworkImage(profilePhotoUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          );
                        }
                        return Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.brandGlass,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: AppColors.brand,
                            size: 24,
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.brandGlass,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.brand,
                        size: 24,
                      ),
                    ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Welcome back,',
                          style: AppTextStyles.caption.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                        ),
                        if (uid != null)
                          StreamBuilder(
                            stream: _profileRepo.streamDriverProfile(uid),
                            builder: (context, snapshot) {
                              final name = snapshot.data?.fullName ?? 'Driver';
                              return Text(
                                name,
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              );
                            },
                          )
                        else
                          Text(
                            'Driver',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                      ],
                    ),
                  ),
                  StatusChip(
                    label: isOnline ? 'Online' : 'Offline',
                    tone: isOnline ? StatusChipTone.success : StatusChipTone.neutral,
                    isActive: isOnline,
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom Sheet Glass Panel (Dynamic height / scroll) ──
          Align(
            alignment: Alignment.bottomCenter,
            child: GlassSurface(
              radius: AppRadius.xxxl,
              blurSigma: AppGlass.blurHeavy,
              margin: const EdgeInsets.only(bottom: AppSpacing.navBarHeight + AppSpacing.md, left: AppSpacing.sm, right: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Active Rental Trip Overlay
                  StreamBuilder<RentalBooking?>(
                    stream: _streamActiveRentalTrip(uid),
                    builder: (context, snapshot) {
                      final booking = snapshot.data;
                      if (booking == null) return const SizedBox.shrink();

                      final isStarted = booking.status == RentalBookingStatus.inProgress;
                      final isEnRoute = booking.rentalTripStatus == RentalTripStatus.headingToPickup;

                      String tripPhaseLabel;
                      if (isStarted) {
                        tripPhaseLabel = 'Rental in Progress';
                      } else if (isEnRoute) {
                        tripPhaseLabel = 'Rental: Heading to Pickup';
                      } else {
                        tripPhaseLabel = 'Assigned Rental Booking';
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceRaised : Colors.white,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.brand.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.car_rental_rounded,
                                        color: AppColors.brand,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        tripPhaseLabel,
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.brand,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => context.push(DriverRoutePaths.rentalBookings),
                                  child: Text(
                                    'View All',
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.brand,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              '${booking.vehicleTitle} • ${booking.customerName}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 14,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    booking.pickupLocation,
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            PrimaryButton(
                              label: isStarted
                                  ? 'Manage Rental Trip'
                                  : (isEnRoute ? 'View Rental Trip' : 'Open Rental Trip'),
                              icon: Icons.directions_car_rounded,
                              showShadow: false,
                              onPressed: () {
                                context.push(DriverRoutePaths.rentalTrip, extra: booking);
                              },
                              height: 44,
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Active ride overlay
                  StreamBuilder<RideModel?>(
                    stream: _rideRepo.streamAssignedRide(),
                    builder: (context, snapshot) {
                      final ride = snapshot.data;
                      final showCancelled = ride != null &&
                          ride.status == 'cancelled' &&
                          ride.id != _dismissedCancelledRideId;
                      final showRide = isOnline && ride != null && ride.status != 'cancelled';

                      if (showCancelled) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.errorSubtle,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ride Cancelled',
                                style: AppTextStyles.titleMedium.copyWith(color: AppColors.error),
                              ),
                              Text(
                                'The customer cancelled this ride.',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              DangerButton(
                                label: 'Dismiss',
                                onPressed: () {
                                  setState(() => _dismissedCancelledRideId = ride.id);
                                },
                                height: 40,
                              ),
                            ],
                          ),
                        );
                      }

                      if (showRide) {
                        final isPickupPhase = ride.status == 'driverEnRoute' || ride.status == 'driverArrived';
                        return Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.md),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.brandGlass,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: AppColors.brandGlassBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ride.status == 'driverArrived'
                                    ? 'Arrived at Pickup'
                                    : (ride.status == 'driverEnRoute' ? 'Heading to Pickup' : 'Ride in Progress'),
                                style: AppTextStyles.titleMedium.copyWith(color: AppColors.brand),
                              ),
                              Text(
                                isPickupPhase ? ride.pickupLabel : ride.dropoffLabel,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              PrimaryButton(
                                label: ride.status == 'driverArrived'
                                    ? 'Start Ride'
                                    : (ride.status == 'driverEnRoute' ? 'Go to Pickup' : 'Get Directions'),
                                icon: ride.status == 'driverArrived'
                                    ? Icons.play_arrow_rounded
                                    : Icons.navigation_rounded,
                                showShadow: false,
                                onPressed: () {
                                  if (isPickupPhase) {
                                    context.push(DriverRoutePaths.tripPickup);
                                  } else {
                                    _openRouteDirections(ride);
                                  }
                                },
                                height: 40,
                              ),
                            ],
                          ),
                        );
                      }

                      return const SizedBox.shrink();
                    },
                  ),

                  // Today's Stats Horizontal Roll
                  StreamBuilder<DriverTierStats?>(
                    stream: _tierRepo.streamDriverTierStats(),
                    builder: (context, tierSnapshot) {
                      final tierStats = tierSnapshot.data;
                      return StreamBuilder<double>(
                        stream: _earningsRepo.streamTodayEarnings(),
                        initialData: 0.0,
                        builder: (context, earningsSnapshot) {
                          final earnings = earningsSnapshot.data ?? 0.0;
                          return Row(
                            children: [
                              Expanded(
                                child: _StatItem(
                                  value: NgnFormat.whole(earnings),
                                  label: "Today's Pay",
                                  icon: Icons.account_balance_wallet_outlined,
                                  color: AppColors.brand,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: _StatItem(
                                  value: '${tierStats?.completedRides ?? 0}',
                                  label: 'Completed',
                                  icon: Icons.check_circle_outline_rounded,
                                  color: AppColors.accent,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: _StatItem(
                                  value: (tierStats?.averageRating ?? 0).toStringAsFixed(1),
                                  label: 'Rating',
                                  icon: Icons.star_border_rounded,
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Go Online / Offline Switch Container
                  GlassContainer(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: isOnline ? AppColors.brandGlass : AppColors.glassBackgroundDark,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isOnline ? Icons.wifi : Icons.wifi_off,
                            color: isOnline ? AppColors.brand : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "You're ${isOnline ? 'Online' : 'Offline'}",
                                style: AppTextStyles.titleMedium.copyWith(
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                ),
                              ),
                              Text(
                                presenceError ??
                                    (isOnline
                                        ? 'Sharing location for ride requests.'
                                        : 'Go online to receive rides.'),
                                style: AppTextStyles.caption.copyWith(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch.adaptive(
                          value: isOnline,
                          activeTrackColor: AppColors.brand,
                          onChanged: _presenceController.isBusy
                              ? null
                              : (value) async {
                                  if (value && _walletBalance <= -_maxNegativeBalance) {
                                    await DriverDebtPromptBottomSheet.show(
                                      context,
                                      currentBalance: _walletBalance,
                                      maxNegativeBalance: _maxNegativeBalance,
                                    );
                                    return;
                                  }
                                  await _presenceController.setOnline(value);
                                },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const _BannerAdsCarousel(target: 'drivers'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerAdsCarousel extends StatefulWidget {
  const _BannerAdsCarousel({required this.target});
  final String target;

  @override
  State<_BannerAdsCarousel> createState() => _BannerAdsCarouselState();
}

class _BannerAdsCarouselState extends State<_BannerAdsCarousel> {
  late final PageController _pageController;
  Timer? _timer;
  int _currentPage = 1000;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1000);
    _startAutoSwipe();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoSwipe() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_totalPages <= 1 || !mounted) return;
      if (!_pageController.hasClients) return;
      final nextPage = _pageController.page!.round() + 1;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('banners')
          .where('target', isEqualTo: widget.target)
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final now = DateTime.now();
        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data();
          final startStr = data['startDate'] as String?;
          final expiryStr = data['expiryDate'] as String?;
          if (startStr == null || expiryStr == null) return false;
          final start = DateTime.tryParse(startStr);
          final expiry = DateTime.tryParse(expiryStr);
          if (start == null || expiry == null) return false;
          return start.isBefore(now) && expiry.isAfter(now);
        }).toList();

        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }

        _totalPages = docs.length;

        // Background prefetch the images to local disk cache
        for (final doc in docs) {
          final url = doc.data()['imageUrl'] as String? ?? '';
          if (url.isNotEmpty) {
            unawaited(DiskCacheManager.instance.cacheImage(url));
          }
        }

        return GlassContainer(
          radius: 12,
          borderColor: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: AspectRatio(
              aspectRatio: 2.4,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                  // Restart timer to avoid immediate jumps
                  _startAutoSwipe();
                },
                itemCount: _totalPages <= 1 ? 1 : 100000,
                itemBuilder: (context, index) {
                  final mappedIndex = index % docs.length;
                  final data = docs[mappedIndex].data();
                  final imageUrl = data['imageUrl'] as String? ?? '';

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // Banner Image
                      DiskCachedImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        loadingWidget: Container(
                          color: isDark ? Colors.white10 : Colors.black12,
                          child: const Center(
                            child: CircularProgressIndicator(color: AppColors.brand),
                          ),
                        ),
                      ),
                      // Page Indicator Dots
                      if (docs.length > 1)
                        Positioned(
                          right: AppSpacing.md,
                          top: AppSpacing.md,
                          child: Row(
                            children: List.generate(docs.length, (dotIndex) {
                              final isActive = dotIndex == (_currentPage % docs.length);
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(left: 4),
                                width: isActive ? 12 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isActive ? AppColors.brand : Colors.white60,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

