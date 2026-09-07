import 'package:cloud_firestore/cloud_firestore.dart';

class EarningsEntry {
  const EarningsEntry({
    required this.id,
    required this.date,
    required this.rideId,
    required this.amountNaira,
    required this.type,
    this.description,
  });

  final String id;
  final DateTime date;
  final String rideId;
  final double amountNaira;
  /// 'ride' | 'bonus' | 'referral' | 'credit' | 'debit'
  final String type;
  final String? description;

  bool get isCredit => type == 'credit' || type == 'ride' || type == 'bonus' || type == 'referral';

  factory EarningsEntry.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return EarningsEntry.fromMap(id: doc.id, data: data);
  }

  factory EarningsEntry.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final ts = data['createdAt'] as Timestamp?;
    return EarningsEntry(
      id: id,
      date: ts?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
      rideId: (data['reference'] as String?) ?? (data['rideId'] as String?) ?? '',
      amountNaira: (data['amountNaira'] as num?)?.toDouble() ?? 0,
      type: (data['type'] as String?) ?? 'ride',
      description: data['description'] as String?,
    );
  }
}
