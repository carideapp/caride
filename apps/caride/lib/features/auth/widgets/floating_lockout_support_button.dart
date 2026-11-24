import 'dart:async';

import 'package:caride/core/auth/lockout_support_service.dart';
import 'package:caride/features/auth/locked_account_support_screen.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Floating support icon button displayed on auth screens whenever the user's
/// account is under an active lockout.
///
/// Tapping it navigates the user directly to their ongoing support chat or past
/// ticket history with CaRide Admin Support.
class FloatingLockoutSupportButton extends StatefulWidget {
  const FloatingLockoutSupportButton({
    super.key,
    required this.role,
    this.emailController,
  });

  final String role; // 'customer' | 'driver' | 'fleet'
  final TextEditingController? emailController;

  @override
  State<FloatingLockoutSupportButton> createState() =>
      _FloatingLockoutSupportButtonState();
}

class _FloatingLockoutSupportButtonState
    extends State<FloatingLockoutSupportButton> {
  bool _isVisible = false;
  String? _lockedEmail;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _checkLockoutStatus();
    // Re-check every 5 seconds in case a lockout just occurred or cleared
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _checkLockoutStatus();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkLockoutStatus() async {
    final email = widget.emailController?.text.trim();
    final hasLock = await LockoutSupportService.hasActiveLockout(
      role: widget.role,
      email: email?.isNotEmpty == true ? email : null,
    );
    final recordedEmail =
        await LockoutSupportService.getRecordedLockedEmail(widget.role);

    if (mounted) {
      setState(() {
        _isVisible = hasLock;
        _lockedEmail = (email?.isNotEmpty == true ? email : recordedEmail) ?? '';
      });
    }
  }

  void _handleOpenSupport() {
    final email = _lockedEmail?.trim() ?? '';
    LockedAccountSupportScreen.show(
      context,
      email: email,
      role: widget.role,
    ).then((_) {
      if (mounted) _checkLockoutStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      bottom: 24,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleOpenSupport,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: AppColors.brand.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.25),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lockout Support',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                    const Text(
                      'Chat with Admin',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B),
                    shape: BoxShape.circle,
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
