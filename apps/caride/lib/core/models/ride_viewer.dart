import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a driver currently inspecting a ride request.
class RideViewer {
  const RideViewer({
    required this.driverUid,
    required this.driverName,
    this.profilePhotoUrl,
    this.updatedAt,
  });

  final String driverUid;
  final String driverName;
  final String? profilePhotoUrl;
  final DateTime? updatedAt;

  factory RideViewer.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return RideViewer(
      driverUid: doc.id,
      driverName: data['driverName'] as String? ?? 'Driver',
      profilePhotoUrl: data['profilePhotoUrl'] as String?,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'driverName': driverName,
      if (profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty)
        'profilePhotoUrl': profilePhotoUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
