int? extractCooldownSeconds(Object error) {
  final raw = error.toString();
  final match =
      RegExp(r'(\d+)\s*seconds?', caseSensitive: false).firstMatch(raw);
  if (match != null) {
    return int.tryParse(match.group(1) ?? '');
  }
  return null;
}

String mapAuthErrorMessage(Object error) {
  final raw = error.toString();
  final lower = raw.toLowerCase();

  // If the message is Termii's confirmation that the token was verified, do not treat as an error
  if (lower.contains('has been verified') ||
      lower.contains('have been verified') ||
      lower.contains('already verified') ||
      lower.contains('successfully verified')) {
    return '';
  }

  // 1. Rate-limiting / Cooldown
  if (lower.contains('please wait') ||
      lower.contains('resource-exhausted') ||
      lower.contains('too-many-requests') ||
      lower.contains('rate-limit') ||
      (lower.contains('wait') && lower.contains('second'))) {
    final seconds = extractCooldownSeconds(error);
    if (seconds != null && seconds > 0) {
      return 'Please wait $seconds seconds before requesting a new code.';
    }
    return 'Please wait a moment before requesting another code.';
  }

  // 2. Termii / SMS delivery issues
  if (lower.contains('country inactive') ||
      lower.contains('sms is unavailable') ||
      lower.contains('sms code') ||
      lower.contains('termii') ||
      lower.contains('sms-unavailable') ||
      lower.contains('unable to send verification sms')) {
    return 'SMS verification is temporarily unavailable. Please try Email verification.';
  }

  // 3. Invalid or incorrect OTP
  if (lower.contains('invalid-otp') ||
      lower.contains('incorrect-code') ||
      lower.contains('invalid pin') ||
      lower.contains('incorrect pin') ||
      lower.contains('token is invalid')) {
    return 'The verification code entered is incorrect. Please check and try again.';
  }

  // 4. Attempts exceeded
  if (lower.contains('pin_attempts') ||
      lower.contains('attempts exceeded') ||
      lower.contains('max attempts') ||
      lower.contains('too many attempts')) {
    return 'Too many incorrect attempts. Please request a new code.';
  }

  // 5. Expired code or session
  if (lower.contains('expired') || lower.contains('session expired')) {
    return 'This verification code has expired. Please request a new one.';
  }

  // 6. Network / connectivity
  if (lower.contains('network-request-failed') ||
      lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network') ||
      lower.contains('offline') ||
      lower.contains('connection') ||
      lower.contains('unexpected end of stream') ||
      lower.contains('okhttp') ||
      lower.contains('deadline-exceeded') ||
      lower.contains('timeout')) {
    return 'Network connection error. Please check your internet connection and try again.';
  }

  // 7. Cancellation
  if (lower.contains('canceled') ||
      lower.contains('cancelled') ||
      lower.contains('sign_in_canceled') ||
      lower.contains('cancelled by user')) {
    return 'Authentication was cancelled.';
  }

  // 8. Account state
  if (lower.contains('user-disabled') ||
      lower.contains('blocked') ||
      lower.contains('suspended')) {
    return 'This account has been disabled. Please contact support.';
  }
  if (lower.contains('already-exists') ||
      lower.contains('email-already-in-use')) {
    return 'An account with this email already exists.';
  }
  if (lower.contains('not-found') || lower.contains('user-not-found')) {
    return 'No account was found for this email.';
  }
  if (lower.contains('invalid-email')) {
    return 'Please enter a valid email address.';
  }

  // 9. Clean up raw message if readable without error wrapper
  final cleaned = raw
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^\[.*?\]\s*'), '')
      .trim();

  if (cleaned.isNotEmpty &&
      !cleaned.contains('{') &&
      !cleaned.contains('Closure')) {
    return cleaned;
  }

  return 'Unable to process your request right now. Please try again.';
}
