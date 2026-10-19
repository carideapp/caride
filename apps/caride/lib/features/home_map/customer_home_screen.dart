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
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:caride/features/profile/data/address_repository.dart';
import 'package:caride/core/services/weather_service.dart';
import 'package:caride/core/services/pending_bank_transfer_service.dart';
import 'package:caride/features/wallet/widgets/pending_bank_transfer_widgets.dart';

/// Redesigned Passenger Home Screen following modern UI standards and CaRide Brand Guidelines.
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

  // ── Live Weather state ───────────────────────────────────────────────────
  WeatherData? _weatherData = WeatherService.cachedData;
  bool _isLoadingWeather = false;

  // ── Service Availability state ──────────────────────────────────────────
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _availabilitySub;
  Map<String, dynamic>? _serviceAvailability;

  // ── Saved addresses repository ─────────────────────────────────────────
  final AddressRepository _addressRepository = AddressRepository();

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
        Tween<Offset>(begin: const Offset(0.0, 0.06), end: Offset.zero).animate(
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

    _availabilitySub = FirebaseFirestore.instance
        .collection('config')
        .doc('serviceAvailability')
        .snapshots()
        .listen((doc) {
      if (mounted && doc.exists) {
        setState(() {
          _serviceAvailability = doc.data();
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(AppUpdateService.checkAndShowUpdateDialog(context));
        unawaited(_checkPendingBankTransfer());
      }
    });
  }

  Future<void> _checkPendingBankTransfer() async {
    final pending =
        await PendingBankTransferService.instance.getPendingTransfer();
    if (pending != null && !pending.isDismissed && mounted) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      await PendingBankTransferPromptSheet.show(context, pending: pending);
    }
  }

  static const String _kLastKnownLatKey = 'customer_last_known_lat';
  static const String _kLastKnownLngKey = 'customer_last_known_lng';

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

    // 2. Subscribe to all online driverPresence documents immediately
    _driverPresenceSub = FirebaseFirestore.instance
        .collection('driverPresence')
        .where('availabilityState', isEqualTo: 'online')
        .snapshots()
        .listen(_onDriverPresenceSnapshot);

    // 3. Instantly load cached/last-known location for immediate display
    await _loadCachedLastKnownLocation();

    // 4. In background, fetch, capture and load updated live current location
    unawaited(_refreshLiveLocationInBackground());
  }

  /// Instantly loads the last known location from local cache (SharedPreferences & OS cache)
  Future<void> _loadCachedLastKnownLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedLat = prefs.getDouble(_kLastKnownLatKey);
      final cachedLng = prefs.getDouble(_kLastKnownLngKey);

      if (cachedLat != null && cachedLng != null) {
        _customerLat = cachedLat;
        _customerLng = cachedLng;
        if (mounted) {
          setState(() {});
        }
        unawaited(_fetchWeather(cachedLat, cachedLng));
        return;
      }

      // If not yet in prefs, check OS device last known position cache
      final lastPos = await Geolocator.getLastKnownPosition();
      if (lastPos != null) {
        _customerLat = lastPos.latitude;
        _customerLng = lastPos.longitude;
        if (mounted) {
          setState(() {});
        }
        unawaited(_fetchWeather(lastPos.latitude, lastPos.longitude));
        // Cache to preferences for subsequent instant boots
        unawaited(prefs.setDouble(_kLastKnownLatKey, lastPos.latitude));
        unawaited(prefs.setDouble(_kLastKnownLngKey, lastPos.longitude));
      }
    } catch (_) {}
  }

  /// In the background, queries high-accuracy GPS, updates state, and persists to cache
  Future<void> _refreshLiveLocationInBackground() async {
    try {
      // Check & request location permission if needed
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return;
        }
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );

      final isDifferent = _customerLat == null ||
          _customerLng == null ||
          (pos.latitude - _customerLat!).abs() > 0.0001 ||
          (pos.longitude - _customerLng!).abs() > 0.0001;

      _customerLat = pos.latitude;
      _customerLng = pos.longitude;

      if (mounted) {
        setState(() {});
      }

      // Save new coordinates to cache for future instant launches
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble(_kLastKnownLatKey, pos.latitude);
        await prefs.setDouble(_kLastKnownLngKey, pos.longitude);
      } catch (_) {}

      if (isDifferent) {
        unawaited(_fetchWeather(pos.latitude, pos.longitude));
      }
    } catch (_) {
      // In case live fetch fails or times out, fallback to OS last known position
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null && (_customerLat == null || _customerLng == null)) {
          _customerLat = lastPos.latitude;
          _customerLng = lastPos.longitude;
          if (mounted) {
            setState(() {});
          }
          unawaited(_fetchWeather(lastPos.latitude, lastPos.longitude));
        }
      } catch (_) {}
    }
  }

  Future<void> _fetchWeather(double lat, double lng) async {
    if (_isLoadingWeather) return;
    _isLoadingWeather = true;
    final data = await WeatherService.fetchWeather(lat, lng);
    if (mounted && data != null) {
      setState(() {
        _weatherData = data;
        _isLoadingWeather = false;
      });
    }
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
        infoWindow: const InfoWindow(title: 'Driver nearby'),
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
    _availabilitySub?.cancel();
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

  String get _currentDetectedState {
    final loc = _weatherData?.locationName.trim() ?? '';
    if (loc.isNotEmpty) return loc;
    final profileState =
        customerAuthController.currentProfile?.state.trim() ?? '';
    return profileState;
  }

  bool _isServiceAvailable(String serviceKey) {
    if (_serviceAvailability == null) return true;
    final entry = _serviceAvailability![serviceKey];
    if (entry is! Map) return true;
    final enabled = entry['enabled'];
    if (enabled is bool && !enabled) return false;

    final allStates = entry['allStates'];
    if (allStates is bool && allStates) return true;

    final userState = _currentDetectedState;
    if (userState.isEmpty) return true;

    final rawStates = entry['availableStates'];
    if (rawStates is List) {
      final permittedStates = rawStates
          .map((e) => e.toString().trim().toLowerCase())
          .toSet();
      final normUser = userState.toLowerCase();
      return permittedStates.any((p) =>
          p == normUser || normUser.contains(p) || p.contains(normUser));
    }
    return true;
  }

  void _showActiveRideWarningSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          12,
          24,
          MediaQuery.of(sheetCtx).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle
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
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Active Ride in Progress',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "You cannot order another ride while there's a current active ride in progress.",
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
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
                  Navigator.pop(sheetCtx);
                  context.go(CustomerRoutePaths.activity);
                },
                child: const Text(
                  'View Current Ride',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onSavedAddressSelected(SavedAddress address) {
    if (_activeRide != null) {
      _showActiveRideWarningSheet(context);
    } else {
      context.push(
        CustomerRoutePaths.rideSetPrice,
        extra: {
          'dropoffLabel': address.label.isNotEmpty
              ? address.label
              : address.address,
          'dropoffLat': address.lat,
          'dropoffLng': address.lng,
        },
      );
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
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pagePadding,
                    vertical: AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Top Header Bar ──
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: isDark
                                ? Colors.white12
                                : const Color(0xFFF3F4F6),
                            backgroundImage: photoUrl.isNotEmpty
                                ? NetworkImage(photoUrl)
                                : null,
                            child: photoUrl.isEmpty
                                ? const Icon(
                                    Icons.person_rounded,
                                    color: AppColors.brand,
                                    size: 24,
                                  )
                                : null,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _greeting(),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  _displayName(fullName, email),
                                  style: AppTextStyles.titleMedium.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          // Dynamic Location & Weather Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkSurface
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.glassBorderDark
                                    : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _weatherData?.weatherIcon ??
                                      Icons.wb_sunny_rounded,
                                  color: AppColors.brand,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _weatherData != null
                                      ? (_weatherData!.locationName.isNotEmpty
                                            ? '${_weatherData!.formattedTemp} · ${_weatherData!.locationName}'
                                            : _weatherData!.formattedTemp)
                                      : (_isLoadingWeather
                                            ? 'Loading weather...'
                                            : 'Weather unavailable'),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white70
                                        : AppColors.textPrimaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ── Hero Headline ──
                      // Text(
                      //   'Where will you go today?',
                      //   style: AppTextStyles.displayLarge.copyWith(
                      //     fontSize: 26,
                      //     fontWeight: FontWeight.w900,
                      //     height: 1.15,
                      //     letterSpacing: -0.4,
                      //   ),
                      // ),
                      // const SizedBox(height: AppSpacing.md),

                      // ── Pending Bank Transfer Banner ──
                      const PendingBankTransferBanner(
                        margin: EdgeInsets.only(bottom: AppSpacing.md),
                      ),

                      // ── Quick Search & Schedule Pill Bar (Reference Image 1) ──
                      GestureDetector(
                        onTap: () async {
                          if (_activeRide != null) {
                            _showActiveRideWarningSheet(context);
                          } else {
                            await context.push(CustomerRoutePaths.rideSetPrice);
                          }
                        },
                        child: Container(
                          height: 56,
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurface
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.glassBorderDark
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search_rounded,
                                color: AppColors.brand,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Where to?',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ── Saved Addresses Card (Only saved addresses below Where to?) ──
                      StreamBuilder<List<SavedAddress>>(
                        stream: _addressRepository.watchAddresses(),
                        builder: (context, snapshot) {
                          final addresses = snapshot.data ?? const [];
                          if (addresses.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _SavedAddressesCard(
                                addresses: addresses,
                                onSelect: _onSavedAddressSelected,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                          );
                        },
                      ),

                      // ── Live Interactive Map Preview (Reference Image 2) ──
                      Container(
                        height: 122,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? AppColors.glassBorderDark
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Stack(
                            children: [
                              GoogleMap(
                                initialCameraPosition: const CameraPosition(
                                  target: LatLng(9.0820, 8.6753),
                                  zoom: 13.0,
                                ),
                                onMapCreated: (ctrl) {
                                  _homeMapController = ctrl;
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
                                      icon:
                                          BitmapDescriptor.defaultMarkerWithHue(
                                            BitmapDescriptor.hueGreen,
                                          ),
                                      infoWindow: const InfoWindow(
                                        title: 'My Location',
                                      ),
                                    ),
                                },
                              ),

                              // Invisible tap overlay to trigger booking
                              Positioned.fill(
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () async {
                                      if (_activeRide != null) {
                                        _showActiveRideWarningSheet(context);
                                      } else {
                                        await context.push(
                                          CustomerRoutePaths.rideSetPrice,
                                        );
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ── Services Header ──
                      Text(
                        'Services',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // ── Dynamic Services Row (With Keke & Bike Support) ──
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Regular Car Ride
                            _ServiceItem(
                              title: 'Ride',
                              icon: Icons.directions_car_rounded,
                              imagePath: 'lib/assets/icons/car.png',
                              onTap: () async {
                                if (_activeRide != null) {
                                  _showActiveRideWarningSheet(context);
                                } else {
                                  await context.push(
                                    CustomerRoutePaths.rideSetPrice,
                                    extra: {
                                      'initialRideType': 'Regular',
                                      'operatingState': _currentDetectedState,
                                    },
                                  );
                                }
                              },
                            ),

                            // 2. Commercial Tricycle (Keke) - respect state availability
                            if (_isServiceAvailable('tricycle')) ...[
                              const SizedBox(width: 18),
                              _ServiceItem(
                                title: 'Tricycle',
                                icon: Icons.electric_rickshaw_rounded,
                                imagePath: 'lib/assets/caride_branded/tricyle.png',
                                onTap: () async {
                                  if (_activeRide != null) {
                                    _showActiveRideWarningSheet(context);
                                  } else {
                                    await context.push(
                                      CustomerRoutePaths.rideSetPrice,
                                      extra: {
                                        'initialRideType': 'Tricycle',
                                        'operatingState': _currentDetectedState,
                                      },
                                    );
                                  }
                                },
                              ),
                            ],

                            // 3. Commercial Motorcycle (Bike) - respect state availability
                            if (_isServiceAvailable('motorcycle')) ...[
                              const SizedBox(width: 18),
                              _ServiceItem(
                                title: 'Motorcycle',
                                icon: Icons.two_wheeler_rounded,
                                imagePath: 'lib/assets/motorcycle.png',
                                onTap: () async {
                                  if (_activeRide != null) {
                                    _showActiveRideWarningSheet(context);
                                  } else {
                                    await context.push(
                                      CustomerRoutePaths.rideSetPrice,
                                      extra: {
                                        'initialRideType': 'Motorcycle',
                                        'operatingState': _currentDetectedState,
                                      },
                                    );
                                  }
                                },
                              ),
                            ],

                            // 4. Courier Delivery
                            if (_isServiceAvailable('courier')) ...[
                              const SizedBox(width: 18),
                              _ServiceItem(
                                title: 'Courier',
                                icon: Icons.inventory_2_rounded,
                                imagePath: 'lib/assets/icons/box.png',
                                onTap: () async {
                                  if (_activeRide != null) {
                                    _showActiveRideWarningSheet(context);
                                  } else {
                                    await context.push(
                                      CustomerRoutePaths.sendItems,
                                    );
                                  }
                                },
                              ),
                            ],

                            // 5. Rentals
                            const SizedBox(width: 18),
                            _ServiceItem(
                              title: 'Rentals',
                              icon: Icons.car_rental_rounded,
                              imagePath: 'lib/assets/icons/rent.png',
                              onTap: () {
                                context.push(CustomerRoutePaths.rentalBookings);
                              },
                            ),

                            // 6. Blog
                            const SizedBox(width: 18),
                            _ServiceItem(
                              title: 'Blog',
                              icon: Icons.article_rounded,
                              imagePath: 'lib/assets/icons/paper.png',
                              onTap: () {
                                context.push(CustomerRoutePaths.forYouPosts);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // ── Educational & Community Blog: For You ──
                      Text(
                        'For you',
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const _ForYouContentSection(),
                      const SizedBox(height: AppSpacing.xl),

                      // ── Active Promotional Banners Carousel ──
                      const _BannerAdsCarousel(target: 'customers'),
                      const SizedBox(height: AppSpacing.xxl),
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
}

/// Circular & Clean Service Item (Aligned with Reference Image 1 & 2)
class _ServiceItem extends StatelessWidget {
  const _ServiceItem({
    required this.title,
    required this.icon,
    this.imagePath,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final String? imagePath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
                border: Border.all(
                  color: isDark
                      ? AppColors.glassBorderDark
                      : const Color(0xFFE5E7EB),
                  width: 1,
                ),
              ),
              child: Center(
                child: imagePath != null
                    ? Image.asset(
                        imagePath!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                            Icon(icon, size: 28, color: AppColors.brand),
                      )
                    : Icon(icon, size: 28, color: AppColors.brand),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Saved Addresses List Card (Displays user's saved addresses below Where to?)
class _SavedAddressesCard extends StatelessWidget {
  const _SavedAddressesCard({required this.addresses, required this.onSelect});

  final List<SavedAddress> addresses;
  final ValueChanged<SavedAddress> onSelect;

  IconData _iconForLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('home')) return Icons.home_rounded;
    if (lower.contains('work') || lower.contains('office')) {
      return Icons.work_rounded;
    }
    if (lower.contains('school') || lower.contains('uni')) {
      return Icons.school_rounded;
    }
    if (lower.contains('gym')) return Icons.fitness_center_rounded;
    return Icons.bookmark_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (addresses.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < addresses.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 64,
                endIndent: 16,
                color: isDark
                    ? AppColors.glassBorderDark
                    : const Color(0xFFF3F4F6),
              ),
            InkWell(
              onTap: () => onSelect(addresses[i]),
              borderRadius: BorderRadius.vertical(
                top: i == 0 ? const Radius.circular(12) : Radius.zero,
                bottom: i == addresses.length - 1
                    ? const Radius.circular(12)
                    : Radius.zero,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white10
                            : const Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconForLabel(addresses[i].label),
                        size: 20,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            addresses[i].label.isNotEmpty
                                ? addresses[i].label
                                : addresses[i].address,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (addresses[i].label.isNotEmpty &&
                              addresses[i].address.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              addresses[i].address,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? Colors.white38 : Colors.grey[400],
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Dynamic Educational & Community Blog Cards ("For you" Section)
class _ForYouContentSection extends StatelessWidget {
  const _ForYouContentSection();

  static final List<ForYouArticle> _fallbackArticles = [
    ForYouArticle(
      id: 'fallback-safety',
      title: 'Ride Safety: Verifying Your Vehicle & Driver PIN',
      shortDescription:
          'Essential steps to confirm your driver before stepping in.',
      category: 'Safety',
      readTime: '3 min read',
      coverImageUrl:
          'https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?auto=format&fit=crop&w=800&q=80',
      content: '''
### Stay Safe on Every Trip

At CaRide, passenger safety is our top priority. Every driver on our platform undergoes background screening and vehicle inspection before they can accept trips.

### 1. Verify Driver License Plate & Vehicle Model
Before getting in, always match the license plate number, vehicle make, and model displayed in your app with the vehicle in front of you.

### 2. Check Driver Photo & Name
Confirm the driver matches their profile photo. Never board a vehicle if a different person is driving.

### 3. Share Your Live Trip Status
Use our built-in trip sharing tool to send your live location and route directly to family or loved ones with a single tap.

### 4. Direct Emergency Assistance
If you ever feel unsafe, use the emergency SOS button available on your active trip screen for immediate 24/7 security dispatch.
''',
    ),
    ForYouArticle(
      id: 'fallback-rental',
      title: 'Car Rentals 101: How CaRide Vehicle Hire Works',
      shortDescription:
          'Everything you need to know about self-drive & chauffeur rentals.',
      category: 'Guide',
      readTime: '4 min read',
      coverImageUrl:
          'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=800&q=80',
      content: '''
### Renting Made Simple & Transparent

Whether you need a luxury SUV for an event, a sedan for client meetings, or a commercial bus for interstate travel, CaRide Car Rental connects you with vetted fleet partners.

### Flexible Booking Options
* **With Chauffeur**: Enjoy relaxed travel with an experienced, professional driver.
* **Self Drive**: Full independence and privacy for your journey.

### Step-by-Step Rental Flow
1. **Browse Fleet Catalog**: Choose category, price range, and location.
2. **Submit Reservation**: Select dates and pickup hours.
3. **Fleet Manager Confirmation**: The vehicle owner confirms availability within minutes.
4. **Transparent Payment**: Pay securely via CaRide Wallet or direct card payment.
5. **Start Your Trip**: Use your unique 4-digit PIN code upon vehicle handover.
''',
    ),
    ForYouArticle(
      id: 'fallback-courier',
      title: 'Sending Items with CaRide Courier',
      shortDescription:
          'Quick door-to-door package delivery tips for seamless sending.',
      category: 'Tips',
      readTime: '2 min read',
      coverImageUrl:
          'https://images.unsplash.com/photo-1580674684081-7617fbf3d745?auto=format&fit=crop&w=800&q=80',
      content: '''
### Fast, Tracked Parcel Delivery

Need documents, electronics, or personal items delivered across town? CaRide Courier provides secure, point-to-point delivery with real-time driver tracking.

### Best Practices Before Dispatching:
* **Secure Packaging**: Ensure fragile items are properly cushioned and sealed.
* **Accurate Recipient Details**: Double check the recipient's phone number and dropoff landmark so the driver can connect effortlessly.
* **Live In-App Tracking**: Watch the courier driver’s progress in real-time until delivery confirmation.
''',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('for_you_articles')
          .where('isActive', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        List<ForYouArticle> articles = [];

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          articles = snapshot.data!.docs.map((doc) {
            return ForYouArticle.fromMap(doc.data(), doc.id);
          }).toList();

          // Sort by newest first
          articles.sort((a, b) {
            final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
        }

        // Use rich fallback articles if Firestore is empty or still loading initial items
        if (articles.isEmpty) {
          articles = _fallbackArticles;
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: articles.map((article) {
              return Padding(
                padding: const EdgeInsets.only(right: 14),
                child: GestureDetector(
                  onTap: () {
                    context.push(
                      CustomerRoutePaths.forYouDetail,
                      extra: article,
                    );
                  },
                  child: Container(
                    width: 254,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? AppColors.glassBorderDark
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Cover Image with Category Chip overlay
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Container(
                                height: 112,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withValues(
                                    alpha: 0.08,
                                  ),
                                ),
                                child: article.coverImageUrl.isNotEmpty
                                    ? Image.network(
                                        article.coverImageUrl,
                                        width: double.infinity,
                                        height: 112,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            _cardPlaceholder(),
                                      )
                                    : _cardPlaceholder(),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 9,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.65),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  article.category.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Title
                        Text(
                          article.title,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF111827),
                            letterSpacing: -0.2,
                            height: 1.25,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),

                        const SizedBox(height: 5),

                        // Short description
                        Text(
                          article.shortDescription,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : const Color(0xFF6B7280),
                            height: 1.35,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _cardPlaceholder() {
    return Container(
      color: AppColors.brand.withValues(alpha: 0.08),
      child: const Center(
        child: Icon(Icons.menu_book_rounded, size: 38, color: AppColors.brand),
      ),
    );
  }
}

/// Auto-Swiping Promotional Banners Carousel with Disk Caching
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
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
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

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? AppColors.glassBorderDark
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: AspectRatio(
              aspectRatio: 3.0,
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
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
                      if (docs.length > 1)
                        Positioned(
                          right: AppSpacing.md,
                          bottom: 8,
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
