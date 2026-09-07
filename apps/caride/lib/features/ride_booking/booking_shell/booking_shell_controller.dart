import 'dart:async';

import 'package:caride/core/config/app_config_repository.dart';
import 'package:caride/core/config/app_env.dart';
import 'package:caride/core/ride/ride_lifecycle.dart';
import 'package:caride/features/home_map/data/mapbox_search_service.dart';
import 'package:caride/features/home_map/data/recent_places_repository.dart';
import 'package:caride/features/profile/data/address_repository.dart';
import 'package:caride/features/ride_booking/booking_shell/models/booking_shell_step.dart';
import 'package:caride/features/ride_booking/booking_shell/models/ride_option.dart';
import 'package:caride/features/ride_booking/booking_shell/models/promo_model.dart';
import 'package:caride/features/ride_booking/data/ride_pricing_repository.dart';
import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:caride/features/ride_booking/data/ride_options_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class BookingShellController extends ChangeNotifier {
  BookingShellController({
    required Map<String, dynamic>? extra,
    RidePricingRepository? pricingRepository,
    RideRepository? rideRepository,
    RideOptionsRepository? rideOptionsRepository,
    RecentPlacesRepository? recentPlacesRepository,
    AddressRepository? addressRepository,
    AppConfigRepository? configRepository,
    MapboxSearchService? searchService,
  })  : _pricingRepository = pricingRepository,
        _rideRepository = rideRepository,
        _rideOptionsRepository = rideOptionsRepository,
        _recentPlacesRepository = recentPlacesRepository,
        _addressRepository = addressRepository,
        _configRepository = configRepository,
        _searchService = searchService {
    _initFromExtra(extra);
    _defaultsSub = _configRepository?.watchAppDefaults().listen((v) {
      _defaults = v;
    });
    _pricingSub = _pricingRepository?.watchPricingConfig().listen((config) {
      _pricingConfig = config;
      _updateDefaultOffer();
    });
    // Load ride options once (not a persistent listener)
    unawaited(_loadRideOptions());
    unawaited(ensureGpsFrom());
  }

  factory BookingShellController.fromExtra({Map<String, dynamic>? extra}) {
    return BookingShellController(
      extra: extra,
      pricingRepository: RidePricingRepository(
        googleMapsApiKey: AppEnv.googleMapsApiKey,
      ),
      rideRepository: RideRepository(),
      rideOptionsRepository: RideOptionsRepository(),
      recentPlacesRepository: RecentPlacesRepository(),
      addressRepository: AddressRepository(),
      configRepository: AppConfigRepository(),
      searchService: MapboxSearchService(AppEnv.googleMapsApiKey),
    );
  }

  factory BookingShellController.forTest({Map<String, dynamic>? extra}) {
    return BookingShellController(extra: extra);
  }

  static BookingShellStep stepForRideStatus(String status) {
    return switch (status) {
      'requested' || 'bidding' => BookingShellStep.bids,
      'driverEnRoute' || 'driverArrived' || 'rideStarted' => BookingShellStep.tracking,
      'cancelled' || 'completed' => BookingShellStep.tracking,
      _ => BookingShellStep.fromTo,
    };
  }

  static bool customerCanCancelStatus(String status) {
    return customerCanCancel(status);
  }

  final RidePricingRepository? _pricingRepository;
  final RideRepository? _rideRepository;
  final RideOptionsRepository? _rideOptionsRepository;
  final RecentPlacesRepository? _recentPlacesRepository;
  final AddressRepository? _addressRepository;
  final AppConfigRepository? _configRepository;
  final MapboxSearchService? _searchService;

  StreamSubscription<AppDefaults?>? _defaultsSub;
  AppDefaults? _defaults;
  StreamSubscription<RidePricingConfig>? _pricingSub;
  RidePricingConfig _pricingConfig = RidePricingConfig.defaults;
  String? _lastCalculatedRideType;
  double? _lastCalculatedDistanceKm;

  // Ride options cached from a single one-shot Firestore fetch
  List<RideOption> _rideOptions = RideOptionsRepository.fallbackOptions;
  List<RideOption> get rideOptions => _rideOptions;

  Future<void> _loadRideOptions() async {
    final repo = _rideOptionsRepository;
    if (repo == null) return;
    final options = await repo.fetchRideOptions();
    if (options.isNotEmpty) {
      _rideOptions = options;
      notifyListeners();
    }
  }

  BookingShellStep _step = BookingShellStep.fromTo;
  BookingShellStep get step => _step;

  MapboxPlace? _from;
  MapboxPlace? get from => _from;

  bool _isResolvingLocation = false;
  bool get isResolvingLocation => _isResolvingLocation;

  MapboxPlace? _to;
  MapboxPlace? get to => _to;

  List<MapboxPlace> _searchResults = const [];
  List<MapboxPlace> get searchResults => _searchResults;

  bool _searching = false;
  bool get searching => _searching;

  List<LatLng>? _routeLine;
  List<LatLng>? get routeLine => _routeLine;

  RouteInfo? _routeInfo;
  RouteInfo? get routeInfo => _routeInfo;

  String _rideType = 'Regular';
  String get rideType => _rideType;

  double _offerNaira = 0;
  double get offerNaira => _offerNaira;

  String? _receiverName;
  String? get receiverName => _receiverName;

  String? _receiverPhone;
  String? get receiverPhone => _receiverPhone;

  bool _pinConfirmationEnabled = false;
  bool get pinConfirmationEnabled => _pinConfirmationEnabled;

  /// True when this booking is a delivery (Send Items) order.
  bool get isDelivery => _receiverName != null || _receiverPhone != null;

  String? _rideId;
  String? get rideId => _rideId;

  PromoModel? _selectedPromo;
  PromoModel? get selectedPromo => _selectedPromo;

  bool _useCreditWallet = false;
  bool get useCreditWallet => _useCreditWallet;

  void setUseCreditWallet(bool value) {
    _useCreditWallet = value;
    notifyListeners();
  }

  void setPromo(PromoModel? promo) {
    _selectedPromo = promo;
    notifyListeners();
  }

  StreamSubscription<RideModel?>? _rideSub;
  RideModel? _ride;
  RideModel? get ride => _ride;

  Stream<RideModel?>? _rideStream;
  Stream<RideModel?>? get rideStream => _rideStream;

  Stream<List<DriverBid>>? _bidsStream;
  Stream<List<DriverBid>>? get bidsStream => _bidsStream;

  Future<MapboxPlace?> geocodePlace(String query) async {
    final svc = _searchService;
    if (svc == null) return null;
    final results = await svc.searchPlaces(query);
    if (results.isEmpty) return null;
    return results.first;
  }

  Stream<List<SavedAddress>> watchSavedAddresses() {
    final repo = _addressRepository;
    if (repo == null) return Stream.value(const []);
    return repo.watchAddresses();
  }

  Stream<List<RecentPlace>> watchRecentPlaces({int limit = 10}) {
    final repo = _recentPlacesRepository;
    if (repo == null) return Stream.value(const []);
    return repo.watchRecentPlaces(limit: limit);
  }

  /// Returns cached ride options (loaded once in the constructor).
  /// Kept for backward-compat but returns a Stream that emits the cached value.
  @Deprecated('Use rideOptions getter instead. Options are loaded once via fetchRideOptions().')
  Stream<List<RideOption>> watchRideOptions() {
    return Stream.value(_rideOptions);
  }

  void _initFromExtra(Map<String, dynamic>? extra) {
    if (extra == null) return;
    _receiverName = extra['receiverName'] as String?;
    _receiverPhone = extra['receiverPhone'] as String?;
    final rid = extra['rideId'];
    final stepExtra = extra['step'];
    if (rid is String && rid.trim().isNotEmpty) {
      _rideId = rid.trim();
      if (stepExtra == BookingShellStep.tracking || stepExtra == 'tracking' || stepExtra == 5) {
        _step = BookingShellStep.tracking;
      } else {
        _step = BookingShellStep.bids;
      }
    } else if (stepExtra == BookingShellStep.tracking || stepExtra == 'tracking' || stepExtra == 5) {
      _step = BookingShellStep.tracking;
    }
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

    if (_rideId == null) {
      _step =
          (hasPickup && hasDropoff) ? BookingShellStep.rideType : BookingShellStep.fromTo;
    }
    if (hasPickup && hasDropoff) {
      unawaited(refreshRoute());
    }
    attachRideStreamIfPossible();
  }

  void attachRideStreamIfPossible() {
    final repo = _rideRepository;
    final id = _rideId;
    if (repo == null || id == null) return;
    _rideStream ??= repo.watchRide(id);
    _bidsStream ??= repo.watchBids(id);

    _rideSub ??= _rideStream!.listen((r) {
      if (r == null) return;
      _ride = r;
      if (r.status == 'cancelled') {
        goTo(BookingShellStep.fromTo);
        return;
      }
      final next = stepForRideStatus(r.status);
      if (_step != next) {
        _step = next;
      }
      notifyListeners();
    });
  }

  Future<void> ensureGpsFrom() async {
    if (_from != null && _from?.id != 'pickup') {
      return;
    }
    _isResolvingLocation = true;
    notifyListeners();
    try {
      final enabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _isResolvingLocation = false;
        notifyListeners();
        return;
      }
      var perm = await geo.Geolocator.checkPermission();
      if (perm == geo.LocationPermission.denied) {
        perm = await geo.Geolocator.requestPermission();
      }
      if (perm == geo.LocationPermission.denied ||
          perm == geo.LocationPermission.deniedForever) {
        _isResolvingLocation = false;
        notifyListeners();
        return;
      }

      // ── Phase 1: fast last known location check / low-accuracy fix ──
      geo.Position? fastPos;
      try {
        fastPos = await geo.Geolocator.getLastKnownPosition();
        fastPos ??= await geo.Geolocator.getCurrentPosition(
          locationSettings: const geo.LocationSettings(
            accuracy: geo.LocationAccuracy.lowest,
            timeLimit: Duration(seconds: 2),
          ),
        );
      } catch (_) {}

      // ── Phase 2: resolve human-readable address ──
      if (fastPos != null) {
        final actualAddress =
            await _searchService?.reverseGeocode(fastPos.latitude, fastPos.longitude);
        if (actualAddress != null && actualAddress.isNotEmpty) {
          _from = MapboxPlace(
            id: 'gps',
            placeName: actualAddress,
            centerLng: fastPos.longitude,
            centerLat: fastPos.latitude,
          );
        }
      }
    } catch (_) {
      final d = _defaults;
      if (_from == null && d != null) {
        final actualAddress = await _searchService?.reverseGeocode(
            d.defaultMapCenterLat, d.defaultMapCenterLng);
        if (actualAddress != null && actualAddress.isNotEmpty) {
          _from = MapboxPlace(
            id: 'pickup',
            placeName: actualAddress,
            centerLng: d.defaultMapCenterLng,
            centerLat: d.defaultMapCenterLat,
          );
        }
        // If geocoding also fails, leave _from as null — don't set a placeholder
      }
    } finally {
      _isResolvingLocation = false;
      notifyListeners();
    }
  }

  Future<void> searchTo(String query) async {
    final svc = _searchService;
    if (svc == null) {
      return;
    }
    if (query.trim().isEmpty) {
      _searchResults = const [];
      _searching = false;
      notifyListeners();
      return;
    }
    _searching = true;
    notifyListeners();
    final proximity = _from;
    final results = await svc.searchPlaces(
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
    _recentPlacesRepository?.recordPlace(place);
    notifyListeners();
    unawaited(refreshRoute());
  }

  void setTo(MapboxPlace place) {
    _to = place;
    _recentPlacesRepository?.recordPlace(place);
    notifyListeners();
    unawaited(refreshRoute());
  }

  void setRideType(String type) {
    _rideType = type;
    _updateDefaultOffer();
    notifyListeners();
  }

  void setReceiverDetails(String? name, String? phone) {
    _receiverName = name;
    _receiverPhone = phone;
    notifyListeners();
  }

  void setPinConfirmationEnabled(bool value) {
    _pinConfirmationEnabled = value;
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
    final prevStep = _step;
    if (next == BookingShellStep.fare) {
      _rideId = null;
      _rideSub?.cancel();
      _rideSub = null;
      _rideStream = null;
      _bidsStream = null;
      _ride = null;
      if (prevStep == BookingShellStep.rideType) {
        _updateDefaultOffer(force: true);
      }
    }
    _step = next;
    notifyListeners();
  }

  void _updateDefaultOffer({bool force = false}) {
    final info = _routeInfo;
    final config = _pricingConfig;
    if (info == null) return;

    final pricing = config.forType(_rideType);
    final suggested = pricing.baseFare +
        (info.distanceKm * pricing.perKmRate) +
        (info.durationMinutes * pricing.perMinuteRate);

    final roundedSuggested = ((suggested / 100).round() * 100).toDouble();

    if (force ||
        _offerNaira == 0 ||
        _lastCalculatedRideType != _rideType ||
        _lastCalculatedDistanceKm != info.distanceKm) {
      _offerNaira = roundedSuggested;
      _lastCalculatedRideType = _rideType;
      _lastCalculatedDistanceKm = info.distanceKm;
      notifyListeners();
    }
  }

  Future<void> refreshRoute() async {
    final repo = _pricingRepository;
    final from = _from;
    final to = _to;
    if (repo == null) return;
    if (from == null || to == null) {
      _routeInfo = null;
      _routeLine = null;
      notifyListeners();
      return;
    }
    if (AppEnv.googleMapsApiKey.isEmpty) return;
    final info = await repo.getRouteInfo(
      fromLng: from.centerLng,
      fromLat: from.centerLat,
      toLng: to.centerLng,
      toLat: to.centerLat,
    );
    final line = await repo.getRouteLine(
      fromLng: from.centerLng,
      fromLat: from.centerLat,
      toLng: to.centerLng,
      toLat: to.centerLat,
    );
    _routeInfo = info;
    _routeLine = line;
    _updateDefaultOffer();
    notifyListeners();
  }

  Future<void> requestRide({required String paymentMethod, String? deliveryPin}) async {
    final repo = _rideRepository;
    final from = _from;
    final to = _to;
    if (repo == null) throw Exception('Ride repository missing.');
    if (from == null || to == null) throw Exception('Missing pickup/dropoff.');
    final id = await repo.createRideRequest(
      pickupLabel: from.placeName,
      pickupLat: from.centerLat,
      pickupLng: from.centerLng,
      dropoffLabel: to.placeName,
      dropoffLat: to.centerLat,
      dropoffLng: to.centerLng,
      rideType: _rideType,
      customerOffer: _offerNaira,
      paymentMethod: paymentMethod,
      useCreditWallet: _useCreditWallet,
      receiverName: _receiverName,
      receiverPhone: _receiverPhone,
      promoCode: _selectedPromo?.code,
      deliveryPin: deliveryPin,
    );
    _rideId = id;
    _rideStream = repo.watchRide(id);
    _bidsStream = repo.watchBids(id);
    _step = BookingShellStep.bids;
    attachRideStreamIfPossible();
    notifyListeners();
  }

  Future<void> acceptBid(DriverBid bid) async {
    final repo = _rideRepository;
    final id = _rideId;
    if (repo == null || id == null) return;
    await repo.acceptBid(rideId: id, bid: bid);
    _step = BookingShellStep.tracking;
    notifyListeners();
  }

  Future<void> declineBid(String bidId) async {
    final repo = _rideRepository;
    final id = _rideId;
    if (repo == null || id == null) return;
    await repo.declineBid(rideId: id, bidId: bidId);
  }

  Future<void> cancelRide({String? reason}) async {
    final repo = _rideRepository;
    final id = _rideId;
    if (repo == null || id == null) return;
    await repo.cancelRide(id, reason: reason);
  }

  @override
  void dispose() {
    _defaultsSub?.cancel();
    _pricingSub?.cancel();
    _rideSub?.cancel();
    super.dispose();
  }
}
