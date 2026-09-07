import 'package:cloud_firestore/cloud_firestore.dart';

class DriverSupportMessage {
  const DriverSupportMessage({
    required this.id,
    required this.senderRole,
    required this.senderUid,
    required this.text,
    this.imageUrl,
    this.createdAt,
  });

  final String id;
  final String senderRole;
  final String senderUid;
  final String text;
  final String? imageUrl;
  final DateTime? createdAt;

  bool get isAdmin => senderRole == 'admin';
  bool get isDriver => senderRole == 'driver';
  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  factory DriverSupportMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return DriverSupportMessage(
      id: doc.id,
      senderRole: (data['senderRole'] as String?) ?? 'driver',
      senderUid: (data['senderUid'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      imageUrl: data['imageUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
