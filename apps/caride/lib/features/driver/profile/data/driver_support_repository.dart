import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'package:caride/core/driver/models/driver_support_chat.dart';
import 'package:caride/core/driver/models/driver_support_message.dart';

class DriverSupportRepository {
  DriverSupportRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _supportChats =>
      _firestore.collection('supportChats');

  Stream<List<DriverSupportChat>> streamDriverChats(String driverUid) {
    return _supportChats
        .where('driverUid', isEqualTo: driverUid)
        .snapshots()
        .map((snap) {
          final rows = snap.docs.map(DriverSupportChat.fromDoc).toList();
          rows.sort((a, b) {
            final left = a.lastMessageAt?.millisecondsSinceEpoch ?? 0;
            final right = b.lastMessageAt?.millisecondsSinceEpoch ?? 0;
            return right.compareTo(left);
          });
          return rows;
        });
  }

  Stream<List<DriverSupportMessage>> streamMessages(String chatId) {
    return _supportChats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(DriverSupportMessage.fromDoc).toList());
  }

  Future<String> uploadChatImage(
    dynamic file,
    String chatId,
  ) async {
    final XFile xfile = file is XFile ? file : XFile((file as File).path);
    final bytes = await xfile.readAsBytes();
    final ext = xfile.name.contains('.') ? xfile.name.split('.').last : 'jpg';
    final fileName = '${DateTime.now().millisecondsSinceEpoch}_attachment.$ext';
    final ref = _storage.ref().child('supportChats/$chatId/$fileName');
    final uploadTask = await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/$ext'),
    );
    return await uploadTask.ref.getDownloadURL();
  }

  Future<String> createChat({
    required String driverUid,
    required String driverName,
    required String driverEmail,
    required String subject,
    required String initialMessage,
    String? initialImageUrl,
  }) async {
    final chatRef = _supportChats.doc();
    final now = FieldValue.serverTimestamp();
    final lastMsg = (initialImageUrl != null && initialImageUrl.isNotEmpty)
        ? (initialMessage.isNotEmpty ? initialMessage : '📷 Attachment')
        : initialMessage;

    await chatRef.set({
      'driverUid': driverUid,
      'driverName': driverName,
      'driverEmail': driverEmail,
      'userType': 'driver',
      'subject': subject,
      'status': 'active',
      'lastMessage': lastMsg,
      'lastMessageAt': now,
      'createdAt': now,
      'resolvedAt': null,
      'resolvedByAdminUid': null,
    });

    final messageData = <String, dynamic>{
      'senderRole': 'driver',
      'senderUid': driverUid,
      'text': initialMessage,
      'createdAt': now,
    };
    if (initialImageUrl != null && initialImageUrl.isNotEmpty) {
      messageData['imageUrl'] = initialImageUrl;
    }

    await chatRef.collection('messages').add(messageData);
    return chatRef.id;
  }

  Future<void> sendDriverMessage({
    required String chatId,
    required String driverUid,
    String text = '',
    String? imageUrl,
  }) async {
    final now = FieldValue.serverTimestamp();
    final chatRef = _supportChats.doc(chatId);
    final messageData = <String, dynamic>{
      'senderRole': 'driver',
      'senderUid': driverUid,
      'text': text,
      'createdAt': now,
    };
    if (imageUrl != null && imageUrl.isNotEmpty) {
      messageData['imageUrl'] = imageUrl;
    }

    await chatRef.collection('messages').add(messageData);

    final displayLastMessage = text.trim().isNotEmpty
        ? text.trim()
        : (imageUrl != null ? '📷 Image attachment' : '');

    await chatRef.set({
      'userType': 'driver',
      'status': 'active',
      'lastMessage': displayLastMessage,
      'lastMessageAt': now,
      'resolvedAt': null,
      'resolvedByAdminUid': null,
    }, SetOptions(merge: true));
  }
}
