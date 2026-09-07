import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_models/shared_models.dart';
import '../data/fleet_repository.dart';

/// Central state controller for the Fleet Manager feature.
class FleetManagerController extends ChangeNotifier {
  FleetManagerController({FleetRepository? repository})
      : _repository = repository ?? fleetRepository;

  final FleetRepository _repository;

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

  int get pendingBookingsCount =>
      _bookings.where((b) => b.status == RentalBookingStatus.pendingApproval).length;
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

  /// Initialize controller subscriptions for the logged-in fleet owner.
  void init([String? uid]) {
    _profileSub?.cancel();
    _profileSub = _repository.streamFleetProfile(uid).listen((profile) {
      _currentProfile = profile;
      notifyListeners();

      if (profile != null && profile.fleetId.isNotEmpty) {
        _subscribeToFleetData(profile.fleetId);
      } else {
        _clearFleetData();
      }
    }, onError: (err) {
      _errorMessage = err.toString();
      notifyListeners();
    });
  }

  void _subscribeToFleetData(String fleetId) {
    _vehiclesSub?.cancel();
    _vehiclesSub = _repository.streamVehicles(fleetId).listen((vehicles) {
      _vehicles = vehicles;
      notifyListeners();
    });

    _bookingsSub?.cancel();
    _bookingsSub = _repository.streamFleetBookings(fleetId).listen((bookings) {
      _bookings = bookings;
      notifyListeners();
    });

    _driversSub?.cancel();
    _driversSub = _repository.streamDrivers(fleetId).listen((drivers) {
      _drivers = drivers;
      notifyListeners();
    });
  }

  void _clearFleetData() {
    _vehiclesSub?.cancel();
    _bookingsSub?.cancel();
    _driversSub?.cancel();
    _vehicles = [];
    _bookings = [];
    _drivers = [];
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

  /// Approve a booking and optionally assign driver.
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
    _profileSub?.cancel();
    _vehiclesSub?.cancel();
    _bookingsSub?.cancel();
    _driversSub?.cancel();
    super.dispose();
  }
}

final fleetManagerController = FleetManagerController();
