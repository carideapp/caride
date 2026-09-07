import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerSupportMessage {
  CustomerSupportMessage({
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

  factory CustomerSupportMessage.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CustomerSupportMessage(
      id: doc.id,
      senderRole: data['senderRole'] as String? ?? '',
      senderUid: data['senderUid'] as String? ?? '',
      text: data['text'] as String? ?? '',
      imageUrl: data['imageUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
