class AuthChallenge {
  const AuthChallenge({
    required this.challengeId,
    required this.email,
    required this.expiresAt,
    required this.isSignUp,
    this.phone,
    this.channel = 'email',
    this.isPasswordReset = false,
  });

  final String challengeId;
  final String email;
  final DateTime expiresAt;
  final bool isSignUp;
  final String? phone;
  final String channel;
  final bool isPasswordReset;

  bool get isSms => channel == 'sms' || (phone != null && phone!.isNotEmpty);
}
