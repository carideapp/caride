import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'data/driver_document_repository.dart';

class DriverProfilePictureScreen extends StatefulWidget {
  const DriverProfilePictureScreen({super.key});

  @override
  State<DriverProfilePictureScreen> createState() =>
      _DriverProfilePictureScreenState();
}

class _DriverProfilePictureScreenState
    extends State<DriverProfilePictureScreen> {
  final _picker = ImagePicker();
  final _documentRepo = DriverDocumentRepository();
  File? _selectedImage;
  bool _isUploading = false;

  String? get _uid => driverAuthController.currentUid;

  Stream<DocumentSnapshot<Map<String, dynamic>>> get _profileStream {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return FirebaseFirestore.instance
        .collection('drivers')
        .doc(uid)
        .snapshots()
        .cast<DocumentSnapshot<Map<String, dynamic>>>();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null) return;
      setState(() => _selectedImage = File(picked.path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not access camera/gallery: $e')),
      );
    }
  }

  void _showPickerSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sheetColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : AppColors.slate900;
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
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
                'Choose Profile Photo',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Select source to pick your profile photo.',
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
                      onPressed: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.camera);
                      },
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
                      onPressed: () {
                        Navigator.pop(ctx);
                        _pickImage(ImageSource.gallery);
                      },
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
        );
      },
    );
  }

  Future<void> _handleUpload() async {
    final image = _selectedImage;
    final uid = _uid;
    if (image == null || uid == null) return;

    setState(() => _isUploading = true);
    try {
      final storageRef = FirebaseStorage.instance
          .ref('driver_profile_photos/$uid/profile.jpg');

      await storageRef.putFile(
        image,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final downloadUrl = await storageRef.getDownloadURL();

      await _documentRepo.saveDocumentMetadata(
        uid: uid,
        documentType: 'profile_photo',
        fileUrl: downloadUrl,
        status: 'pending',
      );

      await FirebaseFirestore.instance.collection('drivers').doc(uid).update({
        'profilePhotoUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _showSuccessPopup();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showSuccessPopup() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Photo Updated',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your profile picture has been updated successfully.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Done',
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
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
          'Profile Picture',
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
                // Info Banner
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
                          'Your profile picture helps passengers identify you. Tap the camera icon to change it.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.grey[300] : const Color(0xFF4A4D70),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Profile Picture frame
                Expanded(
                  child: Center(
                    child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _profileStream,
                      builder: (context, snapshot) {
                        final currentUrl = snapshot.data?.data()?['profilePhotoUrl']
                            as String?;

                        ImageProvider<Object>? imageProvider;
                        if (_selectedImage != null) {
                          imageProvider = FileImage(_selectedImage!);
                        } else if (currentUrl != null && currentUrl.isNotEmpty) {
                          imageProvider = NetworkImage(currentUrl);
                        }

                        return Stack(
                          children: [
                            Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: surfaceColor,
                                border: Border.all(
                                  color: AppColors.primaryGreen,
                                  width: 4,
                                ),
                                boxShadow: isDark
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 24,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                image: imageProvider != null
                                    ? DecorationImage(
                                        image: imageProvider,
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: imageProvider == null
                                  ? const ClipOval(
                                      child: Icon(
                                        Icons.person_rounded,
                                        size: 130,
                                        color: AppColors.primaryGreen,
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: _showPickerSheet,
                                child: Container(
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen,
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: surfaceColor, width: 3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.md),
                Text(
                  'Make sure your face is clearly visible and well-lit.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.lg),

                PrimaryButton(
                  label: 'Save Photo',
                  isLoading: _isUploading,
                  onPressed: _selectedImage != null ? _handleUpload : null,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
