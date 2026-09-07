class AuthChallenge {
  const AuthChallenge({
    required this.challengeId,
    required this.email,
    required this.expiresAt,
    required this.isSignUp,
  });

  final String challengeId;
  final String email;
  final DateTime expiresAt;
  final bool isSignUp;
}
