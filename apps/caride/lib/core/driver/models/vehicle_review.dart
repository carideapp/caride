import 'package:cloud_firestore/cloud_firestore.dart';

import 'vehicle_info.dart';

class VehicleReview {
  const VehicleReview({
    required this.status,
    required this.newValues,
    this.oldValues,
    this.rejectionReason,
    this.submittedAt,
    this.reviewedAt,
    this.reviewedByAdminUid,
  });

  final String status;
  final VehicleInfo newValues;
  final VehicleInfo? oldValues;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedByAdminUid;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory VehicleReview.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return VehicleReview.fromMap(doc.data() ?? const <String, dynamic>{});
  }

  factory VehicleReview.fromMap(Map<String, dynamic> data) {
    return VehicleReview(
      status: (data['status'] as String?) ?? 'pending',
      newValues: VehicleInfo.fromMap(
        Map<String, dynamic>.from(
          (data['newValues'] as Map<String, dynamic>?) ??
              (data['vehicle'] as Map<String, dynamic>?) ??
              const <String, dynamic>{},
        ),
      ),
      oldValues: data['oldValues'] is Map<String, dynamic>
          ? VehicleInfo.fromMap(
              Map<String, dynamic>.from(data['oldValues'] as Map<String, dynamic>),
            )
          : null,
      rejectionReason: data['rejectionReason'] as String?,
      submittedAt: (data['submittedAt'] as Timestamp?)?.toDate(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedByAdminUid: data['reviewedByAdminUid'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'status': status,
      'newValues': newValues.toMap(),
      'oldValues': oldValues?.toMap(),
      'rejectionReason': rejectionReason,
      'submittedAt': submittedAt != null ? Timestamp.fromDate(submittedAt!) : null,
      'reviewedAt': reviewedAt != null ? Timestamp.fromDate(reviewedAt!) : null,
      'reviewedByAdminUid': reviewedByAdminUid,
    };
  }
}
