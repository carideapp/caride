import 'package:cloud_firestore/cloud_firestore.dart';

class CustomerSupportChat {
  CustomerSupportChat({
    required this.id,
    required this.userUid,
    required this.userName,
    required this.userEmail,
    required this.userType,
    required this.subject,
    required this.status,
    this.lastMessage,
    this.lastMessageAt,
    this.createdAt,
    this.resolvedAt,
    this.resolvedByAdminUid,
  });

  final String id;
  final String userUid;
  final String userName;
  final String userEmail;
  final String userType;
  final String subject;
  final String status;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? resolvedByAdminUid;

  factory CustomerSupportChat.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return CustomerSupportChat(
      id: doc.id,
      userUid: data['userUid'] as String? ?? data['driverUid'] as String? ?? '',
      userName: data['userName'] as String? ?? data['driverName'] as String? ?? '',
      userEmail: data['userEmail'] as String? ?? data['driverEmail'] as String? ?? '',
      userType: data['userType'] as String? ?? 'customer',
      subject: data['subject'] as String? ?? '',
      status: data['status'] as String? ?? 'active',
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      resolvedByAdminUid: data['resolvedByAdminUid'] as String?,
    );
  }
}
