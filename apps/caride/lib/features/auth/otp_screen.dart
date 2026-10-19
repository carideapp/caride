import 'dart:async';

import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:caride/core/config/app_env.dart';
import 'package:caride/core/utils/auth_error_mapper.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

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
  static const int _resendDuration = 60;
  int _remainingSeconds = _resendDuration;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initSessionAndTimer();
  }

  Future<void> _initSessionAndTimer() async {
    if (customerAuthController.pendingChallenge == null) {
      final restored = await customerAuthController.restorePendingSession();
      if (!restored && mounted) {
        setState(() => _formError = 'Session expired. Please request a new OTP.');
      }
    }
    if (mounted) {
      _startResendTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;

    if (customerAuthController.pendingChallenge == null) {
      await customerAuthController.restorePendingSession();
    }

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
      setState(() => _formError = null);
      context.go(CustomerRoutePaths.home);
    } catch (error) {
      if (!mounted) return;
      final cooldown = extractCooldownSeconds(error);
      if (cooldown != null && cooldown > 0) {
        _startResendTimer(cooldownOverride: cooldown);
      }
      setState(() => _formError = mapAuthErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _startResendTimer({int? cooldownOverride}) {
    _timer?.cancel();
    int initialSeconds = cooldownOverride ?? _resendDuration;

    final lastSent = customerAuthController.lastOtpSentAt;
    if (cooldownOverride == null && lastSent != null) {
      final elapsed = DateTime.now().difference(lastSent).inSeconds;
      initialSeconds = (_resendDuration - elapsed).clamp(0, _resendDuration);
    }

    setState(() => _remainingSeconds = initialSeconds);
    if (initialSeconds <= 0) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        if (mounted) {
          setState(() => _remainingSeconds = 0);
        }
        return;
      }
      setState(() => _remainingSeconds -= 1);
    });
  }

  Future<void> _resendViaPhone() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _formError = null;
    });
    try {
      final challenge = customerAuthController.pendingChallenge;
      if (challenge?.isSms == true) {
        await customerAuthController.resendPendingOtp();
      } else {
        await customerAuthController.switchToPhoneOtp();
      }
      _codeController.clear();
      _startResendTimer();
      if (!mounted) return;
      final phone = customerAuthController.tempPhone ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification code sent via SMS to $phone'),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final cooldown = extractCooldownSeconds(error);
      if (cooldown != null && cooldown > 0) {
        _startResendTimer(cooldownOverride: cooldown);
      }
      setState(() => _formError = mapAuthErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _sendViaEmail() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _formError = null;
    });
    try {
      final challenge = customerAuthController.pendingChallenge;
      if (challenge?.isSms == false) {
        await customerAuthController.resendPendingOtp();
      } else {
        await customerAuthController.switchToEmailOtp();
      }
      _codeController.clear();
      _startResendTimer();
      if (!mounted) return;
      final email = customerAuthController.tempEmail ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification code sent to $email'),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final cooldown = extractCooldownSeconds(error);
      if (cooldown != null && cooldown > 0) {
        _startResendTimer(cooldownOverride: cooldown);
      }
      setState(() => _formError = mapAuthErrorMessage(error));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openEmailApp() async {
    try {
      final mailtoUri = Uri.parse('mailto:');
      if (await canLaunchUrl(mailtoUri)) {
        await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[OtpScreen] Error opening email app: $e');
    }
  }

  Future<void> _onBack() async {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(CustomerRoutePaths.signup);
    }
  }

  Future<void> _onChangeEmail() async {
    await customerAuthController.clearPendingChallenge();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(CustomerRoutePaths.signup);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final challenge = customerAuthController.pendingChallenge;
    final isSms = challenge?.isSms == true;
    final destination = isSms ? (challenge?.phone ?? '') : (challenge?.email ?? '');

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _onBack,
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
                      child: Icon(
                        isSms ? Icons.phone_android_rounded : Icons.mark_email_read_outlined,
                        color: AppColors.brand,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    isSms ? 'Check your phone' : 'Check your email',
                    style: AppTextStyles.headlineLarge.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    "We sent a ${AppEnv.otpCodeLength}-digit verification code to\n$destination",
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: Text(
                      'Leaving the app to copy the code won\'t reset your progress.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  PinInput(
                    length: AppEnv.otpCodeLength,
                    onCompleted: (v) {
                      _codeController.text = v;
                      if (!_loading) {
                        _submit();
                      }
                    },
                    errorText: _formError,
                  ),
                  if (!isSms) ...[
                    const SizedBox(height: AppSpacing.md),
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: _openEmailApp,
                        icon: const Icon(Icons.mail_outline_rounded, size: 18),
                        label: const Text('Open Email App', style: TextStyle(fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.brand,
                          side: BorderSide(color: AppColors.brand.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    label: 'Verify Code',
                    isLoading: _loading,
                    onPressed: _loading ? null : _submit,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: _remainingSeconds > 0
                        ? RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                              children: [
                                const TextSpan(
                                    text: 'You can resend the code in '),
                                TextSpan(
                                  text: '$_remainingSeconds',
                                  style: const TextStyle(
                                    color: AppColors.brand,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const TextSpan(text: ' seconds'),
                              ],
                            ),
                          )
                        : Text(
                            'You can request a new code now',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Primary resend action for current channel
                  Center(
                    child: TextButton.icon(
                      onPressed: (_remainingSeconds == 0 && !_loading)
                          ? (isSms ? _resendViaPhone : _sendViaEmail)
                          : null,
                      icon: Icon(
                        isSms ? Icons.sms_outlined : Icons.mail_outline_rounded,
                        size: 18,
                        color: _remainingSeconds == 0
                            ? AppColors.brand
                            : (isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight),
                      ),
                      label: Text(
                        isSms
                            ? 'Resend code via Phone Number'
                            : 'Resend code via Email',
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
                  const SizedBox(height: AppSpacing.sm),
                  // Alternative verification option (Phone <-> Email)
                  Center(
                    child: OutlinedButton.icon(
                      onPressed: (_remainingSeconds == 0 && !_loading)
                          ? (isSms ? _sendViaEmail : _resendViaPhone)
                          : null,
                      icon: Icon(
                        isSms
                            ? Icons.mark_email_read_outlined
                            : Icons.phone_android_rounded,
                        size: 18,
                      ),
                      label: Text(
                        isSms
                            ? 'Verify account via Email OTP'
                            : 'Send code via SMS (Phone Number)',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _remainingSeconds == 0
                            ? AppColors.brand
                            : (isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight),
                        side: BorderSide(
                          color: _remainingSeconds == 0
                              ? AppColors.brand.withValues(alpha: 0.5)
                              : (isDark
                                  ? AppColors.darkOutline
                                  : AppColors.lightOutline),
                        ),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Center(
                    child: TextButton(
                      onPressed: _onChangeEmail,
                      child: Text(
                        isSms ? 'Wrong number? Change number' : 'Wrong email? Change email',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          decoration: TextDecoration.underline,
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
