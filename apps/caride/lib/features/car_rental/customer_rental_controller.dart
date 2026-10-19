import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_models/shared_models.dart';
import 'data/customer_rental_repository.dart';

/// State controller for the customer-facing car rental feature.
class CustomerRentalController extends ChangeNotifier {
  CustomerRentalController({CustomerRentalRepository? repository})
      : _repository = repository ?? customerRentalRepository;

  final CustomerRentalRepository _repository;

  StreamSubscription<List<RentalVehicle>>? _vehiclesSub;

  // ── Vehicle Browsing State ─────────────────────────────────────────────
  List<RentalVehicle> _vehicles = [];
  RentalVehicleCategory? _selectedCategory;
  String _selectedCity = 'All Cities';
  String _searchQuery = '';
  String? _selectedBrand;
  final Set<String> _favoriteVehicleIds = {};
  bool _isLoadingVehicles = false;

  // ── Advanced Filters (Matching Filter Sheet) ───────────────────────────
  String _carType = 'all'; // 'all' | 'regular' | 'luxury'
  double _minPrice = 0.0;
  double _maxPrice = 1000000.0;
  String _rentalTime = 'all'; // 'all' | 'hour' | 'day' | 'weekly' | 'monthly'
  String? _selectedColor;
  int? _selectedSeats;
  String? _selectedFuelType;

  // ── Booking State ──────────────────────────────────────────────────────
  bool _isSubmittingBooking = false;
  String? _bookingError;
  String? _lastCreatedBookingId;

  // ── Getters ───────────────────────────────────────────────────────────
  List<RentalVehicle> get vehicles => _filteredVehicles();
  List<RentalVehicle> get allVehiclesUnfiltered => List.unmodifiable(_vehicles);
  RentalVehicleCategory? get selectedCategory => _selectedCategory;
  String get selectedCity => _selectedCity;
  String get searchQuery => _searchQuery;
  String? get selectedBrand => _selectedBrand;
  String get carType => _carType;
  double get minPrice => _minPrice;
  double get maxPrice => _maxPrice;
  String get rentalTime => _rentalTime;
  String? get selectedColor => _selectedColor;
  int? get selectedSeats => _selectedSeats;
  String? get selectedFuelType => _selectedFuelType;
  Set<String> get favoriteVehicleIds => Set.unmodifiable(_favoriteVehicleIds);
  bool isFavorite(String vehicleId) => _favoriteVehicleIds.contains(vehicleId);
  bool get isLoadingVehicles => _isLoadingVehicles;
  bool get isSubmittingBooking => _isSubmittingBooking;
  String? get bookingError => _bookingError;
  String? get lastCreatedBookingId => _lastCreatedBookingId;

  bool get hasActiveFilters =>
      _selectedCategory != null ||
      _selectedCity != 'All Cities' ||
      _selectedBrand != null ||
      _carType != 'all' ||
      _minPrice > 0.0 ||
      _maxPrice < 1000000.0 ||
      _rentalTime != 'all' ||
      _selectedColor != null ||
      _selectedSeats != null ||
      _selectedFuelType != null;

  List<RentalVehicle> _filteredVehicles() {
    var list = _vehicles;

    // Brand filter
    if (_selectedBrand != null && _selectedBrand!.isNotEmpty) {
      final b = _selectedBrand!.toLowerCase();
      list = list.where((v) {
        return v.make.toLowerCase().contains(b) ||
            v.displayName.toLowerCase().contains(b) ||
            v.model.toLowerCase().contains(b);
      }).toList();
    }

    // Car type ('all', 'regular', 'luxury')
    if (_carType == 'regular') {
      list = list.where((v) => v.category != RentalVehicleCategory.luxury && !v.isArmored).toList();
    } else if (_carType == 'luxury') {
      list = list.where((v) => v.category == RentalVehicleCategory.luxury || v.isArmored).toList();
    }

    // Price range
    if (_minPrice > 0.0 || _maxPrice < 1000000.0) {
      list = list.where((v) {
        final rate = v.dailySelfDriveRate > 0 ? v.dailySelfDriveRate : v.dailyWithDriverRate;
        return rate >= _minPrice && rate <= _maxPrice;
      }).toList();
    }

    // Rental time / mode
    if (_rentalTime == 'hour') {
      list = list.where((v) => v.hourlyChauffeurRate > 0).toList();
    }

    // Color
    if (_selectedColor != null && _selectedColor!.isNotEmpty) {
      final c = _selectedColor!.toLowerCase();
      list = list.where((v) => v.color.toLowerCase().contains(c)).toList();
    }

    // Seats
    if (_selectedSeats != null) {
      list = list.where((v) => v.seats == _selectedSeats).toList();
    }

    // Fuel Type
    if (_selectedFuelType != null && _selectedFuelType!.isNotEmpty) {
      final f = _selectedFuelType!.toLowerCase();
      list = list.where((v) => v.fuelType.toLowerCase() == f).toList();
    }

    // Search query
    if (_searchQuery.isEmpty) return List.unmodifiable(list);
    final q = _searchQuery.toLowerCase();
    return list.where((v) {
      return v.make.toLowerCase().contains(q) ||
          v.model.toLowerCase().contains(q) ||
          v.displayName.toLowerCase().contains(q) ||
          v.category.label.toLowerCase().contains(q) ||
          v.city.toLowerCase().contains(q);
    }).toList();
  }

  // ── Initialization ────────────────────────────────────────────────────

  /// Start streaming available vehicles with current filters.
  void init() {
    _isLoadingVehicles = true;
    notifyListeners();
    _startVehicleStream();
  }

  void _startVehicleStream() {
    _vehiclesSub?.cancel();
    _vehiclesSub = _repository
        .streamAvailableVehicles(
          category: _selectedCategory,
          city: _selectedCity == 'All Cities' ? null : _selectedCity,
        )
        .listen(
          (vehicles) {
            _vehicles = vehicles;
            _isLoadingVehicles = false;
            notifyListeners();
          },
          onError: (_) {
            _isLoadingVehicles = false;
            notifyListeners();
          },
        );
  }

  // ── Filter Actions ────────────────────────────────────────────────────

  void setCategory(RentalVehicleCategory? category) {
    if (_selectedCategory == category) {
      _selectedCategory = null;
    } else {
      _selectedCategory = category;
    }
    _isLoadingVehicles = true;
    notifyListeners();
    _startVehicleStream();
  }

  void setCity(String city) {
    _selectedCity = city;
    _isLoadingVehicles = true;
    notifyListeners();
    _startVehicleStream();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setBrand(String? brand) {
    if (_selectedBrand == brand) {
      _selectedBrand = null;
    } else {
      _selectedBrand = brand;
    }
    notifyListeners();
  }

  void toggleFavorite(String vehicleId) {
    if (_favoriteVehicleIds.contains(vehicleId)) {
      _favoriteVehicleIds.remove(vehicleId);
    } else {
      _favoriteVehicleIds.add(vehicleId);
    }
    notifyListeners();
  }

  void applyAdvancedFilters({
    String? city,
    String? carType,
    double? minPrice,
    double? maxPrice,
    String? rentalTime,
    String? color,
    int? seats,
    String? fuelType,
  }) {
    if (city != null && city != _selectedCity) {
      _selectedCity = city;
      _startVehicleStream();
    }
    if (carType != null) _carType = carType;
    if (minPrice != null) _minPrice = minPrice;
    if (maxPrice != null) _maxPrice = maxPrice;
    if (rentalTime != null) _rentalTime = rentalTime;
    _selectedColor = color;
    _selectedSeats = seats;
    _selectedFuelType = fuelType;
    notifyListeners();
  }

  void clearAllFilters() {
    _selectedCity = 'All Cities';
    _selectedCategory = null;
    _selectedBrand = null;
    _carType = 'all';
    _minPrice = 0.0;
    _maxPrice = 1000000.0;
    _rentalTime = 'all';
    _selectedColor = null;
    _selectedSeats = null;
    _selectedFuelType = null;
    _searchQuery = '';
    _startVehicleStream();
    notifyListeners();
  }

  // ── Booking Actions ───────────────────────────────────────────────────

  Future<bool> submitBooking(RentalBooking booking) async {
    _isSubmittingBooking = true;
    _bookingError = null;
    notifyListeners();

    try {
      final id = await _repository.createBooking(booking);
      _lastCreatedBookingId = id;
      _isSubmittingBooking = false;
      notifyListeners();
      return true;
    } on FirebaseException catch (e) {
      _bookingError = _friendlyError(e.code);
      _isSubmittingBooking = false;
      notifyListeners();
      return false;
    } catch (e) {
      _bookingError = 'An unexpected error occurred. Please try again.';
      _isSubmittingBooking = false;
      notifyListeners();
      return false;
    }
  }

  void clearBookingError() {
    _bookingError = null;
    notifyListeners();
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'permission-denied':
        return 'Booking failed: You do not have permission. Please ensure you are signed in.';
      case 'unavailable':
        return 'Network unavailable. Please check your connection and try again.';
      case 'deadline-exceeded':
        return 'Request timed out. Please check your connection and try again.';
      default:
        return 'Booking could not be submitted. Please try again.';
    }
  }

  @override
  void dispose() {
    _vehiclesSub?.cancel();
    super.dispose();
  }
}

/// Global singleton — shared across the rental feature screens.
final customerRentalController = CustomerRentalController();
