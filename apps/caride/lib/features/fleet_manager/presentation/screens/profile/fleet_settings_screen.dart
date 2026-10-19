import 'dart:async';
import 'package:caride/app/theme_mode_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';

import 'package:caride/core/auth/auth_challenge.dart';
import 'package:caride/features/fleet_manager/auth/controllers/fleet_auth_controller.dart';
import 'package:caride/features/fleet_manager/auth/controllers/fleet_auth_error_helper.dart';
import 'package:caride/features/fleet_manager/auth/data/fleet_auth_repository.dart';
import 'package:caride/features/fleet_manager/controllers/fleet_manager_controller.dart';

/// Minimalist Fleet Manager Settings Screen strictly styled after UI/Profile.png and AGENTS.md,
/// featuring single-line menu items, consistent palette, clean typography, bottom sheet appearance, and zero clutter.
class FleetSettingsScreen extends StatefulWidget {
  const FleetSettingsScreen({super.key});

  @override
  State<FleetSettingsScreen> createState() => _FleetSettingsScreenState();
}

class _FleetSettingsScreenState extends State<FleetSettingsScreen> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  String? _bannerError;

  User? get _currentUser => _auth.currentUser;

  // ── Open Password Reset Flow Bottom Sheet ─────────────────────────────────

  void _showResetPasswordBottomSheet(bool isDark) {
    final email = _currentUser?.email;
    if (email == null || email.isEmpty) {
      _showError('No verified email address found for this account.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ResetPasswordSheet(
        email: email,
        isDark: isDark,
      ),
    );
  }

  void _showError(String message) {
    setState(() => _bannerError = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ── Security PIN Bottom Sheet ─────────────────────────────────────────────

  void _showSecurityPinBottomSheet(FleetProfile? profile, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SecurityPinSheet(
        profile: profile,
        isDark: isDark,
        onPinUpdated: () => setState(() {}),
      ),
    );
  }

  // ── Appearance Mode Bottom Sheet ─────────────────────────────────────────

  void _showAppearanceBottomSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AppearanceSheet(isDark: isDark),
    );
  }

  // ── Sign Out Confirmation Bottom Sheet ────────────────────────────────────

  void _showSignOutBottomSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cardBg = isDark ? AppColors.darkSurface : Colors.white;
        final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, color: AppColors.brand, size: 26),
              ),
              const SizedBox(height: 16),
              Text(
                'Sign Out',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: primaryTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to sign out from your Fleet Manager portal?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          'Cancel',
                          style: TextStyle(fontWeight: FontWeight.w600, color: primaryTextColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          fleetManagerController.reset();
                          await fleetAuthRepository.signOut();
                          if (!mounted) return;
                          context.go(CustomerRoutePaths.welcome);
                        },
                        child: const Text(
                          'Sign Out',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Delete Account (Soft Delete) Bottom Sheet ────────────────────────────

  void _showDeleteAccountBottomSheet(FleetProfile? profile, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cardBg = isDark ? AppColors.darkSurface : Colors.white;
        final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);

        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_forever_rounded, color: AppColors.error, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'Delete Fleet Account',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: primaryTextColor),
              ),
              const SizedBox(height: 10),
              Text(
                'This will deactivate your fleet partner profile and unpublish your vehicle listings. Data is safely archived per our standard policy.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _executeSoftDelete(profile);
                  },
                  child: const Text(
                    'Confirm Deactivate Account',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel & Keep Account',
                    style: TextStyle(fontWeight: FontWeight.w600, color: primaryTextColor),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _executeSoftDelete(FleetProfile? profile) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now().toIso8601String();
      final batch = _firestore.batch();

      if (profile != null && profile.fleetId.isNotEmpty) {
        final fleetRef = _firestore.collection('fleets').doc(profile.fleetId);
        batch.set(
          fleetRef,
          {
            'isDeleted': true,
            'deletedAt': now,
            'isActive': false,
            'verificationStatus': 'deactivated',
            'updatedAt': now,
          },
          SetOptions(merge: true),
        );
      }

      final managerRef = _firestore.collection('fleet_managers').doc(uid);
      batch.set(
        managerRef,
        {
          'isDeleted': true,
          'deletedAt': now,
          'isActive': false,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );

      await batch.commit();
      fleetManagerController.reset();
      await fleetAuthRepository.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Your fleet account has been deactivated.'),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      context.go(CustomerRoutePaths.welcome);
    } catch (e) {
      if (!mounted) return;
      _showError('Unable to deactivate account. Please try again later.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final currentTheme = customerThemeMode.value;

    String appearanceLabel = 'System Default';
    if (currentTheme == ThemeMode.light) appearanceLabel = 'Light';
    if (currentTheme == ThemeMode.dark) appearanceLabel = 'Dark';

    return ListenableBuilder(
      listenable: fleetAuthController,
      builder: (context, _) {
        final profile = fleetAuthController.currentProfile;
        final hasPin = profile?.hasSecurityPin ?? false;

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
          body: SafeArea(
            child: Column(
              children: [
                // ── Top Bar with Circular Back Button (AGENTS.md Rule 2) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          border: Border.all(color: borderColor),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.arrow_back, color: primaryTextColor, size: 20),
                          onPressed: () => context.pop(),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── In-View Error Banner (AGENTS.md Rule 3) ──
                if (_bannerError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.error),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _bannerError!,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B), fontWeight: FontWeight.w600),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => setState(() => _bannerError = null),
                            child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF991B1B)),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Settings Content (Single-Line Clean Menu Items per AGENTS.md Rule 4.2 / UI/Profile.png) ──
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: AppColors.brand))
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          children: [
                            // ── Card Group 1: Security ──
                            Container(
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                children: [
                                  _buildSingleLineMenuItem(
                                    icon: Icons.pin_rounded,
                                    title: 'Security PIN',
                                    trailingText: hasPin ? 'Active' : 'Setup',
                                    trailingColor: hasPin ? AppColors.brand : const Color(0xFFF59E0B),
                                    isDark: isDark,
                                    primaryTextColor: primaryTextColor,
                                    onTap: () => _showSecurityPinBottomSheet(profile, isDark),
                                  ),
                                  Divider(height: 1, color: borderColor),
                                  _buildSingleLineMenuItem(
                                    icon: Icons.lock_reset_rounded,
                                    title: 'Reset Password',
                                    isDark: isDark,
                                    primaryTextColor: primaryTextColor,
                                    onTap: () => _showResetPasswordBottomSheet(isDark),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── Card Group 2: Preferences ──
                            Container(
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: borderColor),
                              ),
                              child: Column(
                                children: [
                                  _buildSingleLineMenuItem(
                                    icon: Icons.palette_outlined,
                                    title: 'Appearance Mode',
                                    trailingText: appearanceLabel,
                                    isDark: isDark,
                                    primaryTextColor: primaryTextColor,
                                    onTap: () => _showAppearanceBottomSheet(isDark),
                                  ),
                                  Divider(height: 1, color: borderColor),
                                  _buildSingleLineMenuItem(
                                    icon: Icons.logout_rounded,
                                    title: 'Sign Out',
                                    isDark: isDark,
                                    primaryTextColor: primaryTextColor,
                                    onTap: () => _showSignOutBottomSheet(isDark),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                ),

                // ── Anchored Bottom: Delete Account (Soft Delete per AGENTS.md) ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  child: Center(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text(
                        'Delete Account',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      onPressed: () => _showDeleteAccountBottomSheet(profile, isDark),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSingleLineMenuItem({
    required IconData icon,
    required String title,
    required bool isDark,
    required Color primaryTextColor,
    required VoidCallback onTap,
    String? trailingText,
    Color? trailingColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isDark ? Colors.white : const Color(0xFF374151),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: trailingColor ?? (isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280)),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Multi-Step Password Reset Bottom Sheet Widget ─────────────────────────────

class _ResetPasswordSheet extends StatefulWidget {
  const _ResetPasswordSheet({
    required this.email,
    required this.isDark,
  });

  final String email;
  final bool isDark;

  @override
  State<_ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends State<_ResetPasswordSheet> {
  int _step = 1; // 1: OTP Code, 2: New Password, 3: Success

  // Step 1: Real OTP Challenge State
  AuthChallenge? _challenge;
  bool _isRequestingOtp = true;
  bool _isVerifyingOtp = false;
  final _otpController = TextEditingController();
  int _resendTimerSeconds = 45;
  Timer? _timer;
  bool _canResend = false;

  // Step 2: New Password State
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _sendOtpChallenge();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendCountdown() {
    _timer?.cancel();
    setState(() {
      _resendTimerSeconds = 45;
      _canResend = false;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimerSeconds > 1) {
        setState(() => _resendTimerSeconds--);
      } else {
        _timer?.cancel();
        setState(() => _canResend = true);
      }
    });
  }

  /// Sends a real OTP challenge to the user's email via Firebase Cloud Functions
  Future<void> _sendOtpChallenge() async {
    setState(() {
      _isRequestingOtp = true;
      _errorMessage = null;
    });

    try {
      final challenge = await fleetAuthRepository.requestEmailOtp(
        email: widget.email.trim(),
        isSignUp: false,
      );

      if (!mounted) return;
      setState(() {
        _challenge = challenge;
        _isRequestingOtp = false;
      });
      _startResendCountdown();
    } catch (e) {
      if (!mounted) return;
      final humanError = FleetAuthErrorHelper.parseError(e);
      setState(() {
        _errorMessage = humanError;
        _isRequestingOtp = false;
        _canResend = true;
      });
    }
  }

  void _handleResendCode() {
    if (!_canResend || _isRequestingOtp) return;
    _sendOtpChallenge();
  }

  // ── Step 1: Real OTP Verification ──
  Future<void> _handleVerifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code sent to your email.');
      return;
    }

    if (_challenge == null) {
      setState(() => _errorMessage = 'No active verification code found. Please tap Resend Code.');
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _errorMessage = null;
    });

    try {
      await fleetAuthRepository.verifyEmailOtp(
        challenge: _challenge!,
        code: code,
      );

      if (!mounted) return;
      setState(() {
        _isVerifyingOtp = false;
        _step = 2; // ONLY advances to new password when OTP is authentically verified!
      });
    } catch (e) {
      if (!mounted) return;
      final humanError = FleetAuthErrorHelper.parseError(e);
      setState(() {
        _isVerifyingOtp = false;
        _errorMessage = humanError;
      });
    }
  }

  // ── Password Strength Calculation ──
  double _calculatePasswordStrength(String password) {
    if (password.isEmpty) return 0.0;
    double strength = 0.0;
    if (password.length >= 8) strength += 0.25;
    if (password.contains(RegExp(r'[A-Z]')) && password.contains(RegExp(r'[a-z]'))) strength += 0.25;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.25;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.25;
    return strength;
  }

  String _getPasswordStrengthLabel(double strength) {
    if (strength <= 0.25) return 'Weak';
    if (strength <= 0.5) return 'Fair';
    if (strength <= 0.75) return 'Good';
    return 'Strong';
  }

  Color _getPasswordStrengthColor(double strength) {
    if (strength <= 0.25) return AppColors.error;
    if (strength <= 0.5) return const Color(0xFFF59E0B);
    if (strength <= 0.75) return const Color(0xFF3B82F6);
    return AppColors.brand;
  }

  // ── Step 2: Submit New Password ──
  Future<void> _handleUpdatePassword() async {
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (password.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters long.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Passwords do not match. Please re-enter.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'user-not-found',
          message: 'Active session not found. Please log in again.',
        );
      }

      await user.updatePassword(password);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _step = 3; // Success
      });
    } catch (e) {
      if (!mounted) return;
      final humanError = FleetAuthErrorHelper.parseError(e);
      setState(() {
        _isLoading = false;
        _errorMessage = humanError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark ? AppColors.darkSurface : Colors.white;
    final primaryTextColor = widget.isDark ? Colors.white : const Color(0xFF111827);
    final borderColor = widget.isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final inputFill = widget.isDark ? AppColors.darkBackground : const Color(0xFFF3F4F6);

    final strength = _calculatePasswordStrength(_passwordController.text);
    final strengthLabel = _getPasswordStrengthLabel(strength);
    final strengthColor = _getPasswordStrengthColor(strength);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Drag Handle (AGENTS.md Rule 2)
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: widget.isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── STEP 1: Enter OTP ──
            if (_step == 1) ...[
              Text(
                'Reset Password',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: primaryTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                'A 6-digit verification code has been dispatched to ${widget.email}. Please enter it below to verify your identity.',
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              if (_isRequestingOtp) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(color: AppColors.brand, strokeWidth: 2.5),
                        const SizedBox(height: 14),
                        Text(
                          'Sending verification code to ${widget.email}...',
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // OTP Input Field
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  decoration: BoxDecoration(
                    color: inputFill,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: _errorMessage != null ? AppColors.error : borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.key_rounded, color: AppColors.brand, size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          enabled: !_isVerifyingOtp,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: 4,
                          ),
                          decoration: const InputDecoration(
                            hintText: '• • • • • •',
                            border: InputBorder.none,
                            counterText: '',
                          ),
                          onChanged: (val) {
                            if (val.length == 6) {
                              _handleVerifyOtp();
                            }
                          },
                        ),
                      ),
                      if (_isVerifyingOtp)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: AppColors.brand, strokeWidth: 2),
                        ),
                    ],
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),

                // Resend Timer Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _canResend
                          ? "Didn't receive code?"
                          : 'Resend code in 00:${_resendTimerSeconds.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                      ),
                    ),
                    TextButton(
                      onPressed: _canResend ? _handleResendCode : null,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brand,
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('Resend Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    onPressed: _isVerifyingOtp ? null : _handleVerifyOtp,
                    child: _isVerifyingOtp
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Verify Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              ],
            ],

            // ── STEP 2: Input New Password ──
            if (_step == 2) ...[
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    onPressed: () => setState(() => _step = 1),
                  ),
                  Text(
                    'Set New Password',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: primaryTextColor),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Create a strong password with at least 8 characters.',
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 20),

              // New Password Field
              const Text('New Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: BoxDecoration(
                  color: inputFill,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 20, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(color: primaryTextColor, fontSize: 15, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          hintText: 'Enter new password',
                          border: InputBorder.none,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Live Password Strength Indicator
              if (_passwordController.text.isNotEmpty) ...[
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: strength,
                          minHeight: 6,
                          backgroundColor: widget.isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                          valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      strengthLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: strengthColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ],

              // Confirm Password Field
              const Text('Confirm New Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                decoration: BoxDecoration(
                  color: inputFill,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 20, color: Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: TextStyle(color: primaryTextColor, fontSize: 15, fontWeight: FontWeight.w600),
                        decoration: const InputDecoration(
                          hintText: 'Re-enter new password',
                          border: InputBorder.none,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: Colors.grey,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                    ),
                  ],
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.error),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: _isLoading ? null : _handleUpdatePassword,
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text('Update Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],

            // ── STEP 3: Success Screen ──
            if (_step == 3) ...[
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: AppColors.brand, size: 48),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text(
                  'Password Updated!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: primaryTextColor),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Your password has been changed successfully. You can now use this new password to sign in securely.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: widget.isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Security PIN Bottom Sheet Widget ──────────────────────────────────────────

class _SecurityPinSheet extends StatefulWidget {
  const _SecurityPinSheet({
    required this.profile,
    required this.isDark,
    required this.onPinUpdated,
  });

  final FleetProfile? profile;
  final bool isDark;
  final VoidCallback onPinUpdated;

  @override
  State<_SecurityPinSheet> createState() => _SecurityPinSheetState();
}

class _SecurityPinSheetState extends State<_SecurityPinSheet> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  String _mode = 'menu'; // 'menu', 'create', 'change', 'reset_otp', 'reset_new_pin'
  String _pin = '';
  String _confirmPin = '';
  String _currentPinInput = '';
  bool _isLoading = false;
  String? _errorMessage;

  // Real Reset PIN OTP State
  AuthChallenge? _resetChallenge;
  bool _isRequestingOtp = false;
  bool _isVerifyingOtp = false;
  final _otpController = TextEditingController();
  int _resendTimerSeconds = 45;
  Timer? _resendTimer;
  bool _canResend = false;

  bool get _hasPin => widget.profile?.hasSecurityPin ?? false;

  @override
  void initState() {
    super.initState();
    _mode = _hasPin ? 'menu' : 'create';
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  /// Sends a real OTP verification code to the manager's email for PIN reset
  Future<void> _sendResetPinOtp() async {
    final email = _auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      setState(() => _errorMessage = 'No verified email address found for this account.');
      return;
    }

    setState(() {
      _mode = 'reset_otp';
      _isRequestingOtp = true;
      _errorMessage = null;
      _otpController.clear();
    });

    try {
      final challenge = await fleetAuthRepository.requestEmailOtp(
        email: email.trim(),
        isSignUp: false,
      );

      if (!mounted) return;
      setState(() {
        _resetChallenge = challenge;
        _isRequestingOtp = false;
      });
      _startResendTimer();
    } catch (e) {
      if (!mounted) return;
      final humanError = FleetAuthErrorHelper.parseError(e);
      setState(() {
        _errorMessage = humanError;
        _isRequestingOtp = false;
        _canResend = true;
      });
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendTimerSeconds = 45;
      _canResend = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimerSeconds > 1) {
        setState(() => _resendTimerSeconds--);
      } else {
        _resendTimer?.cancel();
        setState(() => _canResend = true);
      }
    });
  }

  /// Verifies the 6-digit email OTP challenge with Cloud Functions backend
  Future<void> _verifyResetOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the 6-digit code sent to your email.');
      return;
    }

    if (_resetChallenge == null) {
      setState(() => _errorMessage = 'No active verification code found. Tap Resend Code.');
      return;
    }

    setState(() {
      _isVerifyingOtp = true;
      _errorMessage = null;
    });

    try {
      await fleetAuthRepository.verifyEmailOtp(
        challenge: _resetChallenge!,
        code: code,
      );

      if (!mounted) return;
      setState(() {
        _isVerifyingOtp = false;
        _mode = 'reset_new_pin';
        _pin = '';
        _confirmPin = '';
      });
    } catch (e) {
      if (!mounted) return;
      final humanError = FleetAuthErrorHelper.parseError(e);
      setState(() {
        _isVerifyingOtp = false;
        _errorMessage = humanError;
      });
    }
  }

  void _handleNumberPress(String digit) {
    setState(() {
      _errorMessage = null;
      if (_mode == 'create' || _mode == 'reset_new_pin') {
        if (_pin.length < 4) {
          _pin += digit;
        } else if (_confirmPin.length < 4) {
          _confirmPin += digit;
        }
      } else if (_mode == 'change') {
        if (_currentPinInput.length < 4) {
          _currentPinInput += digit;
        } else if (_pin.length < 4) {
          _pin += digit;
        } else if (_confirmPin.length < 4) {
          _confirmPin += digit;
        }
      }
    });
  }

  void _handleBackspace() {
    setState(() {
      _errorMessage = null;
      if (_mode == 'create' || _mode == 'reset_new_pin') {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      } else if (_mode == 'change') {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        } else if (_currentPinInput.isNotEmpty) {
          _currentPinInput = _currentPinInput.substring(0, _currentPinInput.length - 1);
        }
      }
    });
  }

  Future<void> _savePin() async {
    if (_pin.length != 4) {
      setState(() => _errorMessage = 'Please enter a 4-digit PIN');
      return;
    }
    if (_pin != _confirmPin) {
      setState(() {
        _errorMessage = 'PINs do not match. Please try again.';
        _confirmPin = '';
      });
      return;
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);
    try {
      final now = DateTime.now().toIso8601String();
      final batch = _firestore.batch();

      if (widget.profile != null && widget.profile!.fleetId.isNotEmpty) {
        batch.set(
          _firestore.collection('fleets').doc(widget.profile!.fleetId),
          {'securityPin': _pin, 'updatedAt': now},
          SetOptions(merge: true),
        );
      }

      batch.set(
        _firestore.collection('fleet_managers').doc(uid),
        {'securityPin': _pin, 'updatedAt': now},
        SetOptions(merge: true),
      );

      await batch.commit();
      widget.onPinUpdated();

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Text('Security PIN successfully updated!'),
            ],
          ),
          backgroundColor: AppColors.brand,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to save security PIN. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyAndChangePin() async {
    final existingPin = widget.profile?.securityPin;
    if (existingPin != null && existingPin != _currentPinInput) {
      setState(() {
        _errorMessage = 'Current PIN is incorrect.';
        _currentPinInput = '';
      });
      return;
    }
    await _savePin();
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = widget.isDark ? AppColors.darkSurface : Colors.white;
    final primaryTextColor = widget.isDark ? Colors.white : const Color(0xFF111827);
    final borderColor = widget.isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final inputFill = widget.isDark ? AppColors.darkBackground : const Color(0xFFF3F4F6);
    final email = _auth.currentUser?.email ?? 'your registered email';

    return Container(
      padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: widget.isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // ── Menu Mode ──
            if (_mode == 'menu') ...[
              Text(
                'Security PIN Settings',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: primaryTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Your 4-digit security PIN is required to authorize wallet withdrawals.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),

              _buildOptionCard(
                title: 'Change Security PIN',
                icon: Icons.lock_outline_rounded,
                isDark: widget.isDark,
                borderColor: borderColor,
                primaryTextColor: primaryTextColor,
                onTap: () {
                  setState(() {
                    _mode = 'change';
                    _pin = '';
                    _confirmPin = '';
                    _currentPinInput = '';
                  });
                },
              ),
              const SizedBox(height: 12),

              _buildOptionCard(
                title: 'Reset Security PIN via Email OTP',
                icon: Icons.refresh_rounded,
                isDark: widget.isDark,
                borderColor: borderColor,
                primaryTextColor: primaryTextColor,
                onTap: _sendResetPinOtp,
              ),
              const SizedBox(height: 20),
            ],

            // ── Reset PIN Step 1: Email OTP Input ──
            if (_mode == 'reset_otp') ...[
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    onPressed: () => setState(() => _mode = 'menu'),
                  ),
                  Text(
                    'Reset PIN Verification',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: primaryTextColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'A 6-digit security code was sent to $email. Enter code to authorize PIN reset.',
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              if (_isRequestingOtp) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.brand, strokeWidth: 2.5),
                  ),
                ),
              ] else ...[
                // OTP Field
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  decoration: BoxDecoration(
                    color: inputFill,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: _errorMessage != null ? AppColors.error : borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.key_rounded, color: AppColors.brand, size: 22),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          enabled: !_isVerifyingOtp,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: 4,
                          ),
                          decoration: const InputDecoration(
                            hintText: '• • • • • •',
                            border: InputBorder.none,
                            counterText: '',
                          ),
                          onChanged: (val) {
                            if (val.length == 6) {
                              _verifyResetOtp();
                            }
                          },
                        ),
                      ),
                      if (_isVerifyingOtp)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: AppColors.brand, strokeWidth: 2),
                        ),
                    ],
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Color(0xFF991B1B), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Resend Timer Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _canResend
                          ? "Didn't receive code?"
                          : 'Resend code in 00:${_resendTimerSeconds.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 13,
                        color: widget.isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                      ),
                    ),
                    TextButton(
                      onPressed: _canResend ? _sendResetPinOtp : null,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.brand,
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text('Resend Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    onPressed: _isVerifyingOtp ? null : _verifyResetOtp,
                    child: _isVerifyingOtp
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Verify Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              ],
            ],

            // ── Create, Change, or Reset New PIN Mode ──
            if (_mode == 'create' || _mode == 'change' || _mode == 'reset_new_pin') ...[
              Text(
                _mode == 'change'
                    ? (_currentPinInput.length < 4
                        ? 'Enter Current PIN'
                        : (_pin.length < 4 ? 'Enter New 4-Digit PIN' : 'Confirm New PIN'))
                    : (_mode == 'reset_new_pin'
                        ? (_pin.length < 4 ? 'Enter New Security PIN' : 'Confirm New Security PIN')
                        : (_pin.length < 4 ? 'Create 4-Digit PIN' : 'Confirm Your PIN')),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: primaryTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                _mode == 'change' && _currentPinInput.length < 4
                    ? 'Please authenticate with your existing security PIN'
                    : (_pin.length < 4
                        ? 'Choose a memorable 4-digit PIN for withdrawals'
                        : 'Re-enter your 4-digit PIN to confirm'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: widget.isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),

              // PIN Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final activeLength = _mode == 'change' && _currentPinInput.length < 4
                      ? _currentPinInput.length
                      : (_pin.length < 4 ? _pin.length : _confirmPin.length);
                  final filled = index < activeLength;

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? AppColors.brand : Colors.transparent,
                      border: Border.all(
                        color: filled
                            ? AppColors.brand
                            : (widget.isDark ? Colors.white38 : const Color(0xFFD1D5DB)),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.error),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 24),

              // Interactive Numeric Keypad
              _buildKeypad(widget.isDark, primaryTextColor),

              const SizedBox(height: 16),

              if ((_mode == 'create' && _pin.length == 4 && _confirmPin.length == 4) ||
                  (_mode == 'reset_new_pin' && _pin.length == 4 && _confirmPin.length == 4) ||
                  (_mode == 'change' &&
                      _currentPinInput.length == 4 &&
                      _pin.length == 4 &&
                      _confirmPin.length == 4)) ...[
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (_mode == 'change') {
                              _verifyAndChangePin();
                            } else {
                              _savePin();
                            }
                          },
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                          )
                        : const Text('Save Security PIN', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required String title,
    required IconData icon,
    required bool isDark,
    required Color borderColor,
    required Color primaryTextColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.brand, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: primaryTextColor),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: isDark ? Colors.white38 : const Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypad(bool isDark, Color primaryTextColor) {
    return Column(
      children: [
        for (var row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', 'backspace'],
        ])
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: row.map((key) {
                if (key.isEmpty) {
                  return const SizedBox(width: 72, height: 52);
                }
                if (key == 'backspace') {
                  return SizedBox(
                    width: 72,
                    height: 52,
                    child: IconButton(
                      onPressed: _handleBackspace,
                      icon: Icon(Icons.backspace_outlined, color: primaryTextColor, size: 22),
                    ),
                  );
                }
                return SizedBox(
                  width: 72,
                  height: 52,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _handleNumberPress(key);
                    },
                    borderRadius: BorderRadius.circular(26),
                    child: Center(
                      child: Text(
                        key,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

// ── Appearance Mode Bottom Sheet Widget ───────────────────────────────────────

class _AppearanceSheet extends StatelessWidget {
  const _AppearanceSheet({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final currentMode = customerThemeMode.value;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Appearance Mode',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: primaryTextColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how CaRide appears on your device.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 24),

          _buildThemeTile(
            title: 'System Default',
            icon: Icons.brightness_auto_rounded,
            isSelected: currentMode == ThemeMode.system,
            isDark: isDark,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            onTap: () {
              customerThemeMode.setTheme(ThemeMode.system);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 12),

          _buildThemeTile(
            title: 'Light Mode',
            icon: Icons.light_mode_rounded,
            isSelected: currentMode == ThemeMode.light,
            isDark: isDark,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            onTap: () {
              customerThemeMode.setTheme(ThemeMode.light);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 12),

          _buildThemeTile(
            title: 'Dark Mode',
            icon: Icons.dark_mode_rounded,
            isSelected: currentMode == ThemeMode.dark,
            isDark: isDark,
            borderColor: borderColor,
            primaryTextColor: primaryTextColor,
            onTap: () {
              customerThemeMode.setTheme(ThemeMode.dark);
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildThemeTile({
    required String title,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required Color borderColor,
    required Color primaryTextColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.brand : borderColor,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          color: isSelected
              ? (isDark ? AppColors.brand.withValues(alpha: 0.1) : const Color(0xFFF0FDF4))
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brand.withValues(alpha: 0.15)
                    : (isDark ? Colors.white10 : const Color(0xFFF3F4F6)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.brand : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? AppColors.brand : primaryTextColor,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle_rounded, color: AppColors.brand, size: 22),
          ],
        ),
      ),
    );
  }
}
