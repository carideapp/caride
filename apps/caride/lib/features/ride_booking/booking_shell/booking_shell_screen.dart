import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caride/core/maps/google_route_overlay.dart';
import 'package:caride/core/maps/dark_map_style.dart';
import 'package:caride/core/config/app_env.dart';
import 'package:caride/features/profile/data/driver_location_repository.dart';
import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:caride/features/ride_booking/booking_shell/models/booking_shell_step.dart';
import 'package:caride/features/ride_booking/booking_shell/steps/driver_bids_step.dart';
import 'package:caride/features/ride_booking/booking_shell/steps/fare_step.dart';
import 'package:caride/features/ride_booking/booking_shell/steps/from_to_step.dart';
import 'package:caride/features/ride_booking/booking_shell/steps/ride_type_step.dart';
import 'package:caride/features/ride_booking/booking_shell/steps/tracking_step.dart';
import 'package:caride/features/ride_booking/booking_shell/widgets/booking_step_indicator.dart';
import 'package:caride/features/ride_booking/booking_shell/widgets/cancel_ride_bottom_sheet.dart';
import 'package:caride/features/ride_booking/data/ride_pricing_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:caride/features/profile/emergency_screen.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer Booking Shell container hosting the booking map and frosted bottom step sheets.
class BookingShellScreen extends StatefulWidget {
  const BookingShellScreen({super.key, this.extra});

  final Map<String, dynamic>? extra;

  @override
  State<BookingShellScreen> createState() => _BookingShellScreenState();
}

class _BookingShellScreenState extends State<BookingShellScreen> {
  late final BookingShellController _c;
  late BookingShellStep _lastStep;
  GoogleMapController? _map;
  GoogleRouteOverlay? _overlay;
  BitmapDescriptor? _carIcon;
  final bool _followDriver = true;
  DateTime? _lastCameraUpdateAt;
  StreamSubscription? _driverLocSub;
  String? _trackingRideId;

  final Map<MarkerId, Marker> _driverMarkers = {};
  LatLng? _driverLatLng;
  List<LatLng> _trackingRoutePoints = [];

  final RidePricingRepository _pricingRepo = RidePricingRepository(
    googleMapsApiKey: AppEnv.googleMapsApiKey,
  );
  double? _lastRouteDriverLat;
  double? _lastRouteDriverLng;
  String? _lastRideStatus;

  static const double _carBearingOffsetDeg = 0;

  double? _fabDragX;
  double? _fabDragY;

  @override
  void initState() {
    super.initState();
    _c = BookingShellController.fromExtra(extra: widget.extra);
    _lastStep = _c.step;
    unawaited(_c.ensureGpsFrom());
    _c.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _driverLocSub?.cancel();
    _c.removeListener(_onControllerChanged);
    _c.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _map = controller;
    _overlay = GoogleRouteOverlay(controller);
    unawaited(_initMap(controller));
  }

  Future<void> _initMap(GoogleMapController controller) async {
    unawaited(_loadCarIcon());
    unawaited(_syncOverlay());
  }

  Future<void> _loadCarIcon() async {
    if (_carIcon != null) return;
    final bytes = await rootBundle.load('lib/assets/car.png');
    _carIcon = BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      width: 44,
      height: 44,
    );
    _maybeStartTracking();
  }

  void _onControllerChanged() {
    final nextStep = _c.step;
    if (_lastStep != nextStep) {
      _lastStep = nextStep;
      HapticFeedback.selectionClick();
      if (nextStep == BookingShellStep.bids) {
        unawaited(_syncOverlay());
      }
    }

    final currentStatus = _c.ride?.status;
    if (currentStatus != _lastRideStatus) {
      final wasTripInProgress = _lastRideStatus == 'inProgress' ||
          _lastRideStatus == 'tripStarted' ||
          _lastRideStatus == 'rideStarted';
      final isTripInProgress = currentStatus == 'inProgress' ||
          currentStatus == 'tripStarted' ||
          currentStatus == 'rideStarted';

      _lastRideStatus = currentStatus;

      if (isTripInProgress && !wasTripInProgress) {
        // Driver has started the ride!
        // Immediately reset tracking route so polyline and camera switch to dropoff
        _trackingRoutePoints.clear();
        _lastRouteDriverLat = null;
        _lastRouteDriverLng = null;
        if (_driverLatLng != null) {
          final loc = DriverRideLocation(
            latitude: _driverLatLng!.latitude,
            longitude: _driverLatLng!.longitude,
          );
          unawaited(_syncDriverMarker(loc));
        }
      }
    }

    _maybeStartTracking();
    unawaited(_syncOverlay());
  }

  double _sheetHeightForStep(BookingShellStep step) {
    return switch (step) {
      BookingShellStep.fromTo => 336,
      BookingShellStep.rideType => 420,
      BookingShellStep.fare => 430,
      BookingShellStep.bids => 450,
      BookingShellStep.tracking => 370, // Reduced by 10% (370 -> 333)
    };
  }

  void _maybeStartTracking() {
    if (_map == null) return;
    if (_c.step != BookingShellStep.tracking) {
      _trackingRideId = null;
      _driverLocSub?.cancel();
      _driverLocSub = null;
      if (mounted) setState(() => _driverMarkers.clear());
      return;
    }

    final rideId = _c.rideId;
    if (rideId == null) return;
    if (_trackingRideId == rideId && _driverLocSub != null) return;

    _trackingRideId = rideId;
    _driverLocSub?.cancel();

    final driverUid = _c.ride?.driverUid;
    if (driverUid != null && driverUid.isNotEmpty) {
      _driverLocSub = FirebaseFirestore.instance
          .collection('driverPresence')
          .doc(driverUid)
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
                setState(() {
                  _driverLatLng = LatLng(lastLoc.latitude, lastLoc.longitude);
                });
                unawaited(_syncDriverMarker(loc));
              }
            }
          });
    }
  }

  Future<void> _syncDriverMarker(DriverRideLocation? loc) async {
    if (!mounted) return;

    final icon = _carIcon;
    if (loc == null || icon == null) {
      setState(() => _driverMarkers.clear());
      return;
    }

    final rotation = loc.heading != null
        ? (loc.heading! + _carBearingOffsetDeg) % 360
        : 0.0;
    final markerId = const MarkerId('driver_car');
    setState(() {
      _driverMarkers[markerId] = Marker(
        markerId: markerId,
        position: LatLng(loc.latitude, loc.longitude),
        icon: icon,
        rotation: rotation,
        anchor: const Offset(0.5, 0.5),
      );
    });

    final ride = _c.ride;
    final isTripStarted =
        ride?.status == 'inProgress' ||
        ride?.status == 'tripStarted' ||
        ride?.status == 'rideStarted';
    final destLat = isTripStarted
        ? (ride?.dropoffLat ?? ride?.pickupLat)
        : ride?.pickupLat;
    final destLng = isTripStarted
        ? (ride?.dropoffLng ?? ride?.pickupLng)
        : ride?.pickupLng;

    if (_followDriver) {
      final now = DateTime.now();
      final last = _lastCameraUpdateAt;
      if (last == null ||
          now.difference(last) > const Duration(milliseconds: 2000)) {
        _lastCameraUpdateAt = now;
        // Uber/Bolt style: fit camera to show both the driver and target pin (pickup or dropoff).
        if (destLat != null && destLng != null) {
          final driverLatLng = LatLng(loc.latitude, loc.longitude);
          final destLatLng = LatLng(destLat, destLng);
          final southwest = LatLng(
            driverLatLng.latitude < destLatLng.latitude
                ? driverLatLng.latitude
                : destLatLng.latitude,
            driverLatLng.longitude < destLatLng.longitude
                ? driverLatLng.longitude
                : destLatLng.longitude,
          );
          final northeast = LatLng(
            driverLatLng.latitude > destLatLng.latitude
                ? driverLatLng.latitude
                : destLatLng.latitude,
            driverLatLng.longitude > destLatLng.longitude
                ? driverLatLng.longitude
                : destLatLng.longitude,
          );
          await _map?.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(southwest: southwest, northeast: northeast),
              80.0, // padding in px
            ),
          );
        } else {
          await _map?.animateCamera(
            CameraUpdate.newLatLng(LatLng(loc.latitude, loc.longitude)),
          );
        }
      }
    }

    // ── Real road-following route (throttled: >= 200 m movement) ─────────
    if (destLat != null && destLng != null) {
      final movedSinceLastRoute =
          (_lastRouteDriverLat != null && _lastRouteDriverLng != null)
          ? Geolocator.distanceBetween(
              _lastRouteDriverLat!,
              _lastRouteDriverLng!,
              loc.latitude,
              loc.longitude,
            )
          : 9999.0;
      if (movedSinceLastRoute >= 200 || _trackingRoutePoints.isEmpty) {
        _lastRouteDriverLat = loc.latitude;
        _lastRouteDriverLng = loc.longitude;
        _pricingRepo
            .getRouteLine(
              fromLat: loc.latitude,
              fromLng: loc.longitude,
              toLat: destLat,
              toLng: destLng,
            )
            .then((routePoints) {
              if (!mounted) return;
              setState(() {
                _trackingRoutePoints = routePoints ?? [];
              });
            });
      }
    }
  }

  Future<void> _syncOverlay() async {
    final overlay = _overlay;
    if (overlay == null) return;

    // During tracking, clear the pickup→dropoff overlay so only the
    // driver→pickup dashed polyline + driver marker are visible on the map.
    if (_c.step == BookingShellStep.tracking) {
      overlay.clear();
      final ride = _c.ride;
      final isTripStarted =
          ride?.status == 'inProgress' ||
          ride?.status == 'tripStarted' ||
          ride?.status == 'rideStarted';
      final destLat = isTripStarted
          ? (ride?.dropoffLat ?? ride?.pickupLat)
          : ride?.pickupLat;
      final destLng = isTripStarted
          ? (ride?.dropoffLng ?? ride?.pickupLng)
          : ride?.pickupLng;
      if (destLat != null && destLng != null) {
        final destLatLng = LatLng(destLat, destLng);
        if (isTripStarted) {
          final pickupLatLng =
              (ride?.pickupLat != null && ride?.pickupLng != null)
              ? LatLng(ride!.pickupLat!, ride.pickupLng!)
              : destLatLng;
          await overlay.setPins(pickup: pickupLatLng, dropoff: destLatLng);
        } else {
          await overlay.setPins(pickup: destLatLng);
        }
      }
      if (mounted) setState(() {});
      return;
    }

    final from = _c.from;
    final to = _c.to;

    if (from == null || to == null) {
      overlay.clear();
      if (from != null) {
        await _map?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(from.centerLat, from.centerLng),
            14.0,
          ),
        );
      }
      setState(() {});
      return;
    }

    final fromLatLng = LatLng(from.centerLat, from.centerLng);
    final toLatLng = LatLng(to.centerLat, to.centerLng);

    await overlay.setPins(pickup: fromLatLng, dropoff: toLatLng);

    final line = _c.routeLine;
    if (line != null && line.isNotEmpty) {
      overlay.setRouteLine(line);
      await overlay.fitToRoute(
        pickup: fromLatLng,
        dropoff: toLatLng,
        route: line,
      );
    } else {
      await overlay.fitToRoute(pickup: fromLatLng, dropoff: toLatLng);
    }
    if (mounted) setState(() {});
  }

  void _recenter() {
    final from = _c.from;
    if (from != null) {
      _map?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(from.centerLat, from.centerLng),
          14.0,
        ),
      );
    }
  }

  void _handleBack() {
    switch (_c.step) {
      case BookingShellStep.fromTo:
        if (mounted) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go(CustomerRoutePaths.home);
          }
        }
        break;
      case BookingShellStep.rideType:
        _c.goTo(BookingShellStep.fromTo);
        break;
      case BookingShellStep.fare:
        _c.goTo(BookingShellStep.rideType);
        break;
      case BookingShellStep.bids:
        _showCancelBottomSheet();
        break;
      case BookingShellStep.tracking:
        if (mounted) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go(CustomerRoutePaths.home);
          }
        }
        break;
    }
  }

  void _showCancelBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          CancelRideBottomSheet(controller: _c, closeOnCancel: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overlay = _overlay;

    return Scaffold(
      body: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final isDark = theme.brightness == Brightness.dark;
          final isKeyboardUp = MediaQuery.of(context).viewInsets.bottom > 0;
          final double baseHeight = _sheetHeightForStep(_c.step);
          final double keyboardAdjustedHeight =
              (isKeyboardUp && _c.step == BookingShellStep.fromTo)
              ? 340.0
              : baseHeight;
          final double screenHeight = MediaQuery.of(context).size.height;
          final double sheetHeight = keyboardAdjustedHeight.clamp(
            160.0,
            screenHeight * 0.75,
          );
          final bottomPadding = sheetHeight + 16.0;
          return Stack(
            fit: StackFit.expand,
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: LatLng(9.0820, 8.6753),
                  zoom: 13.0,
                ),
                onMapCreated: _onMapCreated,
                style: isDark ? kGoogleMapDarkStyle : null,
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: false,
                mapToolbarEnabled: false,
                padding: EdgeInsets.only(bottom: bottomPadding),
                markers: {
                  if (overlay != null) ...overlay.markers.values,
                  ..._driverMarkers.values,
                },
                polylines: {
                  if (overlay != null) ...overlay.polylines.values,
                  if (_c.step == BookingShellStep.tracking &&
                      _driverLatLng != null &&
                      _c.ride != null) ...[
                    () {
                      final ride = _c.ride!;
                      final isTripStarted =
                          ride.status == 'inProgress' ||
                          ride.status == 'tripStarted' ||
                          ride.status == 'rideStarted';
                      final targetLat = isTripStarted
                          ? (ride.dropoffLat ?? ride.pickupLat)
                          : ride.pickupLat;
                      final targetLng = isTripStarted
                          ? (ride.dropoffLng ?? ride.pickupLng)
                          : ride.pickupLng;
                      if (targetLat == null || targetLng == null) {
                        return const Polyline(polylineId: PolylineId('empty'));
                      }
                      return Polyline(
                        polylineId: const PolylineId('driver_to_target'),
                        points: _trackingRoutePoints.isNotEmpty
                            ? _trackingRoutePoints
                            : [_driverLatLng!, LatLng(targetLat, targetLng)],
                        color: AppColors.brand,
                        width: 5,
                        patterns: [PatternItem.dash(12), PatternItem.gap(8)],
                      );
                    }(),
                  ],
                },
              ),

              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          (isDark
                                  ? AppColors.darkBackground
                                  : AppColors.lightBackground)
                              .withValues(alpha: 0.86),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: GlassSurface(
                    radius: AppRadius.xl,
                    padding: EdgeInsets.zero,
                    child: SizedBox(
                      height: sheetHeight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.pagePadding,
                          vertical: AppSpacing.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BookingStepIndicator(step: _c.step),
                            const SizedBox(height: AppSpacing.md),
                            Expanded(child: _placeholderStep(_c.step)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Top controls
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pagePadding,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      children: [
                        GlassIconButton(
                          icon:
                              (_c.step == BookingShellStep.fromTo ||
                                  _c.step == BookingShellStep.tracking)
                              ? Icons.close_rounded
                              : Icons.arrow_back_ios_new_rounded,
                          onPressed: _handleBack,
                        ),
                        const Spacer(),
                        GlassIconButton(
                          icon: Icons.my_location_rounded,
                          onPressed: _recenter,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_c.step == BookingShellStep.tracking)
                Positioned(
                  right: _fabDragX != null ? null : AppSpacing.pagePadding,
                  left: _fabDragX,
                  bottom: _fabDragY != null ? null : (sheetHeight + 108.0),
                  top: _fabDragY,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        final screenWidth = MediaQuery.of(context).size.width;
                        final screenHeight = MediaQuery.of(context).size.height;
                        final currentX =
                            _fabDragX ??
                            (screenWidth - AppSpacing.pagePadding - 56);
                        final currentY =
                            _fabDragY ??
                            (screenHeight - sheetHeight - 24.0 - 56);
                        _fabDragX = (currentX + details.delta.dx).clamp(
                          16.0,
                          screenWidth - 72.0,
                        );
                        _fabDragY = (currentY + details.delta.dy).clamp(
                          80.0,
                          screenHeight - 100.0,
                        );
                      });
                    },
                    child: FloatingActionButton(
                      heroTag: 'safety_fab_booking_shell',
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                EmergencyScreen(rideId: _c.ride?.id),
                          ),
                        );
                      },
                      backgroundColor: AppColors.error,
                      elevation: 4,
                      shape: const CircleBorder(),
                      child: const Icon(
                        Icons.shield_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _placeholderStep(BookingShellStep step) {
    switch (step) {
      case BookingShellStep.fromTo:
        return FromToStep(controller: _c, key: const ValueKey('fromTo'));
      case BookingShellStep.rideType:
        return RideTypeStep(controller: _c, key: const ValueKey('rideType'));
      case BookingShellStep.fare:
        return FareStep(controller: _c, key: const ValueKey('fare'));
      case BookingShellStep.bids:
        return DriverBidsStep(controller: _c, key: const ValueKey('bids'));
      case BookingShellStep.tracking:
        return TrackingStep(
          controller: _c,
          driverLatLng: _driverLatLng,
          key: const ValueKey('tracking'),
        );
    }
  }
}
