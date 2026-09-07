import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';
import '../../controllers/fleet_manager_controller.dart';

/// Redesigned Add/Edit Rental Vehicle Screen matching the CaRide design-system.md standards.
class AddEditVehicleScreen extends StatefulWidget {
  const AddEditVehicleScreen({super.key, this.vehicle});

  final RentalVehicle? vehicle;

  @override
  State<AddEditVehicleScreen> createState() => _AddEditVehicleScreenState();
}

class _AddEditVehicleScreenState extends State<AddEditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _makeController;
  late final TextEditingController _modelController;
  late final TextEditingController _yearController;
  late final TextEditingController _plateController;
  late final TextEditingController _colorController;
  late final TextEditingController _imageUrlController;
  late final TextEditingController _selfDriveRateController;
  late final TextEditingController _withDriverRateController;
  late final TextEditingController _hourlyRateController;
  late final TextEditingController _cautionDepositController;

  RentalVehicleCategory _selectedCategory = RentalVehicleCategory.sedan;
  String _selectedTransmission = 'Automatic';
  String _selectedFuelType = 'Petrol';
  int _selectedSeats = 5;
  String _selectedCity = 'Abuja';
  String? _assignedDriverId;
  String? _assignedDriverName;

  final Set<String> _selectedFeatures = {
    'Air Conditioning',
    'Bluetooth Audio',
    'Leather Seats',
  };

  bool _isSaving = false;
  String? _error;

  static const Color _lightInputFill = Color(0xFFF3F4F6);
  static const Color _labelColor = Color(0xFF1F2937);
  static const Color _hintColor = Color(0xFF9CA3AF);

  static const _availableFeatures = [
    'Air Conditioning',
    'Bluetooth Audio',
    'Leather Seats',
    'Sunroof',
    'Tinted Windows',
    'GPS Navigation',
    'Backup Camera',
    'USB Fast Charging',
    'Child Safety Seat',
    '4x4 / AWD',
  ];

  static const _sampleCarImages = [
    'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?w=800',
    'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=800',
    'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=800',
    'https://images.unsplash.com/photo-1563720223185-11003d516935?w=800',
  ];

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle;

    _makeController = TextEditingController(text: v?.make ?? '');
    _modelController = TextEditingController(text: v?.model ?? '');
    _yearController =
        TextEditingController(text: v != null ? '${v.year}' : '${DateTime.now().year}');
    _plateController = TextEditingController(text: v?.plateNumber ?? '');
    _colorController = TextEditingController(text: v?.color ?? '');
    _imageUrlController =
        TextEditingController(text: v?.primaryImageUrl ?? _sampleCarImages.first);
    _selfDriveRateController = TextEditingController(
      text: v != null && v.dailySelfDriveRate > 0
          ? v.dailySelfDriveRate.toStringAsFixed(0)
          : '35000',
    );
    _withDriverRateController = TextEditingController(
      text: v != null && v.dailyWithDriverRate > 0
          ? v.dailyWithDriverRate.toStringAsFixed(0)
          : '50000',
    );
    _hourlyRateController = TextEditingController(
      text: v != null && v.hourlyChauffeurRate > 0
          ? v.hourlyChauffeurRate.toStringAsFixed(0)
          : '8000',
    );
    _cautionDepositController = TextEditingController(
      text: v != null && v.cautionDeposit > 0
          ? v.cautionDeposit.toStringAsFixed(0)
          : '50000',
    );

    if (v != null) {
      _selectedCategory = v.category;
      _selectedTransmission = v.transmission;
      _selectedFuelType = v.fuelType;
      _selectedSeats = v.seats;
      _selectedCity = v.city.isNotEmpty ? v.city : 'Abuja';
      _assignedDriverId = v.assignedDefaultDriverId;
      _assignedDriverName = v.assignedDefaultDriverName;
      _selectedFeatures.clear();
      _selectedFeatures.addAll(v.features);
    }
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _plateController.dispose();
    _colorController.dispose();
    _imageUrlController.dispose();
    _selfDriveRateController.dispose();
    _withDriverRateController.dispose();
    _hourlyRateController.dispose();
    _cautionDepositController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final v = widget.vehicle;
      final year = int.tryParse(_yearController.text.trim()) ?? DateTime.now().year;
      final selfDrive = double.tryParse(_selfDriveRateController.text.trim()) ?? 0.0;
      final withDriver = double.tryParse(_withDriverRateController.text.trim()) ?? 0.0;
      final hourly = double.tryParse(_hourlyRateController.text.trim()) ?? 0.0;
      final caution = double.tryParse(_cautionDepositController.text.trim()) ?? 0.0;

      final vehicle = RentalVehicle(
        id: v?.id ?? '',
        fleetId: v?.fleetId ?? '',
        ownerUid: v?.ownerUid ?? '',
        make: _makeController.text.trim(),
        model: _modelController.text.trim(),
        year: year,
        category: _selectedCategory,
        transmission: _selectedTransmission,
        fuelType: _selectedFuelType,
        seats: _selectedSeats,
        plateNumber: _plateController.text.trim().toUpperCase(),
        color: _colorController.text.trim(),
        city: _selectedCity,
        images: [_imageUrlController.text.trim()],
        dailySelfDriveRate: selfDrive,
        dailyWithDriverRate: withDriver,
        hourlyChauffeurRate: hourly,
        cautionDeposit: caution,
        features: _selectedFeatures.toList(),
        status: v?.status ?? RentalVehicleStatus.available,
        assignedDefaultDriverId: _assignedDriverId,
        assignedDefaultDriverName: _assignedDriverName,
        createdAt: v?.createdAt,
      );

      await fleetManagerController.saveVehicle(vehicle);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.vehicle == null
                ? 'Vehicle added to fleet successfully!'
                : 'Vehicle updated successfully!',
          ),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.vehicle != null;
    final primaryTextColor = isDark ? Colors.white : Colors.black;
    final labelTextColor = isDark ? AppColors.textPrimaryDark : _labelColor;
    final inputFill = isDark ? AppColors.darkSurface : _lightInputFill;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Circular Back Button & Title
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
                      border: Border.all(
                        color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: primaryTextColor,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      isEditing ? 'Edit Vehicle' : 'Add Rental Vehicle',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],

                      // ── Vehicle Photo Section ──
                      const Text(
                        'Vehicle Photo URL',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.brand),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _imageUrlController,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        decoration: _pillInputDecoration(
                          hint: 'Paste vehicle photo URL',
                          fillColor: inputFill,
                          prefixIcon: const Icon(Icons.image_rounded, color: AppColors.brand, size: 20),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Image URL required' : null,
                      ),
                      const SizedBox(height: 12),

                      Text(
                        'Or pick a sample photo:',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 64,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _sampleCarImages.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 10),
                          itemBuilder: (context, idx) {
                            final url = _sampleCarImages[idx];
                            return GestureDetector(
                              onTap: () => setState(() => _imageUrlController.text = url),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(
                                  url,
                                  width: 84,
                                  height: 64,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Basic Vehicle Specs ──
                      Divider(height: 32, color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
                      const Text(
                        'Vehicle Specifications',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.brand),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Make', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelTextColor)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _makeController,
                                  style: TextStyle(color: primaryTextColor, fontSize: 15),
                                  decoration: _pillInputDecoration(hint: 'e.g. Toyota', fillColor: inputFill),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Model', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelTextColor)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _modelController,
                                  style: TextStyle(color: primaryTextColor, fontSize: 15),
                                  decoration: _pillInputDecoration(hint: 'e.g. Prado', fillColor: inputFill),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Year', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelTextColor)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _yearController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: primaryTextColor, fontSize: 15),
                                  decoration: _pillInputDecoration(hint: 'e.g. 2024', fillColor: inputFill),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('License Plate', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelTextColor)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _plateController,
                                  textCapitalization: TextCapitalization.characters,
                                  style: TextStyle(color: primaryTextColor, fontSize: 15),
                                  decoration: _pillInputDecoration(hint: 'e.g. ABC-123-XY', fillColor: inputFill),
                                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelTextColor)),
                                const SizedBox(height: 6),
                                _buildPillDropdown<RentalVehicleCategory>(
                                  value: _selectedCategory,
                                  items: RentalVehicleCategory.values
                                      .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedCategory = val);
                                  },
                                  fillColor: inputFill,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Transmission', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelTextColor)),
                                const SizedBox(height: 6),
                                _buildPillDropdown<String>(
                                  value: _selectedTransmission,
                                  items: ['Automatic', 'Manual']
                                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedTransmission = val);
                                  },
                                  fillColor: inputFill,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Color', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelTextColor)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _colorController,
                                  style: TextStyle(color: primaryTextColor, fontSize: 15),
                                  decoration: _pillInputDecoration(hint: 'e.g. Black', fillColor: inputFill),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Seating Capacity', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelTextColor)),
                                const SizedBox(height: 6),
                                _buildPillDropdown<int>(
                                  value: _selectedSeats,
                                  items: [2, 4, 5, 7, 8, 14]
                                      .map((s) => DropdownMenuItem(value: s, child: Text('$s Seats')))
                                      .toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedSeats = val);
                                  },
                                  fillColor: inputFill,
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Rental Pricing ──
                      Divider(height: 32, color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
                      const Text(
                        'Rental Pricing (NGN)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.brand),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Daily Self-Drive', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelTextColor)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _selfDriveRateController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: primaryTextColor, fontSize: 15),
                                  decoration: _pillInputDecoration(hint: '35000', fillColor: inputFill),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Daily with Chauffeur', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelTextColor)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _withDriverRateController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: primaryTextColor, fontSize: 15),
                                  decoration: _pillInputDecoration(hint: '50000', fillColor: inputFill),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Hourly Chauffeur', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelTextColor)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _hourlyRateController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: primaryTextColor, fontSize: 15),
                                  decoration: _pillInputDecoration(hint: '8000', fillColor: inputFill),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Caution Deposit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: labelTextColor)),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _cautionDepositController,
                                  keyboardType: TextInputType.number,
                                  style: TextStyle(color: primaryTextColor, fontSize: 15),
                                  decoration: _pillInputDecoration(hint: '50000', fillColor: inputFill),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Features & Amenities ──
                      Divider(height: 32, color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
                      const Text(
                        'Features & Equipment',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.brand),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _availableFeatures.map((f) {
                          final isSelected = _selectedFeatures.contains(f);
                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedFeatures.remove(f);
                                } else {
                                  _selectedFeatures.add(f);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.brand
                                    : (isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6)),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.brand
                                      : (isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected) ...[
                                    const Icon(Icons.check, size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    f,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark ? AppColors.textSecondaryDark : const Color(0xFF374151)),
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 36),

                      // Submit Button (Green Pill)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          ),
                          onPressed: _isSaving ? null : _save,
                          child: _isSaving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Text(
                                  isEditing ? 'Save Changes' : 'Add Vehicle to Fleet',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillDropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
    required Color fillColor,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  InputDecoration _pillInputDecoration({
    required String hint,
    required Color fillColor,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _hintColor, fontSize: 14),
      filled: true,
      fillColor: fillColor,
      prefixIcon: prefixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
    );
  }
}
