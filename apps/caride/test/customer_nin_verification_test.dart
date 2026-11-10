import 'package:caride/core/widgets/customer_verified_badge.dart';
import 'package:caride/features/profile/data/account_repository.dart';
import 'package:caride/features/profile/id_verification_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AccountProfile NIN Verification Parsing', () {
    test('parses unverified profile when verification fields are absent', () {
      final profile = AccountProfile.fromMap({
        'fullName': 'Adaeze Okafor',
        'email': 'adaeze@caride.ng',
        'phone': '+2348012345678',
      });

      expect(profile.isVerified, isFalse);
      expect(profile.isNinVerified, isFalse);
      expect(profile.maskedNin, isNull);
    });

    test('parses verified profile when isVerified or isNinVerified is true', () {
      final profile = AccountProfile.fromMap({
        'fullName': 'Adaeze Okafor',
        'email': 'adaeze@caride.ng',
        'phone': '+2348012345678',
        'isVerified': true,
        'isNinVerified': true,
        'maskedNin': '123****8901',
      });

      expect(profile.isVerified, isTrue);
      expect(profile.isNinVerified, isTrue);
      expect(profile.maskedNin, equals('123****8901'));
    });

    test('parses verified profile when verificationStatus is verified', () {
      final profile = AccountProfile.fromMap({
        'fullName': 'Chinedu Eze',
        'verificationStatus': 'verified',
      });

      expect(profile.isVerified, isTrue);
    });
  });

  group('CustomerVerifiedBadge & CustomerNameWithBadge Widgets', () {
    testWidgets('CustomerNameWithBadge shows verified icon only when isVerified is true',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                CustomerNameWithBadge(
                  name: 'Verified Rider',
                  isVerified: true,
                ),
                CustomerNameWithBadge(
                  name: 'Unverified Rider',
                  isVerified: false,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Verified Rider'), findsOneWidget);
      expect(find.text('Unverified Rider'), findsOneWidget);
      expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    });
  });

  group('IdVerificationPromptBottomSheet Replica UI', () {
    testWidgets('renders benefits and Verify Now CTA button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  IdVerificationPromptBottomSheet.show(
                    context,
                    noticeMessage:
                        'Only verified users can withdraw from their wallet and use the subsidy wallet when verified.',
                  );
                },
                child: const Text('Open Prompt'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Prompt'));
      await tester.pumpAndSettle();

      expect(find.text('Gain a verified badge'), findsOneWidget);
      expect(find.text('Be able to withdraw from your wallet'), findsOneWidget);
      expect(
        find.text('Be able to use subsidy wallet during ride booking'),
        findsOneWidget,
      );
      expect(find.text('Verify Now'), findsOneWidget);
    });
  });
}

