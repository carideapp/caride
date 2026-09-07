import '../../models/wallet_transaction.dart';

abstract final class MockWallet {
  static const double customerBalance = 12500.75;

  static List<WalletTransaction> customerTransactions() => [
        WalletTransaction(
          id: 'txn_1',
          title: 'Ride to ICM',
          amount: 3500,
          type: WalletTransactionType.debit,
          status: WalletTransactionStatus.completed,
          methodLabel: 'Wallet',
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        ),
        WalletTransaction(
          id: 'txn_2',
          title: 'Top up',
          amount: 10000,
          type: WalletTransactionType.credit,
          status: WalletTransactionStatus.completed,
          methodLabel: 'Card ·••• 4242',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        ),
        WalletTransaction(
          id: 'txn_3',
          title: 'Ride hold',
          amount: 4000,
          type: WalletTransactionType.hold,
          status: WalletTransactionStatus.pending,
          methodLabel: 'Wallet',
          createdAt: DateTime.now().subtract(const Duration(minutes: 12)),
        ),
      ];
}
