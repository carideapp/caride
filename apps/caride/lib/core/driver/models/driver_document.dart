import 'package:cloud_firestore/cloud_firestore.dart';

import '../verification/driver_verification_config.dart';

class DriverDocument {
  const DriverDocument({
    required this.documentType,
    required this.fileUrl,
    required this.status,
    this.rejectionReason,
    this.uploadedAt,
    this.reviewedAt,
  });

  /// Verification document type id
  final String documentType;
  final String fileUrl;
  /// 'pending' | 'approved' | 'rejected'
  final String status;
  final String? rejectionReason;
  final DateTime? uploadedAt;
  final DateTime? reviewedAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get needsUpload => fileUrl.isEmpty;

  String get displayName => documentDefinitionForType(documentType).label;

  factory DriverDocument.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return DriverDocument.fromMap(documentType: doc.id, data: data);
  }

  factory DriverDocument.fromMap({
    required String documentType,
    required Map<String, dynamic> data,
  }) {
    return DriverDocument(
      documentType: documentType,
      fileUrl: (data['fileUrl'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'pending',
      rejectionReason: data['rejectionReason'] as String?,
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate(),
      reviewedAt: (data['reviewedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'documentType': documentType,
      'fileUrl': fileUrl,
      'status': status,
      'rejectionReason': rejectionReason,
      'uploadedAt': uploadedAt != null ? Timestamp.fromDate(uploadedAt!) : null,
    };
  }
}
