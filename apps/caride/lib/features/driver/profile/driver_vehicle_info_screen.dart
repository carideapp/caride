// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/core/driver/models/vehicle_info.dart';
import 'package:caride/core/driver/models/vehicle_review.dart';
import 'package:caride/core/driver/verification/driver_verification_config.dart';
import 'package:caride/features/driver/auth/data/driver_profile_repository.dart';
import 'package:caride/features/driver/profile/widgets/success_dialog.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverVehicleInfoScreen extends StatefulWidget {
  const DriverVehicleInfoScreen({super.key});

  @override
  State<DriverVehicleInfoScreen> createState() =>
      _DriverVehicleInfoScreenState();
}

class _DriverVehicleInfoScreenState extends State<DriverVehicleInfoScreen> {
  final _profileRepo = DriverProfileRepository();
  final _formKey = GlobalKey<FormState>();
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _colorController = TextEditingController();
  final _plateController = TextEditingController();
  final _yearController = TextEditingController();
  String _vehicleType = vehicleTypeRegular;
  bool _isLoading = true;
  bool _isSubmitting = false;
  VehicleReview? _vehicleReview;

  static const _vehicleTypes = supportedVehicleTypes;

  @override
  void initState() {
    super.initState();
    _loadVehicle();
  }

  Future<void> _loadVehicle() async {
    final uid = driverAuthController.currentUid;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    final vehicle = await _profileRepo.getVehicleInfo(uid);
    final review = await _profileRepo.getVehicleReview(uid);
    if (mounted && vehicle != null) {
      _makeController.text = vehicle.make;
      _modelController.text = vehicle.model;
      _colorController.text = vehicle.color;
      _plateController.text = vehicle.plateNumber;
      _yearController.text = vehicle.year.toString();
      _vehicleType = vehicle.vehicleType;
    }
    if (mounted) {
      setState(() {
        _vehicleReview = review;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _colorController.dispose();
    _plateController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = driverAuthController.currentUid;
    if (uid == null) return;

    setState(() => _isSubmitting = true);
    try {
      final year = int.tryParse(_yearController.text.trim()) ??
          DateTime.now().year;
      final vehicle = VehicleInfo(
        make: _makeController.text.trim(),
        model: _modelController.text.trim(),
        year: year,
        color: _colorController.text.trim(),
        plateNumber: _plateController.text.trim(),
        vehicleType: _vehicleType,
        seatCount: seatCountForVehicleType(_vehicleType),
      );
      await _profileRepo.updateVehicleInfo(uid: uid, vehicleInfo: vehicle);
      if (!mounted) return;
      _showSuccessPopup();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save vehicle info: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showSuccessPopup() {
    Navigator.of(context).pop();
    unawaited(SuccessDialog.show(
      context,
      title: 'Vehicle Submitted',
      description: 'Your vehicle information has been submitted for admin review.',
      buttonLabel: 'Okay',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Vehicle Details',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ResponsiveContainer(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: AppSpacing.sm),
                        if (_vehicleReview != null) ...[
                          _VehicleReviewBanner(review: _vehicleReview!),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: borderColor),
                            boxShadow: isDark
                                ? null
                                : [
                                    const BoxShadow(
                                      color: Color(0x0F0F172A),
                                      blurRadius: 18,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryGreen.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.info_outline_rounded,
                                  color: AppColors.primaryGreen,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  'Vehicle info is used to match you with the right ride category.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: isDark ? Colors.grey[300] : const Color(0xFF4A4D70),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Unified Form Fields Card
                        Container(
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            border: Border.all(color: borderColor),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                          ),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            children: [
                              _buildField(
                                label: 'Make (Brand)',
                                controller: _makeController,
                                hint: 'e.g. Toyota',
                                icon: Icons.directions_car_outlined,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _buildField(
                                label: 'Model',
                                controller: _modelController,
                                hint: 'e.g. Camry',
                                icon: Icons.directions_car_filled_outlined,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _buildField(
                                label: 'Color',
                                controller: _colorController,
                                hint: 'e.g. Silver',
                                icon: Icons.palette_outlined,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _buildField(
                                label: 'Plate Number',
                                controller: _plateController,
                                hint: 'e.g. ABC-123-XY',
                                icon: Icons.pin_outlined,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _buildField(
                                label: 'Year',
                                controller: _yearController,
                                hint: 'e.g. 2020',
                                icon: Icons.calendar_today_outlined,
                                keyboardType: TextInputType.number,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // Vehicle Type Selection Header
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            'Vehicle Type',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.slate900,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _buildVehicleTypeCard(context, _vehicleTypes[0])),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(child: _buildVehicleTypeCard(context, _vehicleTypes[1])),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(child: _buildVehicleTypeCard(context, _vehicleTypes[2])),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(child: _buildVehicleTypeCard(context, _vehicleTypes[3])),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        PrimaryButton(
                          label: 'Save Vehicle Info',
                          isLoading: _isSubmitting,
                          onPressed: _handleSubmit,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xs,
            bottom: AppSpacing.xs,
          ),
          child: Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              color: isDark ? Colors.white : AppColors.slate900,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        AppTextField(
          controller: controller,
          hint: hint,
          prefix: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.sm,
            ),
            child: Icon(icon, size: 20, color: AppColors.primaryGreen),
          ),
          keyboardType: keyboardType,
          validator: (val) =>
              (val == null || val.isEmpty) ? '$label is required' : null,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildVehicleTypeCard(BuildContext context, String type) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _vehicleType == type;

    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final activeBorderColor = AppColors.primaryGreen;
    final inactiveBorderColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _vehicleType = type;
          });
        },
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.md,
            horizontal: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: isSelected ? activeBorderColor : inactiveBorderColor,
              width: isSelected ? 2.0 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryGreen.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : (isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'lib/assets/ride_options/$type.png',
                    height: 60,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(
                        height: 60,
                        child: Icon(Icons.directions_car, size: 40),
                      );
                    },
                  ),
                  if (isSelected)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                vehicleTypeLabel(type),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected
                      ? AppColors.primaryGreen
                      : (isDark ? Colors.white : AppColors.slate900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleReviewBanner extends StatelessWidget {
  const _VehicleReviewBanner({required this.review});

  final VehicleReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRejected = review.isRejected;
    final color = isRejected ? theme.colorScheme.error : AppColors.primaryGreen;
    final message = isRejected
        ? review.rejectionReason ?? 'Your previous vehicle update was rejected. Please review and resubmit.'
        : review.isApproved
            ? 'Your latest vehicle information has been approved.'
            : 'Your latest vehicle information is pending admin review.';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isRejected ? Icons.error_outline_rounded : Icons.pending_outlined,
            color: color,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.grey[300] : const Color(0xFF4A4D70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
