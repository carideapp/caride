enum WalletTransactionType { credit, debit, hold, release }

enum WalletTransactionStatus { pending, completed, failed }

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.status,
    required this.methodLabel,
    required this.createdAt,
  });

  final String id;
  final String title;
  final double amount;
  final WalletTransactionType type;
  final WalletTransactionStatus status;
  final String methodLabel;
  final DateTime createdAt;
}
