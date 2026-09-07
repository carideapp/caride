import 'dart:async';
import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/features/driver/profile/data/driver_document_repository.dart';
import 'package:caride/features/driver/profile/widgets/success_dialog.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverRiderPermitScreen extends StatefulWidget {
  const DriverRiderPermitScreen({super.key});

  @override
  State<DriverRiderPermitScreen> createState() =>
      _DriverRiderPermitScreenState();
}

class _DriverRiderPermitScreenState
    extends State<DriverRiderPermitScreen> {
  final _repo = DriverDocumentRepository();
  final _picker = ImagePicker();

  File? _selectedFile;
  bool _isUploading = false;
  String? _errorMessage;

  Future<void> _pickFromCamera() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked != null && mounted) {
        setState(() => _selectedFile = File(picked.path));
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
        setState(() => _selectedFile = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to access gallery.');
      }
    }
  }

  Future<void> _submit() async {
    final file = _selectedFile;
    if (file == null) return;
    final uid = driverAuthController.currentUid;
    if (uid == null) return;

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      await _repo.uploadDocument(
        uid: uid,
        documentType: 'rider_permit',
        file: file,
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      unawaited(SuccessDialog.show(
        context,
        title: 'Rider Permit Submitted',
        description:
            'Your rider permit document has been uploaded successfully. Admin will review within 1–2 business days.',
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

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // Spacer to balance row
                ],
              ),
            ),

            // ── Content Scroll Area ──
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
                      'Rider Permit',
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
                            'Upload a picture of your Rider Permit document. No screenshots, copies, or printed photos. Make sure all details are clearly visible.',
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

                    // ── Main Correct image / selected photo preview ──
                    AspectRatio(
                      aspectRatio: 1,
                      child: _selectedFile != null
                          ? _PhotoPreview(
                              file: _selectedFile!,
                              surface: surface,
                              onRemove: _isUploading
                                  ? null
                                  : () => setState(
                                        () => _selectedFile = null,
                                      ),
                             )
                          : _PlaceholderPreview(
                              assetPath: 'lib/assets/rider_permit_correct.png',
                              surface: surface,
                              isDark: isDark,
                              isCorrect: true,
                            ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ── Sub bad examples display row (Faded, Half-captured, Blurry) ──
                    if (_selectedFile == null)
                      Row(
                        children: [
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: _PlaceholderPreview(
                                assetPath: 'lib/assets/rider_permit_faded.png',
                                surface: surface,
                                isDark: isDark,
                                isCorrect: false,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: _PlaceholderPreview(
                                assetPath: 'lib/assets/rider_permit_half.png',
                                surface: surface,
                                isDark: isDark,
                                isCorrect: false,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: _PlaceholderPreview(
                                assetPath: 'lib/assets/rider_permit_blur.png',
                                surface: surface,
                                isDark: isDark,
                                isCorrect: false,
                              ),
                            ),
                          ),
                        ],
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

            // ── Buttons ──
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
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _pickFromCamera,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedFile != null
                            ? (isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7))
                            : AppColors.primaryGreen,
                        foregroundColor: _selectedFile != null
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
                  PrimaryButton(
                    label: 'Submit for Review',
                    isLoading: _isUploading,
                    onPressed: _selectedFile != null && !_isUploading ? _submit : null,
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

class _PlaceholderPreview extends StatelessWidget {
  const _PlaceholderPreview({
    required this.assetPath,
    required this.surface,
    required this.isDark,
    required this.isCorrect,
  });

  final String assetPath;
  final Color surface;
  final bool isDark;
  final bool isCorrect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isCorrect
              ? AppColors.primaryGreen
              : const Color(0xFFEF4444),
          width: 2.5,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl - 2.5),
            child: Image.asset(
              assetPath,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isCorrect ? AppColors.primaryGreen : const Color(0xFFEF4444),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCorrect ? Icons.check_rounded : Icons.close_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
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
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: AppColors.primaryGreen,
              width: 2.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xl - 2.5),
            child: Image.file(
              file,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: AppColors.primaryGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
          ),
        ),
        if (onRemove != null)
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
      ],
    );
  }
}
