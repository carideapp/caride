import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_models/shared_models.dart';
import '../data/fleet_repository.dart';
import '../notifications/fleet_notifications_controller.dart';

/// Central state controller for the Fleet Manager feature.
class FleetManagerController extends ChangeNotifier {
  FleetManagerController({FleetRepository? repository, FirebaseAuth? auth})
      : _repository = repository ?? fleetRepository,
        _auth = auth ?? FirebaseAuth.instance {
    _authSub = _auth.authStateChanges().listen((user) {
      if (user == null) {
        reset();
      }
    });
  }

  final FleetRepository _repository;
  final FirebaseAuth _auth;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<FleetProfile?>? _profileSub;
  StreamSubscription<List<RentalVehicle>>? _vehiclesSub;
  StreamSubscription<List<RentalBooking>>? _bookingsSub;
  StreamSubscription<List<FleetDriver>>? _driversSub;

  FleetProfile? _currentProfile;
  List<RentalVehicle> _vehicles = [];
  List<RentalBooking> _bookings = [];
  List<FleetDriver> _drivers = [];

  bool _isLoading = false;
  String? _errorMessage;

  FleetProfile? get currentProfile => _currentProfile;
  List<RentalVehicle> get vehicles => _vehicles;
  List<RentalBooking> get bookings => _bookings;
  List<FleetDriver> get drivers => _drivers;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasFleetProfile => _currentProfile != null && _currentProfile!.fleetId.isNotEmpty;

  // ── Computed Stats ────────────────────────────────────────────────────
  int get totalVehiclesCount => _vehicles.length;
  int get availableVehiclesCount =>
      _vehicles.where((v) => v.status == RentalVehicleStatus.available).length;
  int get rentedVehiclesCount =>
      _vehicles.where((v) => v.status == RentalVehicleStatus.rented).length;
  int get maintenanceVehiclesCount =>
      _vehicles.where((v) => v.status == RentalVehicleStatus.maintenance).length;
  int get inactiveVehiclesCount =>
      _vehicles.where((v) => v.status == RentalVehicleStatus.inactive).length;

  int get pendingBookingsCount =>
      _bookings.where((b) =>
          b.status == RentalBookingStatus.pendingApproval ||
          b.status == RentalBookingStatus.awaitingPayment).length;
  int get activeBookingsCount =>
      _bookings.where((b) => b.isActive).length;
  int get completedBookingsCount =>
      _bookings.where((b) => b.status == RentalBookingStatus.completed).length;

  double get totalRevenue => _bookings
      .where((b) =>
          b.status == RentalBookingStatus.completed ||
          b.status == RentalBookingStatus.inProgress ||
          b.status == RentalBookingStatus.confirmed)
      .fold(0.0, (sum, b) => sum + b.totalAmount);

  int get linkedDriversCount => _drivers.length;

  /// Returns all active or pending bookings for a specific vehicle in this fleet.
  List<RentalBooking> getActiveBookingsForVehicle(String vehicleId) {
    return _bookings
        .where((b) =>
            b.vehicleId == vehicleId &&
            (b.status == RentalBookingStatus.pendingApproval ||
             b.status == RentalBookingStatus.confirmed ||
             b.status == RentalBookingStatus.inProgress))
        .toList();
  }

  /// Initialize controller subscriptions for the logged-in fleet owner.
  void init([String? uid]) {
    final targetUid = uid ?? _auth.currentUser?.uid;
    if (targetUid == null) {
      reset();
      return;
    }

    _profileSub?.cancel();
    _profileSub = _repository.streamFleetProfile(targetUid).listen((profile) {
      _currentProfile = profile;
      notifyListeners();

      if (profile != null && profile.fleetId.isNotEmpty) {
        _subscribeToFleetData(profile.fleetId);
        unawaited(FleetNotificationsController().initialize(fleetId: profile.fleetId));
      } else {
        _clearFleetData();
      }
    }, onError: (err) {
      debugPrint('[FleetManagerController] streamFleetProfile error: $err');
      _errorMessage = err.toString();
      notifyListeners();
    });
  }

  void _subscribeToFleetData(String fleetId) {
    _vehiclesSub?.cancel();
    _vehiclesSub = _repository.streamVehicles(fleetId).listen((vehicles) {
      _vehicles = vehicles;
      notifyListeners();
    }, onError: (err) {
      debugPrint('[FleetManagerController] streamVehicles error: $err');
    });

    _bookingsSub?.cancel();
    _bookingsSub = _repository.streamFleetBookings(fleetId).listen((bookings) {
      _bookings = bookings;
      notifyListeners();
    }, onError: (err) {
      debugPrint('[FleetManagerController] streamFleetBookings error: $err');
    });

    _driversSub?.cancel();
    _driversSub = _repository.streamDrivers(fleetId).listen((drivers) {
      _drivers = drivers;
      notifyListeners();
    }, onError: (err) {
      debugPrint('[FleetManagerController] streamDrivers error: $err');
    });
  }

  void _clearFleetData() {
    _vehiclesSub?.cancel();
    _bookingsSub?.cancel();
    _driversSub?.cancel();
    _vehiclesSub = null;
    _bookingsSub = null;
    _driversSub = null;
    _vehicles = [];
    _bookings = [];
    _drivers = [];
    notifyListeners();
  }

  /// Cancel all subscriptions and clear cached fleet data on sign out.
  void reset() {
    _profileSub?.cancel();
    _profileSub = null;
    _clearFleetData();
    _currentProfile = null;
    _errorMessage = null;
    _isLoading = false;
    notifyListeners();
  }

  /// Create or update Fleet business profile.
  Future<FleetProfile> saveFleetProfile(FleetProfile profile) async {
    _setLoading(true);
    try {
      final saved = await _repository.createOrUpdateFleetProfile(profile);
      _currentProfile = saved;
      _subscribeToFleetData(saved.fleetId);
      notifyListeners();
      return saved;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Add or edit a vehicle in the fleet.
  Future<void> saveVehicle(RentalVehicle vehicle) async {
    _setLoading(true);
    try {
      final fleetId = _currentProfile?.fleetId ?? vehicle.fleetId;
      await _repository.saveVehicle(vehicle.copyWith(fleetId: fleetId));
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Quick toggle vehicle availability.
  Future<void> toggleVehicleStatus(
    String vehicleId,
    RentalVehicleStatus status,
  ) async {
    try {
      await _repository.updateVehicleStatus(vehicleId, status);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// Delete a vehicle.
  Future<void> deleteVehicle(String vehicleId) async {
    _setLoading(true);
    try {
      final fleetId = _currentProfile?.fleetId ?? '';
      await _repository.deleteVehicle(vehicleId, fleetId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Upload a vehicle photo to Firebase Storage and return the URL.
  Future<String> uploadVehiclePhoto({
    required String vehicleId,
    required File file,
    required String photoId,
  }) async {
    final fleetId = _currentProfile?.fleetId ?? '';
    return await _repository.uploadVehiclePhoto(
      fleetId: fleetId,
      vehicleId: vehicleId,
      file: file,
      photoId: photoId,
    );
  }

  /// Approve a pending booking — sets status to `awaitingPayment`.
  /// The customer will be prompted to pay before the booking is confirmed.
  Future<void> approveBookingForPayment(String bookingId) async {
    _setLoading(true);
    try {
      await _repository.updateBookingStatus(
        bookingId,
        RentalBookingStatus.awaitingPayment,
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Assign a driver to a confirmed + paid booking.
  /// Only valid when status == confirmed and paymentStatus == 'paid'.
  Future<void> assignDriverToBooking(
    String bookingId, {
    required String assignedDriverId,
    required String assignedDriverName,
    String? assignedDriverPhone,
  }) async {
    _setLoading(true);
    try {
      await _repository.updateBookingStatus(
        bookingId,
        RentalBookingStatus.confirmed,
        assignedDriverId: assignedDriverId,
        assignedDriverName: assignedDriverName,
        assignedDriverPhone: assignedDriverPhone,
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// @deprecated Use [approveBookingForPayment] + [assignDriverToBooking] instead.
  /// Kept for backward compatibility.
  Future<void> approveBooking(
    String bookingId, {
    String? assignedDriverId,
    String? assignedDriverName,
    String? assignedDriverPhone,
  }) async {
    _setLoading(true);
    try {
      await _repository.updateBookingStatus(
        bookingId,
        RentalBookingStatus.confirmed,
        assignedDriverId: assignedDriverId,
        assignedDriverName: assignedDriverName,
        assignedDriverPhone: assignedDriverPhone,
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Decline a booking request.
  Future<void> declineBooking(String bookingId, {String? reason}) async {
    _setLoading(true);
    try {
      await _repository.updateBookingStatus(
        bookingId,
        RentalBookingStatus.rejected,
        rejectionReason: reason,
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Invite a driver to join the fleet.
  Future<void> inviteDriver({
    required String fullName,
    required String phone,
    String email = '',
    String? licenseNumber,
    String? assignedVehicleId,
    String? assignedVehicleTitle,
  }) async {
    final fleetId = _currentProfile?.fleetId;
    if (fleetId == null || fleetId.isEmpty) return;

    _setLoading(true);
    try {
      await _repository.inviteDriver(
        fleetId,
        fullName: fullName,
        phone: phone,
        email: email,
        licenseNumber: licenseNumber,
        assignedVehicleId: assignedVehicleId,
        assignedVehicleTitle: assignedVehicleTitle,
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Search drivers from the platform drivers collection
  Future<List<Map<String, dynamic>>> searchDriversFromPlatform([String query = '']) async {
    return await _repository.searchDriversFromPlatform(query);
  }

  /// Link an existing driver to the fleet
  Future<void> linkDriverToFleet({
    required String driverUid,
    required String fullName,
    required String phone,
    required String email,
    String? username,
    String? photoUrl,
    String? assignedVehicleId,
    String? assignedVehicleTitle,
  }) async {
    final fleetId = _currentProfile?.fleetId;
    final fleetName = _currentProfile?.businessName ?? 'CaRide Fleet';
    if (fleetId == null || fleetId.isEmpty) return;

    _setLoading(true);
    try {
      await _repository.linkDriverToFleet(
        fleetId: fleetId,
        fleetName: fleetName,
        driverUid: driverUid,
        fullName: fullName,
        phone: phone,
        email: email,
        username: username,
        photoUrl: photoUrl,
        assignedVehicleId: assignedVehicleId,
        assignedVehicleTitle: assignedVehicleTitle,
      );
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Remove a driver from the fleet.
  Future<void> removeDriver(String driverDocId) async {
    final fleetId = _currentProfile?.fleetId ?? '';
    _setLoading(true);
    try {
      await _repository.removeDriver(fleetId, driverDocId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool val) {
    if (_isLoading == val) return;
    _isLoading = val;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _authSub = null;
    reset();
    super.dispose();
  }
}

final fleetManagerController = FleetManagerController();
