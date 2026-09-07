import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:caride/core/utils/disk_cache_manager.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:caride/core/maps/dark_map_style.dart';
import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:caride/core/services/app_update_service.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lottie/lottie.dart' hide Marker;
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Passenger Home Screen around a map background, with floating frosted overlays.
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with SingleTickerProviderStateMixin {
  final RideRepository _rideRepository = RideRepository();
  StreamSubscription<RideModel?>? _activeRideSub;
  RideModel? _activeRide;
  String? _lastAutoNavigatedRideId;
  bool _autoNavScheduled = false;
  bool _autoNavInFlight = false;

  // ── Nearby-drivers state ────────────────────────────────────────────────
  GoogleMapController? _homeMapController;
  BitmapDescriptor? _carIcon;
  final Map<MarkerId, Marker> _nearbyDriverMarkers = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _driverPresenceSub;
  double? _customerLat;
  double? _customerLng;
  static const double _nearbyRadiusKm = 10.0;

  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: AppDurations.slow,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: AppCurves.spring,
          ),
        );

    _animationController.forward();

    _activeRideSub = _rideRepository.streamActiveRide().listen((ride) {
      _activeRide = ride;
      if (ride == null) {
        _lastAutoNavigatedRideId = null;
      } else {
        _scheduleAutoNavigateToActiveRide();
      }
    });

    unawaited(_checkPopupAnnouncements());
    unawaited(_initNearbyDrivers());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(AppUpdateService.checkAndShowUpdateDialog(context));
      }
    });
  }

  Future<void> _initNearbyDrivers() async {
    // 1. Load car icon
    try {
      final bytes = await rootBundle.load('lib/assets/car.png');
      _carIcon = BitmapDescriptor.bytes(
        bytes.buffer.asUint8List(),
        width: 36,
        height: 36,
      );
    } catch (_) {}

    // 2. Get customer's current GPS position
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _customerLat = pos.latitude;
      _customerLng = pos.longitude;
      if (mounted) {
        setState(() {});
      }
      // Move map to customer location
      _homeMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(pos.latitude, pos.longitude), 13.0),
      );
    } catch (_) {
      // GPS unavailable — markers will still show relative to default center
    }

    // 3. Subscribe to all online driverPresence documents
    _driverPresenceSub = FirebaseFirestore.instance
        .collection('driverPresence')
        .where('availabilityState', isEqualTo: 'online')
        .snapshots()
        .listen(_onDriverPresenceSnapshot);
  }

  void _onDriverPresenceSnapshot(QuerySnapshot<Map<String, dynamic>> snap) {
    if (!mounted) return;
    final custLat = _customerLat;
    final custLng = _customerLng;
    final newMarkers = <MarkerId, Marker>{};

    for (final doc in snap.docs) {
      final data = doc.data();
      final gp = data['lastLocation'] as GeoPoint?;
      if (gp == null) continue;

      // Filter by 10 km radius when we have customer location
      if (custLat != null && custLng != null) {
        final dist = Geolocator.distanceBetween(
          custLat,
          custLng,
          gp.latitude,
          gp.longitude,
        );
        if (dist > _nearbyRadiusKm * 1000) continue;
      }

      final heading = (data['heading'] as num?)?.toDouble() ?? 0.0;
      final markerId = MarkerId('driver_${doc.id}');
      newMarkers[markerId] = Marker(
        markerId: markerId,
        position: LatLng(gp.latitude, gp.longitude),
        icon:
            _carIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        rotation: heading,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        infoWindow: InfoWindow(title: 'Driver nearby'),
      );
    }

    setState(() {
      _nearbyDriverMarkers
        ..clear()
        ..addAll(newMarkers);
    });
  }

  Future<void> _checkPopupAnnouncements() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snap = await FirebaseFirestore.instance
          .collection('popups')
          .where('target', isEqualTo: 'customers')
          .where('isActive', isEqualTo: true)
          .get();

      if (snap.docs.isEmpty) return;

      final docs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(
        snap.docs,
      );
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
      final dismissedPopups =
          prefs.getStringList('dismissed_popup_announcements') ?? [];
      if (dismissedPopups.contains(popupId)) {
        return;
      }

      // Mark as dismissed immediately when we show it so it doesn't reappear on barrier tap dismissal
      await prefs.setStringList('dismissed_popup_announcements', [
        ...dismissedPopups,
        popupId,
      ]);

      if (!mounted) return;
      unawaited(
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
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
                            child: CircularProgressIndicator(
                              color: AppColors.brand,
                            ),
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
                        final currentDismissed =
                            prefs.getStringList(
                              'dismissed_popup_announcements',
                            ) ??
                            [];
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
        ),
      );
    } catch (e) {
      debugPrint('Error checking popup announcements: $e');
    }
  }

  @override
  void dispose() {
    _activeRideSub?.cancel();
    _driverPresenceSub?.cancel();
    _homeMapController?.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _scheduleAutoNavigateToActiveRide() {
    if (_autoNavScheduled) return;
    _autoNavScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoNavScheduled = false;
      unawaited(_maybeAutoNavigateToActiveRide());
    });
  }

  Future<void> _maybeAutoNavigateToActiveRide() async {
    if (!mounted) return;
    final ride = _activeRide;
    if (ride == null) return;
    if (_autoNavInFlight) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    if (_lastAutoNavigatedRideId == ride.id) return;

    _autoNavInFlight = true;
    _lastAutoNavigatedRideId = ride.id;
    try {
      if (ride.status == 'driverEnRoute' ||
          ride.status == 'driverArrived' ||
          ride.status == 'rideStarted') {
        context.go(CustomerRoutePaths.activity);
        return;
      }

      await context.push(
        CustomerRoutePaths.rideSetPrice,
        extra: {
          'rideId': ride.id,
          'pickupLabel': ride.pickupLabel,
          'pickupLat': ride.pickupLat,
          'pickupLng': ride.pickupLng,
          'dropoffLabel': ride.dropoffLabel,
          'dropoffLat': ride.dropoffLat,
          'dropoffLng': ride.dropoffLng,
        },
      );
    } finally {
      _autoNavInFlight = false;
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _displayName(String fullName, String email) {
    if (fullName.trim().isNotEmpty) {
      return fullName.trim().split(' ').first;
    }
    if (email.trim().isNotEmpty) {
      final namePart = email.split('@').first;
      if (namePart.isNotEmpty) {
        return namePart[0].toUpperCase() + namePart.substring(1);
      }
    }
    return 'Guest';
  }

  void _showActiveRideWarningDialog(BuildContext context) {
    showDialog(
      context: context,
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
                  color: AppColors.error.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Active Ride in Progress',
                style: AppTextStyles.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                "You cannot order another ride while there's a current active ride in progress.",
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'View Current Ride',
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    context.go(CustomerRoutePaths.activity);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: AppColors.error,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Sign Out',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to sign out of your account?',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetCtx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      side: BorderSide(
                        color: isDark
                            ? AppColors.glassBorderDark
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(sheetCtx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Sign Out',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      await customerAuthController.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ListenableBuilder(
              listenable: customerAuthController,
              builder: (context, _) {
                final profile = customerAuthController.currentProfile;
                final photoUrl = profile?.photoUrl ?? '';
                final fullName = profile?.fullName ?? '';
                final email = profile?.email ?? '';

                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pagePadding,
                    vertical: AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header Section ──
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: AppColors.brandGlass,
                            backgroundImage: photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl.isEmpty
                                ? const Icon(
                                    Icons.person_rounded,
                                    color: AppColors.brand,
                                  )
                                : null,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _greeting(),
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                _displayName(fullName, email),
                                style: AppTextStyles.titleLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          // ── Logout Button ──
                          Tooltip(
                            message: 'Sign Out',
                            child: GestureDetector(
                              onTap: () => _confirmLogout(context),
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.glassBorderDark
                                        : const Color(0xFFE5E7EB),
                                  ),
                                  color: isDark
                                      ? AppColors.darkSurface
                                      : Colors.white,
                                ),
                                child: const Icon(
                                  Icons.logout_rounded,
                                  size: 20,
                                  color: AppColors.error,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // ── Hero Section ──
                      Text(
                        'Where are you heading?',
                        style: AppTextStyles.displayLarge.copyWith(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          height: 1.1,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ── Clickable Address Field ──
                      GestureDetector(
                        onTap: () async {
                          if (_activeRide != null) {
                            _showActiveRideWarningDialog(context);
                          } else {
                            await context.push(CustomerRoutePaths.rideSetPrice);
                          }
                        },
                        child: AbsorbPointer(
                          child: AppTextField(
                            hint: 'Search destination...',
                            obscureText: false,
                            prefix: const Icon(
                              Icons.search_rounded,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ── Map Preview Container ──
                      Container(
                        height: 180,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark
                                ? AppColors.glassBorderDark
                                : AppColors.glassBorderLight,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(19),
                          child: AbsorbPointer(
                            child: GoogleMap(
                              initialCameraPosition: const CameraPosition(
                                target: LatLng(9.0820, 8.6753),
                                zoom: 13.0,
                              ),
                              onMapCreated: (ctrl) {
                                _homeMapController = ctrl;
                                // Animate to customer location if already fetched
                                final lat = _customerLat;
                                final lng = _customerLng;
                                if (lat != null && lng != null) {
                                  ctrl.animateCamera(
                                    CameraUpdate.newLatLngZoom(
                                      LatLng(lat, lng),
                                      13.0,
                                    ),
                                  );
                                }
                              },
                              myLocationEnabled: true,
                              myLocationButtonEnabled: false,
                              zoomControlsEnabled: false,
                              compassEnabled: false,
                              mapToolbarEnabled: false,
                              zoomGesturesEnabled: false,
                              scrollGesturesEnabled: false,
                              tiltGesturesEnabled: false,
                              rotateGesturesEnabled: false,
                              style: isDark ? kGoogleMapDarkStyle : null,
                              markers: {
                                ..._nearbyDriverMarkers.values,
                                if (_customerLat != null &&
                                    _customerLng != null)
                                  Marker(
                                    markerId: const MarkerId('user_location'),
                                    position: LatLng(
                                      _customerLat!,
                                      _customerLng!,
                                    ),
                                    icon: BitmapDescriptor.defaultMarkerWithHue(
                                      BitmapDescriptor.hueRed,
                                    ),
                                    infoWindow: const InfoWindow(
                                      title: 'My Location',
                                    ),
                                  ),
                              },
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ── Action Cards Title ──
                      Text(
                        'Services',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ── Side-by-Side Quick Action Cards ──
                      Row(
                        children: [
                          Expanded(
                            child: _ActionCard(
                              title: 'Ride',
                              imagePath:
                                  'lib/assets/lottie/car_animation.lottie',
                              isComingSoon: false,
                              onTap: () async {
                                if (_activeRide != null) {
                                  _showActiveRideWarningDialog(context);
                                } else {
                                  await context.push(
                                    CustomerRoutePaths.rideSetPrice,
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: _ActionCard(
                              title: 'Send Items',
                              imagePath:
                                  'lib/assets/lottie/delivery_bike.lottie',
                              isComingSoon: false,
                              onTap: () async {
                                if (_activeRide != null) {
                                  _showActiveRideWarningDialog(context);
                                } else {
                                  await context.push(
                                    CustomerRoutePaths.sendItems,
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: _ActionCard(
                              title: 'Car Rentals',
                              imagePath:
                                  'lib/assets/caride_branded/car_rental.png',
                              isComingSoon: false,
                              onTap: () {
                                _showCarRentalsComingSoonBottomSheet(context);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _BannerAdsCarousel(target: 'customers'),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _showCarRentalsComingSoonBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BottomSheetShell(
          title: 'Car Rentals',
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xs),
                // Hero Image Card with Generated 2D Happy Passenger Illustration
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: isDark
                          ? AppColors.glassBorderDark
                          : AppColors.glassBorderLight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brand.withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.asset(
                            'lib/assets/caride_branded/happy_passenger.png',
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius: BorderRadius.circular(999),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              'COMING SOON',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                Text(
                  'Rent Vehicles Anytime, Anywhere',
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  "We are expanding CaRide to give you direct access to flexible vehicle rentals tailored for every journey.",
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Feature Glimpse Tiles
                const _RentalFeatureTile(
                  icon: Icons.directions_car_rounded,
                  iconColor: Color(0xFF3B82F6),
                  title: 'Daily & Intercity Cars',
                  subtitle:
                      'Sedans, hatchbacks, and SUVs for personal errands, business, and road trips.',
                ),
                const SizedBox(height: AppSpacing.xs),
                const _RentalFeatureTile(
                  icon: Icons.workspace_premium_rounded,
                  iconColor: Color(0xFFF59E0B),
                  title: 'Luxury & VIP Fleet',
                  subtitle:
                      'Premium executive cars & SUVs for special events, weddings, and high-profile rides.',
                ),
                const SizedBox(height: AppSpacing.xs),
                const _RentalFeatureTile(
                  icon: Icons.local_shipping_rounded,
                  iconColor: Color(0xFF10B981),
                  title: 'Lorries & Cargo Haulage',
                  subtitle:
                      'Commercial trucks, vans, and lorries for heavy transport and logistics.',
                ),
                const SizedBox(height: AppSpacing.xl),

                PrimaryButton(
                  label: 'Got it',
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RentalFeatureTile extends StatelessWidget {
  const _RentalFeatureTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatefulWidget {
  const _ActionCard({
    required this.title,
    required this.imagePath,
    required this.isComingSoon,
    required this.onTap,
  });

  final String title;
  final String imagePath;
  final bool isComingSoon;
  final VoidCallback onTap;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: AppDurations.fast,
        curve: AppCurves.spring,
        child: GlassContainer(
          borderColor: widget.isComingSoon
              ? null
              : (_isPressed ? AppColors.brand : null),
          child: SizedBox(
            height: 155,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Center(
                          child: widget.imagePath.endsWith('.lottie')
                              ? Lottie.asset(
                                  widget.imagePath,
                                  height: 85,
                                  fit: BoxFit.contain,
                                  decoder: (bytes) {
                                    return LottieComposition.decodeZip(
                                      bytes,
                                      filePicker: (files) {
                                        return files.firstWhere(
                                          (f) =>
                                              f.name.startsWith(
                                                'animations/',
                                              ) &&
                                              f.name.endsWith('.json'),
                                        );
                                      },
                                    );
                                  },
                                )
                              : Image.asset(
                                  widget.imagePath,
                                  height: 50,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      widget.title == 'Ride'
                                          ? Icons.directions_car_rounded
                                          : Icons.car_rental_rounded,
                                      size: 50,
                                      color: widget.isComingSoon
                                          ? Colors.grey
                                          : AppColors.brand,
                                    );
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        widget.title,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (widget.isComingSoon)
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Soon',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
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
          borderColor: isDark
              ? AppColors.glassBorderDark
              : AppColors.glassBorderLight,
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: AspectRatio(
              aspectRatio: 16 / 9,
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
                            child: CircularProgressIndicator(
                              color: AppColors.brand,
                            ),
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
                              final isActive =
                                  dotIndex == (_currentPage % docs.length);
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.only(left: 4),
                                width: isActive ? 12 : 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.brand
                                      : Colors.white60,
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
