/// Represents an account or IP lockout triggered by progressive brute-force protection
/// or administrative security enforcement.
class AccountLockoutException implements Exception {
  final String message;
  final String lockType; // 'temporary' | 'manual' | 'ip_restriction'
  final String? stageName;
  final int? remainingSeconds;
  final String email;

  const AccountLockoutException({
    required this.message,
    this.lockType = 'temporary',
    this.stageName,
    this.remainingSeconds,
    this.email = '',
  });

  /// Returns true if this lockout requires manual administrator intervention
  /// (i.e. final escalation stage or manual account lock).
  bool get isManualOrPermanent {
    if (lockType == 'manual' || lockType == 'ip_restriction') return true;
    if (stageName != null) {
      final s = stageName!.toLowerCase();
      if (s.contains('manual') || s.contains('final') || s.contains('admin')) {
        return true;
      }
    }
    final lowerMsg = message.toLowerCase();
    if (lowerMsg.contains('contact') ||
        lowerMsg.contains('manual unlock') ||
        lowerMsg.contains('administrator')) {
      return true;
    }
    return remainingSeconds == null && lockType != 'temporary';
  }

  @override
  String toString() => message;
}

/// Helper to identify and parse account lockout conditions across all auth providers and screens.
class AccountLockoutHelper {
  /// Detects whether an exception or error object corresponds to an account or IP lockout.
  static bool isLockout(Object? error) {
    if (error == null) return false;
    if (error is AccountLockoutException) return true;

    final str = error.toString().toLowerCase();
    return str.contains('temporarily locked') ||
        str.contains('user-disabled') ||
        str.contains('failed login attempts') ||
        str.contains('account has been locked') ||
        str.contains('account is locked') ||
        str.contains('lockout') ||
        str.contains('security lockout') ||
        str.contains('account_locked');
  }

  /// Extracts or converts any error into a canonical [AccountLockoutException].
  static AccountLockoutException extract(Object? error, {String email = ''}) {
    if (error is AccountLockoutException) {
      if (error.email.isEmpty && email.isNotEmpty) {
        return AccountLockoutException(
          message: error.message,
          lockType: error.lockType,
          stageName: error.stageName,
          remainingSeconds: error.remainingSeconds,
          email: email,
        );
      }
      return error;
    }

    final raw = error?.toString() ?? 'Account is locked for security.';
    final lower = raw.toLowerCase();

    final isManual = lower.contains('contact') ||
        lower.contains('administrator') ||
        lower.contains('admin') ||
        lower.contains('manual');

    int? remainingSecs;
    final matchMinutes = RegExp(r'(\d+)\s*(?:minute|min|m)', caseSensitive: false).firstMatch(raw);
    if (matchMinutes != null) {
      final mins = int.tryParse(matchMinutes.group(1) ?? '');
      if (mins != null && mins > 0) {
        remainingSecs = mins * 60;
      }
    }
    final matchSeconds = RegExp(r'(\d+)\s*(?:second|sec|s)', caseSensitive: false).firstMatch(raw);
    if (matchSeconds != null) {
      final secs = int.tryParse(matchSeconds.group(1) ?? '');
      if (secs != null && secs > 0) {
        remainingSecs = secs;
      }
    }

    return AccountLockoutException(
      message: raw,
      lockType: isManual ? 'manual' : 'temporary',
      stageName: isManual ? 'Final Security Lockout' : 'Temporary Lockout',
      remainingSeconds: remainingSecs ?? (isManual ? null : 300),
      email: email,
    );
  }
}
