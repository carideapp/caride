import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import '../../controllers/fleet_manager_controller.dart';

/// Redesigned Fleet Onboarding Setup Screen matching the design system.
class FleetOnboardingScreen extends StatefulWidget {
  const FleetOnboardingScreen({super.key});

  @override
  State<FleetOnboardingScreen> createState() => _FleetOnboardingScreenState();
}

class _FleetOnboardingScreenState extends State<FleetOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _regNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();

  String _selectedCity = 'Abuja';
  bool _isSubmitting = false;
  String? _error;

  static const _supportedCities = [
    'Abuja',
    'Lagos',
    'Port Harcourt',
    'Ibadan',
    'Kano',
    'Enugu',
    'Asaba',
    'Calabar',
  ];

  static const Color _lightInputFill = Color(0xFFF3F4F6);
  static const Color _labelColor = Color(0xFF1F2937);
  static const Color _hintColor = Color(0xFF9CA3AF);
  static const Color _subtitleColor = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    final profile = customerAuthController.currentProfile;
    if (profile != null) {
      _phoneController.text = profile.phone;
      _emailController.text = profile.email;
      _businessNameController.text = '${profile.fullName}\'s Fleet';
      _accountNameController.text = profile.fullName;
    }

    final existingFleet = fleetManagerController.currentProfile;
    if (existingFleet != null && existingFleet.fleetId.isNotEmpty) {
      _businessNameController.text = existingFleet.businessName;
      _regNumberController.text = existingFleet.registrationNumber;
      _phoneController.text = existingFleet.phone;
      _emailController.text = existingFleet.email;
      _addressController.text = existingFleet.address;
      _selectedCity = existingFleet.city.isNotEmpty ? existingFleet.city : 'Abuja';
      _bankNameController.text = existingFleet.bankName ?? '';
      _accountNumberController.text = existingFleet.accountNumber ?? '';
      _accountNameController.text = existingFleet.accountName ?? '';
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _regNumberController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _bankNameController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final existing = fleetManagerController.currentProfile;

      final fleetProfile = FleetProfile(
        fleetId: existing?.fleetId ?? '',
        ownerUid: uid,
        businessName: _businessNameController.text.trim(),
        registrationNumber: _regNumberController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
        address: _addressController.text.trim(),
        city: _selectedCity,
        bankName: _bankNameController.text.trim(),
        accountNumber: _accountNumberController.text.trim(),
        accountName: _accountNameController.text.trim(),
        isVerified: existing?.isVerified ?? false,
      );

      await fleetManagerController.saveFleetProfile(fleetProfile);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Fleet profile saved successfully!'),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      context.go(FleetRoutePaths.dashboard);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black;
    final labelTextColor = isDark ? AppColors.textPrimaryDark : _labelColor;
    final subtitleTextColor = isDark ? AppColors.textSecondaryDark : _subtitleColor;
    final inputFill = isDark ? AppColors.darkSurface : _lightInputFill;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Circular Back Button & Title
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
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Fleet Partner Setup',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        'Business Details',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set up your fleet operations profile to begin listing rental vehicles.',
                        style: TextStyle(
                          fontSize: 15,
                          color: subtitleTextColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 28),

                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // Business Info Section
                      const Text(
                        'Company Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brand,
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text('Fleet Business Name',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: labelTextColor)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _businessNameController,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        decoration: _pillInputDecoration(hint: 'e.g. Apex Luxury Fleet', fillColor: inputFill),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),

                      Text('CAC / Registration Number',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: labelTextColor)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _regNumberController,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        decoration: _pillInputDecoration(hint: 'e.g. RC-1234567', fillColor: inputFill),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),

                      Text('Operational City',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: labelTextColor)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
                        decoration: BoxDecoration(
                          color: inputFill,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCity,
                            isExpanded: true,
                            dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                            items: _supportedCities
                                .map((city) => DropdownMenuItem(
                                      value: city,
                                      child: Text(city, style: TextStyle(color: primaryTextColor, fontSize: 15)),
                                    ))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCity = val);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      Text('Business Address',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: labelTextColor)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _addressController,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        decoration: _pillInputDecoration(hint: 'e.g. Plot 102, CBD, Abuja', fillColor: inputFill),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 28),

                      // Contact Info Section
                      Divider(height: 32, color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
                      const Text(
                        'Contact Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brand,
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text('Phone Number',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: labelTextColor)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        decoration: _pillInputDecoration(hint: 'e.g. +234 801 234 5678', fillColor: inputFill),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 18),

                      Text('Email Address',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: labelTextColor)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        decoration: _pillInputDecoration(hint: 'e.g. ops@fleet.com', fillColor: inputFill),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 28),

                      // Payout Bank Section
                      Divider(height: 32, color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
                      const Text(
                        'Payout Bank Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brand,
                        ),
                      ),
                      const SizedBox(height: 14),

                      Text('Bank Name',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: labelTextColor)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _bankNameController,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        decoration: _pillInputDecoration(hint: 'e.g. Access Bank', fillColor: inputFill),
                      ),
                      const SizedBox(height: 18),

                      Text('Account Number',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: labelTextColor)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _accountNumberController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        decoration: _pillInputDecoration(hint: '10-digit NUBAN account number', fillColor: inputFill),
                      ),
                      const SizedBox(height: 18),

                      Text('Account Name',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: labelTextColor)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _accountNameController,
                        style: TextStyle(color: primaryTextColor, fontSize: 15),
                        decoration: _pillInputDecoration(hint: 'Name as registered with bank', fillColor: inputFill),
                      ),
                      const SizedBox(height: 36),

                      // Submit Button (Green Pill)
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
                          onPressed: _isSubmitting ? null : _submit,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Save & Continue',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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

  InputDecoration _pillInputDecoration({
    required String hint,
    required Color fillColor,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _hintColor, fontSize: 14),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
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
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
    );
  }
}
