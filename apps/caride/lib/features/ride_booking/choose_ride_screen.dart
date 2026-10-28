import 'dart:math' as math;

import 'package:caride/core/config/app_env.dart';
import 'package:caride/core/maps/google_route_overlay.dart';
import 'package:caride/core/maps/dark_map_style.dart';
import 'package:caride/features/ride_booking/booking_shell/models/ride_option.dart';
import 'package:caride/features/ride_booking/data/ride_pricing_repository.dart';
import 'package:caride/features/ride_booking/data/ride_options_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Route params passed from HomeScreen.
class ChooseRideParams {
  const ChooseRideParams({
    required this.pickupLabel,
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLabel,
    required this.dropoffLat,
    required this.dropoffLng,
  });

  final String pickupLabel;
  final double pickupLat;
  final double pickupLng;
  final String dropoffLabel;
  final double dropoffLat;
  final double dropoffLng;
}

class ChooseRideScreen extends StatefulWidget {
  const ChooseRideScreen({super.key, this.params});

  final ChooseRideParams? params;

  @override
  State<ChooseRideScreen> createState() => _ChooseRideScreenState();
}

class _ChooseRideScreenState extends State<ChooseRideScreen> {
  final RidePricingRepository _pricingRepo = RidePricingRepository(
    googleMapsApiKey: AppEnv.googleMapsApiKey,
  );
  final RideOptionsRepository _rideOptionsRepo = RideOptionsRepository();

  GoogleRouteOverlay? _routeOverlay;
  List<LatLng>? _routeLine;

  String _selectedRideType = 'Regular';
  RidePricingConfig? _config;
  RouteInfo? _routeInfo;
  bool _loadingRoute = true;

  List<RideOption>? _rideOptions;

  @override
  void initState() {
    super.initState();
    _loadRideOptions();
    _loadPricingAndRoute();
  }

  Future<void> _loadRideOptions() async {
    final options = await _rideOptionsRepo.fetchRideOptions();
    if (mounted) {
      setState(() {
        _rideOptions = options;
      });
    }
  }

  Future<void> _loadPricingAndRoute() async {
    try {
      final config = await _pricingRepo.watchPricingConfig().first;
      if (mounted) setState(() => _config = config);
    } catch (_) {
      if (mounted) setState(() => _config = RidePricingConfig.defaults);
    }

    final p = widget.params;
    if (p != null && AppEnv.googleMapsApiKey.isNotEmpty) {
      final route = await _pricingRepo.getRouteInfo(
        fromLng: p.pickupLng,
        fromLat: p.pickupLat,
        toLng: p.dropoffLng,
        toLat: p.dropoffLat,
      );
      if (mounted) setState(() => _routeInfo = route);

      final line = await _pricingRepo.getRouteLine(
        fromLng: p.pickupLng,
        fromLat: p.pickupLat,
        toLng: p.dropoffLng,
        toLat: p.dropoffLat,
      );
      if (mounted) {
        setState(() => _routeLine = line);
        _syncMapOverlay();
      }
    }
    if (mounted) setState(() => _loadingRoute = false);
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _routeOverlay = GoogleRouteOverlay(controller);
    await _syncMapOverlay();
  }

  Future<void> _syncMapOverlay() async {
    final overlay = _routeOverlay;
    final p = widget.params;
    if (overlay == null || p == null) return;
    final fromLatLng = LatLng(p.pickupLat, p.pickupLng);
    final toLatLng = LatLng(p.dropoffLat, p.dropoffLng);
    await overlay.setPins(pickup: fromLatLng, dropoff: toLatLng);
    if (mounted) setState(() {});
    final line = _routeLine;
    if (line != null && line.isNotEmpty) {
      overlay.setRouteLine(line);
      await overlay.fitToRoute(
        pickup: fromLatLng,
        dropoff: toLatLng,
        route: line,
      );
    } else {
      await overlay.fitToRoute(
        pickup: fromLatLng,
        dropoff: toLatLng,
      );
    }
    if (mounted) setState(() {});
  }

  String _formattedPrice(String rideType) {
    final cfg = _config;
    if (cfg == null) return '...';
    final pricing = cfg.getPricingFor(
      rideType: rideType,
      operatingState: widget.params?.pickupLabel,
    );
    final distKm = _distanceKmForPricing();
    final durationMins = _durationMinutesForPricing();
    final range = _pricingRepo.computePriceRange(
      pricing: pricing,
      distanceKm: distKm,
      durationMinutes: durationMins,
    );
    return '₦${range.suggested.toStringAsFixed(0)}';
  }

  double _distanceKmForPricing() {
    final routeDist = _routeInfo?.distanceKm;
    if (routeDist != null) return routeDist;
    final p = widget.params;
    if (p == null) return 0.0;
    return _haversineDistance(
      lat1: p.pickupLat,
      lon1: p.pickupLng,
      lat2: p.dropoffLat,
      lon2: p.dropoffLng,
    );
  }

  double _durationMinutesForPricing() {
    final routeDuration = _routeInfo?.durationMinutes;
    if (routeDuration != null) return routeDuration;
    final distance = _distanceKmForPricing();
    const averageSpeedKmh = 30.0;
    return (distance / averageSpeedKmh) * 60.0;
  }

  double _haversineDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    const earthRadius = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  String _routeSummaryText() {
    if (_loadingRoute) return 'Calculating route details...';
    final routeDist = _routeInfo?.distanceKm;
    final routeDuration = _routeInfo?.durationMinutes;
    if (routeDist != null && routeDuration != null) {
      return '${routeDist.toStringAsFixed(1)} km · ${routeDuration.round()} min';
    }
    final distance = _distanceKmForPricing();
    final duration = _durationMinutesForPricing();
    return '${distance.toStringAsFixed(1)} km · ${duration.round()} min';
  }

  String _etaLabel() {
    final routeDuration = _routeInfo?.durationMinutes;
    if (routeDuration != null) {
      return 'ETA: ${routeDuration.round()} min';
    }
    final duration = _durationMinutesForPricing();
    return 'ETA: ${duration.round()} min';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final overlay = _routeOverlay;
    final options = _rideOptions ?? RideOptionsRepository.fallbackOptions;
    final selectedOption = options.cast<RideOption?>().firstWhere(
          (o) => o?.type == _selectedRideType,
          orElse: () => null,
        );

    final p = widget.params;
    final startLatLng = p != null
        ? LatLng(p.pickupLat, p.pickupLng)
        : const LatLng(9.0820, 8.6753);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        fit: StackFit.expand,
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: startLatLng,
              zoom: 13.0,
            ),
            onMapCreated: _onMapCreated,
            style: isDark ? kGoogleMapDarkStyle : null,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            padding: const EdgeInsets.only(bottom: 400),
            markers: overlay != null
                ? Set<Marker>.from(overlay.markers.values)
                : const {},
            polylines: overlay != null
                ? Set<Polyline>.from(overlay.polylines.values)
                : const {},
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
                      (isDark ? AppColors.darkBackground : AppColors.lightBackground).withValues(alpha: 0.86),
                    ],
                  ),
                ),
              ),
            ),
          ),

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
                      icon: Icons.arrow_back_ios_new_rounded,
                      onPressed: () => context.pop(),
                    ),
                  ],
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
                  height: 420,
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(AppSpacing.pagePadding),
                          children: [
                            Text(
                              'Choose a ride',
                              style: AppTextStyles.headlineSmall.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _routeSummaryText(),
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (_loadingRoute)
                              const Center(child: AppLoader())
                            else
                              ...List.generate(options.length, (index) {
                                final ride = options[index];
                                final selected = ride.type == _selectedRideType;
                                return Padding(
                                  padding: EdgeInsets.only(
                                    bottom: index == options.length - 1 ? 0 : AppSpacing.xs,
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                    onTap: () => setState(() => _selectedRideType = ride.type),
                                    child: AnimatedContainer(
                                      duration: AppDurations.fast,
                                      padding: const EdgeInsets.all(AppSpacing.sm),
                                      decoration: BoxDecoration(
                                        color: selected ? AppColors.brandGlass : Colors.transparent,
                                        borderRadius: BorderRadius.circular(AppRadius.lg),
                                        border: Border.all(
                                          color: selected
                                              ? AppColors.brand
                                              : (isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight),
                                          width: selected ? 1.5 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 72,
                                            height: 44,
                                            child: Image.asset(
                                              ride.assetPath,
                                              fit: BoxFit.contain,
                                              errorBuilder: (_, __, ___) => Icon(
                                                _rideIcon(ride.type),
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
                                                  ride.type,
                                                  style: AppTextStyles.bodyLarge.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  _etaLabel(),
                                                  style: AppTextStyles.bodySmall.copyWith(
                                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  ride.subtitle,
                                                  style: AppTextStyles.bodySmall.copyWith(
                                                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            _formattedPrice(ride.type),
                                            style: AppTextStyles.titleLarge.copyWith(
                                              color: AppColors.brand,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.pagePadding,
                          vertical: AppSpacing.sm,
                        ),
                        child: PrimaryButton(
                          label: selectedOption == null
                              ? 'Choose Ride'
                              : 'Choose ${selectedOption.type} Ride',
                          onPressed: (_config == null || selectedOption == null)
                              ? null
                              : () {
                                  final pricing = _config!.forType(selectedOption.type);
                                  final distKm = _distanceKmForPricing();
                                  final durationMins = _durationMinutesForPricing();
                                  final range = _pricingRepo.computePriceRange(
                                    pricing: pricing,
                                    distanceKm: distKm,
                                    durationMinutes: durationMins,
                                  );
                                  context.push(
                                    CustomerRoutePaths.rideOffers,
                                    extra: {
                                      'rideType': selectedOption.type,
                                      'priceMin': range.min,
                                      'priceMax': range.max,
                                      'priceSuggested': range.suggested,
                                      'pickupLabel': widget.params?.pickupLabel ?? '',
                                      'pickupLat': widget.params?.pickupLat ?? 0.0,
                                      'pickupLng': widget.params?.pickupLng ?? 0.0,
                                      'dropoffLabel': widget.params?.dropoffLabel ?? '',
                                      'dropoffLat': widget.params?.dropoffLat ?? 0.0,
                                      'dropoffLng': widget.params?.dropoffLng ?? 0.0,
                                    },
                                  );
                                },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _rideIcon(String rideName) {
  return switch (rideName.toLowerCase()) {
    'comfort' => Icons.airline_seat_recline_normal_rounded,
    'luxury' => Icons.star_rounded,
    'courier' => Icons.local_shipping_rounded,
    _ => Icons.directions_car_filled_rounded,
  };
}
