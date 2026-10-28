import 'dart:io';

import 'package:caride/core/auth/pending_otp_session.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/core/services/termii_service.dart';
import 'package:caride/core/utils/auth_error_mapper.dart';
import 'package:caride/features/driver/profile/driver_terms_screen.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Redesigned Driver Signup Screen matching the driver_login_screen.dart minimalist pill aesthetic.
class DriverSignupScreen extends StatefulWidget {
  const DriverSignupScreen({super.key});

  @override
  State<DriverSignupScreen> createState() => _DriverSignupScreenState();
}

class _DriverSignupScreenState extends State<DriverSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _referralCode = TextEditingController();
  final _scrollController = ScrollController();
  File? _profilePhotoFile;
  bool _obscurePassword = true;
  bool _loading = false;
  bool _acceptTerms = false;
  String? _errorMessage;
  String? _pendingSessionEmail;

  String _selectedCountry = 'Nigeria';
  String? _selectedState;

  static const Color _primaryBrand = AppColors.brand; // Color(0xFF16A34A)
  static const Color _lightInputFill = Color(0xFFF3F4F6);
  static const Color _labelColor = Color(0xFF1F2937);
  static const Color _hintColor = Color(0xFF9CA3AF);
  static const Color _subtitleColor = Color(0xFF6B7280);

  static const List<String> _countries = [
    'Nigeria',
  ];

  static const Map<String, List<String>> _countryStates = {
    'Nigeria': [
      'Abia',
      'Adamawa',
      'Akwa Ibom',
      'Anambra',
      'Bauchi',
      'Bayelsa',
      'Benue',
      'Borno',
      'Cross River',
      'Delta',
      'Ebonyi',
      'Edo',
      'Ekiti',
      'Enugu',
      'FCT (Abuja)',
      'Gombe',
      'Imo',
      'Jigawa',
      'Kaduna',
      'Kano',
      'Katsina',
      'Kebbi',
      'Kogi',
      'Kwara',
      'Lagos',
      'Nasarawa',
      'Niger',
      'Ogun',
      'Ondo',
      'Osun',
      'Oyo',
      'Plateau',
      'Rivers',
      'Sokoto',
      'Taraba',
      'Yobe',
      'Zamfara',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadDraftAndSession();
  }

  Future<void> _loadDraftAndSession() async {
    final session = await PendingOtpSessionService.instance.loadSession(roleFilter: 'driver');
    if (session != null && mounted) {
      setState(() {
        final dest = session.challenge.isSms && session.challenge.phone != null
            ? session.challenge.phone!
            : session.challenge.email;
        _pendingSessionEmail = dest;
        if (_fullName.text.isEmpty && session.fullName != null) _fullName.text = session.fullName!;
        if (_email.text.isEmpty && session.email != null) _email.text = session.email!;
        if (_phone.text.isEmpty && session.phone != null) _phone.text = session.phone!;
        if (_username.text.isEmpty && session.username != null) _username.text = session.username!;
        if (_referralCode.text.isEmpty && session.referralCode != null) _referralCode.text = session.referralCode!;
      });
    } else {
      final draft = await PendingOtpSessionService.instance.loadDraft('driver');
      if (draft != null && mounted) {
        setState(() {
          if (_fullName.text.isEmpty && draft['fullName'] != null) _fullName.text = draft['fullName'] as String;
          if (_email.text.isEmpty && draft['email'] != null) _email.text = draft['email'] as String;
          if (_phone.text.isEmpty && draft['phone'] != null) _phone.text = draft['phone'] as String;
          if (_username.text.isEmpty && draft['username'] != null) _username.text = draft['username'] as String;
          if (_referralCode.text.isEmpty && draft['referralCode'] != null) _referralCode.text = draft['referralCode'] as String;
          if (_selectedState == null && draft['state'] != null) _selectedState = draft['state'] as String;
        });
      }
    }
  }

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _referralCode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickProfilePhoto() async {
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
        setState(() => _errorMessage = "Only JPG and PNG images are supported for profile photo.");
        return;
      }

      final bytes = await file.length();
      if (bytes > 5 * 1024 * 1024) {
        final sizeMb = (bytes / (1024 * 1024)).toStringAsFixed(1);
        setState(() => _errorMessage = "Profile photo exceeds the 5MB size limit (actual: $sizeMb MB). Please select a smaller image.");
        _scrollToTop();
        return;
      }

      setState(() {
        _profilePhotoFile = file;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('[DriverSignupScreen] Error picking profile photo: $e');
      if (mounted) {
        setState(() => _errorMessage = "Unable to access photo gallery. Please check app permissions and try again.");
        _scrollToTop();
      }
    }
  }

  void _navigateToOtp() {
    try {
      context.push(DriverRoutePaths.otp);
    } catch (e) {
      debugPrint('[DriverSignupScreen] Navigation push failed ($e), falling back to go');
      if (mounted) {
        context.go(DriverRoutePaths.otp);
      }
    }
  }

  Future<void> _submit() async {
    if (!_acceptTerms) {
      setState(() => _errorMessage = 'You must accept the Driver Terms & Conditions to proceed.');
      _scrollToTop();
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      setState(() => _errorMessage = 'Please complete all required fields correctly.');
      _scrollToTop();
      return;
    }

    if (_selectedState == null || _selectedState!.trim().isEmpty) {
      setState(() => _errorMessage = 'Please select your operating state.');
      _scrollToTop();
      return;
    }

    final phoneNum = _phone.text.trim();
    final cleanPhone = TermiiService.formatToLocal11Digits(phoneNum);
    final emailAddr = _email.text.trim();

    // If an OTP was already sent for this phone or email and is still valid, reuse it and proceed
    if (_pendingSessionEmail != null) {
      final restored = await driverAuthController.restorePendingSession();
      if (restored && mounted) {
        final pending = driverAuthController.pendingChallenge;
        if (pending != null &&
            DateTime.now().isBefore(pending.expiresAt) &&
            (pending.phone == cleanPhone || pending.email == emailAddr)) {
          _navigateToOtp();
          return;
        }
      }
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final code = _referralCode.text.trim().isEmpty ? null : _referralCode.text.trim();
    final rawUsername = _username.text.trim().replaceAll('@', '').toLowerCase();
    final cleanFullName = _fullName.text.trim();

    await PendingOtpSessionService.instance.saveDraft('driver', {
      'fullName': cleanFullName,
      'username': _username.text.trim(),
      'email': emailAddr,
      'phone': phoneNum,
      'referralCode': _referralCode.text.trim(),
      'state': _selectedState,
    });

    try {
      await driverAuthController.requestOtpForSignup(
        phoneNum,
        emailAddr,
        referralCode: code,
        fullName: cleanFullName,
        password: _password.text,
        username: rawUsername,
        country: _selectedCountry,
        state: _selectedState ?? '',
      );

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_role', 'driver');
      } catch (storageErr) {
        debugPrint('[DriverSignupScreen] Warning: SharedPreferences write failed: $storageErr');
      }
    } catch (e) {
      debugPrint('[DriverSignupScreen] Error during driver signup: $e');
      if (!mounted) return;
      setState(() => _errorMessage = mapAuthErrorMessage(e));
      _scrollToTop();
      return;
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (!mounted) return;
    _navigateToOtp();
  }

  void _onBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(CustomerRoutePaths.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final inputFill = isDark ? AppColors.darkSurface : _lightInputFill;
    final primaryTextColor = isDark ? Colors.white : Colors.black;
    final labelTextColor = isDark ? AppColors.textPrimaryDark : _labelColor;
    final subtitleTextColor = isDark ? AppColors.textSecondaryDark : _subtitleColor;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Back Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: primaryTextColor,
                    ),
                    onPressed: _onBack,
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8.0,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // Title
                      Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        'Sign up to get started as a driver',
                        style: TextStyle(
                          fontSize: 15,
                          color: subtitleTextColor,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Pending OTP resume banner if any
                      if (_pendingSessionEmail != null) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.brandGlass,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.brand.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.mark_email_read_outlined,
                                    color: AppColors.brand,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'A verification code is active for $_pendingSessionEmail',
                                      style: TextStyle(
                                        color: primaryTextColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.brand,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                      ),
                                      onPressed: () async {
                                        await driverAuthController.restorePendingSession();
                                        if (mounted) _navigateToOtp();
                                      },
                                      child: const Text('Enter Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () async {
                                      await driverAuthController.clearPendingChallenge();
                                      if (mounted) setState(() => _pendingSessionEmail = null);
                                    },
                                    child: Text(
                                      'Dismiss',
                                      style: TextStyle(color: subtitleTextColor, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Error Banner
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: AppColors.error,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: AppColors.error,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Profile Photo Picker Section
                      Text(
                        'Profile Photo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: labelTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _pickProfilePhoto,
                        child: Container(
                          height: 130,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: inputFill,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                              width: 1.5,
                            ),
                            image: _profilePhotoFile != null
                                ? DecorationImage(
                                    image: FileImage(_profilePhotoFile!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: _profilePhotoFile == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _primaryBrand.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.add_a_photo_rounded,
                                        color: _primaryBrand,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Select Profile Photo',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'JPG or PNG (max 5MB)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: subtitleTextColor,
                                      ),
                                    ),
                                  ],
                                )
                              : Align(
                                  alignment: Alignment.topRight,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: InkWell(
                                      onTap: () => setState(() => _profilePhotoFile = null),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Colors.black87,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Full Name Field
                      Text(
                        'Full Name',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: labelTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _fullName,
                        textCapitalization: TextCapitalization.words,
                        keyboardType: TextInputType.name,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter full name (e.g. John Doe)',
                          hintStyle: const TextStyle(
                            color: _hintColor,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.person_outline_rounded,
                            color: _hintColor,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: inputFill,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: const BorderSide(
                              color: _primaryBrand,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (v) {
                          final val = v?.trim() ?? '';
                          if (val.isEmpty) return 'Full name is required.';
                          if (val.length < 3) return 'Full name must be at least 3 characters.';
                          final parts = val.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
                          if (parts.length < 2) return 'Please enter both your first and last name.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Username Field
                      Text(
                        'Username',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: labelTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _username,
                        keyboardType: TextInputType.text,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter username (e.g. johndoe)',
                          hintStyle: const TextStyle(
                            color: _hintColor,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.alternate_email_rounded,
                            color: _hintColor,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: inputFill,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: const BorderSide(
                              color: _primaryBrand,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Username is required.';
                          final clean = v.trim().replaceAll('@', '');
                          if (clean.length < 3) return 'Username must be at least 3 characters.';
                          if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(clean)) {
                            return 'Only letters, numbers, and underscores are allowed.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Email Field
                      Text(
                        'Email Address',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: labelTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter email address',
                          hintStyle: const TextStyle(
                            color: _hintColor,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: _hintColor,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: inputFill,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: const BorderSide(
                              color: _primaryBrand,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return 'Please enter your email address.';
                          final emailRegex = RegExp(r'^[\w.+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
                          if (!emailRegex.hasMatch(v)) return 'Enter a valid email address.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Phone Number (+234)
                      Text(
                        'Phone Number',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: labelTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // +234 country code dropdown
                          Container(
                            height: 58,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: inputFill,
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: '+234',
                                icon: Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: subtitleTextColor,
                                ),
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                                items: const [
                                  DropdownMenuItem(
                                    value: '+234',
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text('🇳🇬', style: TextStyle(fontSize: 18)),
                                        SizedBox(width: 4),
                                        Text('+234'),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (_) {},
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _phone,
                              keyboardType: TextInputType.number,
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: 15,
                              ),
                              decoration: InputDecoration(
                                hintText: '08012345678',
                                hintStyle: const TextStyle(
                                  color: _hintColor,
                                  fontSize: 14,
                                ),
                                filled: true,
                                fillColor: inputFill,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 18,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(28),
                                  borderSide: const BorderSide(
                                    color: _primaryBrand,
                                    width: 1.5,
                                  ),
                                ),
                              ),
                              validator: (value) {
                                final v = value?.trim() ?? '';
                                if (v.isEmpty) return 'Please enter your phone number.';
                                final digitsOnly = v.replaceAll(RegExp(r'\D'), '');
                                if (digitsOnly.startsWith('234') && digitsOnly.length == 13) {
                                  return 'Enter your 11-digit number (e.g. 0${digitsOnly.substring(3)}).';
                                }
                                if (digitsOnly.length == 10 && !digitsOnly.startsWith('0')) {
                                  return 'Add a leading 0 (e.g. 0$digitsOnly).';
                                }
                                if (digitsOnly.length != 11) {
                                  return 'Phone number must be exactly 11 digits.';
                                }
                                if (!digitsOnly.startsWith('0')) {
                                  return 'Phone number must start with 0 (e.g. 08012345678).';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Password Field
                      Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: labelTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _password,
                        obscureText: _obscurePassword,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter password',
                          hintStyle: const TextStyle(
                            color: _hintColor,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            color: _hintColor,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: inputFill,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 18,
                          ),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: _primaryBrand,
                                size: 22,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: const BorderSide(
                              color: _primaryBrand,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password.';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Country Dropdown Field
                      Text(
                        'Country',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: labelTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedCountry,
                        isExpanded: true,
                        dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Select Country',
                          hintStyle: const TextStyle(
                            color: _hintColor,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.public_rounded,
                            color: _hintColor,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: inputFill,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: const BorderSide(
                              color: _primaryBrand,
                              width: 1.5,
                            ),
                          ),
                        ),
                        items: _countries.map((country) {
                          return DropdownMenuItem<String>(
                            value: country,
                            child: Text(country),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null && val != _selectedCountry) {
                            setState(() {
                              _selectedCountry = val;
                              _selectedState = null;
                            });
                          }
                        },
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Please select your country.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // State Dropdown Field
                      Text(
                        'State',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: labelTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        key: ValueKey(_selectedCountry),
                        initialValue: _selectedState,
                        isExpanded: true,
                        dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Select State',
                          hintStyle: const TextStyle(
                            color: _hintColor,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.location_city_rounded,
                            color: _hintColor,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: inputFill,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: const BorderSide(
                              color: _primaryBrand,
                              width: 1.5,
                            ),
                          ),
                        ),
                        items: (_countryStates[_selectedCountry] ?? []).map((st) {
                          return DropdownMenuItem<String>(
                            value: st,
                            child: Text(st),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedState = val);
                        },
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Please select your state.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Referral Code Field
                      Text(
                        'Referral Code (Optional)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: labelTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _referralCode,
                        textCapitalization: TextCapitalization.characters,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter referral code if any',
                          hintStyle: const TextStyle(
                            color: _hintColor,
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.card_giftcard_outlined,
                            color: _hintColor,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: inputFill,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 18,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(28),
                            borderSide: const BorderSide(
                              color: _primaryBrand,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Terms and Conditions Checkbox Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _acceptTerms,
                              activeColor: _primaryBrand,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _acceptTerms = val ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const DriverTermsScreen(),
                                  ),
                                );
                              },
                              child: Text.rich(
                                TextSpan(
                                  text: 'I accept the ',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    color: subtitleTextColor,
                                  ),
                                  children: const [
                                    TextSpan(
                                      text: 'Terms & Conditions',
                                      style: TextStyle(
                                        color: _primaryBrand,
                                        fontWeight: FontWeight.w700,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryBrand,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Create Account',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Footer Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account ? ",
                            style: TextStyle(
                              fontSize: 14,
                              color: subtitleTextColor,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.go(DriverRoutePaths.login),
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _primaryBrand,
                              ),
                            ),
                          ),
                        ],
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
}
