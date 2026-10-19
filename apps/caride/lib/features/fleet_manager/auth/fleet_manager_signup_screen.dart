import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

import '../../../../core/services/termii_service.dart';
import '../widgets/fleet_document_picker.dart';
import 'controllers/fleet_auth_controller.dart';
import 'controllers/fleet_auth_error_helper.dart';

/// Redesigned Fleet Manager Multi-step Signup Screen matching the design system.
class FleetManagerSignupScreen extends StatefulWidget {
  const FleetManagerSignupScreen({super.key});

  @override
  State<FleetManagerSignupScreen> createState() =>
      _FleetManagerSignupScreenState();
}

class _FleetManagerSignupScreenState extends State<FleetManagerSignupScreen> {
  // Step 1 Controllers
  final _accountFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralController = TextEditingController();

  // Step 3 Controllers
  final _infoFormKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _companyAddressController = TextEditingController();
  final _rcNumberController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _termsAccepted = false;
  bool _isSubmitting = false;
  String? _errorMessage;


  static const _idDocumentTypes = [
    'NIN Slip',
    'International Passport',
    'Voter\'s Card',
    'Driver\'s License',
  ];

  static const _genderOptions = ['Male', 'Female', 'Other'];

  static const Color _lightInputFill = Color(0xFFF3F4F6);
  static const Color _labelColor = Color(0xFF1F2937);
  static const Color _hintColor = Color(0xFF9CA3AF);
  static const Color _subtitleColor = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _initFromDraft();
    _loadPersistedDraft();
  }

  Future<void> _loadPersistedDraft() async {
    await fleetAuthController.restorePendingSession();
    await fleetAuthController.loadSignupDraft();
    if (mounted) {
      setState(() {
        _initFromDraft();
      });
    }
  }

  void _initFromDraft() {
    final c = fleetAuthController;
    _emailController.text = c.email;
    _phoneController.text = c.phone;
    _passwordController.text = c.password;
    _confirmPasswordController.text = c.confirmPassword;
    _referralController.text = c.referralCode;
    _termsAccepted = c.termsAccepted;
    _fullNameController.text = c.fullName;
    _companyNameController.text = c.companyName;
    _companyAddressController.text = c.companyAddress;
    _rcNumberController.text = c.rcNumber;
  }

  void _syncToDraft() {
    final c = fleetAuthController;
    c.email = _emailController.text.trim();
    c.phone = _phoneController.text.trim();
    c.password = _passwordController.text;
    c.confirmPassword = _confirmPasswordController.text;
    c.referralCode = _referralController.text.trim();
    c.termsAccepted = _termsAccepted;
    c.fullName = _fullNameController.text.trim();
    c.companyName = _companyNameController.text.trim();
    c.companyAddress = _companyAddressController.text.trim();
    c.rcNumber = _rcNumberController.text.trim();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralController.dispose();
    _fullNameController.dispose();
    _companyNameController.dispose();
    _companyAddressController.dispose();
    _rcNumberController.dispose();
    super.dispose();
  }

  // ── Step Navigation & Handlers ────────────────────────────────────────

  void _handleBackNavigation() {
    _syncToDraft();
    fleetAuthController.saveSignupDraft();
    if (fleetAuthController.currentSignupStep > 0) {
      setState(() {
        _errorMessage = null;
        fleetAuthController.previousStep();
        _initFromDraft();
      });
    } else {
      // Revert to Role Selector so user can choose another workspace
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(CustomerRoutePaths.roleSelector);
      }
    }
  }

  Future<void> _handleStep1Continue() async {
    if (!_accountFormKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      const msg = 'Please accept the Terms & Conditions to proceed.';
      setState(() => _errorMessage = msg);
      FleetAuthErrorHelper.showErrorSnackBar(context, msg);
      return;
    }

    _syncToDraft();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final activeChallenge = fleetAuthController.pendingChallenge;
      final cleanPhone = TermiiService.formatToLocal11Digits(_phoneController.text.trim());
      final cleanEmail = _emailController.text.trim().toLowerCase();
      final match = activeChallenge != null &&
          ((activeChallenge.isSms && activeChallenge.phone == cleanPhone) ||
           (!activeChallenge.isSms && activeChallenge.email.toLowerCase() == cleanEmail));

      if (!match) {
        await fleetAuthController.requestSignupOtp();
      }
      if (!mounted) return;

      final verified = await context.push<bool>(FleetRoutePaths.otp);
      if (verified == true && mounted) {
        setState(() {
          _initFromDraft();
        });
      }
    } catch (e) {
      if (!mounted) return;
      final parsed = FleetAuthErrorHelper.parseError(e);
      setState(() => _errorMessage = parsed);
      FleetAuthErrorHelper.showErrorSnackBar(context, parsed);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _handleStep2Continue() {
    _syncToDraft();
    // Save business type choice to Firestore progressively
    fleetAuthController.saveSignupDraft();
    setState(() {
      _errorMessage = null;
      fleetAuthController.setStep(2); // Step index 2 = Information
      _initFromDraft();
    });
  }

  void _handleStep3Continue() {
    if (!_infoFormKey.currentState!.validate()) return;

    if (fleetAuthController.identityDocumentFile == null) {
      const msg = 'Please upload a clear copy of your identity document.';
      setState(() => _errorMessage = msg);
      FleetAuthErrorHelper.showErrorSnackBar(context, msg);
      return;
    }

    if (fleetAuthController.businessType == 'company' &&
        fleetAuthController.cacDocumentFile == null) {
      const msg = 'Please upload the company CAC registration document.';
      setState(() => _errorMessage = msg);
      FleetAuthErrorHelper.showErrorSnackBar(context, msg);
      return;
    }

    _syncToDraft();
    // Save information & documents step data to Firestore progressively
    fleetAuthController.saveSignupDraft();
    setState(() {
      _errorMessage = null;
      fleetAuthController.setStep(3); // Step index 3 = Review
    });
  }

  Future<void> _handleSubmitApplication() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await fleetAuthController.submitFleetApplication();
      if (!mounted) return;
      context.go(FleetRoutePaths.registerSuccess);
    } catch (e) {
      if (!mounted) return;
      final parsed = FleetAuthErrorHelper.parseError(e);
      setState(() => _errorMessage = parsed);
      FleetAuthErrorHelper.showErrorSnackBar(context, parsed);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ── UI Builders ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black;
    final currentStep = fleetAuthController.currentSignupStep;

    return PopScope(
      canPop: currentStep == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar with Circular Back Button
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
                        onPressed: _handleBackNavigation,
                      ),
                    ),
                  ],
                ),
              ),

              // Step Content
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // Error alert
                    if (_errorMessage != null)
                      FleetAuthErrorHelper.buildErrorBanner(
                        message: _errorMessage!,
                        isDark: isDark,
                        onDismiss: () => setState(() => _errorMessage = null),
                      ),

                    if (currentStep == 0) _buildStep1Account(isDark, primaryTextColor),
                    if (currentStep == 1) _buildStep2BusinessType(isDark, primaryTextColor),
                    if (currentStep == 2) _buildStep3Information(isDark, primaryTextColor),
                    if (currentStep == 3) _buildStep4Review(isDark, primaryTextColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  // ── STEP 1: Account ───────────────────────────────────────────────────

  Widget _buildStep1Account(bool isDark, Color primaryTextColor) {
    final labelTextColor = isDark ? AppColors.textPrimaryDark : _labelColor;
    final subtitleTextColor = isDark ? AppColors.textSecondaryDark : _subtitleColor;
    final inputFill = isDark ? AppColors.darkSurface : _lightInputFill;

    return Form(
      key: _accountFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
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
          Text(
            'Enter your credentials to start managing vehicles and fleet operations with CaRide.',
            style: TextStyle(
              fontSize: 15,
              color: subtitleTextColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),

          // Email Address
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
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: primaryTextColor, fontSize: 15),
            decoration: _pillInputDecoration(
              hint: 'e.g. manager@fleetcompany.com',
              fillColor: inputFill,
              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF9CA3AF), size: 20),
            ),
            validator: (val) {
              final v = val?.trim() ?? '';
              if (v.isEmpty) return 'Please enter your email address.';
              final emailRegex = RegExp(r'^[\w.+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
              if (!emailRegex.hasMatch(v)) return 'Enter a valid email address.';
              return null;
            },
          ),
          const SizedBox(height: 18),

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
                  controller: _phoneController,
                  keyboardType: TextInputType.number,
                  style: TextStyle(color: primaryTextColor, fontSize: 15),
                  decoration: _pillInputDecoration(
                    hint: '08012345678',
                    fillColor: inputFill,
                  ),
                  validator: (value) {
                    final v = value?.trim() ?? '';
                    if (v.isEmpty) return 'Please enter your phone number.';
                    final digitsOnly = v.replaceAll(RegExp(r'\D'), '');
                    if (digitsOnly.length != 11) {
                      return 'Phone number must be exactly 11 digits.';
                    }
                    if (!digitsOnly.startsWith('0')) {
                      return 'Phone number must start with 0 (e.g. 0801...).';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Password
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
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: TextStyle(color: primaryTextColor, fontSize: 15),
            decoration: _pillInputDecoration(
              hint: 'At least 8 characters with numbers & symbols',
              fillColor: inputFill,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.brand,
                  size: 22,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            onChanged: (_) => setState(() {}),
            validator: (val) {
              if (val == null || val.length < 6) {
                return 'Password must be at least 6 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 6),
          _buildPasswordStrengthIndicator(_passwordController.text),
          const SizedBox(height: 18),

          // Confirm Password
          Text(
            'Confirm Password',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: labelTextColor,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: TextStyle(color: primaryTextColor, fontSize: 15),
            decoration: _pillInputDecoration(
              hint: 'Re-enter your password',
              fillColor: inputFill,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.brand,
                  size: 22,
                ),
                onPressed: () => setState(
                    () => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
            validator: (val) {
              if (val != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 18),

          // Referral Code (Optional)
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
            controller: _referralController,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(color: primaryTextColor, fontSize: 15),
            decoration: _pillInputDecoration(
              hint: 'e.g. CRD-98765',
              fillColor: inputFill,
            ),
          ),
          const SizedBox(height: 22),

          // Terms & Conditions Checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _termsAccepted,
                  activeColor: AppColors.brand,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  onChanged: (val) =>
                      setState(() => _termsAccepted = val ?? false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'I agree to the CaRide Fleet Terms of Service, Privacy Policy, and Operations Guidelines.',
                  style: TextStyle(
                    fontSize: 13,
                    color: subtitleTextColor,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Continue CTA (Green Pill)
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
              onPressed: _isSubmitting ? null : _handleStep1Continue,
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
                      'Continue',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 20),

          // Already have account ? Sign In
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Already have an account? ',
                style: TextStyle(
                  fontSize: 14,
                  color: subtitleTextColor,
                ),
              ),
              GestureDetector(
                onTap: () => context.push(FleetRoutePaths.login),
                child: const Text(
                  'Sign In',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brand,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator(String password) {
    int strength = 0;
    if (password.length >= 6) strength++;
    if (password.length >= 8) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;

    Color color;
    String label;
    if (strength <= 1) {
      color = AppColors.error;
      label = 'Weak';
    } else if (strength == 2 || strength == 3) {
      color = const Color(0xFFF59E0B);
      label = 'Medium';
    } else {
      color = AppColors.brand;
      label = 'Strong';
    }

    if (password.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: strength / 4,
              backgroundColor: Colors.black12,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // ── STEP 2: Business Type ─────────────────────────────────────────────

  Widget _buildStep2BusinessType(bool isDark, Color primaryTextColor) {
    final subtitleTextColor = isDark ? AppColors.textSecondaryDark : _subtitleColor;
    final selectedType = fleetAuthController.businessType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Business Structure',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: primaryTextColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the structure that best describes your fleet and vehicle operations.',
          style: TextStyle(
            fontSize: 15,
            color: subtitleTextColor,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),

        // Individual Card
        _buildBusinessTypeCard(
          title: 'Individual Operator',
          description: 'I operate vehicles independently under my personal name.',
          icon: Icons.person_rounded,
          isSelected: selectedType == 'individual',
          isDark: isDark,
          onTap: () {
            setState(() => fleetAuthController.businessType = 'individual');
          },
        ),
        const SizedBox(height: 16),

        // Company Card
        _buildBusinessTypeCard(
          title: 'Registered Company',
          description: 'I operate a registered transport or vehicle rental business.',
          icon: Icons.domain_rounded,
          isSelected: selectedType == 'company',
          isDark: isDark,
          onTap: () {
            setState(() => fleetAuthController.businessType = 'company');
          },
        ),
        const SizedBox(height: 36),

        // Continue Button (Green Pill)
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
            onPressed: _handleStep2Continue,
            child: const Text(
              'Continue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildBusinessTypeCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.brand.withValues(alpha: 0.08) : const Color(0xFFF0FDF4))
              : (isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.brand
                : (isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.12),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brand.withValues(alpha: 0.15)
                    : (isDark ? Colors.white10 : const Color(0xFFF3F4F6)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.brand : const Color(0xFF6B7280),
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: isSelected
                          ? AppColors.brand
                          : (isDark ? Colors.white : const Color(0xFF111827)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.brand : const Color(0xFFD1D5DB),
                  width: 2,
                ),
                color: isSelected ? AppColors.brand : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ── STEP 3: Information & Document Uploads ────────────────────────────

  Widget _buildStep3Information(bool isDark, Color primaryTextColor) {
    final labelTextColor = isDark ? AppColors.textPrimaryDark : _labelColor;
    final subtitleTextColor = isDark ? AppColors.textSecondaryDark : _subtitleColor;
    final inputFill = isDark ? AppColors.darkSurface : _lightInputFill;
    final isCompany = fleetAuthController.businessType == 'company';

    return Form(
      key: _infoFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            isCompany ? 'Company & Rep Info' : 'Personal Information',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Provide verified business details and documents for review and operational access.',
            style: TextStyle(
              fontSize: 15,
              color: subtitleTextColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),

          // ── Representative / Personal Info ──
          Text(
            isCompany ? 'Representative Details' : 'Owner Details',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(height: 14),

          Text('Full Name',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: labelTextColor)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _fullNameController,
            style: TextStyle(color: primaryTextColor, fontSize: 15),
            decoration: _pillInputDecoration(hint: 'e.g. Adebayo Ogunlesi', fillColor: inputFill),
            validator: (val) =>
                val == null || val.trim().isEmpty ? 'Full name is required' : null,
          ),
          const SizedBox(height: 18),

          Text('Phone Number',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: labelTextColor)),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: TextStyle(color: primaryTextColor, fontSize: 15),
            decoration: _pillInputDecoration(hint: 'e.g. +234 801 234 5678', fillColor: inputFill),
            validator: (val) => val == null || val.trim().isEmpty
                ? 'Phone number is required'
                : null,
          ),
          const SizedBox(height: 18),

          Text('Gender',
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
                value: fleetAuthController.gender,
                isExpanded: true,
                dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                items: _genderOptions
                    .map((g) => DropdownMenuItem(
                          value: g,
                          child: Text(g, style: TextStyle(color: primaryTextColor, fontSize: 15)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => fleetAuthController.gender = val);
                  }
                },
              ),
            ),
          ),

          // ── Registered Address for Individual Operator ──
          if (!isCompany) ...[
            const SizedBox(height: 18),
            Text('Residentail / Office address',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: labelTextColor)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _companyAddressController,
              style: TextStyle(color: primaryTextColor, fontSize: 15),
              decoration: _pillInputDecoration(
                hint: 'e.g. 14 Crescent Road, Wuse 2, Abuja',
                fillColor: inputFill,
              ),
              validator: (val) => val == null || val.trim().isEmpty
                  ? 'Registered address is required'
                  : null,
            ),
          ],

          const SizedBox(height: 24),

          // ── Company Details (If Company) ──
          if (isCompany) ...[
            Divider(height: 32, color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
            const Text(
              'Company Information',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 14),

            Text('Company Name',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: labelTextColor)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _companyNameController,
              style: TextStyle(color: primaryTextColor, fontSize: 15),
              decoration: _pillInputDecoration(hint: 'e.g. Apex Luxury Fleet Ltd', fillColor: inputFill),
              validator: (val) => val == null || val.trim().isEmpty
                  ? 'Company name is required'
                  : null,
            ),
            const SizedBox(height: 18),

            Text('RC Number',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: labelTextColor)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _rcNumberController,
              style: TextStyle(color: primaryTextColor, fontSize: 15),
              decoration: _pillInputDecoration(hint: 'e.g. RC-1234567', fillColor: inputFill),
              validator: (val) => val == null || val.trim().isEmpty
                  ? 'RC Number is required'
                  : null,
            ),
            const SizedBox(height: 18),

            Text('Full Company Address',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: labelTextColor)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _companyAddressController,
              style: TextStyle(color: primaryTextColor, fontSize: 15),
              decoration: _pillInputDecoration(
                hint: 'e.g. Plot 102, Central Business District, Abuja',
                fillColor: inputFill,
              ),
              validator: (val) => val == null || val.trim().isEmpty
                  ? 'Company address is required'
                  : null,
            ),
            const SizedBox(height: 24),
          ],

          Divider(height: 32, color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),

          // ── Identity Verification Document ──
          const Text(
            'Identity Verification',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.brand,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Select document type and upload a clear, legible photograph or scan.',
            style: TextStyle(
              fontSize: 13,
              color: subtitleTextColor,
            ),
          ),
          const SizedBox(height: 14),

          // Document Type Selector Dropdown (Pill)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
            decoration: BoxDecoration(
              color: inputFill,
              borderRadius: BorderRadius.circular(28),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: fleetAuthController.identityDocumentType,
                isExpanded: true,
                dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                items: _idDocumentTypes
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t, style: TextStyle(color: primaryTextColor, fontSize: 15)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(
                        () => fleetAuthController.identityDocumentType = val);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          FleetDocumentPicker(
            title: 'Upload ${fleetAuthController.identityDocumentType}',
            description:
                'Ensure your full name, photo, and ID number are clearly visible.',
            initialFile: fleetAuthController.identityDocumentFile,
            onFileSelected: (file) {
              setState(
                  () => fleetAuthController.identityDocumentFile = file);
            },
            onFileRemoved: () {
              setState(
                  () => fleetAuthController.identityDocumentFile = null);
            },
          ),
          const SizedBox(height: 20),

          // ── Company Documents (If Company) ──
          if (isCompany) ...[
            FleetDocumentPicker(
              title: 'Upload Company Logo',
              description:
                  'Upload your company or agency brand logo (PNG / JPG).',
              initialFile: fleetAuthController.companyLogoFile,
              onFileSelected: (file) {
                setState(
                    () => fleetAuthController.companyLogoFile = file);
              },
              onFileRemoved: () {
                setState(
                    () => fleetAuthController.companyLogoFile = null);
              },
            ),
            const SizedBox(height: 20),
            FleetDocumentPicker(
              title: 'Upload CAC Registration Document',
              description:
                  'Official CAC Certificate or Status Report for your company.',
              initialFile: fleetAuthController.cacDocumentFile,
              onFileSelected: (file) {
                setState(
                    () => fleetAuthController.cacDocumentFile = file);
              },
              onFileRemoved: () {
                setState(
                    () => fleetAuthController.cacDocumentFile = null);
              },
            ),
            const SizedBox(height: 20),
          ],

          const SizedBox(height: 24),

          // Review Information Button (Green Pill)
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
              onPressed: _handleStep3Continue,
              child: const Text(
                'Review Application',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── STEP 4: Review Before Submission ──────────────────────────────────

  Widget _buildStep4Review(bool isDark, Color primaryTextColor) {
    final c = fleetAuthController;
    final isCompany = c.businessType == 'company';
    final subtitleTextColor = isDark ? AppColors.textSecondaryDark : _subtitleColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          'Review Application',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: primaryTextColor,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Please verify that all details are accurate before submitting for review.',
          style: TextStyle(
            fontSize: 15,
            color: subtitleTextColor,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),

        // 1. Account Section
        _buildReviewCard(
          title: 'Account Credentials',
          isDark: isDark,
          primaryTextColor: primaryTextColor,
          onEdit: () {
            _syncToDraft();
            fleetAuthController.saveSignupDraft();
            setState(() {
              fleetAuthController.setStep(0);
              _initFromDraft();
            });
          },
          children: [
            _buildReviewRow('Email', c.email, isDark),
            if (c.referralCode.isNotEmpty)
              _buildReviewRow('Referral Code', c.referralCode, isDark),
          ],
        ),
        const SizedBox(height: 16),

        // 2. Business Type Section
        _buildReviewCard(
          title: 'Business Structure',
          isDark: isDark,
          primaryTextColor: primaryTextColor,
          onEdit: () {
            _syncToDraft();
            fleetAuthController.saveSignupDraft();
            setState(() {
              fleetAuthController.setStep(1);
            });
          },
          children: [
            _buildReviewRow(
              'Operating Mode',
              isCompany ? 'Registered Company' : 'Individual Operator',
              isDark,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // 3. Information Section
        _buildReviewCard(
          title: isCompany ? 'Company & Representative' : 'Personal Details',
          isDark: isDark,
          primaryTextColor: primaryTextColor,
          onEdit: () {
            _syncToDraft();
            fleetAuthController.saveSignupDraft();
            setState(() {
              fleetAuthController.setStep(2);
              _initFromDraft();
            });
          },
          children: [
            _buildReviewRow(
                isCompany ? 'Representative Name' : 'Full Name', c.fullName, isDark),
            _buildReviewRow('Phone Number', c.phone, isDark),
            if (c.gender != null) _buildReviewRow('Gender', c.gender!, isDark),
            if (isCompany) ...[
              _buildReviewRow('Company Name', c.companyName, isDark),
              _buildReviewRow('RC Number', c.rcNumber, isDark),
            ],
            if (c.companyAddress.isNotEmpty)
              _buildReviewRow(isCompany ? 'Company Address' : 'Residentail / Office address', c.companyAddress, isDark),
          ],
        ),
        const SizedBox(height: 16),

        // 4. Verification Documents Section
        _buildReviewCard(
          title: 'Verification Documents',
          isDark: isDark,
          primaryTextColor: primaryTextColor,
          onEdit: () => fleetAuthController.setStep(2),
          children: [
            _buildReviewRow(
              'Identity Document',
              c.identityDocumentFile != null
                  ? '${c.identityDocumentType} (Attached)'
                  : 'Missing',
              isDark,
              isSuccess: c.identityDocumentFile != null,
            ),
            if (isCompany) ...[
              _buildReviewRow(
                'Company Logo',
                c.companyLogoFile != null ? 'Official Logo (Attached)' : 'Not Attached',
                isDark,
                isSuccess: c.companyLogoFile != null,
              ),
              _buildReviewRow(
                'CAC Document',
                c.cacDocumentFile != null ? 'CAC Certificate (Attached)' : 'Missing',
                isDark,
                isSuccess: c.cacDocumentFile != null,
              ),
            ],
          ],
        ),
        const SizedBox(height: 32),

        // Submit Application Button (Green Pill)
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
            onPressed: _isSubmitting ? null : _handleSubmitApplication,
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
                    'Submit Application',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildReviewCard({
    required String title,
    required bool isDark,
    required Color primaryTextColor,
    required VoidCallback onEdit,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 20, color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value, bool isDark, {bool? isSuccess}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSuccess == true
                    ? AppColors.brand
                    : (isSuccess == false
                        ? AppColors.error
                        : (isDark ? Colors.white : const Color(0xFF111827))),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _pillInputDecoration({
    required String hint,
    required Color fillColor,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _hintColor, fontSize: 14),
      filled: true,
      fillColor: fillColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      prefixIcon: prefixIcon != null
          ? Padding(padding: const EdgeInsets.only(left: 8), child: prefixIcon)
          : null,
      suffixIcon: suffixIcon != null
          ? Padding(padding: const EdgeInsets.only(right: 8), child: suffixIcon)
          : null,
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
