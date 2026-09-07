import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/core/driver/models/driver_profile.dart';
import 'package:caride/core/driver/models/driver_presence.dart';
import 'package:caride/core/driver/models/ride_model.dart';
import '../auth/data/driver_profile_repository.dart';
import '../location/data/driver_presence_repository.dart';
import '../location/data/location_repository.dart';
import '../ride/data/driver_ride_repository.dart';

class DriverPresenceController extends ChangeNotifier {
  final DriverPresenceRepository _presenceRepository;
  final DriverProfileRepository _profileRepository;
  final DriverRideRepository _rideRepository;
  final LocationRepository _locationRepository;

  StreamSubscription<DriverPresence?>? _presenceSubscription;
  StreamSubscription<DriverProfile?>? _profileSubscription;
  StreamSubscription<RideModel?>? _assignedRideSubscription;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _heartbeatTimer;

  DriverPresenceController({
    DriverPresenceRepository? presenceRepository,
    DriverProfileRepository? profileRepository,
    DriverRideRepository? rideRepository,
    LocationRepository? locationRepository,
  }) : _presenceRepository = presenceRepository ?? DriverPresenceRepository(),
       _profileRepository = profileRepository ?? DriverProfileRepository(),
       _rideRepository = rideRepository ?? DriverRideRepository(),
       _locationRepository = locationRepository ?? LocationRepository() {
    driverAuthController.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (!driverAuthController.isAuthenticated && _initialized) {
      _reset();
    }
  }

  Future<void> _reset() async {
    _initialized = false;
    _requestedOnline = false;
    _busy = false;
    _presence = null;
    _assignedRide = null;
    _currentPosition = null;
    _errorMessage = null;
    _approvalStatus = null;
    _vehicleType = null;
    await _stopTracking();
    await _presenceSubscription?.cancel();
    _presenceSubscription = null;
    await _profileSubscription?.cancel();
    _profileSubscription = null;
    await _assignedRideSubscription?.cancel();
    _assignedRideSubscription = null;
    notifyListeners();
  }

  DriverPresence? _presence;
  RideModel? _assignedRide;
  Position? _currentPosition;
  bool _initialized = false;
  bool _busy = false;
  bool _requestedOnline = false;
  String? _errorMessage;
  String? _approvalStatus;
  String? _vehicleType;
  Position? _lastPublishedPosition;
  DateTime? _lastPublishedAt;

  DriverPresence? get presence => _presence;
  RideModel? get assignedRide => _assignedRide;
  Position? get currentPosition => _currentPosition;
  bool get isBusy => _busy;
  String? get errorMessage => _errorMessage;
  bool get isOnline =>
      _presence?.availabilityState == DriverAvailabilityState.online ||
      _presence?.availabilityState == DriverAvailabilityState.onTrip;
  bool get isAvailableForRequests =>
      _presence?.isAvailableForRequests == true;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      await _refreshDriverContext().timeout(const Duration(seconds: 5));
      _presence = await _presenceRepository.getPresence().timeout(const Duration(seconds: 5));
      _requestedOnline = _presence?.isOnline == true || _presence?.isOnTrip == true;
    } catch (e) {
      debugPrint('DriverPresenceController initialization timeout/error: $e');
      _initialized = false;
      return;
    }

    _presenceSubscription = _presenceRepository.streamPresence().listen((presence) {
      _presence = presence;
      notifyListeners();
    });

    final uid = driverAuthController.currentUid;
    if (uid != null) {
      _profileSubscription = _profileRepository.streamDriverProfile(uid).listen((
        profile,
      ) async {
        final nextApprovalStatus = profile?.approvalStatus;
        final approvalChanged = _approvalStatus != nextApprovalStatus;
        _approvalStatus = nextApprovalStatus;

        if (approvalChanged &&
            _approvalStatus != 'approved' &&
            _requestedOnline &&
            _assignedRide == null) {
          _requestedOnline = false;
          await _stopTracking();
          _optimisticallySetPresence(
            availabilityState: DriverAvailabilityState.offline,
            isAvailableForRequests: false,
          );
        }

        notifyListeners();
      });
    }

    _assignedRideSubscription = _rideRepository.streamAssignedRide().listen((
      ride,
    ) async {
      final previousRideId = _assignedRide?.id;
      _assignedRide = ride;
      notifyListeners();

      if (previousRideId != null && ride == null) {
        await _locationRepository.clearRideLocation(previousRideId);
      }

      if (_requestedOnline) {
        await _publishPresence(force: true);
      }
    });

    if (_requestedOnline) {
      await _startTracking();
    }
  }

  Future<bool> setOnline(bool enabled) async {
    debugPrint('setOnline called with enabled: $enabled, _requestedOnline: $_requestedOnline, _busy: $_busy, _approvalStatus: $_approvalStatus');
    
    // Attempt initialization if not initialized yet
    if (!_initialized) {
      await initialize();
    }

    if (_requestedOnline == enabled && !_busy) {
      debugPrint('setOnline early return: requested status matches enabled status');
      return true;
    }

    if (!enabled && _assignedRide != null) {
      _errorMessage = 'You cannot go offline while an active ride is in progress.';
      debugPrint('setOnline error: active ride in progress');
      notifyListeners();
      return false;
    }

    _setBusy(true);
    _errorMessage = null;
    notifyListeners();

    try {
      await _refreshDriverContext().timeout(const Duration(seconds: 5));
      debugPrint('setOnline refreshed context. approvalStatus: $_approvalStatus, vehicleType: $_vehicleType');

      if (enabled) {
        if (_approvalStatus != 'approved') {
          _errorMessage = 'Only verified drivers can go online and receive ride requests.';
          debugPrint('setOnline error: driver not approved');
          return false;
        }

        final locationReady = await _ensureLocationReady();
        if (!locationReady) {
          debugPrint('setOnline error: location not ready. error: $_errorMessage');
          return false;
        }

        _requestedOnline = true;
        // Start tracking and capture initial position in the background
        _startTracking();
        _captureCurrentPosition(forcePublish: true);
        _optimisticallySetPresence(
          availabilityState: _assignedRide != null
              ? DriverAvailabilityState.onTrip
              : DriverAvailabilityState.online,
          isAvailableForRequests: _assignedRide == null,
          currentRideId: _assignedRide?.id,
        );
        await _publishPresence(force: true).timeout(const Duration(seconds: 5));
        debugPrint('setOnline successfully set to online');
      } else {
        _requestedOnline = false;
        await _stopTracking();
        _optimisticallySetPresence(
          availabilityState: DriverAvailabilityState.offline,
          isAvailableForRequests: false,
        );
        await _presenceRepository.setOffline(
          lastLocation: _currentGeoPoint,
          heading: _normalizedHeading(_currentPosition?.heading),
          speedMps: _normalizedSpeed(_currentPosition?.speed),
          accuracyM: _currentPosition?.accuracy,
          vehicleType: _vehicleType,
          approvalStatusSnapshot: _approvalStatus,
        ).timeout(const Duration(seconds: 5));
        debugPrint('setOnline successfully set to offline');
      }

      return true;
    } catch (e, stackTrace) {
      _errorMessage = 'Connection error. Please check your internet connection.';
      debugPrint('setOnline exception: $e\n$stackTrace');
      return false;
    } finally {
      _setBusy(false);
      notifyListeners();
    }
  }

  Future<void> clearError() async {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> _refreshDriverContext() async {
    final uid = driverAuthController.currentUid;
    if (uid == null) return;

    final profile = await _profileRepository.getDriverProfile(uid);
    final vehicle = await _profileRepository.getVehicleInfo(uid);
    _approvalStatus = profile?.approvalStatus;
    _vehicleType = vehicle?.vehicleType;
  }

  Future<bool> _ensureLocationReady() async {
    debugPrint('_ensureLocationReady: checking if location service is enabled...');
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    debugPrint('_ensureLocationReady: location service enabled = $serviceEnabled');
    if (!serviceEnabled) {
      _errorMessage = 'Turn on device location services to go online.';
      return false;
    }

    debugPrint('_ensureLocationReady: checking location permission...');
    var permission = await Geolocator.checkPermission();
    debugPrint('_ensureLocationReady: location permission = $permission');
    if (permission == LocationPermission.denied) {
      debugPrint('_ensureLocationReady: requesting location permission...');
      permission = await Geolocator.requestPermission();
      debugPrint('_ensureLocationReady: requested permission result = $permission');
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      _errorMessage =
          'Location permission is required before you can go online.';
      return false;
    }

    return true;
  }

  Future<void> _startTracking() async {
    if (_positionSubscription != null) return;

    // Instantly seed the current position using the last known position fallback
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && _currentPosition == null) {
        debugPrint('_startTracking: seeded current position with last known location = $lastKnown');
        _currentPosition = lastKnown;
        notifyListeners();
        await _publishPresence();
      }
    } catch (e) {
      debugPrint('_startTracking: failed to get last known position: $e');
    }

    Position? current;
    try {
      debugPrint('_startTracking: getting current position with time limit...');
      current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      ).timeout(const Duration(seconds: 4));
      debugPrint('_startTracking: current position received = $current');
    } catch (e) {
      debugPrint('_startTracking: failed/timed out getting current position: $e');
      current = null;
    }

    if (current != null) {
      _currentPosition = current;
      notifyListeners();
    }

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) async {
      _currentPosition = position;
      notifyListeners();
      await _publishPresence();
    });

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      if (_requestedOnline) {
        await _publishPresence(force: true);
      }
    });
  }

  Future<void> _stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _captureCurrentPosition({bool forcePublish = false}) async {
    // Instantly check last known location if _currentPosition is still null
    try {
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null && _currentPosition == null) {
        debugPrint('_captureCurrentPosition: seeded current position with last known location = $lastKnown');
        _currentPosition = lastKnown;
        notifyListeners();
        if (forcePublish) {
          await _publishPresence(force: true);
        }
      }
    } catch (e) {
      debugPrint('_captureCurrentPosition: failed to get last known position: $e');
    }

    try {
      debugPrint('_captureCurrentPosition: getting current position with time limit...');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      ).timeout(const Duration(seconds: 4));
      debugPrint('_captureCurrentPosition: position received = $position');
      _currentPosition = position;
      notifyListeners();
      if (forcePublish) {
        await _publishPresence(force: true);
      }
    } catch (e) {
      debugPrint('_captureCurrentPosition: failed/timed out getting current position: $e');
      // Keep current state if the initial position lookup fails.
    }
  }

  Future<void> _publishPresence({bool force = false}) async {
    if (!_requestedOnline) return;

    final position = _currentPosition;
    final ride = _assignedRide;
    final availabilityState = ride != null
        ? DriverAvailabilityState.onTrip
        : DriverAvailabilityState.online;
    final availableForRequests =
        ride == null && _approvalStatus == 'approved';

    if (!force && position != null && !_shouldPublish(position)) {
      return;
    }

    try {
      debugPrint('_publishPresence: publishing presence to Firestore. availabilityState: $availabilityState, availableForRequests: $availableForRequests, lastLocation: $_currentGeoPoint, vehicleType: $_vehicleType, approvalStatusSnapshot: $_approvalStatus');
      await _presenceRepository.heartbeat(
        availabilityState: availabilityState,
        isAvailableForRequests: availableForRequests,
        currentRideId: ride?.id,
        lastLocation: _currentGeoPoint,
        heading: _normalizedHeading(position?.heading),
        speedMps: _normalizedSpeed(position?.speed),
        accuracyM: position?.accuracy,
        vehicleType: _vehicleType,
        approvalStatusSnapshot: _approvalStatus,
      );
      debugPrint('_publishPresence: successfully published presence');
    } catch (e, stackTrace) {
      debugPrint('_publishPresence: failed to publish presence: $e\n$stackTrace');
    }

    if (ride != null && position != null) {
      try {
        await _locationRepository.publishLocation(
          rideId: ride.id,
          lat: position.latitude,
          lng: position.longitude,
          heading: _normalizedHeading(position.heading),
          speedMps: _normalizedSpeed(position.speed),
          accuracyM: position.accuracy,
        );
      } catch (e) {
        debugPrint('_publishPresence: failed to publish ride location: $e');
      }
    }

    _lastPublishedPosition = position;
    _lastPublishedAt = DateTime.now();
  }

  bool _shouldPublish(Position position) {
    if (_lastPublishedAt == null || _lastPublishedPosition == null) {
      return true;
    }

    final elapsed = DateTime.now().difference(_lastPublishedAt!);
    if (elapsed >= const Duration(seconds: 15)) {
      return true;
    }

    final distance = Geolocator.distanceBetween(
      _lastPublishedPosition!.latitude,
      _lastPublishedPosition!.longitude,
      position.latitude,
      position.longitude,
    );

    if (distance >= 8) {
      return true;
    }

    final currentHeading = _normalizedHeading(position.heading) ?? 0;
    final previousHeading = _normalizedHeading(
          _lastPublishedPosition!.heading,
        ) ??
        0;
    final headingDelta = (currentHeading - previousHeading).abs();
    return headingDelta >= 12;
  }

  GeoPoint? get _currentGeoPoint {
    final position = _currentPosition;
    if (position == null) return _presence?.lastLocation;
    return GeoPoint(position.latitude, position.longitude);
  }

  double? _normalizedHeading(double? heading) {
    if (heading == null || !heading.isFinite || heading < 0) return null;
    return heading % 360;
  }

  double? _normalizedSpeed(double? speed) {
    if (speed == null || !speed.isFinite) return null;
    return math.max(0, speed);
  }

  void _setBusy(bool value) {
    _busy = value;
  }

  void _optimisticallySetPresence({
    required DriverAvailabilityState availabilityState,
    required bool isAvailableForRequests,
    String? currentRideId,
  }) {
    final uid = driverAuthController.currentUid;
    if (uid == null) return;

    _presence = DriverPresence(
      driverUid: uid,
      availabilityState: availabilityState,
      isAvailableForRequests: isAvailableForRequests,
      lastLocation: _currentGeoPoint,
      heading: _normalizedHeading(_currentPosition?.heading),
      speedMps: _normalizedSpeed(_currentPosition?.speed),
      accuracyM: _currentPosition?.accuracy,
      currentRideId: currentRideId,
      vehicleType: _vehicleType,
      approvalStatusSnapshot: _approvalStatus,
      lastHeartbeatAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _presenceSubscription?.cancel();
    _profileSubscription?.cancel();
    _assignedRideSubscription?.cancel();
    _positionSubscription?.cancel();
    _heartbeatTimer?.cancel();
    super.dispose();
  }
}

final driverPresenceController = DriverPresenceController();
