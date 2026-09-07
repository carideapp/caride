import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:caride/features/chat/conversation_screen.dart';
import 'package:caride/core/maps/dark_map_style.dart';
import 'package:caride/core/utils/phone_launcher.dart';
import 'package:caride/features/profile/data/driver_location_repository.dart';
import 'package:caride/features/profile/data/driver_public_profile_repository.dart';
import 'package:caride/features/ride_booking/data/ride_pricing_repository.dart';
import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:caride/features/ride_booking/data/arrival_calculator.dart';
import 'package:caride/core/maps/google_map_utils.dart';
import 'package:caride/core/config/app_env.dart';

class DriverTrackingScreen extends StatefulWidget {
  const DriverTrackingScreen({super.key, this.rideId});

  final String? rideId;

  @override
  State<DriverTrackingScreen> createState() => _DriverTrackingScreenState();
}

class _DriverTrackingScreenState extends State<DriverTrackingScreen> {
  final RideRepository _rideRepository = RideRepository();
  final DriverPublicProfileRepository _driverProfileRepository =
      DriverPublicProfileRepository();
  final RidePricingRepository _pricingRepo =
      RidePricingRepository(googleMapsApiKey: AppEnv.googleMapsApiKey);

  String? _rideId;
  GoogleMapController? _googleMapController;
  BitmapDescriptor? _carIcon;
  bool _followDriver = true;
  DateTime? _lastCameraUpdateAt;
  final ArrivalCalculator _arrivalCalculator = ArrivalCalculator();
  String _etaText = '';

  // ── State from streams ─────────────────────────────────────────────────
  RideModel? _ride;
  DriverRideLocation? _driverLocation;
  DriverPublicProfile? _driverProfile;

  // Position diffing — skip setState if driver moved < 5m
  double? _lastDriverLat;
  double? _lastDriverLng;
  // Route line refetch threshold: only re-fetch if driver moved >= 200m
  double? _lastRouteDriverLat;
  double? _lastRouteDriverLng;

  // ── Subscriptions ──────────────────────────────────────────────────────
  StreamSubscription<RideModel?>? _rideSub;
  StreamSubscription? _locationSub;
  StreamSubscription<DriverPublicProfile?>? _profileSub;
  StreamSubscription? _vehicleSub;

  String? _plateNumber;
  String? _color;
  String? _make;
  String? _model;

  // ── Map overlays ───────────────────────────────────────────────────────
  final Map<MarkerId, Marker> _markers = {};
  final Set<Circle> _circles = {};
  final Set<Polyline> _polylines = {};

  // Whether location permission is granted (for the blue dot).
  bool _locationPermissionGranted = false;

  @override
  void initState() {
    super.initState();
    _loadCarIcon();
    _checkLocationPermission();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rideId == null) {
      _rideId = widget.rideId ?? _readRideIdFromExtra();
      _startListening();
    }
  }

  @override
  void dispose() {
    _rideSub?.cancel();
    _locationSub?.cancel();
    _profileSub?.cancel();
    _vehicleSub?.cancel();
    _googleMapController?.dispose();
    super.dispose();
  }

  String? _readRideIdFromExtra() {
    try {
      final extra = GoRouterState.of(context).extra;
      if (extra is String) return extra;
      if (extra is Map<String, dynamic>) {
        final v = extra['rideId'];
        if (v is String) return v;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _checkLocationPermission() async {
    final perm = await Geolocator.checkPermission();
    final granted = perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
    if (mounted && granted != _locationPermissionGranted) {
      setState(() => _locationPermissionGranted = granted);
    }
  }

  Future<void> _loadCarIcon() async {
    try {
      // Use shared utility for consistent, correctly-sized bitmap
      final icon = await GoogleMapUtils.getDriverIcon(targetWidth: 44);
      if (mounted) {
        setState(() => _carIcon = icon);
      }
    } catch (_) {
      // Fallback to default marker — no crash
    }
  }

  void _startListening() {
    final rideId = _rideId;
    if (rideId == null || rideId.isEmpty) return;

    // Listen to ride changes
    _rideSub = _rideRepository.watchRide(rideId).listen((ride) {
      if (!mounted) return;
      final oldDriverUid = _ride?.driverUid;
      setState(() => _ride = ride);
      _updateRideOverlays();

      // If driver changed, re-subscribe to profile & location presence
      if (ride?.driverUid != null && (ride!.driverUid != oldDriverUid || _vehicleSub == null)) {
        _profileSub?.cancel();
        _profileSub = _driverProfileRepository
            .watchDriver(ride.driverUid!)
            .listen((profile) {
          if (mounted) setState(() => _driverProfile = profile);
        });

        _locationSub?.cancel();
        _locationSub = FirebaseFirestore.instance
            .collection('driverPresence')
            .doc(ride.driverUid!)
            .snapshots()
            .listen((doc) {
          if (!mounted) return;
          final data = doc.data();
          if (data != null) {
            final GeoPoint? lastLoc = data['lastLocation'] as GeoPoint?;
            if (lastLoc != null) {
              final loc = DriverRideLocation(
                latitude: lastLoc.latitude,
                longitude: lastLoc.longitude,
                heading: (data['heading'] as num?)?.toDouble() ?? 0.0,
              );
              _handleLocationUpdate(loc);
            }
          }
        });

        _vehicleSub?.cancel();
        _vehicleSub = FirebaseFirestore.instance
            .collection('drivers')
            .doc(ride.driverUid!)
            .collection('vehicle')
            .doc('info')
            .snapshots()
            .listen((doc) {
          if (!mounted) return;
          final data = doc.data();
          if (data != null) {
            setState(() {
              _color = data['color'] as String?;
              _make = data['make'] as String?;
              _model = data['model'] as String?;
              _plateNumber = data['plateNumber'] as String?;
            });
          }
        });
      }
    });
  }

  void _handleLocationUpdate(DriverRideLocation loc) {
    // Skip trivial updates when driver has not moved significantly (< 5 m)
    if (_lastDriverLat != null && _lastDriverLng != null) {
      final moved = Geolocator.distanceBetween(
          _lastDriverLat!, _lastDriverLng!, loc.latitude, loc.longitude);
      if (moved < 5.0) return;
    }
    _lastDriverLat = loc.latitude;
    _lastDriverLng = loc.longitude;

    // Compute new marker outside setState to keep it fast
    final newMarkers = Map<MarkerId, Marker>.from(_markers);

    final rotation = loc.heading != null ? (loc.heading! % 360) : 0.0;
    const markerId = MarkerId('driver_car');
    newMarkers[markerId] = Marker(
      markerId: markerId,
      position: LatLng(loc.latitude, loc.longitude),
      icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      rotation: rotation,
      anchor: const Offset(0.5, 0.5),
      flat: true,
    );

    final ride = _ride;

    // Single setState for the entire location update
    setState(() {
      _driverLocation = loc;
      _markers
        ..clear()
        ..addAll(newMarkers);
      // Keep existing polylines until async route fetch updates them
    });

    _animateCameraIfNeeded();

    // Fetch real road-following route (throttled: only if moved >= 200 m)
    if (ride != null) {
      final isEnRoute = ride.status == 'driverEnRoute';
      final targetLat = isEnRoute ? ride.pickupLat : ride.dropoffLat;
      final targetLng = isEnRoute ? ride.pickupLng : ride.dropoffLng;

      if (targetLat != null && targetLng != null) {
        final movedSinceLastRoute = (_lastRouteDriverLat != null && _lastRouteDriverLng != null)
            ? Geolocator.distanceBetween(
                _lastRouteDriverLat!, _lastRouteDriverLng!,
                loc.latitude, loc.longitude)
            : 9999.0;

        if (movedSinceLastRoute >= 200) {
          _lastRouteDriverLat = loc.latitude;
          _lastRouteDriverLng = loc.longitude;
          _pricingRepo
              .getRouteLine(
                fromLat: loc.latitude,
                fromLng: loc.longitude,
                toLat: targetLat,
                toLng: targetLng,
              )
              .then((routePoints) {
            if (!mounted) return;
            final pts = (routePoints != null && routePoints.isNotEmpty)
                ? routePoints
                : [LatLng(loc.latitude, loc.longitude), LatLng(targetLat, targetLng)];
            setState(() {
              _polylines
                ..clear()
                ..add(Polyline(
                  polylineId: const PolylineId('route'),
                  points: pts,
                  color: AppColors.primaryGreen,
                  width: 5,
                  patterns: [PatternItem.dash(12), PatternItem.gap(8)],
                ));
            });
          });
        }
      }
    }

    // ETA calculation (async, does not trigger setState here)
    final rideVal = _ride;
    if (rideVal != null) {
      final isTripInProgress = rideVal.status == 'inProgress' || rideVal.status == 'tripStarted';
      final destLat = isTripInProgress
          ? (rideVal.dropoffLat ?? rideVal.pickupLat)
          : rideVal.pickupLat;
      final destLng = isTripInProgress
          ? (rideVal.dropoffLng ?? rideVal.pickupLng)
          : rideVal.pickupLng;

      if (destLat != null && destLng != null) {
        _arrivalCalculator.calculateEta(
          driverLat: loc.latitude,
          driverLng: loc.longitude,
          destinationLat: destLat,
          destinationLng: destLng,
          isToPickup: !isTripInProgress,
        ).then((eta) {
          if (mounted && eta != _etaText) {
            setState(() => _etaText = eta);
          }
        });
      }
    }
  }

  // ── Map overlay updates ────────────────────────────────────────────────

  void _updateRideOverlays() {
    final ride = _ride;
    if (ride == null) return;
    final pickupLat = ride.pickupLat;
    final pickupLng = ride.pickupLng;
    final dropoffLat = ride.dropoffLat;
    final dropoffLng = ride.dropoffLng;
    final isEnRoute = ride.status == 'driverEnRoute';

    final newCircles = <Circle>{};
    final newMarkers = Map<MarkerId, Marker>.from(_markers);

    // Always show pickup pin
    if (pickupLat != null && pickupLng != null) {
      newCircles.add(Circle(
        circleId: const CircleId('pickup'),
        center: LatLng(pickupLat, pickupLng),
        radius: 20,
        fillColor: AppColors.primaryGreen.withValues(alpha: 0.8),
        strokeColor: Colors.white,
        strokeWidth: 2,
      ));
    }

    // Only show dropoff pin once the driver has picked up (ride started)
    if (!isEnRoute && dropoffLat != null && dropoffLng != null) {
      newCircles.add(Circle(
        circleId: const CircleId('dropoff'),
        center: LatLng(dropoffLat, dropoffLng),
        radius: 20,
        fillColor: AppColors.error.withValues(alpha: 0.8),
        strokeColor: Colors.white,
        strokeWidth: 2,
      ));
      const dropoffMarkerId = MarkerId('dropoff');
      newMarkers[dropoffMarkerId] = Marker(
        markerId: dropoffMarkerId,
        position: LatLng(dropoffLat, dropoffLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(
          title: 'Dropoff',
          snippet: ride.dropoffLabel,
        ),
      );
    } else {
      // Remove stale dropoff marker if now en route
      newMarkers.remove(const MarkerId('dropoff'));
    }

    setState(() {
      _circles
        ..clear()
        ..addAll(newCircles);
      _markers.addAll(newMarkers);
    });

    // If no driver location yet, zoom to pickup area
    if (_driverLocation == null && pickupLat != null && pickupLng != null) {
      _googleMapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(pickupLat, pickupLng), zoom: 13.5),
        ),
      );
    }
  }


  void _animateCameraIfNeeded() {
    if (!_followDriver) return;
    final loc = _driverLocation;
    final ride = _ride;
    if (loc == null) return;

    final now = DateTime.now();
    final last = _lastCameraUpdateAt;
    if (last != null && now.difference(last).inMilliseconds < 1200) return;
    _lastCameraUpdateAt = now;

    final driverPos = LatLng(loc.latitude, loc.longitude);
    final isEnRoute = ride?.status == 'driverEnRoute';

    // Uber/Bolt style: during driverEnRoute fit driver→pickup; during
    // rideStarted fit driver→dropoff.
    final targetLat = isEnRoute ? ride?.pickupLat : ride?.dropoffLat;
    final targetLng = isEnRoute ? ride?.pickupLng : ride?.dropoffLng;

    if (targetLat != null && targetLng != null) {
      final targetPos = LatLng(targetLat, targetLng);
      final bounds = LatLngBounds(
        southwest: LatLng(
          driverPos.latitude < targetPos.latitude
              ? driverPos.latitude
              : targetPos.latitude,
          driverPos.longitude < targetPos.longitude
              ? driverPos.longitude
              : targetPos.longitude,
        ),
        northeast: LatLng(
          driverPos.latitude > targetPos.latitude
              ? driverPos.latitude
              : targetPos.latitude,
          driverPos.longitude > targetPos.longitude
              ? driverPos.longitude
              : targetPos.longitude,
        ),
      );
      _googleMapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 80),
      );
    } else {
      _googleMapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: driverPos, zoom: 15.0),
        ),
      );
    }
  }

  Future<void> _recenter() async {
    setState(() => _followDriver = true);
    _lastCameraUpdateAt = null; // Force immediate update
    _animateCameraIfNeeded();
  }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rideId = _rideId;

    if (rideId == null || rideId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Invalid ride ID')));
    }

    final ride = _ride;
    final loc = _driverLocation;
    final profile = _driverProfile;

    // Derive display values
    final driverName = (profile?.fullName.trim().isNotEmpty ?? false)
        ? profile!.fullName
        : (ride?.driverName?.trim().isNotEmpty ?? false)
            ? ride!.driverName!
            : 'Driver';
    final phone = profile?.phone ?? '';

    final theme = Theme.of(context);

    // Formatting Make + Model + Color
    final vehicleDesc = [
      if (_color != null && _color!.isNotEmpty) _color,
      if (_make != null && _make!.isNotEmpty) _make,
      if (_model != null && _model!.isNotEmpty) _model,
    ].join(' ');

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(9.0820, 8.6753),
                zoom: 13.0,
              ),
              onMapCreated: (controller) {
                _googleMapController = controller;
                // Re-apply overlays if ride data arrived before map was created
                if (_ride != null) _updateRideOverlays();
                // If driver location arrived before map, apply it now
                if (_driverLocation != null) {
                  _animateCameraIfNeeded();
                }
              },
              style: isDark ? kGoogleMapDarkStyle : null,
              myLocationEnabled: _locationPermissionGranted,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              markers: Set<Marker>.from(_markers.values),
              circles: _circles,
              polylines: _polylines,
            ),
          ),

          // ── Top bar ────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  ),
                  const Spacer(),
                  IconButton.filledTonal(
                    onPressed: loc == null ? null : _recenter,
                    icon: Icon(
                      _followDriver
                          ? Icons.my_location_rounded
                          : Icons.location_searching_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom sheet ───────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: SafeArea(
                top: false,
                child: ride == null
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 8),
                          // 1. Header Title
                          Text(
                            ride.status == 'driverArrived'
                                ? 'Your Driver has arrived!'
                                : (ride.status == 'driverEnRoute'
                                    ? (_etaText.isNotEmpty
                                        ? 'Pickup in ${_etaText.replaceAll('Arriving in ', '')}'
                                        : 'Pickup in calculating...')
                                    : (ride.status == 'rideStarted' ? 'Heading to Destination' : _stageForRide(ride.status).$1)),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : AppColors.slate900,
                              fontSize: 26,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // 2. Driver Detail Row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Driver photo with verification checkmark badge
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark ? Colors.white24 : Colors.black12,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 28,
                                      backgroundColor: isDark
                                          ? const Color(0xFF2E2E2E)
                                          : const Color(0xFFF1F5F9),
                                      backgroundImage: (profile?.profilePhotoUrl != null &&
                                              profile!.profilePhotoUrl.isNotEmpty)
                                          ? NetworkImage(profile.profilePhotoUrl)
                                          : null,
                                      child: (profile?.profilePhotoUrl == null ||
                                              profile!.profilePhotoUrl.isEmpty)
                                          ? Icon(
                                              Icons.person_rounded,
                                              size: 32,
                                              color: isDark
                                                  ? Colors.white54
                                                  : AppColors.slate900.withValues(alpha: 0.6),
                                            )
                                          : null,
                                    ),
                                  ),
                                  // Verified gold badge
                                  Positioned(
                                    right: -3,
                                    bottom: -1,
                                    child: Container(
                                      padding: const EdgeInsets.all(1.5),
                                      decoration: const BoxDecoration(
                                        color: Colors.white, // White border ring
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.verified_rounded,
                                        size: 18,
                                        color: Color(0xFFFFB100), // Premium gold/amber color
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 18),

                              // Plate, vehicle spec, and driver name
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Plate Number Badge
                                    if (_plateNumber != null && _plateNumber!.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          _plateNumber!,
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.slate900,
                                            letterSpacing: 0.5,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 6),

                                    // Color · Make Model
                                    Text(
                                      vehicleDesc.isNotEmpty ? vehicleDesc : 'Vehicle info loading...',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white : AppColors.slate900,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 2),

                                    // Driver Full Name
                                    Text(
                                      driverName,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: isDark ? Colors.white60 : Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // 3. Start Code container if driverEnRoute
                          if (ride.status == 'driverEnRoute' &&
                              ride.startCode != null &&
                              ride.startCode!.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.brandGlass,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppColors.brand.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Ride Start Code',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white70 : AppColors.slate900,
                                    ),
                                  ),
                                  Text(
                                    ride.startCode!,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.brand,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),

                          // 4. Action Buttons Row (Chat with Driver and Phone Call)
                          Row(
                            children: [
                              // Chat Button
                              Expanded(
                                child: SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      final driverUid = ride.driverUid ?? '';
                                      Navigator.of(context, rootNavigator: true).push(
                                        MaterialPageRoute(
                                          builder: (_) => ConversationScreen(
                                            driverName: driverName,
                                            rideId: rideId,
                                            driverUid: driverUid,
                                          ),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F5F9),
                                      foregroundColor: isDark ? Colors.white : AppColors.slate900,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(26),
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.chat_bubble_rounded,
                                          size: 18,
                                          color: isDark ? Colors.white70 : AppColors.slate900,
                                        ),
                                        const SizedBox(width: 8),
                                        const Text(
                                          'Chat with driver',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Phone Call Button
                              SizedBox(
                                width: 52,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: phone.trim().isNotEmpty
                                      ? () async {
                                          final ok = await PhoneLauncher.call(phone);
                                          if (!context.mounted) return;
                                          if (!ok) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Unable to place call.'),
                                              ),
                                            );
                                          }
                                        }
                                      : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F5F9),
                                    foregroundColor: isDark ? Colors.white : AppColors.slate900,
                                    elevation: 0,
                                    shape: const CircleBorder(),
                                    padding: EdgeInsets.zero,
                                  ),
                                  child: Icon(
                                    Icons.call_rounded,
                                    size: 20,
                                    color: isDark ? Colors.white70 : AppColors.slate900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),
          ),

          // ── Loading indicator ──────────────────────────────────────
          if (_carIcon == null)
            const Align(
              alignment: Alignment.topCenter,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.only(top: AppSpacing.xl),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Status helpers ───────────────────────────────────────────────────────────

(String, String) _stageForRide(String status) {
  return switch (status) {
    'driverEnRoute' => (
        'Driver is heading to your pickup…',
        'Your driver is moving to your pickup point.'
      ),
    'driverArrived' => (
        'Your Driver has arrived!',
        'Please meet your driver at the pickup address.'
      ),
    'rideStarted' => (
        'On the way to your destination…',
        'Enjoy your ride. You can contact the driver if needed.'
      ),
    'completed' => ('Trip completed', 'Thanks for riding with CaRide.'),
    'cancelled' => ('Ride cancelled', 'This trip has been cancelled.'),
    'bidding' => ('Finding a driver…', 'Waiting for drivers to place bids.'),
    'requested' => ('Requesting ride…', 'Your ride request has been created.'),
    _ => ('Trip update', 'Tracking live ride updates.'),
  };
}
