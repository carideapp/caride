import 'dart:async';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';

import 'package:caride/core/config/app_env.dart';
import 'package:caride/core/utils/safe_image_picker.dart';
import 'package:caride/features/home_map/data/mapbox_search_service.dart';
import '../data/customer_rental_repository.dart';
import 'widgets/vehicle_booking_calendar.dart';

/// Redesigned vehicle booking form screen strictly matching the aesthetic,
/// pill geometry, and typography of [RentalVehicleDetailScreen] and CaRide
/// design system standards.
class RentalBookingFormScreen extends StatefulWidget {
  const RentalBookingFormScreen({super.key, required this.vehicle});

  final RentalVehicle vehicle;

  @override
  State<RentalBookingFormScreen> createState() =>
      _RentalBookingFormScreenState();
}

class _RentalBookingFormScreenState extends State<RentalBookingFormScreen> {
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  final _notesController = TextEditingController();
  final _scrollController = ScrollController();

  // ── Fleet Profile & Self-Drive Operating Office ──
  String _fleetOfficeAddress = '';

  // ── Self-Drive Driver License & Identity Verification State ──
  final _driversLicenseController = TextEditingController();
  String _selectedIdentityType = 'National ID (NIN)'; // National ID (NIN), International Passport, Voter's Card
  XFile? _driversLicenseFile;
  XFile? _identityDocFile;
  String? _driversLicenseUrl;
  String? _identityDocUrl;
  bool _isUploadingDocs = false;
  double _uploadProgress = 0.0;
  String _uploadStatusText = '';
  String? _uploadingDocType;

  // ── Google Places & Address Autocomplete State ──
  late final MapboxSearchService _placesSearchService;
  final _pickupFocusNode = FocusNode();
  final _dropoffFocusNode = FocusNode();

  Timer? _pickupDebounceTimer;
  Timer? _dropoffDebounceTimer;

  List<MapboxPlace> _pickupSuggestions = [];
  List<MapboxPlace> _dropoffSuggestions = [];

  bool _isSearchingPickup = false;
  bool _isSearchingDropoff = false;

  bool _isValidatingPickup = false;
  bool _isValidatingDropoff = false;

  MapboxPlace? _selectedPickupPlace;
  MapboxPlace? _selectedDropoffPlace;

  bool _isPickupValidated = false;
  bool _isDropoffValidated = false;

  // ── Service mode ──
  late RentalServiceType _selectedMode;

  // ── Dates & Time ──
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 2));
  TimeOfDay _pickupTime = const TimeOfDay(hour: 9, minute: 0);

  String get _formattedPickupTime {
    final now = DateTime.now();
    final dt = DateTime(
      now.year,
      now.month,
      now.day,
      _pickupTime.hour,
      _pickupTime.minute,
    );
    return DateFormat('hh:mm a').format(dt);
  }

  // ── Live Vehicle Bookings & Availability ──
  StreamSubscription<List<RentalBooking>>? _bookingsSub;
  List<RentalBooking> _activeBookings = [];

  // ── Options ──
  bool _isInterstate = false;

  // ── Validation ──
  String? _error;

  @override
  void initState() {
    super.initState();
    _placesSearchService = MapboxSearchService(AppEnv.googleMapsApiKey);

    _pickupFocusNode.addListener(() {
      if (!_pickupFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && !_pickupFocusNode.hasFocus) {
            setState(() => _pickupSuggestions = []);
          }
        });
      }
    });

    _dropoffFocusNode.addListener(() {
      if (!_dropoffFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && !_dropoffFocusNode.hasFocus) {
            setState(() => _dropoffSuggestions = []);
          }
        });
      }
    });

    final v = widget.vehicle;
    // Default to the most accessible/available mode
    if (v.allowsSelfDrive) {
      _selectedMode = RentalServiceType.selfDrive;
    } else if (v.allowsChauffeur) {
      _selectedMode = RentalServiceType.withDriver;
    } else {
      _selectedMode = RentalServiceType.dropOff;
    }

    _bookingsSub = customerRentalRepository
        .streamVehicleBookings(widget.vehicle.id)
        .listen((bookings) {
      if (mounted) {
        setState(() => _activeBookings = bookings);
      }
    });

    _loadFleetProfile();
  }

  Future<void> _loadFleetProfile() async {
    final fleetId = widget.vehicle.fleetId;
    if (fleetId.isEmpty) {
      _setFallbackFleetOfficeAddress();
      return;
    }
    try {
      final profile = await customerRentalRepository.getFleetProfile(fleetId: fleetId);
      if (!mounted) return;
      if (profile != null) {
        String office = profile.address.trim();
        if (office.isEmpty) {
          office = '${profile.businessName.isNotEmpty ? profile.businessName : widget.vehicle.displayName} Operating Base, ${profile.city}';
        } else if (!office.toLowerCase().contains(profile.city.toLowerCase())) {
          office = '$office, ${profile.city}';
        }
        setState(() {
          _fleetOfficeAddress = office;
        });
      } else {
        _setFallbackFleetOfficeAddress();
      }
    } catch (_) {
      if (mounted) {
        _setFallbackFleetOfficeAddress();
      }
    } finally {
      if (mounted) {
        _updatePickupForSelfDriveIfNeeded();
      }
    }
  }

  void _setFallbackFleetOfficeAddress() {
    _fleetOfficeAddress = '${widget.vehicle.make} ${widget.vehicle.model} Fleet Office Base, ${widget.vehicle.city}';
  }

  void _updatePickupForSelfDriveIfNeeded() {
    if (_selectedMode == RentalServiceType.selfDrive) {
      final addressToUse = _fleetOfficeAddress.isNotEmpty
          ? _fleetOfficeAddress
          : '${widget.vehicle.make} ${widget.vehicle.model} Fleet Office Base, ${widget.vehicle.city}';
      setState(() {
        _pickupController.text = addressToUse;
        _isPickupValidated = true;
      });
    }
  }

  Future<void> _pickDocumentImage(bool isLicense) async {
    try {
      final image = await SafeImagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (image == null) return;

      // File size validation (5MB max ceiling per AGENTS.md rule 3)
      final bytes = await image.readAsBytes();
      final sizeMB = bytes.lengthInBytes / (1024 * 1024);
      if (sizeMB > 5.0) {
        _showError(
            'Photo "${image.name}" exceeds the 5MB size limit (actual: ${sizeMB.toStringAsFixed(1)} MB). Please select a smaller image.');
        return;
      }

      setState(() {
        if (isLicense) {
          _driversLicenseFile = image;
          _driversLicenseUrl = null;
        } else {
          _identityDocFile = image;
          _identityDocUrl = null;
        }
      });
    } catch (e) {
      _showError('Could not select document image: $e');
    }
  }

  Future<String?> _uploadDocument({
    required XFile file,
    required String docType,
    required String docLabel,
    required double startWeight,
    required double endWeight,
  }) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
      final fileName = '${uid}_${docType}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = FirebaseStorage.instance.ref().child('rental_docs/$fileName');
      final bytes = await file.readAsBytes();

      if (mounted) {
        setState(() {
          _uploadingDocType = docType;
          _uploadStatusText = 'Uploading $docLabel (0%)...';
        });
      }

      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final subscription = uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (snapshot.totalBytes > 0) {
          final docProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          final overallProgress = startWeight + (docProgress * (endWeight - startWeight));
          final percentage = (overallProgress * 100).clamp(0, 100).toInt();
          if (mounted) {
            setState(() {
              _uploadProgress = overallProgress.clamp(0.0, 1.0);
              _uploadingDocType = docType;
              _uploadStatusText = 'Uploading $docLabel ($percentage%)...';
            });
          }
        }
      });

      final taskSnapshot = await uploadTask;
      await subscription.cancel();

      return await taskSnapshot.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Document upload error: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _pickupDebounceTimer?.cancel();
    _dropoffDebounceTimer?.cancel();
    _pickupFocusNode.dispose();
    _dropoffFocusNode.dispose();
    _bookingsSub?.cancel();
    _pickupController.dispose();
    _dropoffController.dispose();
    _notesController.dispose();
    _driversLicenseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onPickupChanged(String query) {
    setState(() {
      if (_selectedPickupPlace != null &&
          _pickupController.text.trim() != _selectedPickupPlace!.placeName.trim()) {
        _selectedPickupPlace = null;
        _isPickupValidated = false;
      }
    });

    _pickupDebounceTimer?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _pickupSuggestions = [];
        _isSearchingPickup = false;
      });
      return;
    }

    _pickupDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() => _isSearchingPickup = true);
      try {
        final results = await _placesSearchService.searchPlaces(query.trim());
        if (!mounted) return;
        setState(() {
          _pickupSuggestions = results;
          _isSearchingPickup = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _pickupSuggestions = [];
          _isSearchingPickup = false;
        });
      }
    });
  }

  void _onDropoffChanged(String query) {
    setState(() {
      if (_selectedDropoffPlace != null &&
          _dropoffController.text.trim() != _selectedDropoffPlace!.placeName.trim()) {
        _selectedDropoffPlace = null;
        _isDropoffValidated = false;
      }
    });

    _dropoffDebounceTimer?.cancel();
    if (query.trim().length < 2) {
      setState(() {
        _dropoffSuggestions = [];
        _isSearchingDropoff = false;
      });
      return;
    }

    _dropoffDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() => _isSearchingDropoff = true);
      try {
        final results = await _placesSearchService.searchPlaces(query.trim());
        if (!mounted) return;
        setState(() {
          _dropoffSuggestions = results;
          _isSearchingDropoff = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _dropoffSuggestions = [];
          _isSearchingDropoff = false;
        });
      }
    });
  }

  void _selectPickupPlace(MapboxPlace place) {
    setState(() {
      _pickupController.text = place.placeName;
      _selectedPickupPlace = place;
      _isPickupValidated = true;
      _pickupSuggestions = [];
    });
    _pickupFocusNode.unfocus();
  }

  void _selectDropoffPlace(MapboxPlace place) {
    setState(() {
      _dropoffController.text = place.placeName;
      _selectedDropoffPlace = place;
      _isDropoffValidated = true;
      _dropoffSuggestions = [];
    });
    _dropoffFocusNode.unfocus();
  }

  bool _isDateUnavailable(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    final iso =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    if (widget.vehicle.blackoutDates.contains(iso)) return true;

    for (final b in _activeBookings) {
      if (b.status == RentalBookingStatus.cancelled ||
          b.status == RentalBookingStatus.rejected ||
          b.status == RentalBookingStatus.completed) {
        continue;
      }
      final s = DateTime(b.startDate.year, b.startDate.month, b.startDate.day);
      final e = DateTime(b.endDate.year, b.endDate.month, b.endDate.day);
      if (!target.isBefore(s) && !target.isAfter(e)) {
        return true;
      }
    }
    return false;
  }

  DateTime _findFirstAvailableDate(DateTime startFrom) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime candidate = startFrom.isBefore(today)
        ? today
        : DateTime(startFrom.year, startFrom.month, startFrom.day);
    final maxDate = today.add(const Duration(days: 90));
    while (candidate.isBefore(maxDate) || candidate.isAtSameMomentAs(maxDate)) {
      if (!_isDateUnavailable(candidate)) {
        return candidate;
      }
      candidate = candidate.add(const Duration(days: 1));
    }
    return today;
  }

  // ── Cost Calculation ──────────────────────────────────────────────────────

  int get _durationDays {
    if (_selectedMode == RentalServiceType.dropOff) return 1;
    final diff = _endDate.difference(_startDate).inDays;
    return diff < 1 ? 1 : diff;
  }

  double get _baseRate {
    if (_selectedMode == RentalServiceType.dropOff) {
      return widget.vehicle.dropOffRate;
    } else if (_selectedMode == RentalServiceType.selfDrive) {
      return widget.vehicle.dailySelfDriveRate;
    }
    return widget.vehicle.dailyWithDriverRate;
  }

  double get _baseCost => _selectedMode == RentalServiceType.dropOff
      ? widget.vehicle.dropOffRate
      : _baseRate * _durationDays;

  double get _cautionDeposit => _selectedMode == RentalServiceType.selfDrive
      ? widget.vehicle.cautionDeposit
      : 0.0;

  double get _interstateCost =>
      _selectedMode != RentalServiceType.dropOff &&
              _isInterstate &&
              widget.vehicle.allowsInterstate
          ? widget.vehicle.interstateDailySurcharge * _durationDays
          : 0.0;

  double get _overnightAllowance =>
      _selectedMode == RentalServiceType.withDriver &&
              widget.vehicle.driverOvernightAllowance > 0 &&
              _durationDays > 1
          ? widget.vehicle.driverOvernightAllowance * (_durationDays - 1)
          : 0.0;

  double get _totalAmount =>
      _baseCost + _cautionDeposit + _interstateCost + _overnightAllowance;

  // ── Validation & Navigation ───────────────────────────────────────────────

  void _showError(String message) {
    setState(() => _error = message);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _proceed() async {
    setState(() => _error = null);

    final isDropOff = _selectedMode == RentalServiceType.dropOff;
    final pickupText = _pickupController.text.trim();

    if (pickupText.isEmpty) {
      _showError(isDropOff
          ? 'Please enter a pickup location (e.g. Airport terminal or Hotel address).'
          : 'Please enter a pickup location to continue.');
      return;
    }

    // Google Maps Address Validation for Pickup Field
    if (!_isPickupValidated) {
      if (pickupText.length < 3) {
        _showError('Please enter a more specific pickup address for Google Maps validation.');
        return;
      }
      setState(() => _isValidatingPickup = true);
      try {
        final candidates = await _placesSearchService.searchPlaces(pickupText);
        if (!mounted) return;
        setState(() => _isValidatingPickup = false);
        if (candidates.isNotEmpty) {
          final matched = candidates.first;
          setState(() {
            _selectedPickupPlace = matched;
            _isPickupValidated = true;
            _pickupController.text = matched.placeName;
          });
        } else {
          _showError(
              'Could not verify "$pickupText" on Google Maps. Please select a suggested address.');
          return;
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isValidatingPickup = false);
        debugPrint('Address validation error: $e');
      }
    }

    final dropoffText = _dropoffController.text.trim();
    if (isDropOff && dropoffText.isEmpty) {
      _showError('Please enter a destination / drop-off address for this transfer.');
      return;
    }

    // Google Maps Address Validation for Drop-off / Destination Field
    if (dropoffText.isNotEmpty && !_isDropoffValidated) {
      if (dropoffText.length < 3) {
        _showError('Please enter a more specific destination address for Google Maps validation.');
        return;
      }
      setState(() => _isValidatingDropoff = true);
      try {
        final candidates = await _placesSearchService.searchPlaces(dropoffText);
        if (!mounted) return;
        setState(() => _isValidatingDropoff = false);
        if (candidates.isNotEmpty) {
          final matched = candidates.first;
          setState(() {
            _selectedDropoffPlace = matched;
            _isDropoffValidated = true;
            _dropoffController.text = matched.placeName;
          });
        } else {
          _showError(
              'Could not verify "$dropoffText" on Google Maps. Please select a suggested destination.');
          return;
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isValidatingDropoff = false);
        debugPrint('Address validation error: $e');
      }
    }

    if (!isDropOff &&
        (_endDate.isBefore(_startDate) ||
            _endDate.isAtSameMomentAs(_startDate))) {
      _showError(
          'End date must be after start date. Please adjust your booking dates.');
      return;
    }

    // Live collision check against booked and blackout dates
    if (isDropOff) {
      if (_isDateUnavailable(_startDate)) {
        _showError(
            'The dates selected are already booked for this vehicle. Kindly check the vehicle availability calendar and select another available date.');
        return;
      }
    } else {
      DateTime d = DateTime(_startDate.year, _startDate.month, _startDate.day);
      final endNorm = DateTime(_endDate.year, _endDate.month, _endDate.day);
      while (!d.isAfter(endNorm)) {
        if (_isDateUnavailable(d)) {
          _showError(
              'The dates selected are already booked for this vehicle. Kindly check the vehicle availability calendar and select another available date.');
          return;
        }
        d = d.add(const Duration(days: 1));
      }
    }

    // Validate that pickup time is not in the past if start date is today
    final now = DateTime.now();
    final isToday = _startDate.year == now.year &&
        _startDate.month == now.month &&
        _startDate.day == now.day;
    if (isToday) {
      final pickupDateTime = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        _pickupTime.hour,
        _pickupTime.minute,
      );
      if (pickupDateTime.isBefore(now.add(const Duration(minutes: 15)))) {
        _showError(
            'Pickup time cannot be in the past. Please select a time at least 15 minutes ahead of now.');
        return;
      }
    }

    // Self-Drive Verification checks
    if (_selectedMode == RentalServiceType.selfDrive) {
      if (_driversLicenseController.text.trim().isEmpty) {
        _showError('Please enter your Driver\'s License number for self-drive verification.');
        return;
      }
      if (_driversLicenseFile == null && (_driversLicenseUrl == null || _driversLicenseUrl!.isEmpty)) {
        _showError('Please upload a photo of your Driver\'s License for verification.');
        return;
      }
      if (_identityDocFile == null && (_identityDocUrl == null || _identityDocUrl!.isEmpty)) {
        _showError('Please upload a photo of your Government ID for verification.');
        return;
      }

      // Determine which documents need uploading
      final needLicenseUpload = _driversLicenseFile != null &&
          (_driversLicenseUrl == null || _driversLicenseUrl!.isEmpty);
      final needIdentityUpload = _identityDocFile != null &&
          (_identityDocUrl == null || _identityDocUrl!.isEmpty);

      if (needLicenseUpload || needIdentityUpload) {
        setState(() {
          _isUploadingDocs = true;
          _uploadProgress = 0.0;
          _uploadStatusText = 'Preparing document upload...';
        });

        final totalDocs = (needLicenseUpload ? 1 : 0) + (needIdentityUpload ? 1 : 0);
        int completedDocs = 0;

        // Upload Driver's License photo if needed
        if (needLicenseUpload) {
          final startWeight = completedDocs / totalDocs;
          completedDocs++;
          final endWeight = completedDocs / totalDocs;

          final uploaded = await _uploadDocument(
            file: _driversLicenseFile!,
            docType: 'license',
            docLabel: 'Driver\'s License',
            startWeight: startWeight,
            endWeight: endWeight,
          );
          if (!mounted) return;
          if (uploaded == null) {
            setState(() {
              _isUploadingDocs = false;
              _uploadingDocType = null;
              _uploadProgress = 0.0;
              _uploadStatusText = '';
            });
            _showError(
                'Upload failed for Driver\'s License photo. Please check your network connection and try again.');
            return;
          }
          _driversLicenseUrl = uploaded;
        }

        // Upload Government ID photo if needed
        if (needIdentityUpload) {
          final startWeight = completedDocs / totalDocs;
          completedDocs++;
          final endWeight = completedDocs / totalDocs;

          final uploaded = await _uploadDocument(
            file: _identityDocFile!,
            docType: 'identity',
            docLabel: _selectedIdentityType,
            startWeight: startWeight,
            endWeight: endWeight,
          );
          if (!mounted) return;
          if (uploaded == null) {
            setState(() {
              _isUploadingDocs = false;
              _uploadingDocType = null;
              _uploadProgress = 0.0;
              _uploadStatusText = '';
            });
            _showError(
                'Upload failed for $_selectedIdentityType photo. Please check your network connection and try again.');
            return;
          }
          _identityDocUrl = uploaded;
        }

        setState(() {
          _uploadProgress = 1.0;
          _uploadStatusText = 'Documents Uploaded!';
          _isUploadingDocs = false;
          _uploadingDocType = null;
        });
      }
    }

    final v = widget.vehicle;
    final effectiveStartDate = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
      _pickupTime.hour,
      _pickupTime.minute,
    );
    final effectiveEndDate = isDropOff
        ? effectiveStartDate
        : DateTime(
            _endDate.year,
            _endDate.month,
            _endDate.day,
            _pickupTime.hour,
            _pickupTime.minute,
          );

    // Build draft booking for summary screen
    final draft = RentalBooking(
      id: '',
      fleetId: v.fleetId,
      vehicleId: v.id,
      vehicleTitle: v.displayName,
      vehicleImage: v.primaryImageUrl,
      vehicleCategory: v.category.label,
      customerId: '', // filled by summary screen from auth
      customerName: '',
      customerPhone: '',
      serviceType: _selectedMode,
      startDate: effectiveStartDate,
      endDate: effectiveEndDate,
      pickupTime: _formattedPickupTime,
      durationDays: _durationDays,
      pickupLocation: _pickupController.text.trim(),
      dropoffLocation: _dropoffController.text.trim(),
      pickupLat: _selectedPickupPlace?.centerLat,
      pickupLng: _selectedPickupPlace?.centerLng,
      dropoffLat: _selectedDropoffPlace?.centerLat,
      dropoffLng: _selectedDropoffPlace?.centerLng,
      totalAmount: _totalAmount,
      cautionDeposit: _cautionDeposit,
      driverAllowance: _overnightAllowance,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      driversLicenseNumber: _selectedMode == RentalServiceType.selfDrive
          ? _driversLicenseController.text.trim()
          : null,
      driversLicenseUrl: _selectedMode == RentalServiceType.selfDrive
          ? _driversLicenseUrl
          : null,
      identityDocumentType: _selectedMode == RentalServiceType.selfDrive
          ? _selectedIdentityType
          : null,
      identityDocumentUrl: _selectedMode == RentalServiceType.selfDrive
          ? _identityDocUrl
          : null,
    );

    context.push(
      CustomerRoutePaths.rentalBookingSummary,
      extra: {'vehicle': v, 'booking': draft},
    );
  }

  // ── Date Pickers ──────────────────────────────────────────────────────────

  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _findFirstAvailableDate(_startDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 90)),
      selectableDayPredicate: (date) => !_isDateUnavailable(date),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.brand,
            brightness: Theme.of(context).brightness,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate.isBefore(_startDate) ||
            _endDate.isAtSameMomentAs(_startDate)) {
          _endDate = _findFirstAvailableDate(_startDate.add(const Duration(days: 1)));
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final firstAllowedEnd = DateTime(_startDate.year, _startDate.month, _startDate.day)
        .add(const Duration(days: 1));
    final initialTarget = _endDate.isAfter(_startDate)
        ? _endDate
        : firstAllowedEnd;
    final initial = _findFirstAvailableDate(
      initialTarget.isBefore(firstAllowedEnd) ? firstAllowedEnd : initialTarget,
    );

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstAllowedEnd,
      lastDate: today.add(const Duration(days: 90)),
      selectableDayPredicate: (date) => !_isDateUnavailable(date),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.brand,
            brightness: Theme.of(context).brightness,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _pickPickupTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _pickupTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.brand,
            brightness: Theme.of(context).brightness,
          ),
          timePickerTheme: TimePickerThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _pickupTime = picked);
    }
  }

  void _openBookingCalendarBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.brand,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vehicle Availability Calendar',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Green = Booked, Grey = Open for booking',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              VehicleBookingCalendar(
                bookings: _activeBookings,
                blackoutDates: widget.vehicle.blackoutDates,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Close Calendar',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final tertiaryTextColor =
        isDark ? AppColors.textTertiaryDark : const Color(0xFF9CA3AF);
    final inputFill =
        isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6);
    final v = widget.vehicle;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: Stack(
        children: [
          // ── Scrollable Body ────────────────────────────────────────────────
          SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Navigation Bar Matching Detail Screen ────────────────
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        // Circular 44x44 Back Button per AGENTS.md
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? AppColors.darkSurface : Colors.white,
                              border: Border.all(
                                color: isDark
                                    ? AppColors.glassBorderDark
                                    : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Icon(
                              Icons.chevron_left_rounded,
                              color: primaryTextColor,
                              size: 26,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              'Book Vehicle',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ),
                        // Circular Balance Spacer
                        const SizedBox(width: 44, height: 44),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Error Banner (Immediate-View per AGENTS.md) ─────────
                      if (_error != null) ...[
                        _ErrorBanner(
                          message: _error!,
                          onDismiss: () => setState(() => _error = null),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // ── Vehicle Summary Card ───────────────────────────────
                      _VehicleMiniCard(
                        v: v,
                        isDark: isDark,
                        primaryText: primaryTextColor,
                        secondaryText: secondaryTextColor,
                        tertiaryText: tertiaryTextColor,
                      ),

                      const SizedBox(height: 24),

                      // ── Service Type Selector ──────────────────────────────
                      if (v.allowsSelfDrive || v.allowsChauffeur || v.allowsDropOff) ...[
                        _buildSectionHeader('Select Service Option', primaryTextColor),
                        const SizedBox(height: 14),
                        _ServiceTypeToggle(
                          selected: _selectedMode,
                          vehicle: v,
                          isDark: isDark,
                          primaryText: primaryTextColor,
                          secondaryText: secondaryTextColor,
                          onChanged: (mode) {
                            setState(() {
                              _selectedMode = mode;
                              if (mode == RentalServiceType.selfDrive) {
                                _updatePickupForSelfDriveIfNeeded();
                              } else {
                                _pickupController.clear();
                                _selectedPickupPlace = null;
                                _isPickupValidated = false;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Date & Pickup Time Selection ──────────────────────
                      if (_selectedMode == RentalServiceType.dropOff) ...[
                        _buildSectionHeader(
                            'Transfer Date & Pickup Time', primaryTextColor),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _DateCard(
                                label: 'Date of Transfer',
                                date: _startDate,
                                isDark: isDark,
                                primaryText: primaryTextColor,
                                secondaryText: secondaryTextColor,
                                onTap: _pickStartDate,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TimeCard(
                                label: 'Pickup Time',
                                time: _formattedPickupTime,
                                isDark: isDark,
                                primaryText: primaryTextColor,
                                secondaryText: secondaryTextColor,
                                onTap: _pickPickupTime,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.brand.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.flight_land_rounded,
                                    size: 14, color: AppColors.brand),
                                const SizedBox(width: 6),
                                Text(
                                  'One-way transfer • Pickup at $_formattedPickupTime',
                                  style: const TextStyle(
                                    color: AppColors.brand,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.brand,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              side: BorderSide(
                                color: AppColors.brand.withValues(alpha: 0.35),
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.calendar_month_rounded,
                                size: 16),
                            label: const Text(
                              'View Vehicle Availability Calendar',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: _openBookingCalendarBottomSheet,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else ...[
                        _buildSectionHeader(
                            'Rental Schedule & Pickup Time', primaryTextColor),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _DateCard(
                                label: 'Start Date',
                                date: _startDate,
                                isDark: isDark,
                                primaryText: primaryTextColor,
                                secondaryText: secondaryTextColor,
                                onTap: _pickStartDate,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _DateCard(
                                label: 'End Date',
                                date: _endDate,
                                isDark: isDark,
                                primaryText: primaryTextColor,
                                secondaryText: secondaryTextColor,
                                onTap: _pickEndDate,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _TimeCard(
                          label: _selectedMode == RentalServiceType.selfDrive
                              ? 'Vehicle Handover / Pickup Time'
                              : 'Chauffeur Arrival / Pickup Time',
                          time: _formattedPickupTime,
                          isDark: isDark,
                          primaryText: primaryTextColor,
                          secondaryText: secondaryTextColor,
                          onTap: _pickPickupTime,
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.brand.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.schedule_rounded,
                                    size: 14, color: AppColors.brand),
                                const SizedBox(width: 6),
                                Text(
                                  '$_durationDays day${_durationDays == 1 ? '' : 's'} rental • Pickup at $_formattedPickupTime',
                                  style: const TextStyle(
                                    color: AppColors.brand,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.brand,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              side: BorderSide(
                                color: AppColors.brand.withValues(alpha: 0.35),
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.calendar_month_rounded,
                                size: 16),
                            label: const Text(
                              'View Vehicle Availability Calendar',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            onPressed: _openBookingCalendarBottomSheet,
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Self-Drive Verification Requirements Section ────────
                      if (_selectedMode == RentalServiceType.selfDrive)
                        _buildSelfDriveVerificationSection(
                          isDark,
                          primaryTextColor,
                          secondaryTextColor,
                          inputFill,
                        ),

                      // ── Pickup Location ────────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader('Pickup Location', primaryTextColor),
                          if (_isPickupValidated && _selectedMode != RentalServiceType.selfDrive)
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    size: 14, color: AppColors.brand),
                                const SizedBox(width: 4),
                                const Text(
                                  'Google Verified',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brand,
                                  ),
                                ),
                              ],
                            )
                          else if (_selectedMode == RentalServiceType.selfDrive)
                            const Text(
                              'Fleet Base',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.brand,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _PillTextField(
                        controller: _pickupController,
                        focusNode: _pickupFocusNode,
                        onChanged: _selectedMode == RentalServiceType.selfDrive ? null : _onPickupChanged,
                        isValidated: _isPickupValidated,
                        isValidating: _isValidatingPickup,
                        readOnly: _selectedMode == RentalServiceType.selfDrive,
                        onClear: _selectedMode == RentalServiceType.selfDrive
                            ? null
                            : () {
                                setState(() {
                                  _pickupController.clear();
                                  _selectedPickupPlace = null;
                                  _isPickupValidated = false;
                                  _pickupSuggestions = [];
                                });
                              },
                        hint: _selectedMode == RentalServiceType.selfDrive
                            ? 'Fleet Base Operating Office'
                            : (_selectedMode == RentalServiceType.dropOff
                                ? 'Search airport terminal, hotel, or pickup address'
                                : 'Search street address, landmark, or hotel'),
                        icon: _selectedMode == RentalServiceType.selfDrive
                            ? Icons.store_rounded
                            : Icons.location_on_rounded,
                        isDark: isDark,
                        fillColor: inputFill,
                        iconColor: AppColors.brand,
                      ),
                      if (_selectedMode != RentalServiceType.selfDrive)
                        _buildAddressSuggestionsWidget(
                          isSearching: _isSearchingPickup,
                          suggestions: _pickupSuggestions,
                          onSelect: _selectPickupPlace,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          secondaryTextColor: secondaryTextColor,
                        ),
                      const SizedBox(height: 20),

                      // ── Drop-off Location ──────────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader(
                            _selectedMode == RentalServiceType.dropOff
                                ? 'Drop-off / Destination'
                                : (_selectedMode == RentalServiceType.selfDrive
                                    ? 'Drop-off Location (Optional)'
                                    : 'Destination (Optional)'),
                            primaryTextColor,
                          ),
                          if (_isDropoffValidated)
                            Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    size: 14, color: AppColors.brand),
                                const SizedBox(width: 4),
                                const Text(
                                  'Google Verified',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brand,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _PillTextField(
                        controller: _dropoffController,
                        focusNode: _dropoffFocusNode,
                        onChanged: _onDropoffChanged,
                        isValidated: _isDropoffValidated,
                        isValidating: _isValidatingDropoff,
                        onClear: () {
                          setState(() {
                            _dropoffController.clear();
                            _selectedDropoffPlace = null;
                            _isDropoffValidated = false;
                            _dropoffSuggestions = [];
                          });
                        },
                        hint: _selectedMode == RentalServiceType.dropOff
                            ? 'Search destination, hotel, or residence'
                            : 'Search return location or destination address',
                        icon: Icons.flag_rounded,
                        isDark: isDark,
                        fillColor: inputFill,
                        iconColor: tertiaryTextColor,
                      ),
                      _buildAddressSuggestionsWidget(
                        isSearching: _isSearchingDropoff,
                        suggestions: _dropoffSuggestions,
                        onSelect: _selectDropoffPlace,
                        isDark: isDark,
                        primaryTextColor: primaryTextColor,
                        secondaryTextColor: secondaryTextColor,
                      ),
                      const SizedBox(height: 24),

                      // ── Interstate Travel Toggle ───────────────────────────
                      if (v.allowsInterstate &&
                          _selectedMode != RentalServiceType.dropOff) ...[
                        _buildSectionHeader('Travel Scope', primaryTextColor),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.glassBorderDark
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0EA5E9)
                                      .withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.route_rounded,
                                    color: Color(0xFF0EA5E9), size: 20),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Interstate Travel',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    if (v.interstateDailySurcharge > 0)
                                      Text(
                                        '+${NgnFormat.currency(v.interstateDailySurcharge)}/day surcharge',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: secondaryTextColor,
                                        ),
                                      )
                                    else
                                      Text(
                                        'Permitted without additional fee',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: secondaryTextColor,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Switch.adaptive(
                                value: _isInterstate,
                                activeTrackColor: AppColors.brand,
                                onChanged: (val) =>
                                    setState(() => _isInterstate = val),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      // ── Special Instructions / Notes ───────────────────────
                      _buildSectionHeader(
                          'Special Notes (Optional)', primaryTextColor),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: inputFill,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: isDark
                                ? AppColors.glassBorderDark
                                : Colors.transparent,
                          ),
                        ),
                        child: TextField(
                          controller: _notesController,
                          maxLines: 3,
                          style: TextStyle(
                              color: primaryTextColor, fontSize: 14),
                          decoration: const InputDecoration(
                            hintText:
                                'Any special requirements, route details or requests...',
                            hintStyle: TextStyle(
                                color: Color(0xFF9CA3AF), fontSize: 13),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 22, vertical: 16),
                            border: InputBorder.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── Live Cost Calculator ───────────────────────────────
                      _buildSectionHeader('Price Breakdown', primaryTextColor),
                      const SizedBox(height: 12),
                      _CostCalculatorCard(
                        durationDays: _durationDays,
                        baseRate: _baseRate,
                        baseCost: _baseCost,
                        cautionDeposit: _cautionDeposit,
                        interstateCost: _interstateCost,
                        overnightAllowance: _overnightAllowance,
                        total: _totalAmount,
                        selectedMode: _selectedMode,
                        isDark: isDark,
                        primaryText: primaryTextColor,
                        secondaryText: secondaryTextColor,
                      ),

                      // Bottom clearance for sticky CTA bar
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Sticky Bottom CTA Bar Matching Detail Screen ───────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildStickyBottomBar(
              context: context,
              totalAmount: _totalAmount,
              isDark: isDark,
              secondaryTextColor: secondaryTextColor,
              isUploading: _isUploadingDocs,
              uploadProgress: _uploadProgress,
              uploadStatusText: _uploadStatusText,
              onProceed: _proceed,
            ),
          ),
        ],
      ),
    );
  }

  // ── Self-Drive Identity & License Verification UI ───────────────────────

  Widget _buildSelfDriveVerificationSection(
    bool isDark,
    Color primaryText,
    Color secondaryText,
    Color inputFill,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Self-Drive Identity & License Verification', primaryText),
        const SizedBox(height: 10),

        // Physical Original Document Notice Card (AGENTS.md style)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.brand.withValues(alpha: 0.12) : const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.brand.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.verified_user_rounded, color: AppColors.brand, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Physical Original Documents Required',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brand,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'For security & identity verification, you must physically present your original Driver\'s License and selected Government ID card to the fleet manager when collecting the vehicle.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF374151),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Driver's License Number Field
        Text(
          'Driver\'s License Number',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryText),
        ),
        const SizedBox(height: 8),
        _PillTextField(
          controller: _driversLicenseController,
          hint: 'Enter valid Driver\'s License number',
          icon: Icons.badge_rounded,
          isDark: isDark,
          fillColor: inputFill,
          iconColor: AppColors.brand,
        ),

        const SizedBox(height: 16),

        // Driver's License Photo Upload Tile
        Text(
          'Driver\'s License Document Photo',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryText),
        ),
        const SizedBox(height: 8),
        _buildDocumentUploadTile(
          title: 'Upload Driver\'s License Photo',
          docType: 'license',
          file: _driversLicenseFile,
          url: _driversLicenseUrl,
          isDark: isDark,
          primaryText: primaryText,
          secondaryText: secondaryText,
          onTap: () => _pickDocumentImage(true),
        ),

        const SizedBox(height: 20),

        // Government ID Type Selector
        Text(
          'Government ID Type',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryText),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            'National ID (NIN)',
            'International Passport',
            'Voter\'s Card',
          ].map((type) {
            final isSelected = _selectedIdentityType == type;
            return ChoiceChip(
              label: Text(type),
              selected: isSelected,
              selectedColor: AppColors.brand,
              backgroundColor: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : primaryText,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(
                  color: isSelected
                      ? AppColors.brand
                      : (isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
                ),
              ),
              onSelected: (_) => setState(() => _selectedIdentityType = type),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),

        // Government ID Photo Upload Tile
        Text(
          'Government ID Photo ($_selectedIdentityType)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryText),
        ),
        const SizedBox(height: 8),
        _buildDocumentUploadTile(
          title: 'Upload $_selectedIdentityType Photo',
          docType: 'identity',
          file: _identityDocFile,
          url: _identityDocUrl,
          isDark: isDark,
          primaryText: primaryText,
          secondaryText: secondaryText,
          onTap: () => _pickDocumentImage(false),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildDocumentUploadTile({
    required String title,
    required String docType,
    required XFile? file,
    required String? url,
    required bool isDark,
    required Color primaryText,
    required Color secondaryText,
    required VoidCallback onTap,
  }) {
    final hasDoc = file != null || (url != null && url.isNotEmpty);
    final isUploadingThis = _isUploadingDocs && _uploadingDocType == docType;
    final isUploadingAny = _isUploadingDocs;

    return InkWell(
      onTap: isUploadingAny ? null : onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isUploadingThis
              ? (isDark ? AppColors.brand.withValues(alpha: 0.15) : const Color(0xFFECFDF5))
              : (hasDoc
                  ? (isDark ? AppColors.brand.withValues(alpha: 0.12) : const Color(0xFFF0FDF4))
                  : (isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB))),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isUploadingThis || hasDoc
                ? AppColors.brand.withValues(alpha: 0.5)
                : (isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isUploadingThis
                        ? AppColors.brand.withValues(alpha: 0.2)
                        : (hasDoc ? AppColors.brand : (isDark ? Colors.white10 : const Color(0xFFE5E7EB))),
                  ),
                  child: isUploadingThis
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                          ),
                        )
                      : Icon(
                          hasDoc ? Icons.check_rounded : Icons.add_a_photo_rounded,
                          color: hasDoc ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF6B7280)),
                          size: 20,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUploadingThis
                            ? 'Uploading Document...'
                            : (hasDoc ? (file?.name ?? 'Document Uploaded') : title),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isUploadingThis || hasDoc ? AppColors.brand : primaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isUploadingThis
                            ? _uploadStatusText
                            : (hasDoc
                                ? 'Tap to change photo (Max 5MB • JPG, PNG)'
                                : 'Max 5MB • JPG, PNG format'),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isUploadingThis ? AppColors.brand : secondaryText,
                          fontWeight: isUploadingThis ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.brand,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    side: BorderSide(
                        color: AppColors.brand.withValues(alpha: isUploadingAny ? 0.15 : 0.3)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: isUploadingAny ? null : onTap,
                  child: Text(
                    isUploadingThis
                        ? 'Uploading'
                        : (hasDoc ? 'Change' : 'Upload'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            if (isUploadingThis) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: _uploadProgress > 0 ? _uploadProgress : null,
                  minHeight: 4,
                  backgroundColor: isDark
                      ? AppColors.brand.withValues(alpha: 0.15)
                      : const Color(0xFFE5E7EB),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Helper Section Header ─────────────────────────────────────────────────

  Widget _buildSectionHeader(String title, Color primaryTextColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w800,
        color: primaryTextColor,
        letterSpacing: -0.2,
      ),
    );
  }

  // ── Address Suggestions Dropdown Widget ───────────────────────────────────

  Widget _buildAddressSuggestionsWidget({
    required bool isSearching,
    required List<MapboxPlace> suggestions,
    required void Function(MapboxPlace) onSelect,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    if (isSearching) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, left: 14),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Searching Google Maps...',
              style: TextStyle(
                fontSize: 12,
                color: secondaryTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: suggestions.map((place) {
            final firstComma = place.placeName.indexOf(',');
            final mainText = firstComma != -1
                ? place.placeName.substring(0, firstComma).trim()
                : place.placeName;
            final subText = firstComma != -1
                ? place.placeName.substring(firstComma + 1).trim()
                : '';

            return InkWell(
              onTap: () => onSelect(place),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? AppColors.glassBorderDark
                          : const Color(0xFFF3F4F6),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.location_on_rounded,
                        color: AppColors.brand,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mainText,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (subText.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              subText,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: secondaryTextColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.north_west_rounded,
                      size: 16,
                      color: secondaryTextColor.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Sticky Bottom CTA Bar ─────────────────────────────────────────────────

  Widget _buildStickyBottomBar({
    required BuildContext context,
    required double totalAmount,
    required bool isDark,
    required Color secondaryTextColor,
    required bool isUploading,
    required double uploadProgress,
    required String uploadStatusText,
    required VoidCallback onProceed,
  }) {
    final progressPercent = (uploadProgress * 100).clamp(0, 100).toInt();

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
          ),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isUploading) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          uploadStatusText.isNotEmpty
                              ? uploadStatusText
                              : 'Uploading verification documents...',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brand,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$progressPercent%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brand,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: uploadProgress > 0 ? uploadProgress : null,
                minHeight: 5,
                backgroundColor: isDark
                    ? AppColors.brand.withValues(alpha: 0.15)
                    : const Color(0xFFE5E7EB),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              // Total price breakdown
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total Estimate',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: secondaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    NgnFormat.currency(totalAmount),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppColors.brand,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),

              const SizedBox(width: 18),

              // Primary Pill Action Button: "Proceed to Summary →"
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    onPressed: isUploading ? null : onProceed,
                    child: isUploading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Uploading ($progressPercent%)...',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Proceed to Summary',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_rounded, size: 19),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Sub-Widgets ───────────────────────────────────────────────────────────────

class _VehicleMiniCard extends StatelessWidget {
  const _VehicleMiniCard({
    required this.v,
    required this.isDark,
    required this.primaryText,
    required this.secondaryText,
    required this.tertiaryText,
  });

  final RentalVehicle v;
  final bool isDark;
  final Color primaryText;
  final Color secondaryText;
  final Color tertiaryText;

  @override
  Widget build(BuildContext context) {
    final hasRating = v.rating != null && v.rating! > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          // Vehicle Image Thumbnail with rounded geometry
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 88,
              height: 66,
              child: () {
                if (v.images.isEmpty) return _placeholder();
                final url = v.images.first.trim();
                if (url.isEmpty) return _placeholder();
                if (url.startsWith('http://') || url.startsWith('https://')) {
                  return Image.network(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  );
                } else {
                  return Image.asset(
                    url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholder(),
                  );
                }
              }(),
            ),
          ),

          const SizedBox(width: 14),

          // Vehicle Info & Live Review Rating
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Chip Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    v.category.label,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brand,
                    ),
                  ),
                ),
                const SizedBox(height: 5),

                // Vehicle Title
                Text(
                  v.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: primaryText,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),

                // Location & Reviews Row
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 13,
                      color: AppColors.brand,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      v.city,
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tertiaryText,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      hasRating ? v.rating!.toStringAsFixed(1) : 'New',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                    Text(
                      hasRating ? ' (${v.reviewCount})' : '',
                      style: TextStyle(
                        fontSize: 11,
                        color: tertiaryText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.brand.withValues(alpha: 0.1),
        child: const Center(
          child: Icon(
            Icons.directions_car_rounded,
            color: AppColors.brand,
            size: 28,
          ),
        ),
      );
}

class _ServiceTypeToggle extends StatelessWidget {
  const _ServiceTypeToggle({
    required this.selected,
    required this.vehicle,
    required this.isDark,
    required this.primaryText,
    required this.secondaryText,
    required this.onChanged,
  });

  final RentalServiceType selected;
  final RentalVehicle vehicle;
  final bool isDark;
  final Color primaryText;
  final Color secondaryText;
  final ValueChanged<RentalServiceType> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = <Widget>[];

    if (vehicle.allowsSelfDrive) {
      options.add(
        Expanded(
          child: _ModeOption(
            label: 'Self-Drive',
            icon: Icons.key_rounded,
            subtitle: '${NgnFormat.currency(vehicle.dailySelfDriveRate)}/day',
            isSelected: selected == RentalServiceType.selfDrive,
            isDark: isDark,
            primaryText: primaryText,
            secondaryText: secondaryText,
            onTap: () => onChanged(RentalServiceType.selfDrive),
          ),
        ),
      );
    }

    if (vehicle.allowsChauffeur) {
      if (options.isNotEmpty) options.add(const SizedBox(width: 10));
      options.add(
        Expanded(
          child: _ModeOption(
            label: 'Chauffeur',
            icon: Icons.person_rounded,
            subtitle: '${NgnFormat.currency(vehicle.dailyWithDriverRate)}/day',
            isSelected: selected == RentalServiceType.withDriver,
            isDark: isDark,
            primaryText: primaryText,
            secondaryText: secondaryText,
            onTap: () => onChanged(RentalServiceType.withDriver),
          ),
        ),
      );
    }

    if (vehicle.allowsDropOff) {
      if (options.isNotEmpty) options.add(const SizedBox(width: 10));
      options.add(
        Expanded(
          child: _ModeOption(
            label: 'Drop-Off',
            icon: Icons.flight_land_rounded,
            subtitle: '${NgnFormat.currency(vehicle.dropOffRate)}/trip',
            isSelected: selected == RentalServiceType.dropOff,
            isDark: isDark,
            primaryText: primaryText,
            secondaryText: secondaryText,
            onTap: () => onChanged(RentalServiceType.dropOff),
          ),
        ),
      );
    }

    return Row(children: options);
  }
}

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.label,
    required this.icon,
    required this.subtitle,
    required this.isSelected,
    required this.isDark,
    required this.primaryText,
    required this.secondaryText,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final String subtitle;
  final bool isSelected;
  final bool isDark;
  final Color primaryText;
  final Color secondaryText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? AppColors.brand.withValues(alpha: 0.16)
                  : const Color(0xFFF0FDF4))
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.brand
                : (isDark
                    ? AppColors.glassBorderDark
                    : const Color(0xFFE5E7EB)),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.brand
                    : (isDark
                        ? Colors.white10
                        : const Color(0xFFF3F4F6)),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.brand,
                size: 20,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isSelected ? AppColors.brand : primaryText,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.brand : secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateCard extends StatelessWidget {
  const _DateCard({
    required this.label,
    required this.date,
    required this.isDark,
    required this.primaryText,
    required this.secondaryText,
    required this.onTap,
  });

  final String label;
  final DateTime date;
  final bool isDark;
  final Color primaryText;
  final Color secondaryText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: AppColors.brand,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        DateFormat('EEE, MMM d').format(date),
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: primaryText,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        DateFormat('yyyy').format(date),
                        style: TextStyle(
                          fontSize: 11,
                          color: secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.edit_calendar_rounded,
                  size: 16,
                  color: secondaryText.withValues(alpha: 0.7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.label,
    required this.time,
    required this.isDark,
    required this.primaryText,
    required this.secondaryText,
    required this.onTap,
  });

  final String label;
  final String time;
  final bool isDark;
  final Color primaryText;
  final Color secondaryText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: secondaryText,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.access_time_rounded,
                    color: AppColors.brand,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: primaryText,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'Tap to change',
                        style: TextStyle(
                          fontSize: 11,
                          color: secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: secondaryText.withValues(alpha: 0.7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PillTextField extends StatelessWidget {
  const _PillTextField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.isDark,
    required this.fillColor,
    required this.iconColor,
    this.focusNode,
    this.onChanged,
    this.isValidated = false,
    this.isValidating = false,
    this.onClear,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool isDark;
  final Color fillColor;
  final Color iconColor;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final bool isValidated;
  final bool isValidating;
  final VoidCallback? onClear;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.isNotEmpty;

        Widget? suffix;
        if (isValidating) {
          suffix = const Padding(
            padding: EdgeInsets.all(14.0),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
              ),
            ),
          );
        } else if (isValidated) {
          suffix = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Tooltip(
                message: 'Verified on Google Maps',
                child: Icon(Icons.check_circle_rounded,
                    color: AppColors.brand, size: 20),
              ),
              if (onClear != null && !readOnly)
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: Color(0xFF9CA3AF)),
                  onPressed: onClear,
                  tooltip: 'Clear',
                  splashRadius: 18,
                )
              else
                const SizedBox(width: 14),
            ],
          );
        } else if (hasText && onClear != null && !readOnly) {
          suffix = IconButton(
            icon: const Icon(Icons.close_rounded,
                size: 18, color: Color(0xFF9CA3AF)),
            onPressed: onClear,
            tooltip: 'Clear',
            splashRadius: 18,
          );
        }

        return TextField(
          controller: controller,
          focusNode: focusNode,
          onChanged: onChanged,
          readOnly: readOnly,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF111827),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            filled: true,
            fillColor: fillColor,
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 18, right: 12),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 46),
            suffixIcon: suffix,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: isDark
                  ? BorderSide(
                      color: isValidated
                          ? AppColors.brand.withValues(alpha: 0.6)
                          : AppColors.glassBorderDark,
                    )
                  : (isValidated
                      ? BorderSide(
                          color: AppColors.brand.withValues(alpha: 0.6),
                          width: 1.2,
                        )
                      : BorderSide.none),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide:
                  const BorderSide(color: AppColors.brand, width: 1.5),
            ),
          ),
        );
      },
    );
  }
}

class _CostCalculatorCard extends StatelessWidget {
  const _CostCalculatorCard({
    required this.durationDays,
    required this.baseRate,
    required this.baseCost,
    required this.cautionDeposit,
    required this.interstateCost,
    required this.overnightAllowance,
    required this.total,
    required this.selectedMode,
    required this.isDark,
    required this.primaryText,
    required this.secondaryText,
  });

  final int durationDays;
  final double baseRate;
  final double baseCost;
  final double cautionDeposit;
  final double interstateCost;
  final double overnightAllowance;
  final double total;
  final RentalServiceType selectedMode;
  final bool isDark;
  final Color primaryText;
  final Color secondaryText;

  @override
  Widget build(BuildContext context) {
    final divider = isDark ? AppColors.glassBorderDark : const Color(0xFFF1F5F9);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: [
          _CostRow(
            label: selectedMode == RentalServiceType.dropOff
                ? 'Drop-Off / Transfer Flat Rate'
                : '${selectedMode == RentalServiceType.selfDrive ? 'Self-Drive' : 'Chauffeur'} Rate (${NgnFormat.currency(baseRate)} × $durationDays d)',
            value: NgnFormat.currency(baseCost),
            secondary: secondaryText,
            primary: primaryText,
          ),
          if (cautionDeposit > 0) ...[
            Divider(height: 22, color: divider),
            _CostRow(
              label: 'Refundable Caution Deposit',
              value: NgnFormat.currency(cautionDeposit),
              secondary: secondaryText,
              primary: primaryText,
            ),
          ],
          if (interstateCost > 0) ...[
            Divider(height: 22, color: divider),
            _CostRow(
              label: 'Interstate Travel Surcharge ($durationDays d)',
              value: NgnFormat.currency(interstateCost),
              secondary: secondaryText,
              primary: primaryText,
            ),
          ],
          if (overnightAllowance > 0) ...[
            Divider(height: 22, color: divider),
            _CostRow(
              label: 'Driver Overnight Allowance (${durationDays - 1} nights)',
              value: NgnFormat.currency(overnightAllowance),
              secondary: secondaryText,
              primary: primaryText,
            ),
          ],
          Divider(height: 26, color: divider),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Estimated Total',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: primaryText,
                ),
              ),
              Text(
                NgnFormat.currency(total),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.brand,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '* Final pricing subject to fleet confirmation. Caution deposit is refundable upon vehicle inspection.',
            style: TextStyle(
              fontSize: 11,
              color: secondaryText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({
    required this.label,
    required this.value,
    required this.secondary,
    required this.primary,
  });

  final String label;
  final String value;
  final Color secondary;
  final Color primary;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: secondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
        ],
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A1215) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Action Required',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(Icons.close_rounded,
                color: AppColors.error, size: 18),
          ),
        ],
      ),
    );
  }
}
