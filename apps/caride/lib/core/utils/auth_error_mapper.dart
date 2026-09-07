String mapAuthErrorMessage(Object error) {
  final raw = error.toString();
  final lower = raw.toLowerCase();
  
  if (lower.contains('canceled') ||
      lower.contains('cancelled') ||
      lower.contains('sign_in_canceled') ||
      lower.contains('cancelled by user')) {
    return 'Authentication was cancelled.';
  }

  if (lower.contains('network-request-failed') ||
      lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('network') ||
      lower.contains('offline') ||
      lower.contains('unavailable') ||
      lower.contains('connection') ||
      lower.contains('unexpected end of stream') ||
      lower.contains('okhttp') ||
      lower.contains('internal-error') ||
      lower.contains('internal error')) {
    return 'A connection error occurred. Please check your internet connection and try again.';
  }
  if (raw.contains('invalid-email')) {
    return 'Please enter a valid email address.';
  }
  if (raw.contains('too-many-requests')) {
    return 'Too many attempts. Please try again shortly.';
  }
  if (raw.contains('deadline-exceeded')) {
    return 'Request timed out. Check your network and retry.';
  }
  if (raw.contains('not-found')) {
    return 'No account was found for this email.';
  }
  if (raw.contains('already-exists')) {
    return 'An account with this email already exists.';
  }
  if (raw.contains('invalid-otp') || raw.contains('incorrect-code')) {
    return 'The OTP code is incorrect.';
  }
  if (raw.contains('expired')) {
    return 'This OTP has expired. Request a new one.';
  }
  return 'Error: ${error.toString()}';
}
