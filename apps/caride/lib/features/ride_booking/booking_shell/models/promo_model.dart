import 'package:cloud_firestore/cloud_firestore.dart';

class PromoModel {
  final String id;
  final String code;
  final String discountType; // 'percentage' | 'flat'
  final double discountValue;
  final double minFare;
  final double maxCap;
  final bool isActive;
  final DateTime? expiryDate;
  final int usageLimitPerCustomer;

  PromoModel({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    required this.minFare,
    required this.maxCap,
    required this.isActive,
    this.usageLimitPerCustomer = 0,
    this.expiryDate,
  });

  factory PromoModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PromoModel.fromMap(doc.id, data);
  }

  factory PromoModel.fromMap(String id, Map<String, dynamic> data) {
    return PromoModel(
      id: id,
      code: (data['code'] as String?) ?? '',
      discountType: (data['discountType'] as String?) ?? 'percentage',
      discountValue: (data['discountValue'] as num?)?.toDouble() ?? 0.0,
      minFare: (data['minFare'] as num?)?.toDouble() ?? 0.0,
      maxCap: (data['maxCap'] as num?)?.toDouble() ?? 0.0,
      isActive: (data['isActive'] as bool?) ?? false,
      usageLimitPerCustomer: (data['usageLimitPerCustomer'] as num?)?.toInt() ?? 0,
      expiryDate: _parseExpiryDate(data['expiryDate']),
    );
  }

  static DateTime? _parseExpiryDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is String) return DateTime.tryParse(val);
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    return null;
  }

  double calculateDiscount(double originalFare) {
    if (originalFare < minFare) return 0.0;
    if (discountType == 'flat') {
      return discountValue.clamp(0.0, originalFare);
    } else {
      final calculated = originalFare * (discountValue / 100);
      if (maxCap > 0 && calculated > maxCap) {
        return maxCap;
      }
      return calculated.clamp(0.0, originalFare);
    }
  }
}
