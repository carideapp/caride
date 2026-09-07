import 'package:cloud_firestore/cloud_firestore.dart';

class DriverSupportChat {
  const DriverSupportChat({
    required this.id,
    required this.driverUid,
    required this.status,
    required this.subject,
    required this.lastMessage,
    this.driverName,
    this.driverEmail,
    this.createdAt,
    this.lastMessageAt,
    this.resolvedAt,
    this.resolvedByAdminUid,
  });

  final String id;
  final String driverUid;
  final String status;
  final String subject;
  final String lastMessage;
  final String? driverName;
  final String? driverEmail;
  final DateTime? createdAt;
  final DateTime? lastMessageAt;
  final DateTime? resolvedAt;
  final String? resolvedByAdminUid;

  bool get isResolved => status == 'resolved';
  bool get isActive => status == 'active';

  factory DriverSupportChat.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return DriverSupportChat(
      id: doc.id,
      driverUid: (data['driverUid'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'active',
      subject: (data['subject'] as String?) ?? 'Customer Care',
      lastMessage: (data['lastMessage'] as String?) ?? '',
      driverName: data['driverName'] as String?,
      driverEmail: data['driverEmail'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      resolvedByAdminUid: data['resolvedByAdminUid'] as String?,
    );
  }
}
