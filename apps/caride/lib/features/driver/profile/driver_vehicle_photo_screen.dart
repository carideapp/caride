import 'dart:async';
import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/features/driver/profile/data/driver_document_repository.dart';
import 'package:caride/features/driver/profile/widgets/success_dialog.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Two-step vehicle photo upload screen.
/// Step 1 → front photo of the vehicle.
/// Step 2 → rear/back photo of the vehicle.
class DriverVehiclePhotoScreen extends StatefulWidget {
  const DriverVehiclePhotoScreen({super.key});

  @override
  State<DriverVehiclePhotoScreen> createState() =>
      _DriverVehiclePhotoScreenState();
}

class _DriverVehiclePhotoScreenState extends State<DriverVehiclePhotoScreen> {
  final _repo = DriverDocumentRepository();
  final _picker = ImagePicker();

  int _step = 0; // 0 = front, 1 = back
  File? _frontFile;
  File? _backFile;
  bool _isUploading = false;
  String? _errorMessage;

  File? get _currentFile => _step == 0 ? _frontFile : _backFile;

  void _setCurrentFile(File? f) {
    if (_step == 0) {
      _frontFile = f;
    } else {
      _backFile = f;
    }
  }

  Future<void> _pickFromCamera() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked != null && mounted) {
        setState(() => _setCurrentFile(File(picked.path)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to access camera.');
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked != null && mounted) {
        setState(() => _setCurrentFile(File(picked.path)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to access gallery.');
      }
    }
  }

  void _goNext() {
    setState(() {
      _step = 1;
      _errorMessage = null;
    });
  }

  void _goBack() {
    setState(() {
      _step = 0;
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    final front = _frontFile;
    final back = _backFile;
    if (front == null || back == null) return;
    final uid = driverAuthController.currentUid;
    if (uid == null) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      // Upload both photos concurrently
      await Future.wait([
        _repo.uploadDocument(
          uid: uid,
          documentType: 'vehicle_photo_front',
          file: front,
        ),
        _repo.uploadDocument(
          uid: uid,
          documentType: 'vehicle_photo_back',
          file: back,
        ),
      ]);

      if (!mounted) return;
      
      // Close the upload screen and show the success popup
      Navigator.of(context).pop();
      
      unawaited(SuccessDialog.show(
        context,
        title: 'Photos Submitted',
        description: 'Your vehicle photos have been uploaded successfully. Admin will review within 1–2 business days.',
        buttonLabel: 'Okay',
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Upload failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surface = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final subtitleColor =
        isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    final isStep1 = _step == 0;
    final title = isStep1 ? 'Vehicle picture' : 'Vehicle picture';
    final instruction = isStep1
        ? 'Take a photo of the car from the front. Make sure the car is fully visible and the registration plate is easy to read.'
        : 'Take a photo of the car from the back. Make sure the car is fully visible and the registration plate is easy to read.';

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top bar ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  if (isStep1)
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  else
                    IconButton(
                      icon: Icon(
                        Icons.arrow_back_rounded,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      onPressed: _isUploading ? null : _goBack,
                    ),
                  const Spacer(),
                  // Step indicator dots
                  Row(
                    children: [
                      _StepDot(active: isStep1),
                      const SizedBox(width: 6),
                      _StepDot(active: !isStep1),
                    ],
                  ),
                  const Spacer(),
                  // Placeholder to balance the row
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ── Content ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: subtitleColor,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            instruction,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              color: subtitleColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Photo preview / placeholder ──
                    AspectRatio(
                      aspectRatio: 1,
                      child: _currentFile != null
                          ? _PhotoPreview(
                              file: _currentFile!,
                              surface: surface,
                              onRemove: _isUploading
                                  ? null
                                  : () => setState(
                                        () => _setCurrentFile(null),
                                      ),
                            )
                          : _PhotoPlaceholder(
                              assetPath: isStep1
                                  ? 'lib/assets/car_front_placeholder.png'
                                  : 'lib/assets/car_back_placeholder.png',
                              surface: surface,
                              isDark: isDark,
                            ),
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),

            // ── Bottom action buttons ──
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Primary: Take a picture (camera)
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _pickFromCamera,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentFile != null
                            ? (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7))
                            : AppColors.primaryGreen,
                        foregroundColor: _currentFile != null
                            ? (isDark ? Colors.white : Colors.black)
                            : Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                      child: const Text(
                        'Take a picture',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Secondary: Choose from gallery
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _pickFromGallery,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7),
                        foregroundColor:
                            isDark ? Colors.white : Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                      child: const Text(
                        'Choose from Gallery',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Step action: Next (step 1) or Submit (step 2)
                  if (isStep1)
                    PrimaryButton(
                      label: 'Next',
                      onPressed: _frontFile != null ? _goNext : null,
                    )
                  else
                    PrimaryButton(
                      label: 'Submit for Review',
                      isLoading: _isUploading,
                      onPressed:
                          _backFile != null && !_isUploading ? _submit : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _StepDot extends StatelessWidget {
  const _StepDot({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: active ? 20 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active ? AppColors.primaryGreen : Colors.grey.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _PhotoPlaceholder extends StatelessWidget {
  const _PhotoPlaceholder({
    required this.assetPath,
    required this.surface,
    required this.isDark,
  });

  final String assetPath;
  final Color surface;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE9EAF0),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Image.asset(
          assetPath,
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  const _PhotoPreview({
    required this.file,
    required this.surface,
    this.onRemove,
  });
  final File file;
  final Color surface;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          child: Image.file(
            file,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        // Green check badge
        Positioned(
          top: 12,
          left: 12,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: AppColors.primaryGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
          ),
        ),
        // Remove button
        if (onRemove != null)
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
              ),
            ),
          ),
      ],
    );
  }
}
