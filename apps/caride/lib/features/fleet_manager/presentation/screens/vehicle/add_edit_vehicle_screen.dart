import 'dart:io';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:caride/features/fleet_manager/controllers/fleet_manager_controller.dart';
import 'package:caride/features/car_rental/presentation/widgets/vehicle_booking_calendar.dart';
/// Strict AGENTS.md compliance:
/// - Max 10 images limit & 5MB per file validation
/// - Allowed extensions strictly JPG and PNG
/// - Proactive, actionable error handling across all scenarios
/// - Upload progress dialog during asset upload & save
/// - Success bottom sheet matching CaRide brand design
class AddEditVehicleScreen extends StatefulWidget {
  const AddEditVehicleScreen({super.key, this.vehicle});

  final RentalVehicle? vehicle;

  @override
  State<AddEditVehicleScreen> createState() => _AddEditVehicleScreenState();
}

class _AddEditVehicleScreenState extends State<AddEditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();

  static const int _maxPhotosLimit = 10;
  static const int _maxFileSizeBytes = 5 * 1024 * 1024; // 5MB
  static const Set<String> _allowedExtensions = {'jpg', 'jpeg', 'png'};

  // ── Controllers ──
  late final TextEditingController _plateController;
  late final TextEditingController _descriptionController;
  final TextEditingController _customMakeController = TextEditingController();
  final TextEditingController _customModelController = TextEditingController();
  final TextEditingController _customColorController = TextEditingController();
  late final TextEditingController _selfDriveRateController;
  late final TextEditingController _withDriverRateController;
  late final TextEditingController _hourlyRateController;
  late final TextEditingController _overtimeRateController;
  late final TextEditingController _cautionDepositController;
  late final TextEditingController _interstateSurchargeController;
  late final TextEditingController _overnightAllowanceController;
  late final TextEditingController _securityEscortRateController;
  late final TextEditingController _dropOffRateController;

  // ── Vehicle Identity State ──
  String? _selectedMake;
  String? _selectedModel;
  int? _selectedYear;
  String? _selectedColor;
  RentalVehicleCategory? _selectedCategory;
  String? _selectedTransmission;
  String? _selectedFuelType;
  int? _selectedSeats;
  String? _selectedCity;
  String? _assignedDriverId;
  String? _assignedDriverName;
  String? _assignedDriverPhone;

  // ── Service & Chauffeur Configuration ──
  String _rentalMode = 'both'; // 'both' | 'chauffeur_only' | 'self_drive_only'
  int? _minChauffeurHours;
  String? _fuelPolicy;

  // ── Executive & Security Options ──
  bool _isArmored = false;
  String? _armorLevel;
  bool _hasSecurityEscortOption = false;
  bool _hasDropOffOption = false;
  bool _allowsInterstate = true;

  // ── Photos State ──
  final List<String> _existingImageUrls = [];
  final List<File> _newImageFiles = [];

  // ── Progress State ──
  bool _isSaving = false;
  double _uploadProgress = 0.0;
  String _progressStatus = '';

  // ── Selected Features / Amenities ──
  final Set<String> _selectedFeatures = {};

  // ── Manual Blackout / Maintenance Dates ('YYYY-MM-DD') ──
  final Set<String> _blackoutDates = {};

  String? _error;

  // ── Feature Groups ──
  static const Map<String, List<String>> _categorizedFeatures = {
    'Executive Comfort': [
      'Leather Reclining Seats',
      'Dual-Zone Climate Control',
      'Tinted Privacy Glass',
      'Acoustic Soundproof Glass',
      'Chilled Bottled Water',
      'Ambient Cabin Lighting',
      'Sunroof / Moonroof',
    ],
    'Connectivity & Tech': [
      'High-Speed Wi-Fi',
      'USB-C Fast Charging',
      'Wireless Phone Charger',
      'Rear VIP Screens',
      'Bluetooth Audio',
      'Apple CarPlay / Android Auto',
      '220V / 12V Power Outlet',
    ],
    'Safety & Utility': [
      'GPS Live Tracking',
      '360° Surround Camera',
      'Dashcam',
      'Run-Flat Tires',
      'Child Safety Seat',
      '4x4 / All-Wheel Drive',
      'Extra Luggage Space',
    ],
  };

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;

    if (v != null) {
      // 1. Make
      if (VehicleCatalog.makes.contains(v.make)) {
        _selectedMake = v.make;
      } else if (v.make.isNotEmpty) {
        _selectedMake = 'Other';
        _customMakeController.text = v.make;
      }

      // 2. Model
      final availableModels = _selectedMake != null
          ? VehicleCatalog.getModels(_selectedMake!)
          : const <String>[];
      if (availableModels.contains(v.model)) {
        _selectedModel = v.model;
      } else if (v.model.isNotEmpty) {
        _selectedModel = 'Other';
        _customModelController.text = v.model;
      } else {
        _selectedModel = availableModels.isNotEmpty ? availableModels.first : null;
      }

      // 3. Year
      if (VehicleCatalog.validYears.contains(v.year)) {
        _selectedYear = v.year;
      }

      // 4. Color
      if (VehicleCatalog.exteriorColors.contains(v.color)) {
        _selectedColor = v.color;
      } else if (v.color.isNotEmpty) {
        _selectedColor = 'Other';
        _customColorController.text = v.color;
      }
    }

    _plateController = TextEditingController(text: v?.plateNumber ?? '');
    _descriptionController = TextEditingController(text: v?.description ?? '');

    // Rates initialize with vehicle rates or remain empty (no hardcoded arbitrary defaults)
    _selfDriveRateController = TextEditingController(
      text: v != null && v.dailySelfDriveRate > 0
          ? v.dailySelfDriveRate.toStringAsFixed(0)
          : '',
    );
    _withDriverRateController = TextEditingController(
      text: v != null && v.dailyWithDriverRate > 0
          ? v.dailyWithDriverRate.toStringAsFixed(0)
          : '',
    );
    _hourlyRateController = TextEditingController(
      text: v != null && v.hourlyChauffeurRate > 0
          ? v.hourlyChauffeurRate.toStringAsFixed(0)
          : '',
    );
    _overtimeRateController = TextEditingController(
      text: v != null && v.overtimeHourlyRate > 0
          ? v.overtimeHourlyRate.toStringAsFixed(0)
          : '',
    );
    _cautionDepositController = TextEditingController(
      text: v != null && v.cautionDeposit > 0
          ? v.cautionDeposit.toStringAsFixed(0)
          : '',
    );
    _interstateSurchargeController = TextEditingController(
      text: v != null && v.interstateDailySurcharge > 0
          ? v.interstateDailySurcharge.toStringAsFixed(0)
          : '',
    );
    _overnightAllowanceController = TextEditingController(
      text: v != null && v.driverOvernightAllowance > 0
          ? v.driverOvernightAllowance.toStringAsFixed(0)
          : '',
    );
    _securityEscortRateController = TextEditingController(
      text: v != null && v.securityEscortDailyRate > 0
          ? v.securityEscortDailyRate.toStringAsFixed(0)
          : '',
    );
    _dropOffRateController = TextEditingController(
      text: v != null && v.dropOffRate > 0
          ? v.dropOffRate.toStringAsFixed(0)
          : '',
    );

    if (v != null) {
      _selectedCategory = v.category;
      _selectedTransmission = v.transmission;
      _selectedFuelType = v.fuelType;
      _selectedSeats = v.seats;
      _selectedCity = v.city;
      _assignedDriverId = v.assignedDefaultDriverId;
      _assignedDriverName = v.assignedDefaultDriverName;
      _assignedDriverPhone = v.assignedDefaultDriverPhone;

      _rentalMode = v.rentalMode;
      _minChauffeurHours = v.minChauffeurHours;
      _fuelPolicy = v.fuelPolicy;

      _isArmored = v.isArmored;
      _armorLevel = v.armorLevel;
      _hasSecurityEscortOption = v.hasSecurityEscortOption;
      _hasDropOffOption = v.allowsDropOff;
      _allowsInterstate = v.allowsInterstate;

      _existingImageUrls.addAll(v.images);
      _selectedFeatures.addAll(v.features);
      _blackoutDates.addAll(v.blackoutDates);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _plateController.dispose();
    _descriptionController.dispose();
    _customMakeController.dispose();
    _customModelController.dispose();
    _customColorController.dispose();
    _selfDriveRateController.dispose();
    _withDriverRateController.dispose();
    _hourlyRateController.dispose();
    _overtimeRateController.dispose();
    _cautionDepositController.dispose();
    _interstateSurchargeController.dispose();
    _overnightAllowanceController.dispose();
    _securityEscortRateController.dispose();
    _dropOffRateController.dispose();
    super.dispose();
  }

  // ── Error Feedback ──

  void _showError(String message) {
    setState(() => _error = message);

    // Scroll to the top error banner for immediate visibility
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
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

  // ── Photo Handling with 10 max & 5MB validation ──

  int get _currentPhotosCount => _existingImageUrls.length + _newImageFiles.length;

  Future<void> _pickFromCamera() async {
    if (_currentPhotosCount >= _maxPhotosLimit) {
      _showError('Maximum photo limit reached (10/10). Please remove an existing photo first.');
      return;
    }

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      if (picked == null) return;

      final file = File(picked.path);
      final ext = file.path.split('.').last.toLowerCase();

      if (!_allowedExtensions.contains(ext)) {
        _showError('Unsupported file format ($ext). Only JPG and PNG image files are supported.');
        return;
      }

      final fileSize = await file.length();
      if (fileSize > _maxFileSizeBytes) {
        final sizeMb = (fileSize / (1024 * 1024)).toStringAsFixed(1);
        _showError('Photo exceeds the 5MB size limit (actual: $sizeMb MB). Please take or select a smaller photo.');
        return;
      }

      setState(() {
        _newImageFiles.add(file);
      });
    } catch (e) {
      _showError('Unable to capture photo: ${e.toString()}');
    }
  }

  Future<void> _pickFromGallery() async {
    if (_currentPhotosCount >= _maxPhotosLimit) {
      _showError('Maximum photo limit reached (10/10). Please remove an existing photo first.');
      return;
    }

    try {
      final pickedList = await _picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (pickedList.isEmpty) return;

      final initialCount = _currentPhotosCount;
      final remainingSlots = _maxPhotosLimit - initialCount;

      if (remainingSlots <= 0) {
        _showError('Maximum photo limit reached (10/10). Please remove an existing photo first.');
        return;
      }

      int addedCount = 0;
      int skippedSizeCount = 0;
      int skippedFormatCount = 0;
      int skippedLimitCount = 0;

      for (final picked in pickedList) {
        if (addedCount >= remainingSlots) {
          skippedLimitCount++;
          continue;
        }

        final file = File(picked.path);
        final ext = file.path.split('.').last.toLowerCase();

        if (!_allowedExtensions.contains(ext)) {
          skippedFormatCount++;
          continue;
        }

        final fileSize = await file.length();
        if (fileSize > _maxFileSizeBytes) {
          skippedSizeCount++;
          continue;
        }

        _newImageFiles.add(file);
        addedCount++;
      }

      setState(() {});

      if (skippedSizeCount > 0 || skippedFormatCount > 0 || skippedLimitCount > 0) {
        final List<String> reasons = [];
        if (skippedLimitCount > 0) reasons.add('$skippedLimitCount exceeded the 10-photo limit');
        if (skippedSizeCount > 0) reasons.add('$skippedSizeCount exceeded 5MB');
        if (skippedFormatCount > 0) reasons.add('$skippedFormatCount non-JPG/PNG format');

        _showError('Notice: Added $addedCount photo(s). Skipped: ${reasons.join(', ')}.');
      }
    } catch (e) {
      _showError('Unable to load gallery photos: ${e.toString()}');
    }
  }

  void _showPhotoSourceSheet() {
    if (_currentPhotosCount >= _maxPhotosLimit) {
      _showError('Maximum limit of 10 photos reached. Remove a photo to add a new one.');
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Upload Vehicle Photos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Upload up to 10 photos (JPG or PNG, max 5MB each).\nRemaining slots: ${_maxPhotosLimit - _currentPhotosCount}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: AppColors.brand),
                ),
                title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Capture new photo (JPG/PNG)', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickFromCamera();
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: AppColors.brand),
                ),
                title: const Text('Select from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Select multiple photos at once', style: TextStyle(fontSize: 12)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _pickFromGallery();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _removeExistingImage(int index) {
    setState(() => _existingImageUrls.removeAt(index));
  }

  void _removeNewImage(int index) {
    setState(() => _newImageFiles.removeAt(index));
  }

  void _setPrimaryExistingImage(int index) {
    if (index == 0) return;
    setState(() {
      final img = _existingImageUrls.removeAt(index);
      _existingImageUrls.insert(0, img);
    });
  }

  // ── Success Bottom Sheet (matches screenshot) ──

  void _showSuccessBottomSheet({required bool isEditing}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag/grab handle indicator
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 28),

              // Center Verified Scalloped Badge (CaRide Brand Emerald)
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.verified_rounded,
                    size: 64,
                    color: AppColors.brand,
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Headline "Successful"
              Text(
                'Successful',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                isEditing
                    ? 'Your vehicle details have been updated successfully.'
                    : 'Your vehicle has been added to the fleet successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryTextColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // Full-width Brand Pill Button "Done"
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(sheetCtx).pop(); // dismiss sheet
                    context.go(FleetRoutePaths.vehicles); // navigate to vehicles screen
                  },
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ── Validation & Save Flow ──

  Future<void> _save() async {
    setState(() => _error = null);

    final isChauffeur = _rentalMode != 'self_drive_only';
    final isSelfDrive = _rentalMode != 'chauffeur_only';

    // 1. Gather all missing required fields for clear feedback
    final List<String> missingFields = [];

    if (_currentPhotosCount == 0) {
      missingFields.add('Vehicle Photos (at least 1 photo)');
    }
    if (_selectedMake == null ||
        (_selectedMake == 'Other' && _customMakeController.text.trim().isEmpty)) {
      missingFields.add('Make');
    }
    if (_selectedModel == null ||
        ((_selectedModel == 'Other' || _selectedMake == 'Other') &&
            _customModelController.text.trim().isEmpty)) {
      missingFields.add('Model');
    }
    if (_selectedYear == null) {
      missingFields.add('Year');
    }
    if (_plateController.text.trim().isEmpty) {
      missingFields.add('Plate Number');
    }
    if (_selectedColor == null ||
        (_selectedColor == 'Other' && _customColorController.text.trim().isEmpty)) {
      missingFields.add('Exterior Color');
    }
    if (_selectedCategory == null) {
      missingFields.add('Vehicle Category');
    }
    if (_selectedTransmission == null) {
      missingFields.add('Transmission');
    }
    if (_selectedFuelType == null) {
      missingFields.add('Fuel Type');
    }
    if (_selectedSeats == null) {
      missingFields.add('Passenger Seats');
    }
    if (_selectedCity == null || _selectedCity!.trim().isEmpty) {
      missingFields.add('Operating State / Base');
    }

    final withDriverRate =
        double.tryParse(_withDriverRateController.text.trim()) ?? 0.0;
    final selfDriveRate =
        double.tryParse(_selfDriveRateController.text.trim()) ?? 0.0;

    if (isChauffeur) {
      if (withDriverRate <= 0) {
        missingFields.add('Daily Rate with Chauffeur');
      }
      if (_minChauffeurHours == null) {
        missingFields.add('Minimum Chauffeur Hours');
      }
      if (_fuelPolicy == null) {
        missingFields.add('Fuel Lease Policy');
      }
    }

    if (isSelfDrive && selfDriveRate <= 0) {
      missingFields.add('Daily Self-Drive Rate');
    }

    if (_isArmored && (_armorLevel == null || _armorLevel!.isEmpty)) {
      missingFields.add('Ballistic Protection Rating');
    }

    final securityEscortRate =
        double.tryParse(_securityEscortRateController.text.trim()) ?? 0.0;
    if (_hasSecurityEscortOption && securityEscortRate <= 0) {
      missingFields.add('Daily Armed Escort Fee');
    }

    final dropOffRate =
        double.tryParse(_dropOffRateController.text.trim()) ?? 0.0;
    if (_hasDropOffOption && dropOffRate <= 0) {
      missingFields.add('Drop-Off / Transfer Flat Rate');
    }

    // Trigger visual validation borders on all form & dropdown fields
    final isFormValid = _formKey.currentState!.validate();

    if (missingFields.isNotEmpty || !isFormValid) {
      if (missingFields.isNotEmpty) {
        _showError(
          'Please complete the required field(s): ${missingFields.join(', ')}.',
        );
      } else {
        _showError('Please complete all required fields correctly.');
      }
      return;
    }

    if (_currentPhotosCount > _maxPhotosLimit) {
      _showError('Too many photos. Maximum allowed is $_maxPhotosLimit photos.');
      return;
    }

    final v = widget.vehicle;
    final isEditing = v != null;
    final vehicleId = v?.id.isNotEmpty == true
        ? v!.id
        : 'veh_${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _isSaving = true;
      _uploadProgress = 0.05;
      _progressStatus = 'Preparing vehicle record...';
    });

    try {
      final effectiveMake = _selectedMake == 'Other'
          ? _customMakeController.text.trim()
          : _selectedMake;
      final effectiveModel = (_selectedModel == 'Other' || _selectedMake == 'Other')
          ? _customModelController.text.trim()
          : _selectedModel;
      final effectiveColor = _selectedColor == 'Other'
          ? _customColorController.text.trim()
          : _selectedColor;

      final hourly = double.tryParse(_hourlyRateController.text.trim()) ?? 0.0;
      final overtime = double.tryParse(_overtimeRateController.text.trim()) ?? 0.0;
      final caution = double.tryParse(_cautionDepositController.text.trim()) ?? 0.0;
      final interstateSurcharge = double.tryParse(_interstateSurchargeController.text.trim()) ?? 0.0;
      final overnightAllowance = double.tryParse(_overnightAllowanceController.text.trim()) ?? 0.0;

      // ── Upload New Photos to Firebase Storage with Progress ──
      final uploadedUrls = List<String>.from(_existingImageUrls);
      if (_newImageFiles.isNotEmpty) {
        final totalToUpload = _newImageFiles.length;
        for (int i = 0; i < totalToUpload; i++) {
          final file = _newImageFiles[i];
          final photoNumber = i + 1;
          setState(() {
            _progressStatus = 'Uploading photo $photoNumber of $totalToUpload...';
            _uploadProgress = 0.1 + (0.75 * (photoNumber / totalToUpload));
          });

          final photoId = 'photo_${DateTime.now().millisecondsSinceEpoch}_$i';
          final url = await fleetManagerController.uploadVehiclePhoto(
            vehicleId: vehicleId,
            file: file,
            photoId: photoId,
          );
          uploadedUrls.add(url);
        }
      }

      setState(() {
        _progressStatus = 'Finalizing vehicle details...';
        _uploadProgress = 0.95;
      });

      final toSave = RentalVehicle(
        id: v?.id ?? '',
        fleetId: v?.fleetId ?? '',
        ownerUid: v?.ownerUid ?? '',
        make: effectiveMake ?? '',
        model: effectiveModel ?? '',
        year: _selectedYear ?? DateTime.now().year,
        category: _selectedCategory ?? RentalVehicleCategory.sedan,
        transmission: _selectedTransmission ?? 'Automatic',
        fuelType: _selectedFuelType ?? 'Petrol',
        seats: _selectedSeats ?? 4,
        plateNumber: _plateController.text.trim().toUpperCase(),
        color: effectiveColor ?? '',
        city: _selectedCity ?? 'Abuja',
        description: _descriptionController.text.trim(),
        images: uploadedUrls,
        dailySelfDriveRate: isSelfDrive ? selfDriveRate : 0.0,
        dailyWithDriverRate: isChauffeur ? withDriverRate : 0.0,
        hourlyChauffeurRate: hourly,
        overtimeHourlyRate: overtime,
        cautionDeposit: isSelfDrive ? caution : 0.0,
        hasDropOffOption: _hasDropOffOption,
        dropOffRate: _hasDropOffOption ? dropOffRate : 0.0,
        rentalMode: _rentalMode,
        minChauffeurHours: _minChauffeurHours ?? 3,
        fuelPolicy: _fuelPolicy ?? 'dry_lease',
        isArmored: _isArmored,
        armorLevel: _isArmored ? _armorLevel : null,
        hasSecurityEscortOption: _hasSecurityEscortOption,
        securityEscortDailyRate: _hasSecurityEscortOption ? securityEscortRate : 0.0,
        allowsInterstate: _allowsInterstate,
        interstateDailySurcharge: _allowsInterstate ? interstateSurcharge : 0.0,
        driverOvernightAllowance: _allowsInterstate ? overnightAllowance : 0.0,
        features: _selectedFeatures.toList(),
        blackoutDates: _blackoutDates.toList(),
        status: v?.status ?? RentalVehicleStatus.available,
        assignedDefaultDriverId: _assignedDriverId,
        assignedDefaultDriverName: _assignedDriverName,
        assignedDefaultDriverPhone: _assignedDriverPhone,
        createdAt: v?.createdAt,
      );

      await fleetManagerController.saveVehicle(toSave);

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _uploadProgress = 1.0;
      });

      // Present the brand-aligned success bottom sheet and route to vehicles screen
      _showSuccessBottomSheet(isEditing: isEditing);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      String friendlyMsg = 'Failed to save vehicle: ${e.toString()}';
      if (e.toString().contains('network') || e.toString().contains('SocketException')) {
        friendlyMsg = 'Network connection failure. Please verify your internet connection and try again.';
      } else if (e.toString().contains('permission-denied') || e.toString().contains('PERMISSION_DENIED')) {
        friendlyMsg = 'Upload permission denied. Please verify your account privileges.';
      } else if (e.toString().contains('storage/canceled')) {
        friendlyMsg = 'Photo upload was interrupted. Please try again.';
      }

      _showError(friendlyMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.vehicle != null;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final inputFill = isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6);
    final cardBgColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    final operatingStates = fleetManagerController.currentProfile?.operatingStates ?? [];
    final availableCities = operatingStates.isNotEmpty
        ? operatingStates
        : const ['Abuja', 'Lagos', 'Rivers', 'Kano', 'Oyo', 'Enugu', 'Delta'];

    final drivers = fleetManagerController.drivers;

    final isChauffeurAllowed = _rentalMode != 'self_drive_only';
    final isSelfDriveAllowed = _rentalMode != 'chauffeur_only';

    return Stack(
      children: [
        Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
          body: SafeArea(
            child: Column(
              children: [
                // ── Top Navigation Bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor),
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: primaryTextColor,
                          ),
                          onPressed: () {
                            if (_isSaving) return;
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isEditing ? 'Edit Vehicle' : 'Add Rental Vehicle',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Scrollable Form Body ──
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Immediate In-View Error Feedback Banner (AGENTS.md)
                          if (_error != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF3F1D1D) : const Color(0xFFFEF2F2),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.error),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
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
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _error!,
                                          style: TextStyle(
                                            color: isDark ? Colors.white70 : const Color(0xFF991B1B),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                                    onPressed: () => setState(() => _error = null),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],

                          // ── SECTION 1: Vehicle Photo Upload (Max 10, 5MB, JPG/PNG) ──
                          _buildSectionCard(
                            title: 'Vehicle Photos',
                            subtitle: 'Upload clear photos (JPG or PNG only, max 5MB each). First image is cover.',
                            icon: Icons.photo_camera_rounded,
                            isRequired: true,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildPhotoGallery(borderColor, isDark),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.brand),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Allowed: JPG, PNG • Max size: 5MB per file • Max 10 photos.',
                                        style: TextStyle(fontSize: 11, color: secondaryTextColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── SECTION 2: Vehicle Identity & Specs ──
                          _buildSectionCard(
                            title: 'Vehicle Specifications',
                            subtitle: 'Make, model, year, and mechanical configuration.',
                            icon: Icons.directions_car_rounded,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDropdownField<String>(
                                        label: 'Make',
                                        value: _selectedMake,
                                        hintText: 'Select Make',
                                        isRequired: true,
                                        validator: (v) => v == null || v.isEmpty ? 'Make is required' : null,
                                        items: VehicleCatalog.makes.map((m) {
                                          return DropdownMenuItem(value: m, child: Text(m));
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _selectedMake = val;
                                              _selectedModel = null;
                                            });
                                          }
                                        },
                                        inputFill: inputFill,
                                        primaryTextColor: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDropdownField<String>(
                                        key: ValueKey('model_${_selectedMake}_$_selectedModel'),
                                        label: 'Model',
                                        value: _selectedModel,
                                        hintText: _selectedMake == null ? 'Select Make first' : 'Select Model',
                                        isRequired: true,
                                        validator: (v) => v == null || v.isEmpty ? 'Model is required' : null,
                                        items: _selectedMake == null
                                            ? const []
                                            : VehicleCatalog.getModels(_selectedMake!).map((m) {
                                                return DropdownMenuItem(value: m, child: Text(m));
                                              }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() => _selectedModel = val);
                                          }
                                        },
                                        inputFill: inputFill,
                                        primaryTextColor: primaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_selectedMake == 'Other' || _selectedModel == 'Other') ...[
                                  const SizedBox(height: 12),
                                  if (_selectedMake == 'Other') ...[
                                    _buildFormField(
                                      label: 'Custom Make',
                                      hint: 'Specify vehicle manufacturer',
                                      controller: _customMakeController,
                                      isRequired: true,
                                      inputFill: inputFill,
                                      primaryTextColor: primaryTextColor,
                                      validator: (v) {
                                        if (_selectedMake == 'Other' && (v == null || v.trim().isEmpty)) {
                                          return 'Please enter the vehicle make';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  if (_selectedModel == 'Other' || _selectedMake == 'Other') ...[
                                    _buildFormField(
                                      label: 'Custom Model',
                                      hint: 'Specify vehicle model',
                                      controller: _customModelController,
                                      isRequired: true,
                                      inputFill: inputFill,
                                      primaryTextColor: primaryTextColor,
                                      validator: (v) {
                                        if ((_selectedModel == 'Other' || _selectedMake == 'Other') &&
                                            (v == null || v.trim().isEmpty)) {
                                          return 'Please enter the vehicle model';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ],
                                const SizedBox(height: 14),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDropdownField<int>(
                                        label: 'Year',
                                        value: _selectedYear,
                                        hintText: 'Select Year',
                                        isRequired: true,
                                        validator: (v) => v == null ? 'Year is required' : null,
                                        items: VehicleCatalog.validYears.map((y) {
                                          return DropdownMenuItem(value: y, child: Text('$y'));
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() => _selectedYear = val);
                                          }
                                        },
                                        inputFill: inputFill,
                                        primaryTextColor: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildFormField(
                                        label: 'Plate Number',
                                        hint: 'e.g. ABC-123XY',
                                        controller: _plateController,
                                        isRequired: true,
                                        inputFill: inputFill,
                                        primaryTextColor: primaryTextColor,
                                        validator: (v) => v == null || v.trim().isEmpty ? 'Plate is required' : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDropdownField<String>(
                                        label: 'Exterior Color',
                                        value: _selectedColor,
                                        hintText: 'Select Exterior Color',
                                        isRequired: true,
                                        validator: (v) => v == null || v.isEmpty ? 'Color is required' : null,
                                        items: VehicleCatalog.exteriorColors.map((c) {
                                          return DropdownMenuItem(value: c, child: Text(c));
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() => _selectedColor = val);
                                          }
                                        },
                                        inputFill: inputFill,
                                        primaryTextColor: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDropdownField<RentalVehicleCategory>(
                                        label: 'Vehicle Category',
                                        value: _selectedCategory,
                                        hintText: 'Select Category',
                                        isRequired: true,
                                        validator: (v) => v == null ? 'Category is required' : null,
                                        items: RentalVehicleCategory.values.map((cat) {
                                          return DropdownMenuItem(value: cat, child: Text(cat.label));
                                        }).toList(),
                                        onChanged: (cat) {
                                          if (cat != null) setState(() => _selectedCategory = cat);
                                        },
                                        inputFill: inputFill,
                                        primaryTextColor: primaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_selectedColor == 'Other') ...[
                                  const SizedBox(height: 12),
                                  _buildFormField(
                                    label: 'Custom Exterior Color',
                                    hint: 'e.g. Matte Olive, Midnight Purple',
                                    controller: _customColorController,
                                    isRequired: true,
                                    inputFill: inputFill,
                                    primaryTextColor: primaryTextColor,
                                    validator: (v) {
                                      if (_selectedColor == 'Other' && (v == null || v.trim().isEmpty)) {
                                        return 'Please specify the exterior color';
                                      }
                                      return null;
                                    },
                                  ),
                                ],
                                const SizedBox(height: 14),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDropdownField<String>(
                                        label: 'Transmission',
                                        value: _selectedTransmission,
                                        hintText: 'Select Transmission',
                                        isRequired: true,
                                        validator: (v) => v == null || v.isEmpty ? 'Transmission is required' : null,
                                        items: const [
                                          DropdownMenuItem(value: 'Automatic', child: Text('Automatic')),
                                          DropdownMenuItem(value: 'Manual', child: Text('Manual')),
                                        ],
                                        onChanged: (v) {
                                          if (v != null) setState(() => _selectedTransmission = v);
                                        },
                                        inputFill: inputFill,
                                        primaryTextColor: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDropdownField<String>(
                                        label: 'Fuel Type',
                                        value: _selectedFuelType,
                                        hintText: 'Select Fuel Type',
                                        isRequired: true,
                                        validator: (v) => v == null || v.isEmpty ? 'Fuel type is required' : null,
                                        items: const [
                                          DropdownMenuItem(value: 'Petrol', child: Text('Petrol')),
                                          DropdownMenuItem(value: 'Diesel', child: Text('Diesel')),
                                          DropdownMenuItem(value: 'Hybrid', child: Text('Hybrid')),
                                          DropdownMenuItem(value: 'Electric', child: Text('Electric')),
                                        ],
                                        onChanged: (v) {
                                          if (v != null) setState(() => _selectedFuelType = v);
                                        },
                                        inputFill: inputFill,
                                        primaryTextColor: primaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),

                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDropdownField<int>(
                                        label: 'Passenger Seats',
                                        value: _selectedSeats,
                                        hintText: 'Select Seats',
                                        isRequired: true,
                                        validator: (v) => v == null ? 'Seats is required' : null,
                                        items: [2, 4, 5, 7, 8, 12, 15].map((s) {
                                          return DropdownMenuItem(value: s, child: Text('$s Passengers'));
                                        }).toList(),
                                        onChanged: (v) {
                                          if (v != null) setState(() => _selectedSeats = v);
                                        },
                                        inputFill: inputFill,
                                        primaryTextColor: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDropdownField<String>(
                                        label: 'Operating State / Base',
                                        value: _selectedCity,
                                        hintText: 'Select Operating State',
                                        isRequired: true,
                                        validator: (v) => v == null || v.isEmpty ? 'State is required' : null,
                                        items: availableCities.map((city) {
                                          return DropdownMenuItem(value: city, child: Text(city));
                                        }).toList(),
                                        onChanged: (v) {
                                          if (v != null) setState(() => _selectedCity = v);
                                        },
                                        inputFill: inputFill,
                                        primaryTextColor: primaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── SECTION 3: Vehicle Description & Highlights ──
                          _buildSectionCard(
                            title: 'Vehicle Description',
                            subtitle: 'Overview, condition, amenities, or special notes for prospective renters.',
                            icon: Icons.notes_rounded,
                            isRequired: false,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFormField(
                                  label: 'About this Vehicle',
                                  hint: 'Describe your vehicle (e.g. Pristine condition, executive leather interior, panoramic glass roof, whisper-quiet cabin, perfect for airport transfers, VIP escorts, and long-distance travel)...',
                                  controller: _descriptionController,
                                  maxLines: 4,
                                  minLines: 3,
                                  keyboardType: TextInputType.multiline,
                                  inputFill: inputFill,
                                  primaryTextColor: primaryTextColor,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.brand),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'A well-detailed description attracts up to 40% more rental bookings.',
                                        style: TextStyle(fontSize: 11, color: secondaryTextColor),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── SECTION 4: Service Mode & Chauffeur Settings ──
                          _buildSectionCard(
                            title: 'Service & Rental Mode',
                            subtitle: 'Select whether this vehicle is chauffeur-only or available for self-drive.',
                            icon: Icons.badge_outlined,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Offered Rental Mode',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _buildModeChip('both', 'Both (Chauffeur & Self-Drive)'),
                                    _buildModeChip('chauffeur_only', 'Chauffeur Only (With Driver)'),
                                    _buildModeChip('self_drive_only', 'Self-Drive Only'),
                                  ],
                                ),
                                const SizedBox(height: 18),

                                if (isChauffeurAllowed) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildDropdownField<int>(
                                          label: 'Minimum Chauffeur Hours',
                                          value: _minChauffeurHours,
                                          hintText: 'Select Minimum Hours',
                                          isRequired: isChauffeurAllowed,
                                          validator: (v) =>
                                              isChauffeurAllowed && v == null
                                                  ? 'Minimum hours required'
                                                  : null,
                                          items: const [
                                            DropdownMenuItem(value: 2, child: Text('2 Hours minimum')),
                                            DropdownMenuItem(value: 3, child: Text('3 Hours minimum')),
                                            DropdownMenuItem(value: 4, child: Text('4 Hours (Half Day)')),
                                            DropdownMenuItem(value: 8, child: Text('8 Hours (Business Day)')),
                                            DropdownMenuItem(value: 12, child: Text('12 Hours (Full Day)')),
                                          ],
                                          onChanged: (v) {
                                            if (v != null) setState(() => _minChauffeurHours = v);
                                          },
                                          inputFill: inputFill,
                                          primaryTextColor: primaryTextColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildDropdownField<String>(
                                          label: 'Fuel Lease Policy',
                                          value: _fuelPolicy,
                                          hintText: 'Select Fuel Lease Policy',
                                          isRequired: isChauffeurAllowed,
                                          validator: (v) =>
                                              isChauffeurAllowed && (v == null || v.isEmpty)
                                                  ? 'Fuel policy required'
                                                  : null,
                                          items: const [
                                            DropdownMenuItem(
                                              value: 'dry_lease',
                                              child: Text('Dry Lease (Renter Refuels)'),
                                            ),
                                            DropdownMenuItem(
                                              value: 'wet_lease',
                                              child: Text('Wet Lease (Fuel Included)'),
                                            ),
                                          ],
                                          onChanged: (v) {
                                            if (v != null) setState(() => _fuelPolicy = v);
                                          },
                                          inputFill: inputFill,
                                          primaryTextColor: primaryTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── SECTION 4: Pricing & Security Deposit ──
                          _buildSectionCard(
                            title: 'Pricing & Tariffs (NGN)',
                            subtitle: 'Transparent rental and chauffeur rates in Nigerian Naira (₦).',
                            icon: Icons.payments_outlined,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            child: Column(
                              children: [
                                if (isChauffeurAllowed) ...[
                                  _buildFormField(
                                    label: 'Daily Rate with Professional Chauffeur (₦/day)',
                                    hint: 'e.g. 75,000',
                                    controller: _withDriverRateController,
                                    keyboardType: TextInputType.number,
                                    prefixText: '₦ ',
                                    isRequired: isChauffeurAllowed,
                                    inputFill: inputFill,
                                    primaryTextColor: primaryTextColor,
                                    validator: (v) {
                                      if (isChauffeurAllowed) {
                                        final val = double.tryParse(v ?? '');
                                        if (val == null || val <= 0) return 'Please enter a valid daily chauffeur rate';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildFormField(
                                          label: 'Hourly Chauffeur Rate',
                                          hint: 'e.g. 10,000',
                                          controller: _hourlyRateController,
                                          keyboardType: TextInputType.number,
                                          prefixText: '₦ ',
                                          inputFill: inputFill,
                                          primaryTextColor: primaryTextColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildFormField(
                                          label: 'Overtime Rate / Hour',
                                          hint: 'e.g. 8,000',
                                          controller: _overtimeRateController,
                                          keyboardType: TextInputType.number,
                                          prefixText: '₦ ',
                                          inputFill: inputFill,
                                          primaryTextColor: primaryTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                if (isSelfDriveAllowed) ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildFormField(
                                          label: 'Daily Self-Drive Rate',
                                          hint: 'e.g. 45,000',
                                          controller: _selfDriveRateController,
                                          keyboardType: TextInputType.number,
                                          prefixText: '₦ ',
                                          isRequired: isSelfDriveAllowed,
                                          inputFill: inputFill,
                                          primaryTextColor: primaryTextColor,
                                          validator: (v) {
                                            if (isSelfDriveAllowed) {
                                              final val = double.tryParse(v ?? '');
                                              if (val == null || val <= 0) return 'Please enter a valid daily self-drive rate';
                                            }
                                            return null;
                                          },
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildFormField(
                                          label: 'Caution / Refundable Deposit',
                                          hint: 'e.g. 50,000',
                                          controller: _cautionDepositController,
                                          keyboardType: TextInputType.number,
                                          prefixText: '₦ ',
                                          inputFill: inputFill,
                                          primaryTextColor: primaryTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],

                                const SizedBox(height: 14),
                                Divider(
                                  height: 1,
                                  color: borderColor,
                                ),
                                const SizedBox(height: 14),

                                // Airport & Point-to-Point Drop-Off / Transfer
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  activeThumbColor: AppColors.brand,
                                  activeTrackColor: AppColors.brand.withValues(alpha: 0.35),
                                  title: Text(
                                    'Airport & City Drop-Off / Transfer',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Offer one-way flat-rate rides (e.g. airport pickup to home/hotel)',
                                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                                  ),
                                  value: _hasDropOffOption,
                                  onChanged: (val) => setState(() => _hasDropOffOption = val),
                                ),

                                if (_hasDropOffOption) ...[
                                  const SizedBox(height: 8),
                                  _buildFormField(
                                    label: 'Drop-Off / Transfer Flat Rate (₦/trip)',
                                    hint: 'e.g. 25,000',
                                    controller: _dropOffRateController,
                                    keyboardType: TextInputType.number,
                                    prefixText: '₦ ',
                                    isRequired: _hasDropOffOption,
                                    inputFill: inputFill,
                                    primaryTextColor: primaryTextColor,
                                    validator: (v) {
                                      if (_hasDropOffOption) {
                                        final val = double.tryParse(v ?? '');
                                        if (val == null || val <= 0) return 'Please enter a valid drop-off transfer rate';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.brand.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.brand.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.flight_land_rounded,
                                          size: 18,
                                          color: AppColors.brand,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'Customers can book this vehicle for one-way rides (like an airport transfer to their home) at this transparent flat price.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: secondaryTextColor,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── SECTION: Schedule & Maintenance Blackout Dates ──
                          _buildSectionCard(
                            title: 'Schedule & Maintenance Blackout Dates',
                            subtitle:
                                'View customer bookings and tap any available date to block it for servicing or personal use.',
                            icon: Icons.calendar_month_rounded,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B)
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFFF59E0B)
                                          .withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.build_circle_outlined,
                                        size: 18,
                                        color: Color(0xFFF59E0B),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Tap any future date below to toggle it as Maintenance (Amber). Blocked dates will be closed to customer bookings. Existing customer reservations are shown in Green.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: secondaryTextColor,
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Builder(
                                  builder: (ctx) {
                                    final vehicleId = widget.vehicle?.id ?? '';
                                    final bookings = vehicleId.isNotEmpty
                                        ? fleetManagerController
                                            .getActiveBookingsForVehicle(vehicleId)
                                        : const <RentalBooking>[];
                                    return VehicleBookingCalendar(
                                      bookings: bookings,
                                      blackoutDates: _blackoutDates.toList(),
                                      isManagerMode: true,
                                      onDateTapped: (date) {
                                        final now = DateTime.now();
                                        final today =
                                            DateTime(now.year, now.month, now.day);
                                        if (date.isBefore(today)) return;

                                        // Check if already booked by customer
                                        final isBooked = bookings.any((b) {
                                          if (b.status ==
                                                  RentalBookingStatus.cancelled ||
                                              b.status ==
                                                  RentalBookingStatus.rejected ||
                                              b.status ==
                                                  RentalBookingStatus.completed) {
                                            return false;
                                          }
                                          final s = DateTime(b.startDate.year,
                                              b.startDate.month, b.startDate.day);
                                          final e = DateTime(b.endDate.year,
                                              b.endDate.month, b.endDate.day);
                                          final target = DateTime(
                                              date.year, date.month, date.day);
                                          return !target.isBefore(s) &&
                                              !target.isAfter(e);
                                        });

                                        if (isBooked) {
                                          _showError(
                                              'This date is already booked by a customer and cannot be blocked for maintenance.');
                                          return;
                                        }

                                        final iso =
                                            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                                        setState(() {
                                          if (_blackoutDates.contains(iso)) {
                                            _blackoutDates.remove(iso);
                                          } else {
                                            _blackoutDates.add(iso);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                                if (_blackoutDates.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${_blackoutDates.length} date(s) marked for maintenance',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFF59E0B),
                                        ),
                                      ),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed: () =>
                                            setState(() => _blackoutDates.clear()),
                                        child: const Text(
                                          'Clear All',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── SECTION 5: Executive & VIP Security Mobility ──
                          _buildSectionCard(
                            title: 'Executive Protection & Inter-State Options',
                            subtitle: 'High-security options, armored certification, and travel allowances.',
                            icon: Icons.shield_outlined,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            child: Column(
                              children: [
                                // Armored / Bulletproof Toggle
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  activeThumbColor: AppColors.brand,
                                  activeTrackColor: AppColors.brand.withValues(alpha: 0.35),
                                  title: Text(
                                    'Armored / Bulletproof Vehicle',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Certified ballistic glass & body armor protection',
                                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                                  ),
                                  value: _isArmored,
                                  onChanged: (val) => setState(() => _isArmored = val),
                                ),

                                if (_isArmored) ...[
                                  const SizedBox(height: 8),
                                  _buildDropdownField<String>(
                                    label: 'Ballistic Protection Rating',
                                    value: _armorLevel,
                                    hintText: 'Select Ballistic Protection Rating',
                                    isRequired: _isArmored,
                                    validator: (v) =>
                                        _isArmored && (v == null || v.isEmpty)
                                            ? 'Protection rating is required'
                                            : null,
                                    items: const [
                                      DropdownMenuItem(value: 'B4', child: Text('B4 (Handgun / Small Arms Protection)')),
                                      DropdownMenuItem(value: 'B6', child: Text('B6 (High-Powered Rifle / AK-47 Protection)')),
                                      DropdownMenuItem(value: 'B7', child: Text('B7 (Military Grade / Armor-Piercing Protection)')),
                                    ],
                                    onChanged: (v) {
                                      if (v != null) setState(() => _armorLevel = v);
                                    },
                                    inputFill: inputFill,
                                    primaryTextColor: primaryTextColor,
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.brand.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: AppColors.brand.withValues(alpha: 0.25),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.shield_outlined,
                                          size: 18,
                                          color: AppColors.brand,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'The daily rental rates entered under Rental Rates & Pricing represent the armored rental fee for this vehicle.',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: secondaryTextColor,
                                              height: 1.35,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                const Divider(height: 24),

                                // Armed Security Escort Option
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  activeThumbColor: AppColors.brand,
                                  activeTrackColor: AppColors.brand.withValues(alpha: 0.35),
                                  title: Text(
                                    'Armed Security Escort Available',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Fleet can provide armed MOPOL / police chase escort on request',
                                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                                  ),
                                  value: _hasSecurityEscortOption,
                                  onChanged: (val) => setState(() => _hasSecurityEscortOption = val),
                                ),

                                if (_hasSecurityEscortOption) ...[
                                  const SizedBox(height: 10),
                                  _buildFormField(
                                    label: 'Daily Armed Escort Fee',
                                    hint: 'e.g. 75,000',
                                    controller: _securityEscortRateController,
                                    keyboardType: TextInputType.number,
                                    prefixText: '₦ ',
                                    isRequired: _hasSecurityEscortOption,
                                    inputFill: inputFill,
                                    primaryTextColor: primaryTextColor,
                                    validator: (v) {
                                      if (_hasSecurityEscortOption && (v == null || v.trim().isEmpty)) {
                                        return 'Daily escort fee is required';
                                      }
                                      final fee = double.tryParse(v ?? '');
                                      if (_hasSecurityEscortOption && (fee == null || fee <= 0)) {
                                        return 'Please enter a valid amount';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 14),
                                ],

                                const Divider(height: 24),

                                // Inter-State Travel Option
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  activeThumbColor: AppColors.brand,
                                  activeTrackColor: AppColors.brand.withValues(alpha: 0.35),
                                  title: Text(
                                    'Inter-State Travel Allowed',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Client may take this vehicle across state borders',
                                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                                  ),
                                  value: _allowsInterstate,
                                  onChanged: (val) => setState(() => _allowsInterstate = val),
                                ),

                                if (_allowsInterstate) ...[
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildFormField(
                                          label: 'Inter-State Daily Surcharge',
                                          hint: 'e.g. 25,000',
                                          controller: _interstateSurchargeController,
                                          keyboardType: TextInputType.number,
                                          prefixText: '₦ ',
                                          inputFill: inputFill,
                                          primaryTextColor: primaryTextColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _buildFormField(
                                          label: 'Driver Overnight Lodging',
                                          hint: 'e.g. 15,000',
                                          controller: _overnightAllowanceController,
                                          keyboardType: TextInputType.number,
                                          prefixText: '₦ ',
                                          inputFill: inputFill,
                                          primaryTextColor: primaryTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── SECTION 6: Categorized Executive Amenities ──
                          _buildSectionCard(
                            title: 'Executive Amenities & In-Cabin Comfort',
                            subtitle: 'Select all features provided in this vehicle.',
                            icon: Icons.stars_rounded,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _categorizedFeatures.entries.map((entry) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: entry.value.map((feat) {
                                          final isSelected = _selectedFeatures.contains(feat);
                                          return FilterChip(
                                            label: Text(feat),
                                            selected: isSelected,
                                            onSelected: (selected) {
                                              setState(() {
                                                if (selected) {
                                                  _selectedFeatures.add(feat);
                                                } else {
                                                  _selectedFeatures.remove(feat);
                                                }
                                              });
                                            },
                                            backgroundColor: inputFill,
                                            selectedColor: AppColors.brand,
                                            labelStyle: TextStyle(
                                              color: isSelected ? Colors.white : primaryTextColor,
                                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                              fontSize: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                              side: BorderSide(
                                                color: isSelected ? AppColors.brand : borderColor,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── SECTION 7: Driver Assignment ──
                          _buildSectionCard(
                            title: 'Default Driver Assignment',
                            subtitle: 'Assign a dedicated chauffeur from your verified fleet roster.',
                            icon: Icons.person_pin_circle_outlined,
                            cardBgColor: cardBgColor,
                            borderColor: borderColor,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            child: _buildDropdownField<String?>(
                              label: 'Assigned Driver',
                              value: _assignedDriverId,
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Unassigned (Pool Vehicle)'),
                                ),
                                ...drivers.map((d) {
                                  return DropdownMenuItem<String?>(
                                    value: d.id,
                                    child: Text('${d.fullName} (${d.phone})'),
                                  );
                                }),
                              ],
                              onChanged: (id) {
                                setState(() {
                                  _assignedDriverId = id;
                                  if (id == null) {
                                    _assignedDriverName = null;
                                  } else {
                                    final d = drivers.firstWhere((x) => x.id == id);
                                    _assignedDriverName = d.fullName;
                                  }
                                });
                              },
                              inputFill: inputFill,
                              primaryTextColor: primaryTextColor,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Submit Action (Green Pill Button) ──
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_outline_rounded, size: 22),
                              label: Text(
                                _isSaving
                                    ? 'Saving Vehicle...'
                                    : (isEditing ? 'Save Changes' : 'Add Vehicle to Fleet'),
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              onPressed: _isSaving ? null : _save,
                            ),
                          ),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Full-Screen Upload Progress Animation Overlay ──
        if (_isSaving)
          Positioned.fill(
            child: PopScope(
              canPop: false,
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
                child: Center(
                  child: Container(
                    width: 290,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Animated Brand Upload Icon
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 34,
                              height: 34,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                color: AppColors.brand,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        Text(
                          isEditing ? 'Updating Vehicle' : 'Adding to Fleet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          _progressStatus.isNotEmpty ? _progressStatus : 'Please wait while uploading...',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryTextColor,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 18),

                        // Linear animated progress bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _uploadProgress,
                            minHeight: 6,
                            color: AppColors.brand,
                            backgroundColor: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                          ),
                        ),
                        const SizedBox(height: 10),

                        Text(
                          '${(_uploadProgress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── Helper Widgets ──

  Widget _buildModeChip(String mode, String label) {
    final isSelected = _rentalMode == mode;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _rentalMode = mode);
      },
      selectedColor: AppColors.brand,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkSurface
          : const Color(0xFFF3F4F6),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black),
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? AppColors.brand
              : (Theme.of(context).brightness == Brightness.dark
                  ? AppColors.glassBorderDark
                  : const Color(0xFFE5E7EB)),
        ),
      ),
    );
  }

  Widget _buildPhotoGallery(Color borderColor, bool isDark) {
    final canAddMore = _currentPhotosCount < _maxPhotosLimit;

    return SizedBox(
      height: 110,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // "Add Photo" Button Card
          GestureDetector(
            onTap: canAddMore ? _showPhotoSourceSheet : () => _showError('Maximum limit of $_maxPhotosLimit photos reached.'),
            child: Container(
              width: 100,
              height: 100,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: canAddMore ? AppColors.brand : Colors.grey.shade400,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (canAddMore ? AppColors.brand : Colors.grey).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_a_photo_outlined,
                      color: canAddMore ? AppColors.brand : Colors.grey,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    canAddMore ? 'Add Photo' : 'Max Photos',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: canAddMore ? AppColors.brand : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Existing Images from URL
          ...List.generate(_existingImageUrls.length, (idx) {
            final url = _existingImageUrls[idx];
            final isPrimary = idx == 0;
            return Stack(
              children: [
                GestureDetector(
                  onTap: () => _setPrimaryExistingImage(idx),
                  child: Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isPrimary ? AppColors.brand : borderColor,
                        width: isPrimary ? 2 : 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),
                if (isPrimary)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'COVER',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                Positioned(
                  top: 4,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => _removeExistingImage(idx),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          }),

          // Newly Picked Local Files
          ...List.generate(_newImageFiles.length, (idx) {
            final file = _newImageFiles[idx];
            final isPrimary = _existingImageUrls.isEmpty && idx == 0;
            return Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isPrimary ? AppColors.brand : borderColor,
                      width: isPrimary ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(file, fit: BoxFit.cover),
                  ),
                ),
                if (isPrimary)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.brand,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'COVER',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                Positioned(
                  top: 4,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => _removeNewImage(idx),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    required Color cardBgColor,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    bool isRequired = false,
  }) {
    return Material(
      color: cardBgColor,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppColors.brand, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                          if (isRequired) ...[
                            const SizedBox(width: 5),
                            const Icon(Icons.emergency, size: 9, color: AppColors.error),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required Color inputFill,
    required Color primaryTextColor,
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    int? minLines,
    String? prefixText,
    String? Function(String?)? validator,
  }) {
    final borderRadius = BorderRadius.circular(maxLines > 1 ? 18 : 28);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.emergency,
                size: 8,
                color: AppColors.error,
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          minLines: minLines,
          style: TextStyle(color: primaryTextColor, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
            prefixText: prefixText,
            prefixStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.brand),
            filled: true,
            fillColor: inputFill,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 18,
              vertical: maxLines > 1 ? 16 : 15,
            ),
            border: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: borderRadius,
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdownField<T>({
    Key? key,
    required String label,
    T? value,
    String? hintText,
    bool isRequired = false,
    String? Function(T?)? validator,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required Color inputFill,
    required Color primaryTextColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Icon(
                Icons.emergency,
                size: 8,
                color: AppColors.error,
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          key: key ?? ValueKey(value),
          initialValue: value,
          hint: hintText != null
              ? Text(
                  hintText,
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                )
              : null,
          items: items,
          onChanged: onChanged,
          validator: validator,
          isExpanded: true,
          style: TextStyle(color: primaryTextColor, fontSize: 14),
          dropdownColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurface
              : Colors.white,
          decoration: InputDecoration(
            filled: true,
            fillColor: inputFill,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: const BorderSide(color: AppColors.error, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
