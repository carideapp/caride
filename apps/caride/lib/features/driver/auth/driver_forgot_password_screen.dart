import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

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
  bool _loading = false;
  bool _sent = false;
  String? _errorMessage;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await driverAuthController.sendPasswordResetEmail(_email.text.trim());
      if (!mounted) return;
      setState(() {
        _loading = false;
        _sent = true;
      });
    } on Exception catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = _friendlyError(e));
    } finally {
      if (mounted && !_sent) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString().toLowerCase();
    if (msg.contains('not-found') || msg.contains('user-not-found')) {
      return 'No account found for this email address.';
    }
    if (msg.contains('too-many-requests') || msg.contains('resource-exhausted')) {
      return 'Too many attempts. Please try again later.';
    }
    return 'Unable to send password reset email. Please try again.';
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
                        : 'Enter your email and we\'ll send you a password reset link.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  if (!_sent) ...[
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
