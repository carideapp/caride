import 'package:cloud_functions/cloud_functions.dart';
import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:caride/features/driver/auth/data/driver_profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

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

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final pendingChallenge = driverAuthController.pendingChallenge;
    final isSignUp = pendingChallenge?.isSignUp ?? false;
    final referralCode = driverAuthController.pendingReferralCode;
    final fullName = driverAuthController.pendingFullName;
    final phone = driverAuthController.pendingPhone;

    try {
      await driverAuthController.verifyPendingOtp(_code.text.trim());
      await customerAuthController.provisionRole('driver');

      if (!mounted) return;

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
      setState(() => _errorMessage = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyError(Object e) {
    final msg = e.toString();
    if (msg.contains('permission-denied') || msg.contains('incorrect')) {
      return 'Incorrect code. Please try again.';
    }
    if (msg.contains('expired') || msg.contains('deadline')) {
      return 'Your code has expired. Please request a new one.';
    }
    if (msg.contains('resource-exhausted')) {
      return 'Too many attempts. Please request a new code.';
    }
    return 'Error: ${e.toString()}';
  }

  Future<void> _resend() async {
    final challenge = driverAuthController.pendingChallenge;
    if (challenge == null) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      if (challenge.isSignUp) {
        await driverAuthController.requestOtpForSignup(challenge.email);
      } else {
        await driverAuthController.requestOtpForLogin(challenge.email);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New code sent to your email.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to resend code.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final challenge = driverAuthController.pendingChallenge;
    final email = challenge?.email ?? '';

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
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'We sent a 6-digit verification code to\n$email',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl * 1.5),

                  PinInput(
                    length: 6,
                    onCompleted: (v) {
                      _code.text = v;
                      _verify();
                    },
                    errorText: _errorMessage,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  PrimaryButton(
                    label: 'Verify Code',
                    isLoading: _loading,
                    onPressed: _verify,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: TextButton(
                      onPressed: _loading ? null : _resend,
                      child: Text(
                        'Resend code',
                        style: AppTextStyles.titleSmall.copyWith(color: AppColors.brand),
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
