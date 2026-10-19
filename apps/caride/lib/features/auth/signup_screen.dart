import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:caride/core/auth/pending_otp_session.dart';
import 'package:caride/core/services/deep_link_service.dart';
import 'package:caride/core/utils/auth_error_mapper.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

/// Redesigned Customer Signup Screen matching the modern pill-styled minimalist aesthetic.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referredByController = TextEditingController();

  bool _loading = false;
  bool _agreedToTos = false;
  bool _obscurePassword = true;
  String? _formError;
  String? _pendingSessionEmail;

  static const Color _primaryBrand = AppColors.brand; // Color(0xFF16A34A)
  static const Color _lightInputFill = Color(0xFFF3F4F6);
  static const Color _labelColor = Color(0xFF1F2937);
  static const Color _hintColor = Color(0xFF9CA3AF);
  static const Color _subtitleColor = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _checkPendingReferralCode();
    _checkPendingOtpSession();
  }

  Future<void> _checkPendingOtpSession() async {
    final session = await PendingOtpSessionService.instance.loadSession(roleFilter: 'customer');
    if (session != null && mounted) {
      setState(() {
        _pendingSessionEmail = session.challenge.isSms
            ? (session.phone ?? session.challenge.phone ?? '')
            : session.challenge.email;
        if (_emailController.text.isEmpty && session.email != null) {
          _emailController.text = session.email!;
        }
        if (_phoneController.text.isEmpty && session.phone != null) {
          _phoneController.text = session.phone!;
        }
        if (_fullNameController.text.isEmpty && session.fullName != null) {
          _fullNameController.text = session.fullName!;
        }
      });
    } else {
      final draft = await PendingOtpSessionService.instance.loadDraft('customer');
      if (draft != null && mounted) {
        if (_fullNameController.text.isEmpty && draft['fullName'] != null) {
          _fullNameController.text = draft['fullName'] as String;
        }
        if (_emailController.text.isEmpty && draft['email'] != null) {
          _emailController.text = draft['email'] as String;
        }
        if (_phoneController.text.isEmpty && draft['phone'] != null) {
          _phoneController.text = draft['phone'] as String;
        }
        if (_referredByController.text.isEmpty && draft['referredBy'] != null) {
          _referredByController.text = draft['referredBy'] as String;
        }
      }
    }
  }

  Future<void> _checkPendingReferralCode() async {
    final code = await DeepLinkService.instance.getOrFetchPendingReferralCode();
    if (code != null && code.isNotEmpty && mounted) {
      setState(() {
        _referredByController.text = code;
      });
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _referredByController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _formError = null);
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (!_agreedToTos) {
      setState(() => _formError = 'You must agree to the Terms & Conditions to proceed.');
      return;
    }

    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();

    if (_pendingSessionEmail != null) {
      final restored = await customerAuthController.restorePendingSession();
      if (restored && mounted) {
        context.push(CustomerRoutePaths.otp);
        return;
      }
    }

    final fullNameTrimmed = _fullNameController.text.trim();
    setState(() => _loading = true);
    try {
      await customerAuthController.requestOtpForSignup(
        phone,
        email,
        _passwordController.text,
        _referredByController.text.trim(),
        fullNameTrimmed,
      );
      await PendingOtpSessionService.instance.saveDraft('customer', {
        'fullName': fullNameTrimmed,
        'email': email,
        'phone': phone,
        'referredBy': _referredByController.text.trim(),
      });
      if (!mounted) return;
      context.push(CustomerRoutePaths.otp);
    } catch (error) {
      if (!mounted) return;
      setState(() => _formError = mapAuthErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
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
                        'Sign up to get started as a passenger',
                        style: TextStyle(
                          fontSize: 15,
                          color: subtitleTextColor,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 32),

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
                                        final router = GoRouter.of(context);
                                        await customerAuthController.restorePendingSession();
                                        if (mounted) router.push(CustomerRoutePaths.otp);
                                      },
                                      child: const Text('Enter Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () async {
                                      await customerAuthController.clearPendingChallenge();
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

                      // Error message banner if any
                      if (_formError != null) ...[
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
                                  _formError!,
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

                      // Field 1: Full Name
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
                        controller: _fullNameController,
                        textCapitalization: TextCapitalization.words,
                        keyboardType: TextInputType.name,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter full name (First & Last)',
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
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) {
                            return 'Please enter your full name.';
                          }
                          if (v.length < 2) {
                            return 'Name must be at least 2 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Field 2: Email Address
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

                      // Field 3: Phone Number (+234)
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
                      const SizedBox(height: 20),

                      // Field 3: Password
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
                          final v = value ?? '';
                          if (v.isEmpty) {
                            return 'Please enter a password.';
                          }
                          if (v.length < 6) {
                            return 'Password must be at least 6 characters.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Field 4: Referral Code (Optional)
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
                        controller: _referredByController,
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
                              value: _agreedToTos,
                              activeColor: _primaryBrand,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  _agreedToTos = val ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: subtitleTextColor,
                                ),
                                children: [
                                  const TextSpan(text: 'I agree to CaRide '),
                                  TextSpan(
                                    text: 'Terms & Conditions.',
                                    style: const TextStyle(
                                      color: _primaryBrand,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        context.push(CustomerRoutePaths.legal);
                                      },
                                  ),
                                ],
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
                                  'Sign Up',
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
                            onTap: () => context.go(CustomerRoutePaths.login),
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
