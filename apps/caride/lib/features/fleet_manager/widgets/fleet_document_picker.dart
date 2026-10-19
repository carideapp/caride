import 'dart:io';
import 'package:caride/core/utils/safe_image_picker.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Redesigned Fleet Document Picker following the CaRide design-system.md standards.
class FleetDocumentPicker extends StatefulWidget {
  const FleetDocumentPicker({
    super.key,
    required this.title,
    required this.description,
    this.initialFile,
    this.initialUrl,
    required this.onFileSelected,
    this.onFileRemoved,
    this.isUploading = false,
    this.uploadProgress,
    this.uploadSuccess = false,
    this.errorMessage,
    this.isRequired = true,
  });

  final String title;
  final String description;
  final File? initialFile;
  final String? initialUrl;
  final ValueChanged<File> onFileSelected;
  final VoidCallback? onFileRemoved;
  final bool isUploading;
  final double? uploadProgress;
  final bool uploadSuccess;
  final String? errorMessage;
  final bool isRequired;

  @override
  State<FleetDocumentPicker> createState() => _FleetDocumentPickerState();
}

class _FleetDocumentPickerState extends State<FleetDocumentPicker> {
  File? _file;

  @override
  void initState() {
    super.initState();
    _file = widget.initialFile;
  }

  @override
  void didUpdateWidget(covariant FleetDocumentPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFile != oldWidget.initialFile) {
      _file = widget.initialFile;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await SafeImagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (picked != null) {
        final f = File(picked.path);
        setState(() => _file = f);
        widget.onFileSelected(f);
      }
    } catch (e) {
      debugPrint('[FleetDocumentPicker] Error picking image: $e');
    }
  }

  void _showPickerSourceModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select source to upload your document',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  tileColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF9FAFB),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: AppColors.brand, size: 20),
                  ),
                  title: const Text(
                    'Take a Photo',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: const Text('Capture document with camera', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.camera);
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  tileColor: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF9FAFB),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_rounded, color: Color(0xFF2563EB), size: 20),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: const Text('Pick document photo or image', style: TextStyle(fontSize: 12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _removeFile() {
    setState(() => _file = null);
    widget.onFileRemoved?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasFile = _file != null || (widget.initialUrl != null && widget.initialUrl!.isNotEmpty);
    final fileName = _file != null ? _file!.path.split(Platform.pathSeparator).last : 'Document attached';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title & optional badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
            if (widget.isRequired)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'REQUIRED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: AppColors.brand,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.description,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 10),

        // Main Picker Card (20px rounded corners with brand subtle border)
        Container(
          decoration: BoxDecoration(
            color: hasFile
                ? (isDark ? AppColors.brand.withValues(alpha: 0.08) : const Color(0xFFF0FDF4))
                : (isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hasFile
                  ? AppColors.brand
                  : (isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
              width: hasFile ? 1.5 : 1.0,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: hasFile
              ? _buildSelectedFileView(isDark, fileName)
              : _buildEmptyPickerView(isDark),
        ),

        // Error message if any
        if (widget.errorMessage != null && widget.errorMessage!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.error),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.errorMessage!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyPickerView(bool isDark) {
    return InkWell(
      onTap: _showPickerSourceModal,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_upload_outlined,
                color: AppColors.brand,
                size: 28,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Upload Document',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Clear, readable photo (PNG, JPG, JPEG)',
              style: TextStyle(
                color: isDark ? AppColors.textTertiaryDark : const Color(0xFF9CA3AF),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.attach_file_rounded, size: 14, color: AppColors.brand),
                  SizedBox(width: 6),
                  Text(
                    'Browse Files',
                    style: TextStyle(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFileView(bool isDark, String fileName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            // Preview thumbnail or icon
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _file != null
                  ? Image.file(
                      _file!,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _defaultFileIcon(),
                    )
                  : (widget.initialUrl != null && widget.initialUrl!.isNotEmpty)
                      ? Image.network(
                          widget.initialUrl!,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultFileIcon(),
                        )
                      : _defaultFileIcon(),
            ),
            const SizedBox(width: 14),

            // File Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppColors.brand, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.isUploading
                        ? 'Uploading document...'
                        : 'Document selected & ready',
                    style: TextStyle(
                      color: widget.isUploading
                          ? AppColors.brand
                          : (isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280)),
                      fontSize: 12,
                    ),
                  ),
                  if (widget.isUploading && widget.uploadProgress != null) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: widget.uploadProgress,
                        backgroundColor: Colors.black12,
                        valueColor: const AlwaysStoppedAnimation(AppColors.brand),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Divider(
          height: 1,
          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
        ),
        const SizedBox(height: 8),

        // Action Buttons: Replace & Remove (Pill buttons)
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 14, color: AppColors.brand),
              label: const Text(
                'Replace',
                style: TextStyle(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              onPressed: _showPickerSourceModal,
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.error),
              label: const Text(
                'Remove',
                style: TextStyle(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              onPressed: _removeFile,
            ),
          ],
        ),
      ],
    );
  }

  Widget _defaultFileIcon() {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.description_rounded,
        color: AppColors.brand,
        size: 26,
      ),
    );
  }
}
