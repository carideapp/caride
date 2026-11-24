import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:caride/core/auth/account_lockout_exception.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// Modal bottom sheet presenting account lockout status, live countdown timer,
/// and support contact actions for final security lockouts.
class AccountLockoutBottomSheet extends StatefulWidget {
  const AccountLockoutBottomSheet({
    super.key,
    required this.lockout,
  });

  final AccountLockoutException lockout;

  /// Primary support recipient as specified for operations team
  static const String supportEmailPrimary = 'operations@caride.ng';
  static const String supportEmailAlias = 'opeations@caride.ng';

  /// Present the Account Lockout Bottom Sheet modally.
  static Future<void> show(
    BuildContext context, {
    required AccountLockoutException lockout,
  }) {
    return BottomSheetShell.show<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      child: AccountLockoutBottomSheet(lockout: lockout),
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
    _remainingSeconds = widget.lockout.remainingSeconds ??
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
    setState(() => _openingEmail = true);
    final userEmail = widget.lockout.email.trim();
    final subject = 'Account Lockout Support Request - ${userEmail.isNotEmpty ? userEmail : "CaRide User"}';
    final body = 'Hello CaRide Operations Team,\n\n'
        'My account has reached the maximum failed login attempt limit and is currently locked for security.\n\n'
        'Account Email: ${userEmail.isNotEmpty ? userEmail : "Not provided"}\n'
        'Lockout Stage: ${widget.lockout.stageName ?? "Final Lockout / Manual Unlock Required"}\n'
        'Timestamp: ${DateTime.now().toLocal()}\n'
        'Device OS: ${Platform.operatingSystem}\n\n'
        'Please review my account and assist in restoring access.\n\n'
        'Thank you.';

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: AccountLockoutBottomSheet.supportEmailPrimary,
      query: 'cc=${AccountLockoutBottomSheet.supportEmailAlias}'
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
            Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 18),
            SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Support email (operations@caride.ng) copied to clipboard.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
    final subtitleTextColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
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
                color: (_timerExpired ? AppColors.success : const Color(0xFFF59E0B))
                    .withValues(alpha: isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: (_timerExpired ? AppColors.success : const Color(0xFFF59E0B))
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

            // Contact Support Button (Launches Gmail/Mail compose)
            PrimaryButton(
              label: _openingEmail ? 'Opening Mail App...' : 'Contact Support',
              icon: Icons.mail_rounded,
              isLoading: _openingEmail,
              onPressed: _handleContactSupport,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Copy Email Tile
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: _copySupportEmail,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: isDark ? Colors.white70 : AppColors.brand,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Copy ${AccountLockoutBottomSheet.supportEmailPrimary}',
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

          // Action Button for Temporary Lockout
          if (!isManual) ...[
            PrimaryButton(
              label: _timerExpired ? 'Try Again' : 'Close',
              icon: _timerExpired ? Icons.arrow_forward_rounded : null,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Subtle help link for users who need immediate assistance
            TextButton(
              onPressed: _handleContactSupport,
              child: Text(
                'Need help? Contact Operations Support',
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
