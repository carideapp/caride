import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/features/driver/profile/driver_terms_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverSignupScreen extends StatefulWidget {
  const DriverSignupScreen({super.key});

  @override
  State<DriverSignupScreen> createState() => _DriverSignupScreenState();
}

class _DriverSignupScreenState extends State<DriverSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _referralCode = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  bool _acceptTerms = false;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _referralCode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_acceptTerms) {
      setState(() => _errorMessage = 'You must accept the Terms & Conditions to proceed.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final code = _referralCode.text.trim().isEmpty ? null : _referralCode.text.trim();
      await driverAuthController.signUpWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
        referralCode: code,
        fullName: null,
        phone: null,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('canceled') ||
        msg.contains('cancelled') ||
        msg.contains('sign_in_canceled') ||
        msg.contains('cancelled by user') ||
        msg.contains('googlesigninexceptioncode.canceled') ||
        msg.contains('12501')) {
      return 'Google sign-in was cancelled.';
    }

    if (e is FirebaseAuthException) {
      final message = (e.message ?? '').toLowerCase();
      switch (e.code) {
        case 'already-exists':
        case 'email-already-in-use':
          return 'An account with this email already exists. Please sign in.';
        case 'invalid-argument':
        case 'invalid-email':
          return 'Enter a valid email address.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'failed-precondition':
          if (message.contains('gmail credentials')) {
            return 'Email signup is not configured yet. Please contact support.';
          }
          return 'Signup is temporarily unavailable. Please try again shortly.';
        case 'unavailable':
        case 'internal':
        case 'deadline-exceeded':
          return 'Service is temporarily unavailable. Please try again.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
      }
    }

    if (msg.contains('already-exists') || msg.contains('already in use')) {
      return 'An account with this email already exists. Please sign in.';
    }
    if (msg.contains('network') ||
        msg.contains('connection') ||
        msg.contains('unexpected end of stream') ||
        msg.contains('okhttp') ||
        msg.contains('internal-error') ||
        msg.contains('internal error')) {
      return 'A connection error occurred. Please check your internet connection and try again.';
    }
    if (msg.contains('gmail credentials')) {
      return 'Email signup is not configured yet. Please contact support.';
    }
    return 'Unable to create account. Please try again.';
  }

  void _onBack() {
    context.go(CustomerRoutePaths.welcome);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        title: 'Drive with CaRide',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _onBack,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding,
          vertical: AppSpacing.xl,
        ),
        child: Form(
          key: _formKey,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: GlassSurface(
              radius: AppRadius.xxl,
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Create Account',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.headlineMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Sign up to get started as a driver',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  AppTextField(
                    controller: _email,
                    hint: 'Email Address',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    validator: FormValidators.email,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _password,
                    hint: 'Password',
                    obscureText: _obscurePassword,
                    prefixIcon: Icons.lock_outline_rounded,
                    suffix: GestureDetector(
                      onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                      child: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                        size: 20,
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required.';
                      if (v.length < 6) return 'Password must be at least 6 characters.';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppTextField(
                    controller: _referralCode,
                    hint: 'Referral Code (Optional)',
                    keyboardType: TextInputType.text,
                    prefixIcon: Icons.card_giftcard_outlined,
                    textCapitalization: TextCapitalization.characters,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    InlineError(message: _errorMessage!),
                  ],
                  const SizedBox(height: AppSpacing.md),

                  Row(
                    children: [
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _acceptTerms,
                          activeColor: AppColors.primaryGreen,
                          onChanged: (val) {
                            setState(() {
                              _acceptTerms = val ?? false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
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
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Terms & Conditions',
                                  style: const TextStyle(
                                    color: AppColors.primaryGreen,
                                    fontWeight: FontWeight.bold,
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
                  const SizedBox(height: AppSpacing.lg),

                  PrimaryButton(
                    label: 'Create Account',
                    isLoading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.go(DriverRoutePaths.login),
                        child: Text(
                          'Sign In',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.brand,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}
