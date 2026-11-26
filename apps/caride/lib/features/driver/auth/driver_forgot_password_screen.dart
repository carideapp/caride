import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/core/services/termii_service.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

enum _DriverRecoveryMethod { phone, email }

class DriverForgotPasswordScreen extends StatefulWidget {
  const DriverForgotPasswordScreen({super.key});

  @override
  State<DriverForgotPasswordScreen> createState() =>
      _DriverForgotPasswordScreenState();
}

class _DriverForgotPasswordScreenState
    extends State<DriverForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  _DriverRecoveryMethod _method = _DriverRecoveryMethod.phone;
  bool _loading = false;
  bool _sent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      if (_method == _DriverRecoveryMethod.phone) {
        await driverAuthController.requestPasswordResetPhoneOtp(_phone.text.trim());
        if (!mounted) return;
        setState(() => _loading = false);
        context.push(DriverRoutePaths.otp);
      } else {
        await driverAuthController.sendPasswordResetEmail(_email.text.trim());
        if (!mounted) return;
        setState(() {
          _loading = false;
          _sent = true;
        });
      }
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyError(e));
    } finally {
      if (mounted && !_sent && _method != _DriverRecoveryMethod.phone) {
        setState(() => _loading = false);
      }
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('not-found') || msg.contains('user-not-found') || msg.contains('no account')) {
      return _method == _DriverRecoveryMethod.phone
          ? 'No driver account found for this phone number.'
          : 'No driver account found for this email address.';
    }
    if (msg.contains('too-many-requests') || msg.contains('resource-exhausted')) {
      return 'Too many attempts. Please try again later.';
    }
    return e.toString().replaceAll('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        title: 'Recover Account',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(DriverRoutePaths.login);
            }
          },
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
            vertical: AppSpacing.xl,
          ),
          child: Form(
            key: _formKey,
            child: GlassSurface(
              radius: AppRadius.xxl,
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.brandGlass,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.brandGlassBorder),
                      ),
                      child: const Icon(
                        Icons.lock_reset_rounded,
                        color: AppColors.brand,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    _sent ? 'Check your email' : 'Recover your account',
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _sent
                        ? 'We\'ve sent reset instructions to your email. Please check your inbox and click the reset button.'
                        : _method == _DriverRecoveryMethod.phone
                            ? 'Enter your phone number to receive a 6-digit reset code via SMS.'
                            : 'Enter your email and we\'ll send you a password reset link.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Method Selector Toggle
                  if (!_sent) ...[
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _method = _DriverRecoveryMethod.phone;
                              _errorMessage = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: _method == _DriverRecoveryMethod.phone
                                    ? AppColors.brand
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                  color: _method == _DriverRecoveryMethod.phone
                                      ? AppColors.brand
                                      : (isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.phone_iphone_rounded,
                                    size: 18,
                                    color: _method == _DriverRecoveryMethod.phone
                                        ? Colors.white
                                        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Phone Number',
                                    style: AppTextStyles.labelLarge.copyWith(
                                      color: _method == _DriverRecoveryMethod.phone
                                          ? Colors.white
                                          : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _method = _DriverRecoveryMethod.email;
                              _errorMessage = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: _method == _DriverRecoveryMethod.email
                                    ? AppColors.brand
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                  color: _method == _DriverRecoveryMethod.email
                                      ? AppColors.brand
                                      : (isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    size: 18,
                                    color: _method == _DriverRecoveryMethod.email
                                        ? Colors.white
                                        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Email Address',
                                    style: AppTextStyles.labelLarge.copyWith(
                                      color: _method == _DriverRecoveryMethod.email
                                          ? Colors.white
                                          : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  if (!_sent) ...[
                    if (_method == _DriverRecoveryMethod.phone) ...[
                      AppTextField(
                        controller: _phone,
                        hint: 'Phone Number (e.g. 08012345678)',
                        keyboardType: TextInputType.phone,
                        prefixIcon: Icons.phone_outlined,
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Please enter your phone number.';
                          }
                          final clean = TermiiService.formatToLocal11Digits(val.trim());
                          if (clean.length != 11 || !clean.startsWith('0')) {
                            return 'Phone number must be 11 digits (e.g. 08012345678).';
                          }
                          return null;
                        },
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        InlineError(message: _errorMessage!),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(
                        label: 'Send verification code',
                        isLoading: _loading,
                        onPressed: _submit,
                      ),
                    ] else ...[
                      AppTextField(
                        controller: _email,
                        hint: 'Email Address',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: FormValidators.email,
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        InlineError(message: _errorMessage!),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(
                        label: 'Send reset link',
                        isLoading: _loading,
                        onPressed: _submit,
                      ),
                    ],
                  ] else ...[
                    PrimaryButton(
                      label: 'Back to Sign In',
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(DriverRoutePaths.login);
                        }
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
