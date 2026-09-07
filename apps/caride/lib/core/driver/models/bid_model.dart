import 'package:cloud_firestore/cloud_firestore.dart';

class BidModel {
  const BidModel({
    required this.bidId,
    required this.rideId,
    required this.driverUid,
    required this.driverName,
    required this.offerNaira,
    required this.etaMinutes,
    required this.status,
    this.counterOffer,
    this.createdAt,
    this.expiresAt,
  });

  final String bidId;
  final String rideId;
  final String driverUid;
  final String driverName;
  final double offerNaira;
  final int etaMinutes;
  /// 'pending' | 'accepted' | 'rejected' | 'countered' | 'expired' | 'declined'
  final String status;
  final double? counterOffer;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  bool get isExpired =>
      expiresAt != null ? DateTime.now().isAfter(expiresAt!) : false;
  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isCountered => status == 'countered';

  factory BidModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return BidModel.fromMap(bidId: doc.id, data: data);
  }

  factory BidModel.fromMap({
    required String bidId,
    required Map<String, dynamic> data,
  }) {
    return BidModel(
      bidId: bidId,
      rideId: (data['rideId'] as String?) ?? '',
      driverUid: (data['driverUid'] as String?) ?? '',
      driverName: (data['driverName'] as String?) ?? 'Driver',
      offerNaira: (data['offerNaira'] as num?)?.toDouble() ?? 0,
      etaMinutes: (data['etaMinutes'] as num?)?.toInt() ?? 5,
      status: (data['status'] as String?) ?? 'pending',
      counterOffer: (data['counterOffer'] as num?)?.toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'bidId': bidId,
      'rideId': rideId,
      'driverUid': driverUid,
      'driverName': driverName,
      'offerNaira': offerNaira,
      'etaMinutes': etaMinutes,
      'status': status,
      if (counterOffer != null) 'counterOffer': counterOffer,
    };
  }
}
