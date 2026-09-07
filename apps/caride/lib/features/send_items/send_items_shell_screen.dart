import 'dart:async';

import 'package:caride/core/config/app_env.dart';
import 'package:caride/core/maps/google_route_overlay.dart';
import 'package:caride/core/maps/dark_map_style.dart';
import 'package:caride/features/profile/data/driver_location_repository.dart';
import 'package:caride/features/profile/emergency_screen.dart';
import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:caride/features/ride_booking/booking_shell/models/booking_shell_step.dart';
import 'package:caride/features/ride_booking/booking_shell/steps/driver_bids_step.dart';
import 'package:caride/features/ride_booking/booking_shell/steps/from_to_step.dart';
import 'package:caride/features/ride_booking/booking_shell/steps/tracking_step.dart';
import 'package:caride/features/ride_booking/booking_shell/widgets/cancel_ride_bottom_sheet.dart';
import 'package:caride/features/ride_booking/data/ride_pricing_repository.dart';
import 'package:caride/features/send_items/models/send_items_step.dart';
import 'package:caride/features/send_items/review_delivery_screen.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Full-screen booking shell for the Send Items (delivery/courier) flow.
///
/// Steps: fromTo → fare → (ReviewDeliveryScreen pushed) → bids → tracking
///
/// Reuses [BookingShellController], [FromToStep], [DriverBidsStep],
/// and [TrackingStep] from the ride booking flow. Review is a standalone screen.
class SendItemsShellScreen extends StatefulWidget {
  const SendItemsShellScreen({super.key, this.extra});

  final Map<String, dynamic>? extra;

  @override
  State<SendItemsShellScreen> createState() => _SendItemsShellScreenState();
}

class _SendItemsShellScreenState extends State<SendItemsShellScreen> {
  late final BookingShellController _c;
  final DriverLocationRepository _driverLocationRepository =
      DriverLocationRepository();
  final RidePricingRepository _pricingRepo =
      RidePricingRepository(googleMapsApiKey: AppEnv.googleMapsApiKey);

  BookingShellStep _lastBookingStep = BookingShellStep.fromTo;
  SendItemsStep _step = SendItemsStep.fromTo;
  GoogleMapController? _map;
  GoogleRouteOverlay? _overlay;
  BitmapDescriptor? _carIcon;
  DateTime? _lastCameraUpdateAt;
  StreamSubscription<DriverRideLocation?>? _driverLocSub;
  String? _trackingRideId;
  final Map<MarkerId, Marker> _driverMarkers = {};
  // Road-following polyline for tracking step
  final Set<Polyline> _trackingPolylines = {};
  // Route refetch throttle: only re-fetch if driver moved >= 200m
  double? _lastRouteDriverLat;
  double? _lastRouteDriverLng;
  double _dragOffset = 0.0;

  static const double _carBearingOffsetDeg = 0;

  @override
  void initState() {
    super.initState();
    _c = BookingShellController.fromExtra(extra: widget.extra);
    // Force ride type to Courier for all Send Items bookings
    _c.setRideType('Courier');
    _lastBookingStep = _c.step;
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
    unawaited(_loadCarIcon());
    unawaited(_syncOverlay());
  }

  Future<void> _loadCarIcon() async {
    if (_carIcon != null) return;
    final bytes = await rootBundle.load('lib/assets/motorcycle.png');
    _carIcon = BitmapDescriptor.bytes(
      bytes.buffer.asUint8List(),
      width: 44,
      height: 44,
    );
    _maybeStartTracking();
  }

  void _onControllerChanged() {
    // Track booking step changes driven by Firestore (bids + tracking).
    final bs = _c.step;
    if (_lastBookingStep != bs) {
      _lastBookingStep = bs;
      SendItemsStep? mapped;
      if (bs == BookingShellStep.bids &&
          (_step == SendItemsStep.review ||
              _step == SendItemsStep.fromTo ||
              _step == SendItemsStep.fare)) {
        mapped = SendItemsStep.bids;
      } else if (bs == BookingShellStep.tracking) {
        mapped = SendItemsStep.tracking;
      } else if (bs == BookingShellStep.fromTo &&
          _step == SendItemsStep.tracking) {
        mapped = SendItemsStep.fromTo;
      }
      if (mapped != null && mapped != _step) {
        setState(() {
          _step = mapped!;
          _dragOffset = 0;
        });
        HapticFeedback.selectionClick();
      }
    }
    _maybeStartTracking();
    unawaited(_syncOverlay());
  }

  void _maybeStartTracking() {
    if (_map == null) return;
    if (_step != SendItemsStep.tracking) {
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
    _driverLocSub = _driverLocationRepository
        .watchRideDriverLocation(rideId)
        .listen((loc) => unawaited(_syncDriverMarker(loc)));
  }

  Future<void> _syncDriverMarker(DriverRideLocation? loc) async {
    if (!mounted) return;
    final icon = _carIcon;
    if (loc == null || icon == null) {
      setState(() {
        _driverMarkers.clear();
      });
      return;
    }
    final rotation =
        loc.heading != null ? (loc.heading! + _carBearingOffsetDeg) % 360 : 0.0;
    const markerId = MarkerId('driver_car');
    setState(() {
      _driverMarkers[markerId] = Marker(
        markerId: markerId,
        position: LatLng(loc.latitude, loc.longitude),
        icon: icon,
        rotation: rotation,
        anchor: const Offset(0.5, 0.5),
      );
    });

    // ── Uber/Bolt camera: fit driver + pickup in bounds ──────────────────
    final now = DateTime.now();
    final last = _lastCameraUpdateAt;
    if (last == null || now.difference(last) > const Duration(milliseconds: 2000)) {
      _lastCameraUpdateAt = now;
      final ride = _c.ride;
      final pickupLat = ride?.pickupLat;
      final pickupLng = ride?.pickupLng;
      if (pickupLat != null && pickupLng != null) {
        final driverPos = LatLng(loc.latitude, loc.longitude);
        final pickupPos = LatLng(pickupLat, pickupLng);
        final southwest = LatLng(
          driverPos.latitude < pickupPos.latitude ? driverPos.latitude : pickupPos.latitude,
          driverPos.longitude < pickupPos.longitude ? driverPos.longitude : pickupPos.longitude,
        );
        final northeast = LatLng(
          driverPos.latitude > pickupPos.latitude ? driverPos.latitude : pickupPos.latitude,
          driverPos.longitude > pickupPos.longitude ? driverPos.longitude : pickupPos.longitude,
        );
        await _map?.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(southwest: southwest, northeast: northeast),
            80.0,
          ),
        );
      } else {
        await _map?.animateCamera(
          CameraUpdate.newLatLng(LatLng(loc.latitude, loc.longitude)),
        );
      }
    }

    // ── Real road-following route (throttled: >= 200 m movement) ─────────
    final ride = _c.ride;
    final pickupLat = ride?.pickupLat;
    final pickupLng = ride?.pickupLng;
    if (pickupLat != null && pickupLng != null) {
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
              toLat: pickupLat,
              toLng: pickupLng,
            )
            .then((routePoints) {
          if (!mounted) return;
          final pts = (routePoints != null && routePoints.isNotEmpty)
              ? routePoints
              : [LatLng(loc.latitude, loc.longitude), LatLng(pickupLat, pickupLng)];
          setState(() {
            _trackingPolylines
              ..clear()
              ..add(Polyline(
                polylineId: const PolylineId('driver_to_pickup'),
                points: pts,
                color: AppColors.brand,
                width: 5,
                patterns: [PatternItem.dash(12), PatternItem.gap(8)],
              ));
          });
        });
      }
    }
  }

  Future<void> _syncOverlay() async {
    final overlay = _overlay;
    if (overlay == null) return;

    try {
      // During tracking, clear pickup→dropoff overlay; show only pickup pin.
      if (_step == SendItemsStep.tracking) {
        overlay.clear();
        final ride = _c.ride;
        if (ride?.pickupLat != null && ride?.pickupLng != null) {
          await overlay.setPins(pickup: LatLng(ride!.pickupLat!, ride.pickupLng!));
        }
        if (mounted) setState(() {});
        return;
      }

      final from = _c.from;
      final to = _c.to;

      if (from == null || to == null) {
        overlay.clear();
        if (from != null) {
          try {
            await _map?.animateCamera(
              CameraUpdate.newLatLngZoom(
                  LatLng(from.centerLat, from.centerLng), 14.0),
            );
          } catch (_) {}
        }
        return;
      }

      final fromLatLng = LatLng(from.centerLat, from.centerLng);
      final toLatLng = LatLng(to.centerLat, to.centerLng);
      await overlay.setPins(pickup: fromLatLng, dropoff: toLatLng);

      final line = _c.routeLine;
      if (line != null && line.isNotEmpty) {
        overlay.setRouteLine(line);
        try {
          await overlay.fitToRoute(pickup: fromLatLng, dropoff: toLatLng, route: line);
        } catch (_) {}
      } else {
        try {
          await overlay.fitToRoute(pickup: fromLatLng, dropoff: toLatLng);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error syncing route overlay: $e');
    } finally {
      if (mounted) setState(() {});
    }
  }

  void _recenter() {
    final from = _c.from;
    if (from != null) {
      _map?.animateCamera(
        CameraUpdate.newLatLngZoom(
            LatLng(from.centerLat, from.centerLng), 14.0),
      );
    }
  }

  void _handleBack() {
    switch (_step) {
      case SendItemsStep.fromTo:
        if (mounted) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go(CustomerRoutePaths.home);
          }
        }
      case SendItemsStep.fare:
        setState(() => _step = SendItemsStep.fromTo);
      case SendItemsStep.review:
        // review is a pushed screen — this case is unreachable in normal flow
        setState(() => _step = SendItemsStep.fare);
      case SendItemsStep.bids:
        _showCancelBottomSheet();
      case SendItemsStep.tracking:
        if (mounted) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go(CustomerRoutePaths.home);
          }
        }
    }
  }

  void _showCancelBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CancelRideBottomSheet(
        controller: _c,
        closeOnCancel: false,
      ),
    );
  }

  double _sheetHeightForStep(SendItemsStep step) {
    return switch (step) {
      SendItemsStep.fromTo => 336,
      SendItemsStep.fare => 260,
      // review is a full-screen push — height unused but kept for exhaustive switch
      SendItemsStep.review => 430,
      SendItemsStep.bids => 550,
      SendItemsStep.tracking => 370,
    };
  }

  /// Advances from fromTo to fare when both addresses are set.
  void _onFromToNext() {
    if (_c.from != null && _c.to != null) {
      setState(() {
        _step = SendItemsStep.fare;
        _dragOffset = 0;
      });
    }
  }

  /// Called by FareStep when the user taps "Continue to Review" — pushes the
  /// standalone [ReviewDeliveryScreen] instead of showing it in the sheet.
  void _onFareNext() {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: false,
        builder: (_) => ReviewDeliveryScreen(
          controller: _c,
          onConfirmed: _onReviewConfirmed,
        ),
      ),
    );
  }

  /// Called by [ReviewDeliveryScreen] when the user taps "Confirm delivery".
  /// Creates the ride, pops the review screen, then advances to bids.
  Future<void> _onReviewConfirmed({
    required String paymentMethod,
    String? deliveryPin,
  }) async {
    // Pop the ReviewDeliveryScreen immediately to give instant visual feedback
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    
    setState(() {
      _step = SendItemsStep.bids;
      _dragOffset = 0;
    });

    await _c.requestRide(
      paymentMethod: paymentMethod,
      deliveryPin: deliveryPin,
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
          final double baseHeight = _sheetHeightForStep(_step);
          final double keyboardAdjustedHeight =
              (isKeyboardUp && _step == SendItemsStep.fromTo) ? 340.0 : baseHeight;
          final double drag = _step == SendItemsStep.fromTo ? _dragOffset : 0.0;
          final double rawHeight = keyboardAdjustedHeight - drag;
          final double screenHeight = MediaQuery.of(context).size.height;
          final double sheetHeight = rawHeight.clamp(160.0, screenHeight - 120.0);
          final double bottomPadding = sheetHeight + 16.0;

          return Stack(
            fit: StackFit.expand,
            children: [
              // ── Map ──
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
                  if (_step != SendItemsStep.tracking && overlay != null)
                    ...overlay.polylines.values,
                  ..._trackingPolylines,
                },
              ),

              // ── Gradient fade ──
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

              // ── Bottom sheet ──
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: GestureDetector(
                    onVerticalDragUpdate: _step == SendItemsStep.fromTo
                        ? (d) {
                            setState(() => _dragOffset += d.delta.dy);
                          }
                        : null,
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
                              // Step indicator + title (matches booking shell)
                              _SendItemsStepIndicator(step: _step),
                              const SizedBox(height: AppSpacing.md),
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: AppDurations.fast,
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  child: _buildStep(_step),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Safety FAB (tracking step only) — matches booking_shell_screen ──
              if (_step == SendItemsStep.tracking)
                Positioned(
                  bottom: bottomPadding + 12,
                  right: AppSpacing.pagePadding,
                  child: FloatingActionButton.extended(
                    heroTag: 'safety_fab_send_items',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EmergencyScreen(rideId: _c.ride?.id),
                        ),
                      );
                    },
                    backgroundColor: AppColors.error,
                    icon: const Icon(
                      Icons.shield_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: const Text(
                      'Safety',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // ── Top controls ──
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
                          icon: (_step == SendItemsStep.fromTo ||
                                  _step == SendItemsStep.tracking)
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
            ],
          );
        },
      ),
    );
  }

  Widget _buildStep(SendItemsStep step) {
    switch (step) {
      case SendItemsStep.fromTo:
        return _FromToWrapper(
          controller: _c,
          onNext: _onFromToNext,
          key: const ValueKey('si_fromTo'),
        );
      case SendItemsStep.fare:
        return _FareWrapper(
          controller: _c,
          onNext: _onFareNext,
          key: const ValueKey('si_fare'),
        );
      case SendItemsStep.review:
        // Review is now a pushed full-screen route — this state is unreachable
        // in normal flow but kept for enum exhaustiveness.
        return const SizedBox.shrink();
      case SendItemsStep.bids:
        return DriverBidsStep(
          controller: _c,
          key: const ValueKey('si_bids'),
        );
      case SendItemsStep.tracking:
        return TrackingStep(
          controller: _c,
          key: const ValueKey('si_tracking'),
        );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step indicator + title — mirrors BookingStepIndicator from booking_shell
// ─────────────────────────────────────────────────────────────────────────────

class _SendItemsStepIndicator extends StatelessWidget {
  const _SendItemsStepIndicator({required this.step});

  final SendItemsStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = switch (step) {
      SendItemsStep.fromTo => 'Where to & from?',
      SendItemsStep.fare => 'Set your delivery fare',
      SendItemsStep.review => 'Review delivery',
      SendItemsStep.bids => 'Finding a courier',
      SendItemsStep.tracking => 'Tracking delivery',
    };
    final idx = SendItemsStep.values.indexOf(step);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress dots (same style as BookingStepIndicator)
        Row(
          children: List.generate(SendItemsStep.values.length, (i) {
            final active = i <= idx;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: i == SendItemsStep.values.length - 1 ? 0 : AppSpacing.xs,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Step title
        Text(
          label,
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Thin wrappers so we can intercept "next" navigation
// ─────────────────────────────────────────────────────────────────────────────

/// Wraps [FromToStep] and triggers [onNext] when both addresses are set.
class _FromToWrapper extends StatefulWidget {
  const _FromToWrapper({
    super.key,
    required this.controller,
    required this.onNext,
  });

  final BookingShellController controller;
  final VoidCallback onNext;

  @override
  State<_FromToWrapper> createState() => _FromToWrapperState();
}

class _FromToWrapperState extends State<_FromToWrapper> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_check);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_check);
    super.dispose();
  }

  void _check() {
    if (widget.controller.step == BookingShellStep.rideType) {
      // Intercept the navigation when the user explicitly clicks "Done"
      // (which calls controller.goTo(rideType)). We reset it back to fromTo
      // to keep our shell in control, and trigger onNext ourselves.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.controller.goTo(BookingShellStep.fromTo);
          widget.onNext();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FromToStep(
      controller: widget.controller,
      hideTitle: true,
    );
  }
}

/// Wraps [FareStep] and intercepts the "Request Ride" action to redirect
/// to the Review step instead of creating the ride directly.
class _FareWrapper extends StatelessWidget {
  const _FareWrapper({
    super.key,
    required this.controller,
    required this.onNext,
  });

  final BookingShellController controller;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return _SendItemsFareStep(controller: controller, onNext: onNext);
  }
}

/// A modified FareStep for Send Items that shows "Continue to Review" instead
/// of "Request Ride" and does NOT submit the ride — just advances the step.
class _SendItemsFareStep extends StatefulWidget {
  const _SendItemsFareStep({
    required this.controller,
    required this.onNext,
  });

  final BookingShellController controller;
  final VoidCallback onNext;

  @override
  State<_SendItemsFareStep> createState() => _SendItemsFareStepState();
}

class _SendItemsFareStepState extends State<_SendItemsFareStep> {
  static const double _step = 50;
  bool _isNavigating = false;

  Future<void> _editOffer() async {
    final initial = widget.controller.offerNaira.round().toString();
    final ctrl = TextEditingController(text: initial);

    final v = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassSurface(
          radius: AppRadius.lg,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Set delivery fare',
                style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: ctrl,
                hint: 'Fare amount',
                obscureText: false,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Save',
                      onPressed: () {
                        final parsed = double.tryParse(
                          ctrl.text.trim().replaceAll(',', ''),
                        );
                        Navigator.pop(context, parsed);
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
    if (v != null) widget.controller.setOffer(v);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = widget.controller;

    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final offer = c.offerNaira;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassContainer(
              padding: EdgeInsets.zero,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => c.decrementOffer(step: _step),
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: _editOffer,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                        child: Column(
                          children: [
                            Text(
                              NgnFormat.whole(offer),
                              style: AppTextStyles.headlineMedium.copyWith(
                                color: AppColors.brand,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tap to edit',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => c.incrementOffer(step: _step),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Continue to Review',
              isLoading: _isNavigating,
              onPressed: (offer > 0 && !_isNavigating)
                  ? () async {
                      if (mounted) {
                        setState(() => _isNavigating = true);
                      }
                      widget.onNext();
                      await Future.delayed(const Duration(milliseconds: 800));
                      if (mounted) {
                        setState(() => _isNavigating = false);
                      }
                    }
                  : null,
            ),
          ],
        );
      },
    );
  }
}
