import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';

/// Helper to parse, translate, and display user-friendly error messages
/// across all Fleet Manager authentication and onboarding screens.
class FleetAuthErrorHelper {
  /// Converts any dynamic exception or error into a clear, actionable human-readable message.
  static String parseError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code.toLowerCase()) {
        case 'user-not-found':
          return 'No Fleet Manager account found with this email. Please check your email or register a new fleet account.';
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password. Please verify your credentials and try again.';
        case 'email-already-in-use':
        case 'email-already-exists':
          return 'An account already exists with this email address. Please sign in instead.';
        case 'invalid-email':
          return 'Please enter a valid email address.';
        case 'weak-password':
          return 'Password is too weak. Please use at least 6 characters with a combination of letters and numbers.';
        case 'user-disabled':
          return 'This Fleet Manager account has been deactivated. Please contact CaRide Support for assistance.';
        case 'too-many-requests':
          return 'Too many consecutive failed attempts. Please wait a few moments before trying again.';
        case 'network-request-failed':
          return 'Network error: Please check your internet connection and try again.';
        case 'invalid-verification-code':
          return 'Incorrect OTP verification code. Please check your email inbox and enter the 6-digit code.';
        case 'session-expired':
        case 'expired-action-code':
          return 'This verification code has expired. Please tap "Resend Code" to request a new code.';
        case 'quota-exceeded':
          return 'Service temporarily busy. Please wait a few moments and try again.';
        case 'operation-not-allowed':
          return 'This sign-in method is currently not enabled. Please contact support.';
        case 'requires-recent-login':
          return 'For security, please sign in again before performing this action.';
        default:
          if (error.message != null && error.message!.isNotEmpty) {
            return error.message!;
          }
          return 'An authentication error occurred. Please try again.';
      }
    }

    if (error is SocketException || error is HttpException) {
      return 'Network connection error. Please verify your internet connection and try again.';
    }

    final str = error.toString().toLowerCase();

    if (str.contains('user-not-found') || str.contains('not-found')) {
      return 'No Fleet Manager account found with this email. Please verify or register.';
    } else if (str.contains('wrong-password') || str.contains('invalid-credential')) {
      return 'Incorrect email or password. Please try again.';
    } else if (str.contains('email-already-in-use') || str.contains('already in use')) {
      return 'An account already exists with this email address. Please sign in instead.';
    } else if (str.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    } else if (str.contains('weak-password')) {
      return 'Password is too weak. Use at least 6 characters with numbers and symbols.';
    } else if (str.contains('network') || str.contains('socket') || str.contains('connection')) {
      return 'Unable to reach CaRide servers. Please check your internet connection.';
    } else if (str.contains('otp') && (str.contains('invalid') || str.contains('wrong') || str.contains('incorrect'))) {
      return 'The OTP verification code is incorrect. Please check your email inbox.';
    } else if (str.contains('expired')) {
      return 'The verification code has expired. Please tap "Resend Code".';
    } else if (str.contains('too-many-requests') || str.contains('too many')) {
      return 'Too many failed attempts. Please wait a moment before trying again.';
    } else if (str.contains('document') || str.contains('upload')) {
      return 'Failed to upload document. Please ensure the image is clear and under 5MB.';
    }

    // Clean Exception prefix if present
    var cleanMsg = error.toString();
    if (cleanMsg.startsWith('Exception: ')) {
      cleanMsg = cleanMsg.substring(11);
    }
    if (cleanMsg.isEmpty) {
      return 'An unexpected error occurred. Please try again.';
    }
    return cleanMsg;
  }

  /// Displays an immediate floating error SnackBar at the top/bottom for visible feedback.
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  /// Builds a prominent, beautifully styled error banner with a dismiss action.
  static Widget buildErrorBanner({
    required String message,
    required VoidCallback onDismiss,
    bool isDark = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.error.withValues(alpha: 0.15)
            : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Action Required',
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: TextStyle(
                    color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onDismiss,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
