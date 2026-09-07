# BookingShell Implementation Plan
	
> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
	
**Goal:** Replace the customer booking multi-screen flow with a single `BookingShellScreen` (full-screen map + fixed-height premium bottom sheet) launched from `CustomerRoutePaths.rideSetPrice`.
	
**Architecture:** `BookingShellScreen` owns the Mapbox map and a `MapboxRouteOverlay`. A `BookingShellController` (`ChangeNotifier`) orchestrates step state, place selection, route computation, ride creation, bid streaming, and tracking streams, and the UI listens via `AnimatedBuilder`.
	
**Tech Stack:** Flutter, Firestore, Cloud Functions callables (accept/cancel), `mapbox_maps_flutter`, existing `design_system`, `permission_handler` (already), optional `geolocator` for GPS “From” default.
	
---
	
## File Structure (to be created/modified)
	
**Create**
- `lib/features/ride_booking/booking_shell/booking_shell_controller.dart` — state machine + repository orchestration
- `lib/features/ride_booking/booking_shell/booking_shell_screen.dart` — map background + fixed bottom sheet + step switcher
- `lib/features/ride_booking/booking_shell/models/booking_shell_step.dart` — step enum
- `lib/features/ride_booking/booking_shell/models/ride_option.dart` — ride option list (Regular/Comfort/Luxury/Courier)
- `lib/features/ride_booking/booking_shell/widgets/booking_step_indicator.dart` — minimal progress dots/segments
- `lib/features/ride_booking/booking_shell/steps/from_to_step.dart` — From/To selection UI
- `lib/features/ride_booking/booking_shell/steps/ride_type_step.dart` — ride type selection UI
- `lib/features/ride_booking/booking_shell/steps/fare_step.dart` — offer stepper + editable input + request CTA
- `lib/features/ride_booking/booking_shell/steps/driver_bids_step.dart` — bids list + accept/reject only
- `lib/features/ride_booking/booking_shell/steps/tracking_step.dart` — embedded tracking UI (map car + chat/call)
- `test/booking_shell_controller_test.dart` — controller state/logic tests
- `test/fare_stepper_test.dart` — pure logic tests for offer stepper behavior
	
**Modify**
- `lib/router/customer_route_factory.dart` — route `rideSetPrice` now returns `BookingShellScreen` and forwards the existing `extra` payload.
- `lib/features/profile/driver_tracking_screen.dart` — extract reusable “tracking content” into a widget that BookingShell can embed (or a shared helper in `lib/features/profile/widgets/`).
- `pubspec.yaml` — add `geolocator` dependency (if not already present) to fetch current GPS coordinates for default “From”.
	
---
	
## Task 1: Add BookingShell route (replace `rideSetPrice`)
	
**Files:**
- Modify: `lib/router/customer_route_factory.dart`
- Create: `lib/features/ride_booking/booking_shell/booking_shell_screen.dart` (stub)
- Test: `test/booking_shell_route_smoke_test.dart`
	
- [ ] **Step 1: Write a smoke widget test ensuring `rideSetPrice` builds BookingShell**
	
Create `test/booking_shell_route_smoke_test.dart`:
	
```dart
import 'package:caride/router/customer_route_factory.dart';
import 'package:caride/features/ride_booking/booking_shell/booking_shell_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('customer route factory builds BookingShell for rideSetPrice', () {
    final delegates = buildCustomerRouteDelegates();
    final widget = delegates.rideSetPrice(null, <String, dynamic>{});
    expect(widget, isA<BookingShellScreen>());
  });
}
```
	
- [ ] **Step 2: Run the test (expect FAIL: missing BookingShellScreen)**
	
Run:
```bash
flutter test test/booking_shell_route_smoke_test.dart
```
Expected: FAIL with import/type not found for `BookingShellScreen`.
	
- [ ] **Step 3: Create a minimal BookingShellScreen stub**
	
Create `lib/features/ride_booking/booking_shell/booking_shell_screen.dart`:
	
```dart
import 'package:caride/core/config/app_env.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class BookingShellScreen extends StatelessWidget {
  const BookingShellScreen({super.key, this.extra});

  final Map<String, dynamic>? extra;

  @override
  Widget build(BuildContext context) {
    final hasMapboxToken = AppEnv.mapboxAccessToken.isNotEmpty;
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (hasMapboxToken)
            const MapWidget()
          else
            Image.asset('lib/assets/map_placeholder.jpeg', fit: BoxFit.cover),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xl),
                  ),
                ),
                child: const SizedBox(height: 220),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```
	
- [ ] **Step 4: Update route factory to return BookingShellScreen**
	
Update `lib/router/customer_route_factory.dart` `rideSetPrice` delegate:
	
```dart
import 'package:caride/features/ride_booking/booking_shell/booking_shell_screen.dart';
```
	
And replace:
	
```dart
rideSetPrice: (context, dynamic extra) {
  if (extra is Map<String, dynamic>) {
    return ChooseRideScreen(
      params: ChooseRideParams(
        pickupLabel: extra['pickupLabel'] ?? '',
        pickupLat: extra['pickupLat'] ?? 0.0,
        pickupLng: extra['pickupLng'] ?? 0.0,
        dropoffLabel: extra['dropoffLabel'] ?? '',
        dropoffLat: extra['dropoffLat'] ?? 0.0,
        dropoffLng: extra['dropoffLng'] ?? 0.0,
      ),
    );
  }
  return const ChooseRideScreen();
},
```
	
With:
	
```dart
rideSetPrice: (context, dynamic extra) {
  return BookingShellScreen(
    extra: extra is Map<String, dynamic> ? extra : null,
  );
},
```
	
- [ ] **Step 5: Run the smoke test (expect PASS)**
	
Run:
```bash
flutter test test/booking_shell_route_smoke_test.dart
```
Expected: PASS.
	
---
	
## Task 2: Define BookingShell models (step enum + ride options)
	
**Files:**
- Create: `lib/features/ride_booking/booking_shell/models/booking_shell_step.dart`
- Create: `lib/features/ride_booking/booking_shell/models/ride_option.dart`
- Test: `test/booking_shell_models_test.dart`
	
- [ ] **Step 1: Add tests for step ordering and ride option list**
	
Create `test/booking_shell_models_test.dart`:
	
```dart
import 'package:caride/features/ride_booking/booking_shell/models/booking_shell_step.dart';
import 'package:caride/features/ride_booking/booking_shell/models/ride_option.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('booking steps have stable order', () {
    expect(BookingShellStep.values, [
      BookingShellStep.fromTo,
      BookingShellStep.rideType,
      BookingShellStep.fare,
      BookingShellStep.bids,
      BookingShellStep.tracking,
    ]);
  });

  test('ride options include Regular/Comfort/Luxury/Courier', () {
    final types = rideOptions.map((o) => o.type).toList();
    expect(types, ['Regular', 'Comfort', 'Luxury', 'Courier']);
  });
}
```
	
- [ ] **Step 2: Run tests (expect FAIL: missing files)**
	
Run:
```bash
flutter test test/booking_shell_models_test.dart
```
Expected: FAIL due to missing imports.
	
- [ ] **Step 3: Implement step enum**
	
Create `lib/features/ride_booking/booking_shell/models/booking_shell_step.dart`:
	
```dart
enum BookingShellStep {
  fromTo,
  rideType,
  fare,
  bids,
  tracking,
}
```
	
- [ ] **Step 4: Implement ride options**
	
Create `lib/features/ride_booking/booking_shell/models/ride_option.dart`:
	
```dart
class RideOption {
  const RideOption({
    required this.type,
    required this.subtitle,
    required this.assetPath,
  });

  final String type;
  final String subtitle;
  final String assetPath;
}

const List<RideOption> rideOptions = [
  RideOption(
    type: 'Regular',
    subtitle: 'Affordable rides, all to yourself',
    assetPath: 'lib/assets/ride_options/regular.png',
  ),
  RideOption(
    type: 'Comfort',
    subtitle: 'Faster pickup with better comfort',
    assetPath: 'lib/assets/ride_options/comfort.png',
  ),
  RideOption(
    type: 'Luxury',
    subtitle: 'Premium trip experience',
    assetPath: 'lib/assets/ride_options/luxury.png',
  ),
  RideOption(
    type: 'Courier',
    subtitle: 'Send and receive packages',
    assetPath: 'lib/assets/ride_options/courier.png',
  ),
];
```
	
- [ ] **Step 5: Run tests (expect PASS)**
	
Run:
```bash
flutter test test/booking_shell_models_test.dart
```
Expected: PASS.
	
---
	
## Task 3: BookingShellController (state machine + orchestration)
	
**Files:**
- Create: `lib/features/ride_booking/booking_shell/booking_shell_controller.dart`
- Modify (dependency): `pubspec.yaml` (add `geolocator`)
- Test: `test/booking_shell_controller_test.dart`
	
- [ ] **Step 1: Add controller tests for smart-start and offer stepper logic**
	
Create `test/booking_shell_controller_test.dart`:
	
```dart
import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:caride/features/ride_booking/booking_shell/models/booking_shell_step.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('smart start: starts at rideType when extra has pickup+dropoff', () {
    final c = BookingShellController.fromExtra(
      extra: {
        'pickupLabel': 'A',
        'pickupLat': 1.0,
        'pickupLng': 2.0,
        'dropoffLabel': 'B',
        'dropoffLat': 3.0,
        'dropoffLng': 4.0,
      },
    );
    expect(c.step, BookingShellStep.rideType);
  });

  test('smart start: starts at fromTo when extra missing dropoff', () {
    final c = BookingShellController.fromExtra(
      extra: {
        'pickupLabel': 'A',
        'pickupLat': 1.0,
        'pickupLng': 2.0,
      },
    );
    expect(c.step, BookingShellStep.fromTo);
  });

  test('offer stepper increments/decrements with floor at 0', () {
    final c = BookingShellController.fromExtra(extra: null);
    c.setOffer(100);
    c.decrementOffer(step: 50);
    expect(c.offerNaira, 50);
    c.decrementOffer(step: 999);
    expect(c.offerNaira, 0);
    c.incrementOffer(step: 25);
    expect(c.offerNaira, 25);
  });
}
```
	
- [ ] **Step 2: Run tests (expect FAIL: controller missing)**
	
Run:
```bash
flutter test test/booking_shell_controller_test.dart
```
Expected: FAIL due to missing controller file.
	
- [ ] **Step 3: Add `geolocator` dependency**
	
Modify `pubspec.yaml` dependencies to include:
	
```yaml
  geolocator: ^13.0.1
```
	
Then run:
```bash
flutter pub get
```
Expected: dependency resolves successfully.
	
- [ ] **Step 4: Implement BookingShellController**
	
Create `lib/features/ride_booking/booking_shell/booking_shell_controller.dart`:
	
```dart
import 'dart:async';

import 'package:caride/core/config/app_env.dart';
import 'package:caride/core/config/app_config_repository.dart';
import 'package:caride/features/home_map/data/mapbox_search_service.dart';
import 'package:caride/features/home_map/data/recent_places_repository.dart';
import 'package:caride/features/profile/data/address_repository.dart';
import 'package:caride/features/ride_booking/booking_shell/models/booking_shell_step.dart';
import 'package:caride/features/ride_booking/booking_shell/models/ride_option.dart';
import 'package:caride/features/ride_booking/data/ride_pricing_repository.dart';
import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class BookingShellController extends ChangeNotifier {
  BookingShellController({
    required RidePricingRepository pricingRepository,
    required RideRepository rideRepository,
    required RecentPlacesRepository recentPlacesRepository,
    required AddressRepository addressRepository,
    required AppConfigRepository configRepository,
    required MapboxSearchService searchService,
    Map<String, dynamic>? extra,
  })  : _pricingRepository = pricingRepository,
        _rideRepository = rideRepository,
        _recentPlacesRepository = recentPlacesRepository,
        _addressRepository = addressRepository,
        _configRepository = configRepository,
        _searchService = searchService {
    _initFromExtra(extra);
    _defaultsSub = _configRepository.watchAppDefaults().listen((v) {
      _defaults = v;
      if (_from == null && v != null) {
        _from = MapboxPlace(
          id: 'pickup',
          placeName: 'Pickup location',
          centerLng: v.defaultMapCenterLng,
          centerLat: v.defaultMapCenterLat,
        );
        notifyListeners();
      }
    });
  }

  factory BookingShellController.fromExtra({Map<String, dynamic>? extra}) {
    final pricingRepository = RidePricingRepository(mapboxAccessToken: AppEnv.mapboxAccessToken);
    return BookingShellController(
      pricingRepository: pricingRepository,
      rideRepository: RideRepository(),
      recentPlacesRepository: RecentPlacesRepository(),
      addressRepository: AddressRepository(),
      configRepository: AppConfigRepository(),
      searchService: MapboxSearchService(AppEnv.mapboxAccessToken),
      extra: extra,
    );
  }

  final RidePricingRepository _pricingRepository;
  final RideRepository _rideRepository;
  final RecentPlacesRepository _recentPlacesRepository;
  final AddressRepository _addressRepository;
  final AppConfigRepository _configRepository;
  final MapboxSearchService _searchService;

  StreamSubscription? _defaultsSub;
  AppDefaults? _defaults;

  BookingShellStep _step = BookingShellStep.fromTo;
  BookingShellStep get step => _step;

  MapboxPlace? _from;
  MapboxPlace? get from => _from;

  MapboxPlace? _to;
  MapboxPlace? get to => _to;

  List<MapboxPlace> _searchResults = const [];
  List<MapboxPlace> get searchResults => _searchResults;

  bool _searching = false;
  bool get searching => _searching;

  List<Position>? _routeLine;
  List<Position>? get routeLine => _routeLine;

  RouteInfo? _routeInfo;
  RouteInfo? get routeInfo => _routeInfo;

  String _rideType = rideOptions.first.type;
  String get rideType => _rideType;

  double _offerNaira = 0;
  double get offerNaira => _offerNaira;

  String? _rideId;
  String? get rideId => _rideId;

  Stream<RideModel?>? _rideStream;
  Stream<RideModel?>? get rideStream => _rideStream;

  Stream<List<DriverBid>>? _bidsStream;
  Stream<List<DriverBid>>? get bidsStream => _bidsStream;

  void _initFromExtra(Map<String, dynamic>? extra) {
    if (extra == null) return;
    final hasPickup = extra['pickupLat'] != null && extra['pickupLng'] != null;
    final hasDropoff = extra['dropoffLat'] != null && extra['dropoffLng'] != null;
    if (hasPickup) {
      _from = MapboxPlace(
        id: 'pickup',
        placeName: (extra['pickupLabel'] as String?) ?? 'Pickup',
        centerLat: (extra['pickupLat'] as num).toDouble(),
        centerLng: (extra['pickupLng'] as num).toDouble(),
      );
    }
    if (hasDropoff) {
      _to = MapboxPlace(
        id: 'dropoff',
        placeName: (extra['dropoffLabel'] as String?) ?? 'Dropoff',
        centerLat: (extra['dropoffLat'] as num).toDouble(),
        centerLng: (extra['dropoffLng'] as num).toDouble(),
      );
    }
    _step = (hasPickup && hasDropoff) ? BookingShellStep.rideType : BookingShellStep.fromTo;
  }

  Future<void> ensureGpsFrom() async {
    if (_from != null) return;
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _from = MapboxPlace(
        id: 'gps',
        placeName: 'Current location',
        centerLng: pos.longitude,
        centerLat: pos.latitude,
      );
      notifyListeners();
    } catch (_) {}
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = const [];
      _searching = false;
      notifyListeners();
      return;
    }
    _searching = true;
    notifyListeners();
    final proximity = _from;
    final results = await _searchService.searchPlaces(
      query,
      proximityLat: proximity?.centerLat,
      proximityLng: proximity?.centerLng,
    );
    _searchResults = results;
    _searching = false;
    notifyListeners();
  }

  void setFrom(MapboxPlace place) {
    _from = place;
    _recentPlacesRepository.recordPlace(place);
    notifyListeners();
  }

  void setTo(MapboxPlace place) {
    _to = place;
    _recentPlacesRepository.recordPlace(place);
    notifyListeners();
  }

  void setRideType(String type) {
    _rideType = type;
    notifyListeners();
  }

  void setOffer(double value) {
    _offerNaira = value < 0 ? 0 : value;
    notifyListeners();
  }

  void incrementOffer({required double step}) {
    _offerNaira = (_offerNaira + step).clamp(0, double.infinity);
    notifyListeners();
  }

  void decrementOffer({required double step}) {
    _offerNaira = (_offerNaira - step).clamp(0, double.infinity);
    notifyListeners();
  }

  void goTo(BookingShellStep next) {
    _step = next;
    notifyListeners();
  }

  Future<void> refreshRoute() async {
    final from = _from;
    final to = _to;
    if (from == null || to == null) {
      _routeInfo = null;
      _routeLine = null;
      notifyListeners();
      return;
    }

    if (AppEnv.mapboxAccessToken.isEmpty) return;

    final info = await _pricingRepository.getRouteInfo(
      fromLng: from.centerLng,
      fromLat: from.centerLat,
      toLng: to.centerLng,
      toLat: to.centerLat,
    );
    final line = await _pricingRepository.getRouteLine(
      fromLng: from.centerLng,
      fromLat: from.centerLat,
      toLng: to.centerLng,
      toLat: to.centerLat,
    );
    _routeInfo = info;
    _routeLine = line;
    notifyListeners();
  }

  Future<void> requestRide({required String paymentMethod}) async {
    final from = _from;
    final to = _to;
    if (from == null || to == null) throw Exception('Missing pickup/dropoff.');
    final id = await _rideRepository.createRideRequest(
      pickupLabel: from.placeName,
      pickupLat: from.centerLat,
      pickupLng: from.centerLng,
      dropoffLabel: to.placeName,
      dropoffLat: to.centerLat,
      dropoffLng: to.centerLng,
      rideType: _rideType,
      customerOffer: _offerNaira,
      paymentMethod: paymentMethod,
    );
    _rideId = id;
    _rideStream = _rideRepository.watchRide(id);
    _bidsStream = _rideRepository.watchBids(id);
    _step = BookingShellStep.bids;
    notifyListeners();
  }

  Future<void> acceptBid(DriverBid bid) async {
    final id = _rideId;
    if (id == null) return;
    await _rideRepository.acceptBid(rideId: id, bid: bid);
    _step = BookingShellStep.tracking;
    notifyListeners();
  }

  Future<void> declineBid(String bidId) async {
    final id = _rideId;
    if (id == null) return;
    await _rideRepository.declineBid(rideId: id, bidId: bidId);
  }

  Future<void> cancelRide({String? reason}) async {
    final id = _rideId;
    if (id == null) return;
    await _rideRepository.cancelRide(id, reason: reason);
  }

  @override
  void dispose() {
    _defaultsSub?.cancel();
    super.dispose();
  }
}
```
	
- [ ] **Step 5: Fix compile errors by correcting imports to match actual paths**
	
If the repository/model imports differ, align them to the existing code:
- `RidePricingRepository` + `RouteInfo`: `lib/features/ride_booking/data/ride_pricing_repository.dart`
- `RideRepository`, `RideModel`, `DriverBid`: `lib/features/ride_booking/data/ride_repository.dart`
- `rideOptions`: `lib/features/ride_booking/booking_shell/models/ride_option.dart`
	
- [ ] **Step 6: Run controller tests (expect PASS)**
	
Run:
```bash
flutter test test/booking_shell_controller_test.dart
```
Expected: PASS.
	
---
	
## Task 4: BookingShellScreen UI (map + fixed premium sheet + step switcher)
	
**Files:**
- Modify: `lib/features/ride_booking/booking_shell/booking_shell_screen.dart` (replace stub)
- Create: `lib/features/ride_booking/booking_shell/widgets/booking_step_indicator.dart`
- Create: step widgets under `lib/features/ride_booking/booking_shell/steps/`
	
- [ ] **Step 1: Replace BookingShellScreen stub with controller-driven layout**
	
Replace `lib/features/ride_booking/booking_shell/booking_shell_screen.dart` with:
	
```dart
import 'dart:async';

import 'package:caride/core/config/app_env.dart';
import 'package:caride/core/maps/mapbox_route_overlay.dart';
import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:caride/features/ride_booking/booking_shell/models/booking_shell_step.dart';
import 'package:caride/features/ride_booking/booking_shell/steps/driver_bids_step.dart';
import 'package:caride/features/ride_booking/booking_shell/steps/fare_step.dart';
import 'package:caride/features/ride_booking/booking_shell/steps/from_to_step.dart';
import 'package:caride/features/ride_booking/booking_shell/steps/ride_type_step.dart';
import 'package:caride/features/ride_booking/booking_shell/steps/tracking_step.dart';
import 'package:caride/features/ride_booking/booking_shell/widgets/booking_step_indicator.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:navigation/navigation.dart';

class BookingShellScreen extends StatefulWidget {
  const BookingShellScreen({super.key, this.extra});

  final Map<String, dynamic>? extra;

  @override
  State<BookingShellScreen> createState() => _BookingShellScreenState();
}

class _BookingShellScreenState extends State<BookingShellScreen> {
  late final BookingShellController _c;
  MapboxMap? _map;
  MapboxRouteOverlay? _overlay;
  bool _follow = true;
  Timer? _followThrottle;

  @override
  void initState() {
    super.initState();
    MapboxOptions.setAccessToken(AppEnv.mapboxAccessToken);
    _c = BookingShellController.fromExtra(extra: widget.extra);
    unawaited(_c.ensureGpsFrom());
    _c.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _followThrottle?.cancel();
    _c.removeListener(_onControllerChanged);
    _c.dispose();
    super.dispose();
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _map = mapboxMap;
    _overlay = MapboxRouteOverlay(mapboxMap);
    unawaited(_syncOverlay());
  }

  void _onControllerChanged() {
    unawaited(_syncOverlay());
  }

  Future<void> _syncOverlay() async {
    final overlay = _overlay;
    final from = _c.from;
    final to = _c.to;
    if (overlay == null) return;
    if (from == null && to == null) {
      await overlay.clear();
      return;
    }
    if (from != null && to != null) {
      await overlay.setPins(
        pickup: Position(from.centerLng, from.centerLat),
        dropoff: Position(to.centerLng, to.centerLat),
      );
      final line = _c.routeLine;
      if (line != null && line.isNotEmpty) {
        await overlay.setRouteLine(line);
        await overlay.fitToRoute(
          pickup: Position(from.centerLng, from.centerLat),
          dropoff: Position(to.centerLng, to.centerLat),
          route: line,
        );
      } else {
        await overlay.fitToRoute(
          pickup: Position(from.centerLng, from.centerLat),
          dropoff: Position(to.centerLng, to.centerLat),
        );
      }
      return;
    }
    final p = from ?? to!;
    await overlay.setPins(
      pickup: Position(p.centerLng, p.centerLat),
      dropoff: Position(p.centerLng, p.centerLat),
    );
  }

  void _onUserGesture() {
    if (!_follow) return;
    setState(() => _follow = false);
  }

  Future<void> _recenter() async {
    final map = _map;
    if (map == null) return;
    setState(() => _follow = true);
    await _syncOverlay();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMapboxToken = AppEnv.mapboxAccessToken.isNotEmpty;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (hasMapboxToken)
            MapWidget(
              onMapCreated: _onMapCreated,
              onTapListener: (_, __) => _onUserGesture(),
              onScrollListener: (_) => _onUserGesture(),
              onZoomListener: (_) => _onUserGesture(),
              onRotateListener: (_) => _onUserGesture(),
              onPitchListener: (_) => _onUserGesture(),
            )
          else
            Image.asset('lib/assets/map_placeholder.jpeg', fit: BoxFit.cover),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    theme.scaffoldBackgroundColor.withValues(alpha: 0.86),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  const Spacer(),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      onPressed: _recenter,
                      icon: Icon(_follow ? Icons.my_location_rounded : Icons.location_searching_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(AppRadius.xl),
                      ),
                    ),
                    child: SizedBox(
                      height: 340,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            BookingStepIndicator(step: _c.step),
                            const SizedBox(height: AppSpacing.md),
                            Expanded(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 260),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                child: _stepBody(_c.step),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepBody(BookingShellStep step) {
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
        return TrackingStep(controller: _c, key: const ValueKey('tracking'));
    }
  }
}
```
	
- [ ] **Step 2: Implement BookingStepIndicator**
	
Create `lib/features/ride_booking/booking_shell/widgets/booking_step_indicator.dart`:
	
```dart
import 'package:caride/features/ride_booking/booking_shell/models/booking_shell_step.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class BookingStepIndicator extends StatelessWidget {
  const BookingStepIndicator({super.key, required this.step});

  final BookingShellStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final idx = BookingShellStep.values.indexOf(step);

    return Row(
      children: List.generate(BookingShellStep.values.length, (i) {
        final active = i <= idx;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i == BookingShellStep.values.length - 1 ? 0 : AppSpacing.xs),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 6,
              decoration: BoxDecoration(
                color: active ? theme.colorScheme.primary : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        );
      }),
    );
  }
}
```
	
- [ ] **Step 3: Run `flutter analyze` (expect step widgets missing)**
	
Run:
```bash
flutter analyze
```
Expected: analyzer errors for missing step widget imports until Task 5–9 are complete.
	
---
	
## Task 5: From/To step (search + recents + saved + route refresh)
	
**Files:**
- Create: `lib/features/ride_booking/booking_shell/steps/from_to_step.dart`
- Modify: `lib/features/ride_booking/booking_shell/booking_shell_controller.dart` (call `refreshRoute()` on setFrom/setTo)
	
- [ ] **Step 1: Update controller setters to refresh route automatically**
	
Update `setFrom` and `setTo` in `BookingShellController`:
	
```dart
void setFrom(MapboxPlace place) {
  _from = place;
  _recentPlacesRepository.recordPlace(place);
  notifyListeners();
  unawaited(refreshRoute());
}

void setTo(MapboxPlace place) {
  _to = place;
  _recentPlacesRepository.recordPlace(place);
  notifyListeners();
  unawaited(refreshRoute());
}
```
	
- [ ] **Step 2: Implement FromToStep UI**
	
Create `lib/features/ride_booking/booking_shell/steps/from_to_step.dart`:
	
```dart
import 'dart:async';

import 'package:caride/features/home_map/data/mapbox_search_service.dart';
import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:caride/features/ride_booking/booking_shell/models/booking_shell_step.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class FromToStep extends StatefulWidget {
  const FromToStep({super.key, required this.controller});
  final BookingShellController controller;

  @override
  State<FromToStep> createState() => _FromToStepState();
}

class _FromToStepState extends State<FromToStep> {
  late final TextEditingController _fromCtrl;
  late final TextEditingController _toCtrl;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fromCtrl = TextEditingController(text: widget.controller.from?.placeName ?? '');
    _toCtrl = TextEditingController(text: widget.controller.to?.placeName ?? '');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  void _searchTo(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), () {
      unawaited(widget.controller.search(q));
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Where to?', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        TextField(
          controller: _fromCtrl,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'From',
            prefixIcon: Icon(Icons.my_location_rounded),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _toCtrl,
          decoration: const InputDecoration(
            labelText: 'To',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          onChanged: _searchTo,
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: c.searching
              ? const Center(child: CircularProgressIndicator.adaptive())
              : _ResultsList(
                  results: c.searchResults,
                  onPick: (p) {
                    c.setTo(p);
                    _toCtrl.text = p.placeName;
                    if (c.from != null && c.to != null) {
                      c.goTo(BookingShellStep.rideType);
                    }
                  },
                ),
        ),
      ],
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({required this.results, required this.onPick});

  final List<MapboxPlace> results;
  final ValueChanged<MapboxPlace> onPick;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return const Center(child: Text('Search for a destination.'));
    }
    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final p = results[i];
        return ListTile(
          title: Text(p.placeName, maxLines: 2, overflow: TextOverflow.ellipsis),
          onTap: () => onPick(p),
        );
      },
    );
  }
}
```
	
- [ ] **Step 3: Run `flutter analyze` (expect remaining steps missing, FromToStep compiles)**
	
Run:
```bash
flutter analyze
```
Expected: FromToStep compiles; remaining errors for not-yet-implemented steps.
	
---
	
## Task 6: Ride Type step (options + route summary + continue)
	
**Files:**
- Create: `lib/features/ride_booking/booking_shell/steps/ride_type_step.dart`
	
- [ ] **Step 1: Implement RideTypeStep**
	
Create `lib/features/ride_booking/booking_shell/steps/ride_type_step.dart`:
	
```dart
import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:caride/features/ride_booking/booking_shell/models/booking_shell_step.dart';
import 'package:caride/features/ride_booking/booking_shell/models/ride_option.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class RideTypeStep extends StatelessWidget {
  const RideTypeStep({super.key, required this.controller});
  final BookingShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = controller.routeInfo;
    final summary = info == null
        ? 'Route summary unavailable'
        : '${info.distanceKm.toStringAsFixed(1)} km • ${info.durationMinutes.round()} min';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Choose a ride', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(summary, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: ListView.separated(
            itemCount: rideOptions.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, i) {
              final opt = rideOptions[i];
              final selected = controller.rideType == opt.type;
              return AppCard(
                onTap: () => controller.setRideType(opt.type),
                child: Row(
                  children: [
                    Image.asset(opt.assetPath, width: 44, height: 44),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(opt.type, style: theme.textTheme.titleMedium),
                          const SizedBox(height: 2),
                          Text(opt.subtitle, style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    if (selected) const Icon(Icons.check_circle),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: 'Continue',
          onPressed: controller.from != null && controller.to != null
              ? () => controller.goTo(BookingShellStep.fare)
              : null,
        ),
      ],
    );
  }
}
```
	
---
	
## Task 7: Fare step (stepper +/- + tap-to-edit + request ride)
	
**Files:**
- Create: `lib/features/ride_booking/booking_shell/steps/fare_step.dart`
- Test: `test/fare_stepper_test.dart`
	
- [ ] **Step 1: Add a pure test for the stepper edit behavior**
	
Create `test/fare_stepper_test.dart`:
	
```dart
import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('setOffer clamps negatives to zero', () {
    final c = BookingShellController.fromExtra(extra: null);
    c.setOffer(-10);
    expect(c.offerNaira, 0);
  });
}
```
	
- [ ] **Step 2: Implement FareStep UI**
	
Create `lib/features/ride_booking/booking_shell/steps/fare_step.dart`:
	
```dart
import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class FareStep extends StatefulWidget {
  const FareStep({super.key, required this.controller});
  final BookingShellController controller;

  @override
  State<FareStep> createState() => _FareStepState();
}

class _FareStepState extends State<FareStep> {
  static const double _step = 50;
  bool _requesting = false;

  Future<void> _editOffer() async {
    final theme = Theme.of(context);
    final initial = widget.controller.offerNaira.round().toString();
    final ctrl = TextEditingController(text: initial);
    final v = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Set your offer'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(prefixText: '₦'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.primary),
              onPressed: () {
                final parsed = double.tryParse(ctrl.text.trim().replaceAll(',', ''));
                Navigator.pop(context, parsed);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    if (v != null) widget.controller.setOffer(v);
  }

  Future<void> _requestRide() async {
    setState(() => _requesting = true);
    try {
      await widget.controller.requestRide(paymentMethod: 'cash');
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.controller;
    final offer = c.offerNaira;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Set your fare', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Row(
            children: [
              IconButton(
                onPressed: () => c.decrementOffer(step: _step),
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: InkWell(
                  onTap: _editOffer,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Column(
                      children: [
                        Text('₦${offer.toStringAsFixed(0)}', style: theme.textTheme.headlineSmall),
                        const SizedBox(height: 2),
                        Text('Tap to edit', style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => c.incrementOffer(step: _step),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
        const Spacer(),
        PrimaryButton(
          label: _requesting ? 'Requesting...' : 'Request Ride',
          onPressed: _requesting ? null : _requestRide,
        ),
      ],
    );
  }
}
```
	
- [ ] **Step 3: Run tests**
	
Run:
```bash
flutter test test/fare_stepper_test.dart
```
Expected: PASS.
	
---
	
## Task 8: Driver Bids step (stream bids + accept/reject only)
	
**Files:**
- Create: `lib/features/ride_booking/booking_shell/steps/driver_bids_step.dart`
	
- [ ] **Step 1: Implement DriverBidsStep**
	
Create `lib/features/ride_booking/booking_shell/steps/driver_bids_step.dart`:
	
```dart
import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

class DriverBidsStep extends StatelessWidget {
  const DriverBidsStep({super.key, required this.controller});
  final BookingShellController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stream = controller.bidsStream;
    if (stream == null) {
      return const Center(child: Text('No ride request yet.'));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Driver bids', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: StreamBuilder<List<DriverBid>>(
            stream: stream,
            builder: (context, snap) {
              if (snap.hasError) return const Center(child: Text('Unable to load bids.'));
              if (!snap.hasData) return const Center(child: CircularProgressIndicator.adaptive());
              final bids = snap.data!;
              if (bids.isEmpty) return const Center(child: Text('Waiting for offers...'));
              return ListView.separated(
                itemCount: bids.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, i) {
                  final b = bids[i];
                  return AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.driverName, style: theme.textTheme.titleMedium),
                              const SizedBox(height: 2),
                              Text('₦${b.offerNaira.toStringAsFixed(0)}', style: theme.textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => controller.declineBid(b.id),
                          child: const Text('Reject'),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        FilledButton(
                          onPressed: () => controller.acceptBid(b),
                          child: const Text('Accept'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
```
	
---
	
## Task 9: Tracking step (embed tracking behavior + auto-follow with recenter)
	
**Files:**
- Create: `lib/features/ride_booking/booking_shell/steps/tracking_step.dart`
- Modify: `lib/features/profile/driver_tracking_screen.dart` (extract reusable widget)
	
- [ ] **Step 1: Extract a reusable tracking widget from DriverTrackingScreen**
	
Create `lib/features/profile/widgets/driver_tracking_content.dart` and refactor `DriverTrackingScreen` to use it.
	
`lib/features/profile/widgets/driver_tracking_content.dart`:
	
```dart
import 'package:caride/core/utils/phone_launcher.dart';
import 'package:caride/features/chat/conversation_screen.dart';
import 'package:caride/features/profile/data/driver_location_repository.dart';
import 'package:caride/features/profile/data/driver_public_profile_repository.dart';
import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

class DriverTrackingContent extends StatelessWidget {
  const DriverTrackingContent({
    super.key,
    required this.ride,
    required this.driverProfile,
    required this.onChat,
    required this.onCall,
  });

  final RideModel ride;
  final DriverPublicProfile? driverProfile;
  final VoidCallback onChat;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final driverName = driverProfile?.name ?? ride.driverName ?? 'Driver';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('On the way', style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(driverName, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(ride.status, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(onPressed: onChat, icon: const Icon(Icons.chat_bubble_outline)),
              IconButton(onPressed: onCall, icon: const Icon(Icons.call_outlined)),
            ],
          ),
        ),
      ],
    );
  }
}
```
	
Then update `DriverTrackingScreen` to render `DriverTrackingContent(...)` in its bottom UI instead of duplicating driver name/buttons.
	
- [ ] **Step 2: Implement BookingShell TrackingStep using the extracted content and existing map tracking**
	
Create `lib/features/ride_booking/booking_shell/steps/tracking_step.dart`:
	
```dart
import 'package:caride/core/utils/phone_launcher.dart';
import 'package:caride/features/chat/conversation_screen.dart';
import 'package:caride/features/profile/data/driver_public_profile_repository.dart';
import 'package:caride/features/profile/widgets/driver_tracking_content.dart';
import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

class TrackingStep extends StatelessWidget {
  const TrackingStep({super.key, required this.controller});
  final BookingShellController controller;

  @override
  Widget build(BuildContext context) {
    final rideStream = controller.rideStream;
    if (rideStream == null) return const Center(child: Text('No ride yet.'));
    return StreamBuilder<RideModel?>(
      stream: rideStream,
      builder: (context, snap) {
        final ride = snap.data;
        if (ride == null) return const Center(child: CircularProgressIndicator.adaptive());
        final driverUid = ride.driverUid;
        if (driverUid == null) return const Center(child: Text('Waiting for driver...'));
        return StreamBuilder<DriverPublicProfile?>(
          stream: DriverPublicProfileRepository().watchDriver(driverUid),
          builder: (context, profSnap) {
            final prof = profSnap.data;
            return DriverTrackingContent(
              ride: ride,
              driverProfile: prof,
              onChat: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ConversationScreen(
                      rideId: ride.id,
                      driverName: prof?.name ?? ride.driverName ?? 'Driver',
                    ),
                  ),
                );
              },
              onCall: () {
                final phone = prof?.phone;
                if (phone != null) PhoneLauncher.call(phone);
              },
            );
          },
        );
      },
    );
  }
}
```
	
---
	
## Task 10: Full verification
	
**Files:** (all above)
	
- [ ] **Step 1: Run analyzer**
	
Run:
```bash
flutter analyze
```
Expected: no issues.
	
- [ ] **Step 2: Run all customer app tests**
	
Run:
```bash
flutter test
```
Expected: PASS.
	
- [ ] **Step 3: Manual smoke checks**
	
Run:
```bash
flutter run
```
Check:
- Home → “Choose Ride Option” opens BookingShell (not ChooseRideScreen).
- If Home passed From/To, BookingShell starts at Ride Type.
- Fare stepper works (+/- and tap-to-edit).
- Request Ride transitions to bids.
- Accepting a bid transitions to tracking.
	
