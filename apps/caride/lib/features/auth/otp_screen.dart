import 'dart:async';

import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:caride/core/config/app_env.dart';
import 'package:caride/core/utils/auth_error_mapper.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer OTP Screen using PinInput, GlassAppBar, and GlassSurface.
class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _formError;
  static const int _resendDuration = 56;
  int _remainingSeconds = _resendDuration;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (customerAuthController.pendingChallenge == null) {
      setState(() => _formError = 'Session expired. Please request a new OTP.');
      return;
    }

    setState(() {
      _loading = true;
      _formError = null;
    });
    try {
      await customerAuthController.verifyPendingOtp(_codeController.text.trim());
      if (!mounted) return;
      context.go(CustomerRoutePaths.home);
    } catch (error) {
      if (!mounted) return;
      setState(() => _formError = mapAuthErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _remainingSeconds = _resendDuration);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _remainingSeconds <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => _remainingSeconds = 0);
        }
        return;
      }
      setState(() => _remainingSeconds -= 1);
    });
  }

  Future<void> _resend() async {
    final pending = customerAuthController.pendingChallenge;
    if (pending == null || _remainingSeconds > 0) return;
    setState(() {
      _loading = true;
      _formError = null;
    });
    try {
      if (pending.isSignUp) {
        await customerAuthController.requestOtpForSignup(pending.email);
      } else {
        await customerAuthController.requestOtpForLogin(pending.email);
      }
      _codeController.clear();
      _startResendTimer();
    } catch (error) {
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
    final challenge = customerAuthController.pendingChallenge;
    final email = challenge?.email ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: 'Verify OTP',
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
                        Icons.mark_email_read_outlined,
                        color: AppColors.brand,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Check your email',
                    style: AppTextStyles.headlineLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    "We sent a ${AppEnv.otpCodeLength}-digit verification code to\n$email",
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl * 1.5),
                  PinInput(
                    length: AppEnv.otpCodeLength,
                    onCompleted: (v) {
                      _codeController.text = v;
                      _submit();
                    },
                    errorText: _formError,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Verify Code',
                    isLoading: _loading,
                    onPressed: _submit,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        children: [
                          const TextSpan(text: 'You can resend the code in '),
                          TextSpan(
                            text: '$_remainingSeconds',
                            style: TextStyle(
                              color: AppColors.brand,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(text: ' seconds'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: TextButton(
                      onPressed: _remainingSeconds == 0 ? _resend : null,
                      child: Text(
                        'Resend code',
                        style: AppTextStyles.titleSmall.copyWith(
                          color: _remainingSeconds == 0
                              ? AppColors.brand
                              : (isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
