import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/core/driver/verification/driver_verification_config.dart';
import 'package:caride/features/driver/profile/data/driver_document_repository.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverDocumentUploadScreen extends StatefulWidget {
  const DriverDocumentUploadScreen({
    super.key,
    required this.docTitle,
    this.documentType,
  });

  final String docTitle;
  final String? documentType;

  @override
  State<DriverDocumentUploadScreen> createState() =>
      _DriverDocumentUploadScreenState();
}

class _DriverDocumentUploadScreenState
    extends State<DriverDocumentUploadScreen> {
  final _repo = DriverDocumentRepository();
  final _picker = ImagePicker();
  File? _selectedFile;
  bool _isUploading = false;
  String? _errorMessage;

  String get _docType {
    if (widget.documentType != null && widget.documentType!.isNotEmpty) {
      return widget.documentType!;
    }
    return widget.docTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  Future<void> _pickImage() async {
    final source = await _showSourceDialog();
    if (source == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked != null && mounted) {
        setState(() => _selectedFile = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Unable to access camera/gallery.');
      }
    }
  }

  Future<ImageSource?> _showSourceDialog() async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : AppColors.slate900;
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: sheetColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Select Image Source',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Choose how you want to select the document photo.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: mutedTextColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx, ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Camera'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text('Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF3F4F7),
                      foregroundColor: primaryTextColor,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _upload() async {
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
        documentType: _docType,
        file: file,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${widget.docTitle} uploaded. Admin will review within 1–2 business days.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Upload failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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
          'Upload Document',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.sm),
                Text(
                  documentDefinitionForType(_docType).description ??
                      'Please upload a clear photo of your ${widget.docTitle.toLowerCase()}. Ensure all details are clearly visible.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[300] : const Color(0xFF4A4D70),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),
                Expanded(
                  child: GestureDetector(
                    onTap: _isUploading ? null : _pickImage,
                    child: Container(
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
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                        child: _selectedFile != null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                    child: Image.file(
                                      _selectedFile!,
                                      height: 220,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  TextButton.icon(
                                    onPressed: _isUploading
                                        ? null
                                        : () => setState(
                                              () => _selectedFile = null,
                                            ),
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                                    label: const Text(
                                      'Remove and retry',
                                      style: TextStyle(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.md),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGreen.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.cloud_upload_outlined,
                                      size: 48,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    'Tap to upload ${widget.docTitle}',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: AppColors.primaryGreen,
                                      fontWeight: FontWeight.w800,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Supports Camera or Gallery image selection',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Submit for Review',
                  isLoading: _isUploading,
                  onPressed: _selectedFile != null ? _upload : null,
                ),
                const SizedBox(height: AppSpacing.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
