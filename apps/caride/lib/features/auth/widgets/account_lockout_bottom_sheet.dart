import 'dart:async';
import 'dart:io' show Platform;

import 'package:caride/core/auth/account_lockout_exception.dart';
import 'package:caride/core/auth/lockout_support_service.dart';
import 'package:caride/features/auth/locked_account_support_screen.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// Modal bottom sheet presenting account lockout status, live countdown timer,
/// direct password reset action, and in-app support chat actions.
class AccountLockoutBottomSheet extends StatefulWidget {
  const AccountLockoutBottomSheet({
    super.key,
    required this.lockout,
    this.role = 'customer',
    this.onResetPassword,
  });

  final AccountLockoutException lockout;
  final String role; // 'customer' | 'driver' | 'fleet'
  final VoidCallback? onResetPassword;

  /// Primary support recipient as specified for operations team
  static const String supportEmailPrimary = 'operations@caride.ng';
  static const String supportEmailAlias = 'opeations@caride.ng';

  /// Present the Account Lockout Bottom Sheet modally.
  static Future<void> show(
    BuildContext context, {
    required AccountLockoutException lockout,
    String role = 'customer',
    VoidCallback? onResetPassword,
  }) {
    return BottomSheetShell.show<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      child: AccountLockoutBottomSheet(
        lockout: lockout,
        role: role,
        onResetPassword: onResetPassword,
      ),
    );
  }

  @override
  State<AccountLockoutBottomSheet> createState() =>
      _AccountLockoutBottomSheetState();
}

class _AccountLockoutBottomSheetState extends State<AccountLockoutBottomSheet> {
  Timer? _countdownTimer;
  late int _remainingSeconds;
  bool _timerExpired = false;
  bool _openingEmail = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds =
        widget.lockout.remainingSeconds ??
        (widget.lockout.isManualOrPermanent ? 0 : 300);

    if (!widget.lockout.isManualOrPermanent && _remainingSeconds > 0) {
      _startCountdown();
    } else if (!widget.lockout.isManualOrPermanent && _remainingSeconds <= 0) {
      _timerExpired = true;
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds > 1) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _remainingSeconds = 0;
          _timerExpired = true;
        });
      }
    });
  }

  String _formatTime(int totalSeconds) {
    if (totalSeconds <= 0) return '00:00';
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _handleContactSupport() async {
    Navigator.of(context).pop();
    final userEmail = widget.lockout.email.trim();
    if (userEmail.isNotEmpty) {
      await LockoutSupportService.recordActiveLockout(
        role: widget.role,
        email: userEmail,
      );
    }
    if (!mounted) return;
    await LockedAccountSupportScreen.show(
      context,
      email: userEmail,
      role: widget.role,
      stageName: widget.lockout.stageName,
    );
  }

  void _handleResetPassword() {
    Navigator.of(context).pop();
    if (widget.onResetPassword != null) {
      widget.onResetPassword!();
      return;
    }
    final role = widget.role.trim().toLowerCase();
    if (role == 'driver') {
      context.push(DriverRoutePaths.forgotPassword);
    } else if (role == 'fleet') {
      context.push(FleetRoutePaths.forgotPassword);
    } else {
      context.push(CustomerRoutePaths.forgotPassword);
    }
  }

  Future<void> _handleEmailSupportFallback() async {
    setState(() => _openingEmail = true);
    final userEmail = widget.lockout.email.trim();
    final subject =
        'Account Lockout Support Request - ${userEmail.isNotEmpty ? userEmail : "CaRide User"}';
    final body =
        'Hello CaRide Operations Team,\n\n'
        'My account has reached the maximum failed login attempt limit and is currently locked for security.\n\n'
        'Account Email: ${userEmail.isNotEmpty ? userEmail : "Not provided"}\n'
        'Role: ${widget.role}\n'
        'Lockout Stage: ${widget.lockout.stageName ?? "Final Lockout / Manual Unlock Required"}\n'
        'Timestamp: ${DateTime.now().toLocal()}\n'
        'Device OS: ${Platform.operatingSystem}\n\n'
        'Please review my account and assist in restoring access.\n\n'
        'Thank you.';

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: AccountLockoutBottomSheet.supportEmailPrimary,
      query:
          'cc=${AccountLockoutBottomSheet.supportEmailAlias}'
          '&subject=${Uri.encodeComponent(subject)}'
          '&body=${Uri.encodeComponent(body)}',
    );

    try {
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(emailUri);
      }
    } catch (e) {
      debugPrint('[AccountLockout] Failed to launch email client: $e');
      await _copySupportEmail();
    } finally {
      if (mounted) {
        setState(() => _openingEmail = false);
      }
    }
  }

  Future<void> _copySupportEmail() async {
    await Clipboard.setData(
      const ClipboardData(text: AccountLockoutBottomSheet.supportEmailPrimary),
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Support email (operations@caride.ng) copied to clipboard.',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.brand,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isManual = widget.lockout.isManualOrPermanent;

    final primaryTextColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final subtitleTextColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;
    final accentColor = isManual ? AppColors.error : const Color(0xFFF59E0B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),

          // Security Icon Badge
          Center(
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.28),
                  width: 1.5,
                ),
              ),
              child: Icon(
                isManual
                    ? Icons.lock_person_rounded
                    : (_timerExpired
                          ? Icons.check_circle_outline_rounded
                          : Icons.lock_clock_rounded),
                size: 34,
                color: _timerExpired && !isManual
                    ? AppColors.success
                    : accentColor,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Title
          Text(
            isManual
                ? 'Account Locked'
                : (_timerExpired
                      ? 'Lockout Expired'
                      : 'Account Temporarily Locked'),
            textAlign: TextAlign.center,
            style: AppTextStyles.headlineSmall.copyWith(
              color: primaryTextColor,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Description
          Text(
            isManual
                ? 'You have reached the maximum number of failed login attempts. For security reasons, your account has been locked and requires administrative review to restore access.'
                : (_timerExpired
                      ? 'The temporary security lockout has expired. You may now attempt to sign in again with your credentials.'
                      : 'Too many consecutive failed login attempts were detected. For your protection, sign-in has been temporarily disabled.'),
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: subtitleTextColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Account identifier tag if known
          if (widget.lockout.email.trim().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_circle_outlined,
                    size: 16,
                    color: subtitleTextColor,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      widget.lockout.email.trim(),
                      style: AppTextStyles.caption.copyWith(
                        color: primaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // ─── Countdown Section (for temporary lockouts) ────────────────────
          if (!isManual) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                color:
                    (_timerExpired
                            ? AppColors.success
                            : const Color(0xFFF59E0B))
                        .withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color:
                      (_timerExpired
                              ? AppColors.success
                              : const Color(0xFFF59E0B))
                          .withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    _formatTime(_remainingSeconds),
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      color: _timerExpired
                          ? AppColors.success
                          : (isDark ? Colors.white : const Color(0xFFB45309)),
                      letterSpacing: 2.0,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _timerExpired
                        ? 'Ready to sign in'
                        : 'Lockout countdown remaining',
                    style: AppTextStyles.caption.copyWith(
                      color: _timerExpired
                          ? AppColors.success
                          : (isDark ? Colors.white70 : const Color(0xFF92400E)),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // ─── Last Account Lockout Section (Contact Support via Gmail/Mail) ───
          if (isManual) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: isDark ? 0.12 : 0.06),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 18,
                        color: AppColors.error,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Maximum Escalation Stage',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'To unlock this account, tap below to contact the Operations team directly with your registered details.',
                    style: AppTextStyles.caption.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Contact Support Button (Opens in-app chat direct with Admin Support)
            PrimaryButton(
              label: 'Contact Support',
              icon: Icons.chat_bubble_outline_rounded,
              onPressed: _handleContactSupport,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Email Fallback Link
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: _handleEmailSupportFallback,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.mail_outline_rounded,
                      size: 14,
                      color: isDark ? Colors.white70 : AppColors.brand,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Email Operations Support (${AccountLockoutBottomSheet.supportEmailPrimary})',
                      style: AppTextStyles.caption.copyWith(
                        color: isDark ? Colors.white70 : AppColors.brand,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],

          // ─── Action Buttons for Temporary Lockout ──────────────────────────
          if (!isManual) ...[
            // 1. Direct "Reset Password" button inside the lockout sheet itself
            PrimaryButton(
              label: 'Reset Forgotten Password',
              icon: Icons.lock_reset_rounded,
              onPressed: _handleResetPassword,
            ),
            const SizedBox(height: AppSpacing.sm),

            // 2. Try Signing In / Close
            SecondaryButton(
              label: _timerExpired ? 'Try Signing In' : 'Close',
              icon: _timerExpired ? Icons.arrow_forward_rounded : null,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Subtle help link for users who need immediate support
            TextButton(
              onPressed: _handleContactSupport,
              child: Text(
                'Need help? Chat with Operations Support',
                style: AppTextStyles.caption.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],

          // Close button for manual lockout
          if (isManual) ...[
            SecondaryButton(
              label: 'Dismiss',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
