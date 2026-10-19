import 'dart:io';

import 'package:caride/core/utils/safe_image_picker.dart';
import 'package:caride/features/profile/data/account_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Minimalist Customer Edit Profile Screen adhering to CaRide Profile design standards.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final AccountRepository _accountRepo = AccountRepository();
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  bool _loading = false;
  bool _initialized = false;
  
  String _currentPhotoUrl = '';
  File? _newImageFile;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await _accountRepo.watchProfile().first;
    if (profile != null && mounted) {
      setState(() {
        _nameController.text = profile.fullName;
        _phoneController.text = profile.phone;
        _currentPhotoUrl = profile.photoUrl;
        _initialized = true;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await SafeImagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (picked != null && mounted) {
        setState(() => _newImageFile = File(picked.path));
      }
    } catch (e) {
      debugPrint('Error picking profile image: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);
    try {
      String? updatedPhotoUrl;
      if (_newImageFile != null) {
        updatedPhotoUrl = await _accountRepo.uploadProfilePhoto(_newImageFile!);
      }

      await _accountRepo.updateProfile(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        photoUrl: updatedPhotoUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.brand,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: !_initialized 
          ? const Center(child: AppLoader())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 14,
                bottom: 50,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top App Bar with Circular Back Button
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: primaryTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Edit Profile',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 28),

                    // Centered 96x96 Avatar with Camera Icon
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
                              border: Border.all(
                                color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                                width: 1.5,
                              ),
                            ),
                            child: ClipOval(
                              child: _newImageFile != null
                                  ? Image.file(_newImageFile!, fit: BoxFit.cover)
                                  : (_currentPhotoUrl.isNotEmpty 
                                      ? Image.network(
                                          _currentPhotoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.person_rounded,
                                            size: 48,
                                            color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                          ),
                                        ) 
                                      : Icon(
                                          Icons.person_rounded,
                                          size: 48,
                                          color: isDark ? Colors.white70 : const Color(0xFF4B5563),
                                        )),
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickImage,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.brand,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? AppColors.darkBackground : Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Form Inputs inside clean 24px rounded card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Full Name',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            style: TextStyle(fontSize: 15, color: primaryTextColor),
                            decoration: InputDecoration(
                              hintText: 'Enter your full name',
                              hintStyle: TextStyle(fontSize: 14, color: secondaryTextColor),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                              prefixIcon: Icon(Icons.person_outline_rounded, color: secondaryTextColor, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Please enter your name';
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Phone Number',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(fontSize: 15, color: primaryTextColor),
                            decoration: InputDecoration(
                              hintText: 'Enter your phone number',
                              hintStyle: TextStyle(fontSize: 14, color: secondaryTextColor),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                              prefixIcon: Icon(Icons.phone_outlined, color: secondaryTextColor, size: 20),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(28),
                                borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Please enter your phone number';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Primary 56px Pill Button
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
                        onPressed: _loading ? null : _saveProfile,
                        child: _loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ),
    );
  }
}
