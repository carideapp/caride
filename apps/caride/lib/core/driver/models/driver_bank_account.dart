import 'package:cloud_firestore/cloud_firestore.dart';

class DriverBankAccount {
  const DriverBankAccount({
    required this.id,
    required this.bankCode,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.maskedAccountNumber,
    required this.verificationStatus,
    this.recipientCode,
    this.isDefault = false,
    this.createdAt,
  });

  final String id;
  final String bankCode;
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String maskedAccountNumber;
  final String verificationStatus;
  final String? recipientCode;
  final bool isDefault;
  final DateTime? createdAt;

  bool get isVerified => verificationStatus == 'verified';

  factory DriverBankAccount.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return DriverBankAccount(
      id: doc.id,
      bankCode: (data['bankCode'] as String?) ?? '',
      bankName: (data['bankName'] as String?) ?? '',
      accountNumber: (data['accountNumber'] as String?) ?? '',
      accountName: (data['accountName'] as String?) ?? '',
      maskedAccountNumber: (data['maskedAccountNumber'] as String?) ?? '',
      verificationStatus: (data['verificationStatus'] as String?) ?? 'pending',
      recipientCode: data['recipientCode'] as String?,
      isDefault: (data['isDefault'] as bool?) ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
