import 'package:caride/core/auth/account_lockout_exception.dart';
import 'package:caride/core/auth/lockout_support_service.dart';
import 'package:caride/features/auth/widgets/account_lockout_bottom_sheet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountLockoutException & Helper Tests', () {
    test('Correctly identifies temporary lockout vs manual lockout', () {
      final temp = AccountLockoutException(
        message: 'Too many attempts. Locked for 5 minutes.',
        lockType: 'temporary',
        stageName: 'Stage 1',
        remainingSeconds: 300,
        email: 'user@example.com',
      );
      expect(temp.isManualOrPermanent, isFalse);
      expect(temp.remainingSeconds, equals(300));
      expect(temp.email, equals('user@example.com'));

      final manual = AccountLockoutException(
        message: 'Account locked for security. Please contact administrator.',
        lockType: 'manual',
        stageName: 'Stage 4',
        remainingSeconds: null,
        email: 'driver@caride.ng',
      );
      expect(manual.isManualOrPermanent, isTrue);
    });

    test('AccountLockoutHelper.isLockout detects various lockout error formats', () {
      expect(
        AccountLockoutHelper.isLockout('firebase_auth/user-disabled: Your account is temporarily locked.'),
        isTrue,
      );
      expect(
        AccountLockoutHelper.isLockout('Too many failed login attempts. Please wait 15 minutes.'),
        isTrue,
      );
      expect(
        AccountLockoutHelper.isLockout('Account has been locked by administrator.'),
        isTrue,
      );
      expect(
        AccountLockoutHelper.isLockout('Invalid password or credential'),
        isFalse,
      );
      expect(
        AccountLockoutHelper.isLockout(null),
        isFalse,
      );
    });

    test('AccountLockoutHelper.extract parses remaining time and manual status', () {
      final parsed1 = AccountLockoutHelper.extract(
        'Too many failed login attempts. Account is locked. Please try again in 15 minutes.',
        email: 'test@caride.ng',
      );
      expect(parsed1.email, equals('test@caride.ng'));
      expect(parsed1.remainingSeconds, equals(15 * 60));
      expect(parsed1.isManualOrPermanent, isFalse);

      final parsedManual = AccountLockoutHelper.extract(
        'Maximum attempts exceeded. Please contact administrator to unlock account.',
        email: 'fleet@caride.ng',
      );
      expect(parsedManual.isManualOrPermanent, isTrue);
    });

    test('Support email constants point to operations@caride.ng and opeations@caride.ng', () {
      expect(AccountLockoutBottomSheet.supportEmailPrimary, equals('operations@caride.ng'));
      expect(AccountLockoutBottomSheet.supportEmailAlias, equals('opeations@caride.ng'));
    });
  });

  group('LockoutSupportService & State Persistence Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('Records, retrieves, and clears active lockout session correctly', () async {
      expect(await LockoutSupportService.hasActiveLockout(role: 'customer'), isFalse);

      await LockoutSupportService.recordActiveLockout(
        role: 'customer',
        email: 'customer@caride.ng',
        chatId: 'chat_cust_123',
      );

      expect(await LockoutSupportService.hasActiveLockout(role: 'customer'), isTrue);
      expect(
        await LockoutSupportService.getRecordedLockedEmail('customer'),
        equals('customer@caride.ng'),
      );
      expect(
        await LockoutSupportService.getActiveChatId(
          role: 'customer',
          email: 'customer@caride.ng',
        ),
        equals('chat_cust_123'),
      );

      // Separate roles are isolated
      expect(await LockoutSupportService.hasActiveLockout(role: 'driver'), isFalse);

      await LockoutSupportService.clearLockoutRecord(
        role: 'customer',
        email: 'customer@caride.ng',
      );
      expect(await LockoutSupportService.hasActiveLockout(role: 'customer'), isFalse);
    });

    test('Isolated driver and fleet support sessions', () async {
      await LockoutSupportService.recordActiveLockout(
        role: 'driver',
        email: 'driver@caride.ng',
        chatId: 'driver_chat_456',
      );
      await LockoutSupportService.recordActiveLockout(
        role: 'fleet',
        email: 'fleet@caride.ng',
        chatId: 'fleet_ticket_789',
      );

      expect(await LockoutSupportService.hasActiveLockout(role: 'driver'), isTrue);
      expect(await LockoutSupportService.hasActiveLockout(role: 'fleet'), isTrue);
      expect(
        await LockoutSupportService.getActiveChatId(role: 'driver', email: 'driver@caride.ng'),
        equals('driver_chat_456'),
      );
      expect(
        await LockoutSupportService.getActiveChatId(role: 'fleet', email: 'fleet@caride.ng'),
        equals('fleet_ticket_789'),
      );
    });
  });
}
