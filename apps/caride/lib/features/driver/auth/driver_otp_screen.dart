import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:caride/features/driver/auth/data/driver_profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:caride/core/utils/auth_error_mapper.dart';

class DriverOtpScreen extends StatefulWidget {
  const DriverOtpScreen({super.key});

  @override
  State<DriverOtpScreen> createState() => _DriverOtpScreenState();
}

class _DriverOtpScreenState extends State<DriverOtpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  bool _loading = false;
  String? _errorMessage;
  static const int _resendDuration = 60;
  int _remainingSeconds = _resendDuration;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initSessionAndTimer();
  }

  Future<void> _initSessionAndTimer() async {
    if (driverAuthController.pendingChallenge == null) {
      final restored = await driverAuthController.restorePendingSession();
      if (!restored && mounted) {
        setState(() => _errorMessage = 'Session expired. Please request a new OTP.');
      }
    }
    if (mounted) {
      _startResendTimer();
    }
  }

  void _startResendTimer({int? cooldownOverride}) {
    _timer?.cancel();
    int initialSeconds = cooldownOverride ?? _resendDuration;

    setState(() => _remainingSeconds = initialSeconds);
    if (initialSeconds <= 0) return;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _remainingSeconds = 0);
        return;
      }
      setState(() => _remainingSeconds -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    if (driverAuthController.pendingChallenge == null) {
      await driverAuthController.restorePendingSession();
    }

    final pendingChallenge = driverAuthController.pendingChallenge;
    if (pendingChallenge == null) {
      setState(() => _errorMessage = 'Session expired. Please request a new OTP.');
      return;
    }
    final isSignUp = pendingChallenge.isSignUp;
    final referralCode = driverAuthController.pendingReferralCode;
    final fullName = driverAuthController.pendingFullName;
    final phone = driverAuthController.pendingPhone;

    try {
      await driverAuthController.verifyPendingOtp(_code.text.trim());
      await customerAuthController.provisionRole('driver');

      if (!mounted) return;
      setState(() => _errorMessage = null);

      if (isSignUp) {
        await FirebaseFunctions.instance
            .httpsCallable('createDriverProfileCallable')
            .call(<String, dynamic>{
          if (referralCode != null) 'referredByCode': referralCode,
        });

        final uid = driverAuthController.currentUid;
        if (uid != null && (fullName != null || phone != null)) {
          await DriverProfileRepository().updateBasicInfo(
            uid: uid,
            fullName: fullName,
            phone: phone,
          );
        }
      }

      if (!mounted) return;
      if (isSignUp) {
        context.go(DriverRoutePaths.onboarding);
      } else {
        context.go(DriverRoutePaths.home);
      }
    } catch (e) {
      if (!mounted) return;
      final cooldown = extractCooldownSeconds(e);
      if (cooldown != null && cooldown > 0) {
        _startResendTimer(cooldownOverride: cooldown);
      }
      setState(() => _errorMessage = mapAuthErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }


  Future<void> _resendViaPhone() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final challenge = driverAuthController.pendingChallenge;
      if (challenge?.isSms == true) {
        await driverAuthController.resendPendingOtp();
      } else {
        await driverAuthController.switchToPhoneOtp();
      }
      _startResendTimer();
      if (!mounted) return;
      final phone = driverAuthController.pendingPhone ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification code sent via SMS to $phone'),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final cooldown = extractCooldownSeconds(e);
      if (cooldown != null && cooldown > 0) {
        _startResendTimer(cooldownOverride: cooldown);
      }
      setState(() => _errorMessage = mapAuthErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendViaEmail() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final challenge = driverAuthController.pendingChallenge;
      if (challenge?.isSms == false) {
        await driverAuthController.resendPendingOtp();
      } else {
        await driverAuthController.switchToEmailOtp();
      }
      _startResendTimer();
      if (!mounted) return;
      final email = driverAuthController.pendingEmail ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification code sent to $email'),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final cooldown = extractCooldownSeconds(e);
      if (cooldown != null && cooldown > 0) {
        _startResendTimer(cooldownOverride: cooldown);
      }
      setState(() => _errorMessage = mapAuthErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEmailApp() async {
    try {
      final mailtoUri = Uri.parse('mailto:');
      if (await canLaunchUrl(mailtoUri)) {
        await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[DriverOtpScreen] Error opening email app: $e');
    }
  }

  Future<void> _onChangeEmail() async {
    await driverAuthController.clearPendingChallenge();
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(DriverRoutePaths.signup);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final challenge = driverAuthController.pendingChallenge;
    final isSms = challenge?.isSms == true;
    final destination = isSms ? (challenge?.phone ?? '') : (challenge?.email ?? '');

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        title: 'Verify Code',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            driverAuthController.clearPendingChallenge();
            if (context.canPop()) context.pop();
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
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'We sent a 6-digit verification code to\n$destination',
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
                    length: 6,
                    onCompleted: (v) {
                      _code.text = v;
                      if (!_loading) {
                        _verify();
                      }
                    },
                    errorText: _errorMessage,
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
                    onPressed: _loading ? null : _verify,
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
