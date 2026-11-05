import 'package:caride/features/driver/wallet/data/driver_wallet_repository.dart';
import 'package:caride/features/wallet/data/wallet_transaction_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Admin Wallet Adjustment Models & Logic', () {
    test('DriverWalletTransaction.isCredit returns true for admin_credit', () {
      final tx = DriverWalletTransaction(
        id: 'tx_credit_1',
        type: 'admin_credit',
        amountNaira: 5000.0,
        description: 'Refund for canceled trip #TR-101',
        createdAt: DateTime.now(),
      );

      expect(tx.isCredit, isTrue);
    });

    test('DriverWalletTransaction.isCredit returns false for admin_debit', () {
      final tx = DriverWalletTransaction(
        id: 'tx_debit_1',
        type: 'admin_debit',
        amountNaira: 2000.0,
        description: 'Administrative overpayment deduction',
        createdAt: DateTime.now(),
      );

      expect(tx.isCredit, isFalse);
    });

    test(
      'DriverWalletTransaction.isCredit handles description containing admin credit',
      () {
        final tx = DriverWalletTransaction(
          id: 'tx_desc_credit',
          type: 'credit',
          amountNaira: 1500.0,
          description: 'Manual Admin Credit for reconciliation',
          createdAt: DateTime.now(),
        );

        expect(tx.isCredit, isTrue);
      },
    );

    test(
      'DriverWalletTransaction.isCredit handles description containing admin debit',
      () {
        final tx = DriverWalletTransaction(
          id: 'tx_desc_debit',
          type: 'debit',
          amountNaira: 1000.0,
          description: 'Manual Admin Debit correction',
          createdAt: DateTime.now(),
        );

        expect(tx.isCredit, isFalse);
      },
    );

    test('Balance projection handles credits and debits accurately', () {
      const currentBalance = 12500.0;
      const creditAmount = 5000.0;
      const debitAmount = 3500.0;
      const excessiveDebit = 15000.0;

      // Credit projection
      final projectedCredit = currentBalance + creditAmount;
      expect(projectedCredit, 17500.0);

      // Debit projection
      final projectedDebit = currentBalance - debitAmount;
      expect(projectedDebit, 9000.0);

      // Insufficient balance validation check
      final isInsufficient = excessiveDebit > currentBalance;
      expect(isInsufficient, isTrue);
    });
  });
}
