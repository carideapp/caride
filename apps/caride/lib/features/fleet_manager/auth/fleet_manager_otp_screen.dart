import 'dart:async';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navigation/navigation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'controllers/fleet_auth_controller.dart';
import 'controllers/fleet_auth_error_helper.dart';

/// Redesigned Fleet Manager OTP Verification Screen matching the design system.
class FleetManagerOtpScreen extends StatefulWidget {
  const FleetManagerOtpScreen({super.key});

  @override
  State<FleetManagerOtpScreen> createState() => _FleetManagerOtpScreenState();
}

class _FleetManagerOtpScreenState extends State<FleetManagerOtpScreen> {
  static const int _otpLength = 6;
  static const int _timerSeconds = 60;

  final List<TextEditingController> _otpControllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(_otpLength, (_) => FocusNode());

  Timer? _timer;
  int _secondsRemaining = _timerSeconds;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  static const Color _lightInputFill = Color(0xFFF3F4F6);
  static const Color _subtitleColor = Color(0xFF6B7280);

  @override
  void initState() {
    super.initState();
    _initSessionAndCountdown();
  }

  Future<void> _initSessionAndCountdown() async {
    if (fleetAuthController.pendingChallenge == null) {
      final restored = await fleetAuthController.restorePendingSession();
      if (!restored && mounted) {
        setState(() => _errorMessage = 'Session expired. Please request a new OTP.');
      }
    }
    if (mounted) {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _timer?.cancel();
    final challenge = fleetAuthController.pendingChallenge;
    if (challenge != null) {
      final diff = challenge.expiresAt.difference(DateTime.now()).inSeconds;
      setState(() => _secondsRemaining = diff.clamp(0, _timerSeconds));
    } else {
      setState(() => _secondsRemaining = _timerSeconds);
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _openEmailApp() async {
    try {
      final mailtoUri = Uri.parse('mailto:');
      if (await canLaunchUrl(mailtoUri)) {
        await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[FleetManagerOtpScreen] Error opening email app: $e');
    }
  }

  void _onChangeEmail() {
    fleetAuthController.pendingChallenge = null;
    fleetAuthController.setStep(0);
    context.pop(false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _otpControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _enteredCode =>
      _otpControllers.map((c) => c.text.trim()).join();

  Future<void> _handleVerify() async {
    final code = _enteredCode;
    if (code.length != 6) {
      const msg = 'Please enter all 6 digits of the verification code.';
      setState(() => _errorMessage = msg);
      FleetAuthErrorHelper.showErrorSnackBar(context, msg);
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      await fleetAuthController.verifySignupOtp(code);
      if (!mounted) return;

      // OTP verified successfully -> move to Step 2 (Business Type) in Signup
      fleetAuthController.setStep(1);
      context.pop(true);
    } catch (e) {
      if (!mounted) return;
      final parsed = FleetAuthErrorHelper.parseError(e);
      setState(() {
        _errorMessage = parsed;
      });
      FleetAuthErrorHelper.showErrorSnackBar(context, parsed);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _handleResendPhone() async {
    if (_isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final challenge = fleetAuthController.pendingChallenge;
      if (challenge?.isSms == true) {
        await fleetAuthController.requestSignupOtp();
      } else {
        await fleetAuthController.switchToPhoneOtp();
      }
      _startCountdown();
      if (!mounted) return;
      final phone = fleetAuthController.phone;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A fresh verification code has been sent via SMS to $phone.'),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final parsed = FleetAuthErrorHelper.parseError(e);
      setState(() => _errorMessage = parsed);
      FleetAuthErrorHelper.showErrorSnackBar(context, parsed);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _handleSendEmail() async {
    if (_isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      await fleetAuthController.switchToEmailOtp();
      _startCountdown();
      if (!mounted) return;
      final email = fleetAuthController.email;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('A verification code has been sent to your email: $email.'),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final parsed = FleetAuthErrorHelper.parseError(e);
      setState(() => _errorMessage = parsed);
      FleetAuthErrorHelper.showErrorSnackBar(context, parsed);
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black;
    final subtitleTextColor = isDark ? AppColors.textSecondaryDark : _subtitleColor;
    final inputFill = isDark ? AppColors.darkSurface : _lightInputFill;
    final challenge = fleetAuthController.pendingChallenge;
    final isSms = challenge?.isSms == true;
    final destination = isSms ? (challenge?.phone ?? fleetAuthController.phone) : fleetAuthController.email;

    final formattedCountdown =
        '00:${_secondsRemaining.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Circular Back Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: primaryTextColor,
                      ),
                      onPressed: () => context.pop(false),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Title
                    Text(
                      'Verification',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      destination.isNotEmpty
                          ? 'Enter the 6-digit code sent to $destination'
                          : (isSms
                              ? 'Enter the code sent to your phone to verify your account.'
                              : 'Enter the code sent to your email to verify your account.'),
                      style: TextStyle(
                        fontSize: 15,
                        color: subtitleTextColor,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Leaving the app to copy the code won\'t reset your progress.',
                      style: TextStyle(
                        fontSize: 13,
                        color: subtitleTextColor,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Error Banner
                    if (_errorMessage != null)
                      FleetAuthErrorHelper.buildErrorBanner(
                        message: _errorMessage!,
                        isDark: isDark,
                        onDismiss: () => setState(() => _errorMessage = null),
                      ),

                    // 6-digit OTP Inputs (Circular / Pill Cells)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (index) {
                        return SizedBox(
                          width: 48,
                          height: 56,
                          child: TextFormField(
                            controller: _otpControllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 1,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: inputFill,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: const BorderSide(
                                  color: AppColors.brand,
                                  width: 1.5,
                                ),
                              ),
                            ),
                            onChanged: (val) {
                              if (val.isNotEmpty && index < 5) {
                                _focusNodes[index + 1].requestFocus();
                              } else if (val.isEmpty && index > 0) {
                                _focusNodes[index - 1].requestFocus();
                              }
                              if (_enteredCode.length == 6) {
                                _handleVerify();
                              }
                            },
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),

                    if (!isSms) ...[
                      const SizedBox(height: 16),
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
                    const SizedBox(height: 24),

                    // Resend Link / Countdown for current channel
                    Center(
                      child: _secondsRemaining > 0
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Didn't receive code? Resend in ",
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: subtitleTextColor,
                                  ),
                                ),
                                Text(
                                  formattedCountdown,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brand,
                                  ),
                                ),
                              ],
                            )
                          : GestureDetector(
                              onTap: _isResending ? null : (isSms ? _handleResendPhone : _handleSendEmail),
                              child: _isResending
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation(AppColors.brand),
                                      ),
                                    )
                                  : Text(
                                      isSms ? 'Resend code via Phone Number' : 'Resend code via Email',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.brand,
                                      ),
                                    ),
                            ),
                    ),
                    const SizedBox(height: 16),

                    // Alternative verification option (Phone <-> Email switch)
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: _isResending ? null : (isSms ? _handleSendEmail : _handleResendPhone),
                        icon: Icon(
                          isSms ? Icons.mark_email_read_outlined : Icons.phone_android_rounded,
                          size: 18,
                        ),
                        label: Text(
                          isSms ? 'Verify account via Email OTP' : 'Send code via SMS (Phone Number)',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.brand,
                          side: BorderSide(color: AppColors.brand.withValues(alpha: 0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // Verify Button (Green Pill)
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: _isVerifying ? null : _handleVerify,
                        child: _isVerifying
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Verify Code',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: _onChangeEmail,
                        child: Text(
                          isSms ? 'Wrong number? Change number' : 'Wrong email? Change email',
                          style: TextStyle(
                            fontSize: 13,
                            color: subtitleTextColor,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
