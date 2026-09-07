class WalletResponseParser {
  const WalletResponseParser._();

  static ({String authorizationUrl, String reference}) parseInitializeTopUpResult(
    Map<dynamic, dynamic> data,
  ) {
    final authorizationUrl = data['authorizationUrl'] as String?;
    final reference = data['reference'] as String?;
    if (authorizationUrl == null ||
        authorizationUrl.isEmpty ||
        reference == null ||
        reference.isEmpty) {
      throw Exception('Payment initialization response is invalid.');
    }
    return (
      authorizationUrl: authorizationUrl,
      reference: reference,
    );
  }

  static double parseVerifiedAmount(Map<dynamic, dynamic> data) {
    final amount = data['amountNaira'];
    if (amount is! num) {
      throw Exception('Payment verification response is invalid.');
    }
    return amount.toDouble();
  }
}
