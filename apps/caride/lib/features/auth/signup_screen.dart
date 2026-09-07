import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:caride/core/utils/auth_error_mapper.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

import 'package:caride/core/services/deep_link_service.dart';

/// Redesigned Customer Signup Screen featuring GlassAppBar, GlassSurface inputs, and clean styling.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _referredByController = TextEditingController();

  bool _loading = false;
  bool _agreedToTos = false;
  bool _obscurePassword = true;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _checkPendingReferralCode();
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
    _emailController.dispose();
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
      setState(() => _formError = 'You must agree to the terms');
      return;
    }
    setState(() => _loading = true);
    try {
      await customerAuthController.requestOtpForSignup(
        _emailController.text,
        _passwordController.text,
        _referredByController.text.trim(),
      );
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = Responsive.isTablet(context) || Responsive.isSmallTablet(context);
    final isLandscape = Responsive.isLandscape(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go(CustomerRoutePaths.welcome),
        ),
        title: 'Sign Up',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePadding,
          vertical: AppSpacing.lg,
        ),
        child: Form(
          key: _formKey,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isTablet || isLandscape ? 500 : double.infinity,
              ),
                child: GlassSurface(
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
                        'Sign up to get started as a passenger',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AppTextField(
                        controller: _emailController,
                        hint: 'Email Address',
                        obscureText: false,
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: (val) {
                          final v = val?.trim() ?? '';
                          if (v.isEmpty) {
                            return 'Email is required';
                          }
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _passwordController,
                        hint: 'Password',
                        obscureText: _obscurePassword,
                        prefixIcon: Icons.lock_outline_rounded,
                        suffix: GestureDetector(
                          onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                          child: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            size: 20,
                          ),
                        ),
                        validator: (val) {
                          final v = val ?? '';
                          if (v.isEmpty) {
                            return 'Password is required';
                          }
                          if (v.length < 6) {
                             return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _referredByController,
                        hint: 'Referral Code (Optional)',
                        obscureText: false,
                        prefixIcon: Icons.card_giftcard_rounded,
                        textCapitalization: TextCapitalization.characters,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Checkbox(
                            value: _agreedToTos,
                            onChanged: (v) => setState(() => _agreedToTos = v ?? false),
                            activeColor: AppColors.brand,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                  fontWeight: FontWeight.w500,
                                ),
                                children: [
                                  const TextSpan(text: 'I agree to CaRide '),
                                  TextSpan(
                                    text: 'Terms & Conditions.',
                                    style: TextStyle(
                                      color: AppColors.brand,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    recognizer: TapGestureRecognizer()..onTap = () {},
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_formError != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        InlineError(message: _formError!),
                      ],
                       PrimaryButton(
                        label: 'Sign Up',
                        isLoading: _loading,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Already have an account? ',
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.go(CustomerRoutePaths.login),
                            child: Text(
                              'Sign In',
                              style: AppTextStyles.bodyLarge.copyWith(
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
