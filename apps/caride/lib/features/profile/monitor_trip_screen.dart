import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:caride/features/profile/data/driver_location_repository.dart';
import 'package:caride/features/profile/data/driver_public_profile_repository.dart';
import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:caride/features/ride_booking/data/arrival_calculator.dart';
import 'package:caride/core/maps/dark_map_style.dart';
import 'package:caride/core/maps/google_map_utils.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class MonitorTripScreen extends StatefulWidget {
  const MonitorTripScreen({super.key, this.params});

  final Map<String, dynamic>? params;

  @override
  State<MonitorTripScreen> createState() => _MonitorTripScreenState();
}

class _MonitorTripScreenState extends State<MonitorTripScreen> {
  final RideRepository _rideRepository = RideRepository();
  final DriverLocationRepository _driverLocationRepository = DriverLocationRepository();
  final DriverPublicProfileRepository _driverProfileRepository = DriverPublicProfileRepository();
  final ArrivalCalculator _arrivalCalculator = ArrivalCalculator();

  String? _rideId;
  String? _code;
  GoogleMapController? _googleMapController;
  BitmapDescriptor? _carIcon;
  bool _followDriver = true;
  DateTime? _lastCameraUpdateAt;
  String _etaText = '';

  RideModel? _ride;
  DriverRideLocation? _driverLocation;
  DriverPublicProfile? _driverProfile;
  String _customerName = 'Passenger';

  // Position diffing — skip setState if driver moved < 5m
  double? _lastDriverLat;
  double? _lastDriverLng;

  StreamSubscription<RideModel?>? _rideSub;
  StreamSubscription<DriverRideLocation?>? _locationSub;
  StreamSubscription<DriverPublicProfile?>? _profileSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _customerSub;

  final Map<MarkerId, Marker> _markers = {};
  final Set<Circle> _circles = {};
  final Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _rideId = widget.params?['rideId'] as String?;
    _code = widget.params?['code'] as String?;
    _loadCarIcon();
    _startListening();
  }

  @override
  void dispose() {
    _rideSub?.cancel();
    _locationSub?.cancel();
    _profileSub?.cancel();
    _customerSub?.cancel();
    _googleMapController?.dispose();
    super.dispose();
  }

  Future<void> _loadCarIcon() async {
    try {
      final icon = await GoogleMapUtils.getDriverIcon(targetWidth: 44);
      if (mounted) {
        setState(() => _carIcon = icon);
      }
    } catch (_) {}
  }

  void _startListening() {
    final rideId = _rideId;
    if (rideId == null || rideId.isEmpty) return;

    _rideSub = _rideRepository.watchRide(rideId).listen((ride) {
      if (!mounted) return;
      final oldDriverUid = _ride?.driverUid;
      final oldCustomerUid = _ride?.customerUid;
      setState(() => _ride = ride);
      _updateRideOverlays();

      if (ride != null) {
        // Fetch passenger/customer profile
        if (ride.customerUid != oldCustomerUid) {
          _customerSub?.cancel();
          _customerSub = FirebaseFirestore.instance
              .collection('customers')
              .doc(ride.customerUid)
              .snapshots()
              .listen((doc) {
            if (mounted) {
              setState(() {
                _customerName = doc.data()?['fullName'] as String? ?? 'Passenger';
              });
            }
          });
        }

        // Fetch driver profile
        if (ride.driverUid != null && ride.driverUid != oldDriverUid) {
          _profileSub?.cancel();
          _profileSub = _driverProfileRepository
              .watchDriver(ride.driverUid!)
              .listen((profile) {
            if (mounted) setState(() => _driverProfile = profile);
          });
        }
      }
    });

    _locationSub = _driverLocationRepository.watchRideDriverLocation(rideId).listen((loc) {
      if (!mounted) return;

      // Skip trivial updates when driver has not moved significantly (< 5 m)
      if (loc != null && _lastDriverLat != null && _lastDriverLng != null) {
        final moved = Geolocator.distanceBetween(
          _lastDriverLat!, _lastDriverLng!, loc.latitude, loc.longitude);
        if (moved < 5.0) return;
      }
      if (loc != null) {
        _lastDriverLat = loc.latitude;
        _lastDriverLng = loc.longitude;
      }

      // Compute new marker + polyline outside setState to keep it fast
      final newMarkers = Map<MarkerId, Marker>.from(_markers);
      final newPolylines = <Polyline>{};

      if (loc != null) {
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
        final dropoffLat = ride?.dropoffLat;
        final dropoffLng = ride?.dropoffLng;
        if (dropoffLat != null && dropoffLng != null) {
          newPolylines.add(Polyline(
            polylineId: const PolylineId('route'),
            points: [LatLng(loc.latitude, loc.longitude), LatLng(dropoffLat, dropoffLng)],
            color: AppColors.primaryGreen,
            width: 4,
            patterns: [PatternItem.dash(20), PatternItem.gap(10)],
          ));
        }
      } else {
        newMarkers.remove(const MarkerId('driver_car'));
      }

      // Single setState for the entire location update
      setState(() {
        _driverLocation = loc;
        _markers
          ..clear()
          ..addAll(newMarkers);
        _polylines
          ..clear()
          ..addAll(newPolylines);
      });

      _animateCameraIfNeeded();

      final ride = _ride;
      if (loc != null && ride != null) {
        final isTripInProgress = ride.status == 'inProgress' || ride.status == 'tripStarted';
        final destLat = isTripInProgress
            ? (ride.dropoffLat ?? ride.pickupLat)
            : ride.pickupLat;
        final destLng = isTripInProgress
            ? (ride.dropoffLng ?? ride.pickupLng)
            : ride.pickupLng;

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
    });
  }

  void _updateRideOverlays() {
    final ride = _ride;
    if (ride == null) return;
    final pickupLat = ride.pickupLat;
    final pickupLng = ride.pickupLng;
    final dropoffLat = ride.dropoffLat;
    final dropoffLng = ride.dropoffLng;

    final newCircles = <Circle>{};
    final newMarkers = Map<MarkerId, Marker>.from(_markers);

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

    if (dropoffLat != null && dropoffLng != null) {
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
    }

    setState(() {
      _circles
        ..clear()
        ..addAll(newCircles);
      _markers.addAll(newMarkers);
    });

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
    final dropoffLat = ride?.dropoffLat;
    final dropoffLng = ride?.dropoffLng;
    if (dropoffLat != null && dropoffLng != null) {
      final dropoffPos = LatLng(dropoffLat, dropoffLng);
      final bounds = LatLngBounds(
        southwest: LatLng(
          driverPos.latitude < dropoffPos.latitude ? driverPos.latitude : dropoffPos.latitude,
          driverPos.longitude < dropoffPos.longitude ? driverPos.longitude : dropoffPos.longitude,
        ),
        northeast: LatLng(
          driverPos.latitude > dropoffPos.latitude ? driverPos.latitude : dropoffPos.latitude,
          driverPos.longitude > dropoffPos.longitude ? driverPos.longitude : dropoffPos.longitude,
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

  void _recenter() {
    setState(() => _followDriver = true);
    _lastCameraUpdateAt = null;
    _animateCameraIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rideId = _rideId;

    if (rideId == null || rideId.isEmpty) {
      return const Scaffold(body: Center(child: Text('Invalid Trip ID')));
    }

    final ride = _ride;
    final loc = _driverLocation;
    final profile = _driverProfile;

    final driverName = (profile?.fullName.trim().isNotEmpty ?? false)
        ? profile!.fullName
        : (ride?.driverName?.trim().isNotEmpty ?? false)
            ? ride!.driverName!
            : 'Driver';
    final driverRating = profile?.averageRating ?? 0.0;
    final stage = ride != null ? _stageForRide(ride.status) : ('Loading…', '');

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(9.0820, 8.6753),
                zoom: 13.0,
              ),
              onMapCreated: (controller) {
                _googleMapController = controller;
                if (_ride != null) _updateRideOverlays();
                if (_driverLocation != null) {
                  _animateCameraIfNeeded();
                }
              },
              style: isDark ? kGoogleMapDarkStyle : null,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              markers: Set<Marker>.from(_markers.values),
              circles: _circles,
              polylines: _polylines,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 14),
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
                        border: Border.all(
                          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: loc == null ? null : _recenter,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        _followDriver
                            ? Icons.my_location_rounded
                            : Icons.location_searching_rounded,
                        size: 20,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: ride == null
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                            ),
                          ),
                        )
                      : Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.brand.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Code: $_code',
                                    style: const TextStyle(
                                      color: AppColors.brand,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _AddressRow(
                              iconColor: AppColors.primaryGreen,
                              label: ride.pickupLabel,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _AddressRow(
                              iconColor: AppColors.error,
                              label: ride.dropoffLabel,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const Divider(),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              stage.$1,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              (ride.status == 'driverEnRoute' && _etaText.isNotEmpty)
                                  ? _etaText
                                  : stage.$2,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            if (loc == null && ride.driverUid != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Waiting for driver location…',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryGreen,
                                    ),
                              ),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            const Divider(),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: const Icon(Icons.person_rounded, color: AppColors.primaryGreen),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _customerName,
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Text(
                                        'Passenger',
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                              color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                  child: Text(
                                    driverName.isEmpty ? '?' : driverName.substring(0, 1),
                                    style: Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        driverName.isEmpty ? 'Driver' : driverName,
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      if (driverRating > 0)
                                        Text(
                                          '★ ${driverRating.toStringAsFixed(1)} • Driver',
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
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

class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.iconColor, required this.label});

  final Color iconColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.location_on_rounded, color: iconColor, size: 18),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            label.isEmpty ? '—' : label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

(String, String) _stageForRide(String status) {
  return switch (status) {
    'driverEnRoute' => (
        'Driver is heading to pickup…',
        'The vehicle is moving to the passenger\'s pickup point.'
      ),
    'driverArrived' => (
        'Driver has arrived at pickup',
        'Driver is waiting for passenger at the pickup location.'
      ),
    'rideStarted' => (
        'On the way to destination…',
        'Friend is in transit. Vehicle is heading to the destination.'
      ),
    'completed' => ('Trip completed', 'The trip has safely completed.'),
    'cancelled' => ('Ride cancelled', 'This trip has been cancelled.'),
    'bidding' => ('Finding a driver…', 'Waiting for driver bids.'),
    'requested' => ('Requesting ride…', 'Ride request has been created.'),
    _ => ('Trip update', 'Tracking live updates.'),
  };
}
