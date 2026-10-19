import 'package:caride/features/profile/data/wallet_response_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WalletRepository parsing', () {
    test('parses initialize top up response', () {
      final result = WalletResponseParser.parseInitializeTopUpResult({
        'authorizationUrl': 'https://checkout.transactpay.ai/abc',
        'reference': 'ref_123',
      });

      expect(result.authorizationUrl, contains('transactpay.ai'));
      expect(result.reference, 'ref_123');
    });

    test('throws when initialize response is invalid', () {
      expect(
        () => WalletResponseParser.parseInitializeTopUpResult({
          'authorizationUrl': '',
        }),
        throwsException,
      );
    });

    test('parses verified amount and throws on invalid data', () {
      expect(
        WalletResponseParser.parseVerifiedAmount({'amountNaira': 5000}),
        5000,
      );

      expect(
        () => WalletResponseParser.parseVerifiedAmount({'amountNaira': '5000'}),
        throwsException,
      );
    });
  });
}
