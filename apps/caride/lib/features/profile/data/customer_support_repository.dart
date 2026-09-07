import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:caride/core/models/customer_support_chat.dart';
import 'package:caride/core/models/customer_support_message.dart';

class CustomerSupportRepository {
  CustomerSupportRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? _safeStorageInstance();

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  static FirebaseStorage _safeStorageInstance() {
    try {
      return FirebaseStorage.instance;
    } catch (_) {
      try {
        return FirebaseStorage.instanceFor(bucket: 'gs://caride-app.firebasestorage.app');
      } catch (_) {
        return FirebaseStorage.instanceFor(bucket: 'caride-app.firebasestorage.app');
      }
    }
  }

  CollectionReference<Map<String, dynamic>> get _supportChats =>
      _firestore.collection('supportChats');

  /// Uploads an image file to Firebase Storage under `supportChats/{chatId}/`
  /// and returns the download URL.
  Future<String> uploadChatImage(File file, String chatId) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child('supportChats').child(chatId).child(fileName);
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await task.ref.getDownloadURL();
  }

  Stream<List<CustomerSupportChat>> streamCustomerChats(String customerUid) {
    return _supportChats
        .where('userUid', isEqualTo: customerUid)
        .where('userType', isEqualTo: 'customer')
        .snapshots()
        .map((snap) {
      final rows = snap.docs.map(CustomerSupportChat.fromDoc).toList();
      rows.sort((a, b) {
        final left = a.lastMessageAt?.millisecondsSinceEpoch ?? 0;
        final right = b.lastMessageAt?.millisecondsSinceEpoch ?? 0;
        return right.compareTo(left);
      });
      return rows;
    });
  }

  Stream<List<CustomerSupportMessage>> streamMessages(String chatId) {
    return _supportChats
        .doc(chatId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs.map(CustomerSupportMessage.fromDoc).toList());
  }

  Future<String> createChat({
    required String customerUid,
    required String customerName,
    required String customerEmail,
    required String subject,
    required String initialMessage,
    String? initialImageUrl,
  }) async {
    final chatRef = _supportChats.doc();
    final now = FieldValue.serverTimestamp();
    final lastMsg = (initialImageUrl != null && initialImageUrl.isNotEmpty)
        ? (initialMessage.isNotEmpty ? initialMessage : '📷 Image')
        : initialMessage;

    await chatRef.set({
      'userUid': customerUid,
      'userName': customerName,
      'userEmail': customerEmail,
      'userType': 'customer',
      'subject': subject,
      'status': 'active',
      'lastMessage': lastMsg,
      'lastMessageAt': now,
      'createdAt': now,
      'resolvedAt': null,
      'resolvedByAdminUid': null,
    });

    final messageData = <String, dynamic>{
      'senderRole': 'customer',
      'senderUid': customerUid,
      'text': initialMessage,
      'createdAt': now,
    };
    if (initialImageUrl != null && initialImageUrl.isNotEmpty) {
      messageData['imageUrl'] = initialImageUrl;
    }

    await chatRef.collection('messages').add(messageData);
    return chatRef.id;
  }

  Future<void> sendCustomerMessage({
    required String chatId,
    required String customerUid,
    required String text,
    String? imageUrl,
  }) async {
    final now = FieldValue.serverTimestamp();
    final chatRef = _supportChats.doc(chatId);
    final messageData = <String, dynamic>{
      'senderRole': 'customer',
      'senderUid': customerUid,
      'text': text,
      'createdAt': now,
    };
    if (imageUrl != null && imageUrl.isNotEmpty) {
      messageData['imageUrl'] = imageUrl;
    }

    await chatRef.collection('messages').add(messageData);

    final displayLastMessage = (imageUrl != null && imageUrl.isNotEmpty)
        ? (text.isNotEmpty ? text : '📷 Image')
        : text;

    await chatRef.set({
      'status': 'active',
      'lastMessage': displayLastMessage,
      'lastMessageAt': now,
      'resolvedAt': null,
      'resolvedByAdminUid': null,
    }, SetOptions(merge: true));
  }
}
