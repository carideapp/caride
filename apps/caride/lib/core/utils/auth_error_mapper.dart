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

  // 8. Account & Identity state
  if (lower.contains('user-disabled') ||
      lower.contains('blocked') ||
      lower.contains('suspended')) {
    return 'This account has been disabled. Please contact support.';
  }
  if (lower.contains('driver account already exists') ||
      lower.contains('driver-already-exists')) {
    return 'A driver account with this email already exists. Please sign in instead.';
  }
  if (lower.contains('already-exists') ||
      lower.contains('email-already-in-use') ||
      lower.contains('account already exists')) {
    return 'An account with this email address already exists. Please sign in instead.';
  }
  if (lower.contains('phone-number-already-exists') ||
      lower.contains('phone number already in use') ||
      lower.contains('phone already exists') ||
      lower.contains('phone-already-registered')) {
    return 'This phone number is already registered. Please sign in or use another number.';
  }
  if (lower.contains('username-already-exists') ||
      lower.contains('username already taken') ||
      lower.contains('username taken') ||
      lower.contains('username is taken')) {
    return 'This username is already taken. Please choose a different username.';
  }
  if (lower.contains('not-found') || lower.contains('user-not-found')) {
    return 'No account was found for this email.';
  }
  if (lower.contains('invalid-email') || lower.contains('invalid email')) {
    return 'Please enter a valid email address.';
  }
  if (lower.contains('weak-password')) {
    return 'Password is too weak. Please choose a stronger password (at least 6 characters).';
  }
  if (lower.contains('wrong-password') || lower.contains('invalid-credential')) {
    return 'Invalid email or password. Please check your details and try again.';
  }
  if (lower.contains('invalid-argument') || lower.contains('invalid-phone')) {
    return 'The phone number or email format is invalid. Please check your information.';
  }
  if (lower.contains('invalid-referral') || lower.contains('referral-not-found')) {
    return 'The referral code entered is invalid. Please verify or leave it blank.';
  }
  if (lower.contains('permission-denied')) {
    return 'Permission denied. Please check your account permissions and try again.';
  }
  if (lower.contains('unauthenticated')) {
    return 'Your session has expired. Please try signing up again.';
  }
  if (lower.contains('internal') || lower.contains('server-error') || lower.contains('500')) {
    return 'Our servers encountered a temporary issue. Please try again shortly.';
  }

  // 9. System / Platform / Native runtime crashes (never dump stack traces to the user)
  if (lower.contains('nosuchmethoderror') ||
      lower.contains('platformexception') ||
      lower.contains('nullpointerexception') ||
      lower.contains('classnotfoundexception') ||
      lower.contains('missingplugin') ||
      lower.contains('exception in java') ||
      raw.contains('Lio/flutter') ||
      raw.contains('at android.') ||
      raw.contains('package:')) {
    return 'A temporary system error occurred. Please restart the app and try again.';
  }

  // 10. Clean up raw message if it is a short, user-readable string
  final cleaned = raw
      .replaceFirst(RegExp(r'^Exception:\s*'), '')
      .replaceFirst(RegExp(r'^\[.*?\]\s*'), '')
      .trim();

  // If the string contains stack trace markers, line breaks, or code syntax, do not expose it
  if (cleaned.isNotEmpty &&
      cleaned.length < 120 &&
      !cleaned.contains('\n') &&
      !cleaned.contains('{') &&
      !cleaned.contains('}') &&
      !cleaned.contains('Closure') &&
      !cleaned.contains('at ') &&
      !cleaned.contains('(') &&
      !cleaned.contains(')')) {
    return cleaned;
  }

  return 'Unable to create account right now. Please check your details and try again.';
}
