import 'dart:io';

import 'package:caride/features/profile/data/account_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer Edit Profile Screen featuring GlassAppBar, GlassContainer, and AppTextField.
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
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() => _newImageFile = File(picked.path));
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
    
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: 'Edit Profile',
      ),
      body: !_initialized 
        ? const Center(child: AppLoader())
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
              vertical: AppSpacing.lg,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.brandGlass,
                          backgroundImage: _newImageFile != null
                              ? FileImage(_newImageFile!) as ImageProvider
                              : (_currentPhotoUrl.isNotEmpty 
                                  ? NetworkImage(_currentPhotoUrl) 
                                  : null),
                          child: (_newImageFile == null && _currentPhotoUrl.isEmpty)
                              ? const Icon(Icons.person, size: 50, color: AppColors.brand)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: AppColors.brand,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  GlassSurface(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Full Name',
                          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppTextField(
                          controller: _nameController,
                          hint: 'Enter your full name',
                          obscureText: false,
                          prefixIcon: Icons.person_outline_rounded,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Please enter your name';
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Phone Number',
                          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppTextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          hint: 'Enter your phone number',
                          obscureText: false,
                          prefixIcon: Icons.phone_outlined,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Please enter your phone number';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 36),
                  PrimaryButton(
                    label: 'Save Changes',
                    isLoading: _loading,
                    onPressed: _saveProfile,
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
