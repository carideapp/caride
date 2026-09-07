import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:caride/core/utils/auth_error_mapper.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Forgot Password Screen with frosted glass recovery card and custom app bars.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      await customerAuthController.sendPasswordResetEmail(
        _email.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _sent = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapAuthErrorMessage(e))),
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
                      : 'Enter your email and we’ll send reset steps.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                GlassSurface(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!_sent) ...[
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
