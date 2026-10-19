import 'dart:io';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:caride/features/fleet_manager/controllers/fleet_manager_controller.dart';
import 'package:caride/features/fleet_manager/auth/controllers/fleet_auth_controller.dart';
import 'package:caride/features/fleet_manager/auth/data/fleet_auth_repository.dart';

/// Full screen for editing Fleet Manager representative profile details.
class FleetProfileDetailsScreen extends StatefulWidget {
  const FleetProfileDetailsScreen({super.key});

  @override
  State<FleetProfileDetailsScreen> createState() => _FleetProfileDetailsScreenState();
}

class _FleetProfileDetailsScreenState extends State<FleetProfileDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  String _gender = 'Male';
  File? _avatarFile;
  File? _coverPhotoFile;
  String? _errorMessage;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isUploadingCover = false;

  static const _genderOptions = ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    final profile = fleetManagerController.currentProfile;
    final customerProfile = customerAuthController.currentProfile;

    _nameController = TextEditingController(
      text: profile?.fullName.isNotEmpty == true
          ? profile!.fullName
          : (customerProfile?.fullName ?? ''),
    );
    _phoneController = TextEditingController(
      text: profile?.phone.isNotEmpty == true
          ? profile!.phone
          : (customerProfile?.phone ?? ''),
    );
    _addressController = TextEditingController(
      text: profile?.address ?? '',
    );
    if (profile?.gender != null && profile!.gender!.isNotEmpty) {
      _gender = profile.gender!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked != null) {
        setState(() => _avatarFile = File(picked.path));
      }
    } catch (e) {
      debugPrint('[FleetProfileDetailsScreen] Error picking avatar: $e');
    }
  }

  Future<void> _pickCoverPhoto() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1080,
      );
      if (picked == null) return;

      final file = File(picked.path);
      final ext = picked.name.split('.').last.toLowerCase();
      if (ext != 'jpg' && ext != 'jpeg' && ext != 'png') {
        const msg = 'Only JPG and PNG images are supported for business cover photo.';
        setState(() => _errorMessage = msg);
        _showErrorSnackBar(msg);
        return;
      }

      final bytes = await file.length();
      if (bytes > 5 * 1024 * 1024) {
        final sizeMb = (bytes / (1024 * 1024)).toStringAsFixed(1);
        final msg = 'Cover photo exceeds the 5MB size limit (actual: $sizeMb MB). Please select a smaller image.';
        setState(() => _errorMessage = msg);
        _showErrorSnackBar(msg);
        return;
      }

      setState(() {
        _coverPhotoFile = file;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('[FleetProfileDetailsScreen] Error picking cover photo: $e');
    }
  }

  Future<void> _handleSave() async {
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) {
      const msg = 'Please complete all required fields correctly.';
      setState(() => _errorMessage = msg);
      _showErrorSnackBar(msg);
      return;
    }

    setState(() {
      _isSaving = true;
      _isUploadingAvatar = _avatarFile != null;
      _isUploadingCover = _coverPhotoFile != null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid ?? '';
      final current = fleetManagerController.currentProfile;

      String? photoUrl = current?.profilePictureUrl;
      if (_avatarFile != null) {
        photoUrl = await fleetAuthRepository.uploadFleetDocument(
          uid: uid,
          docName: 'profile_photo',
          file: _avatarFile!,
        );
        if (mounted) setState(() => _isUploadingAvatar = false);
      }

      String? coverUrl = current?.coverPhotoUrl;
      if (_coverPhotoFile != null) {
        coverUrl = await fleetAuthRepository.uploadFleetDocument(
          uid: uid,
          docName: 'cover_photo',
          file: _coverPhotoFile!,
        );
        if (mounted) setState(() => _isUploadingCover = false);
      }

      final updatedProfile = (current ??
              FleetProfile(
                fleetId: uid,
                ownerUid: uid,
                businessName: 'CaRide Fleet Partner',
                phone: _phoneController.text.trim(),
                email: user?.email ?? '',
              ))
          .copyWith(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        gender: _gender,
        profilePictureUrl: photoUrl,
        coverPhotoUrl: coverUrl,
        updatedAt: DateTime.now(),
      );

      // Save to Fleet Controller & Firestore
      await fleetManagerController.saveFleetProfile(updatedProfile);

      // Also update draft/auth profile
      fleetAuthController.fullName = _nameController.text.trim();
      fleetAuthController.phone = _phoneController.text.trim();
      fleetAuthController.gender = _gender;
      await fleetAuthController.saveSignupDraft();

      if (!mounted) return;

      _showProfileUpdatedBottomSheet();
    } catch (e) {
      if (!mounted) return;
      const humanError = 'Failed to save changes. Please check network connection and retry.';
      setState(() => _errorMessage = humanError);
      _showErrorSnackBar(humanError);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _isUploadingAvatar = false;
          _isUploadingCover = false;
        });
      }
    }
  }

  void _showProfileUpdatedBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            14,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle per AGENTS.md
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              // Emerald Success Icon in tinted circle
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.brand,
                  size: 46,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Profile Details Updated',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),

              // Body
              Text(
                'Your representative profile, business details, and cover photos have been successfully updated across CaRide.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryTextColor,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 28),

              // Full Pill Action Button per AGENTS.md
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
                    Navigator.pop(ctx); // Close modal
                    Navigator.pop(context); // Return to previous profile view
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
            ],
          ),
        );
      },
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final email = FirebaseAuth.instance.currentUser?.email ?? 'fleet@caride.com';
    final profile = fleetManagerController.currentProfile;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Navigation Bar with circular back button ──
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
                      onPressed: () => context.pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Profile Details',
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

            // ── Main Content Form ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dual In-View Error Banner if any error
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF3F1414) : const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Action Required',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.error,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _errorMessage!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.white70 : const Color(0xFF991B1B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                                onPressed: () => setState(() => _errorMessage = null),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      // ── Business Cover Photo ──
                      Text(
                        'Business Cover Photo',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _isSaving ? null : _pickCoverPhoto,
                        child: Stack(
                          children: [
                            Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                                  width: 1.5,
                                ),
                                image: _coverPhotoFile != null
                                    ? DecorationImage(
                                        image: FileImage(_coverPhotoFile!),
                                        fit: BoxFit.cover,
                                      )
                                    : (profile?.coverPhotoUrl != null && profile!.coverPhotoUrl!.isNotEmpty)
                                        ? DecorationImage(
                                            image: NetworkImage(profile.coverPhotoUrl!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                              ),
                              child: (_coverPhotoFile == null && (profile?.coverPhotoUrl == null || profile!.coverPhotoUrl!.isEmpty))
                                  ? Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: AppColors.brand.withValues(alpha: 0.12),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.add_photo_alternate_rounded,
                                            color: AppColors.brand,
                                            size: 28,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Upload Business Cover Photo',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white70 : const Color(0xFF374151),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Recommended 16:9 • JPG or PNG (max 5MB)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: secondaryTextColor,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Align(
                                      alignment: Alignment.bottomRight,
                                      child: Padding(
                                        padding: const EdgeInsets.all(10.0),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.75),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                                              SizedBox(width: 4),
                                              Text(
                                                'Change Cover',
                                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            if (_isUploadingCover)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      SizedBox(
                                        width: 32,
                                        height: 32,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 3,
                                          color: AppColors.brand,
                                        ),
                                      ),
                                      SizedBox(height: 10),
                                      Text(
                                        'Uploading cover photo...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Avatar Photo Preview ──
                      Center(
                        child: GestureDetector(
                          onTap: _isSaving ? null : _pickAvatar,
                          child: Stack(
                            children: [
                              Container(
                                width: 104,
                                height: 104,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
                                  border: Border.all(
                                    color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                                    width: 2,
                                  ),
                                ),
                                child: _avatarFile != null
                                    ? ClipOval(
                                        child: Image.file(
                                          _avatarFile!,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : (profile?.profilePictureUrl != null &&
                                            profile!.profilePictureUrl!.isNotEmpty)
                                        ? ClipOval(
                                            child: Image.network(
                                              profile.profilePictureUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(
                                                Icons.person_rounded,
                                                size: 56,
                                                color: Color(0xFF9CA3AF),
                                              ),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.person_rounded,
                                            size: 56,
                                            color: Color(0xFF9CA3AF),
                                          ),
                              ),
                              if (_isUploadingAvatar)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 26,
                                          height: 26,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.6,
                                            color: AppColors.brand,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Uploading',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              if (!_isUploadingAvatar)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: AppColors.brand,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark ? AppColors.darkBackground : Colors.white,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      color: Colors.white,
                                      size: 17,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ── Full Name Field ──
                      _buildFieldLabel('Full Name *', isDark),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Full Name is required' : null,
                        decoration: _pillInputDecoration('e.g. Adebayo Ogunlesi', Icons.person_outline_rounded, isDark),
                      ),
                      const SizedBox(height: 16),

                      // ── Phone Number Field ──
                      _buildFieldLabel('Phone Number *', isDark),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        validator: (v) => (v == null || v.trim().length < 8) ? 'Enter valid phone number' : null,
                        decoration: _pillInputDecoration('e.g. +234 801 234 5678', Icons.phone_outlined, isDark),
                      ),
                      const SizedBox(height: 16),

                      // ── Email Field (Read Only) ──
                      _buildFieldLabel('Email Address (Verified)', isDark),
                      const SizedBox(height: 6),
                      TextFormField(
                        initialValue: email,
                        enabled: false,
                        style: TextStyle(color: primaryTextColor.withValues(alpha: 0.6), fontSize: 15),
                        decoration: _pillInputDecoration('Email', Icons.email_outlined, isDark).copyWith(
                          suffixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF9CA3AF)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Gender Picker ──
                      _buildFieldLabel('Gender', isDark),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _gender,
                            isExpanded: true,
                            dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                            items: _genderOptions
                                .map((g) => DropdownMenuItem(
                                      value: g,
                                      child: Text(g, style: TextStyle(color: primaryTextColor, fontSize: 15)),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _gender = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Residential / Office Address ──
                      _buildFieldLabel('Residentail / Office address', isDark),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _addressController,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        decoration: _pillInputDecoration('e.g. Suite 4, Central Business District, Abuja', Icons.pin_drop_outlined, isDark),
                      ),
                      const SizedBox(height: 32),

                      // ── Save Button ──
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          onPressed: _isSaving ? null : _handleSave,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                )
                              : const Text(
                                  'Save Changes',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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

  Widget _buildFieldLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.textPrimaryDark : const Color(0xFF374151),
      ),
    );
  }

  InputDecoration _pillInputDecoration(String hint, IconData prefixIcon, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF9CA3AF),
        fontSize: 14,
      ),
      filled: true,
      fillColor: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
      prefixIcon: Icon(prefixIcon, color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280), size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(
          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: AppColors.error, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }
}
