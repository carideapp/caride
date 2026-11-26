import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:caride/core/services/termii_service.dart';
import 'package:design_system/design_system.dart';
import 'package:caride/core/utils/auth_error_mapper.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

enum _RecoveryMethod { phone, email }

/// Redesigned Forgot Password Screen with phone OTP and email reset options.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  _RecoveryMethod _method = _RecoveryMethod.phone;
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
      if (_method == _RecoveryMethod.phone) {
        await customerAuthController.requestPasswordResetPhoneOtp(_phone.text.trim());
        if (!mounted) return;
        setState(() => _loading = false);
        context.push(CustomerRoutePaths.otp);
      } else {
        await customerAuthController.sendPasswordResetEmail(
          _email.text.trim(),
        );
        if (!mounted) return;
        setState(() {
          _loading = false;
          _sent = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = mapAuthErrorMessage(e);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage ?? 'An error occurred. Please try again.')),
      );
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
        title: 'Reset Password',
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePadding,
                vertical: AppSpacing.md,
              ),
              children: [
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Recover access',
                  style: AppTextStyles.headlineLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _sent
                      ? 'Check your inbox for reset instructions.'
                      : _method == _RecoveryMethod.phone
                          ? 'Enter your phone number to receive a 6-digit reset code via SMS.'
                          : 'Enter your email and we’ll send password reset steps.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Method Selector Toggle
                if (!_sent) ...[
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _method = _RecoveryMethod.phone;
                            _errorMessage = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: _method == _RecoveryMethod.phone
                                  ? AppColors.brand
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: _method == _RecoveryMethod.phone
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
                                  color: _method == _RecoveryMethod.phone
                                      ? Colors.white
                                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Phone Number',
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: _method == _RecoveryMethod.phone
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
                            _method = _RecoveryMethod.email;
                            _errorMessage = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                            decoration: BoxDecoration(
                              color: _method == _RecoveryMethod.email
                                  ? AppColors.brand
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(
                                color: _method == _RecoveryMethod.email
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
                                  color: _method == _RecoveryMethod.email
                                      ? Colors.white
                                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Email Address',
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: _method == _RecoveryMethod.email
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
                  const SizedBox(height: AppSpacing.md),
                ],

                GlassSurface(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_sent) ...[
                        if (_method == _RecoveryMethod.phone) ...[
                          Text(
                            'Phone Number',
                            style: AppTextStyles.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          AppTextField(
                            controller: _phone,
                            hint: '08012345678',
                            obscureText: false,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
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
                          const SizedBox(height: AppSpacing.md),
                          PrimaryButton(
                            label: 'Send verification code',
                            isLoading: _loading,
                            onPressed: _submit,
                          ),
                        ] else ...[
                          Text(
                            'Email Address',
                            style: AppTextStyles.titleMedium,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          AppTextField(
                            controller: _email,
                            hint: 'name@example.com',
                            obscureText: false,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.done,
                            prefixIcon: Icons.email_outlined,
                            validator: FormValidators.email,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          PrimaryButton(
                            label: 'Send reset link',
                            isLoading: _loading,
                            onPressed: _submit,
                          ),
                        ],
                        if (_errorMessage != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          InlineError(message: _errorMessage!),
                        ],
                      ],
                      if (_sent) ...[
                        const Icon(
                          Icons.mark_email_read_outlined,
                          size: 48,
                          color: AppColors.brand,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        PrimaryButton(
                          label: 'Back to sign in',
                          onPressed: () => context.go(CustomerRoutePaths.login),
                        ),
                      ],
                    ],
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
