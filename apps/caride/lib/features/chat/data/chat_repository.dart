import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatThread {
  const ChatThread({
    required this.rideId,
    required this.name,
    required this.preview,
    required this.timestamp,
    required this.driverUid,
    this.unread = 0,
  });

  final String rideId;
  final String name;
  final String preview;
  final DateTime timestamp;
  final String driverUid;
  final int unread;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.text,
    required this.senderUid,
    required this.createdAt,
  });

  final String id;
  final String text;
  final String senderUid;
  final DateTime createdAt;
}

class ChatRepository {
  ChatRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<ChatThread>> watchThreads() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.value(const []);
    }

    return _firestore
        .collection('rideMessages')
        .where('participantUids', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((doc) {
                final data = doc.data();
                final participantUids = List<String>.from(data['participantUids'] ?? []);
                final driverUid = participantUids.firstWhere((id) => id != uid, orElse: () => '');
                final unreadMap = data['unreadCounts'] as Map<String, dynamic>?;
                final unreadCount = (unreadMap?[uid] as num?)?.toInt() ??
                    (data['unreadCount_$uid'] as num?)?.toInt() ??
                    (data['unreadCount'] as num?)?.toInt() ??
                    0;

                return ChatThread(
                  rideId: doc.id,
                  name: (data['driverName'] as String?) ??
                      (data['peerName'] as String?) ??
                      'Driver',
                  preview:
                      (data['lastMessage'] as String?) ?? 'No messages yet',
                  timestamp:
                      (data['lastMessageAt'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0),
                  unread: unreadCount,
                  driverUid: driverUid,
                );
              })
              .toList(growable: false);
        });
  }

  /// Streams the total unread messages count across all active chat threads for the current user.
  Stream<int> watchTotalUnreadCount() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('rideMessages')
        .where('participantUids', arrayContains: uid)
        .snapshots()
        .map((snap) {
          int total = 0;
          for (final doc in snap.docs) {
            final data = doc.data();
            final unreadMap = data['unreadCounts'] as Map<String, dynamic>?;
            final unreadCount = (unreadMap?[uid] as num?)?.toInt() ??
                (data['unreadCount_$uid'] as num?)?.toInt() ??
                (data['unreadCount'] as num?)?.toInt() ??
                0;
            total += unreadCount;
          }
          return total;
        });
  }

  /// Streams the unread messages count for a single active ride thread for the current user.
  Stream<int> watchUnreadCountForRide(String rideId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null || rideId.isEmpty) return Stream.value(0);

    return _firestore
        .collection('rideMessages')
        .doc(rideId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return 0;
          final data = doc.data() ?? {};
          final unreadMap = data['unreadCounts'] as Map<String, dynamic>?;
          return (unreadMap?[uid] as num?)?.toInt() ??
              (data['unreadCount_$uid'] as num?)?.toInt() ??
              (data['unreadCount'] as num?)?.toInt() ??
              0;
        });
  }

  /// Marks a specific chat thread as read for the current user.
  Future<void> markAsRead(String rideId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || rideId.isEmpty) return;

    try {
      await _firestore.collection('rideMessages').doc(rideId).set({
        'unreadCounts': {uid: 0},
        'unreadCount_$uid': 0,
        'unreadCount': 0,
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Stream<List<ChatMessage>> watchMessages(String rideId) {
    return _firestore
        .collection('rideMessages')
        .doc(rideId)
        .collection('messages')
        .orderBy('createdAt')
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((doc) {
                final data = doc.data();
                return ChatMessage(
                  id: doc.id,
                  text: (data['text'] as String?) ?? '',
                  senderUid: (data['senderUid'] as String?) ?? '',
                  createdAt:
                      (data['createdAt'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0),
                );
              })
              .toList(growable: false);
        });
  }

  Future<void> sendMessage({
    required String rideId,
    required String text,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final docRef = _firestore
        .collection('rideMessages')
        .doc(rideId)
        .collection('messages')
        .doc();
    final parentRef = _firestore.collection('rideMessages').doc(rideId);
    final now = FieldValue.serverTimestamp();

    final parentDoc = await parentRef.get();
    Map<String, dynamic> parentData = {};
    String recipientUid = '';

    if (!parentDoc.exists || parentDoc.data()?['participantUids'] == null) {
      final rideDoc = await _firestore.collection('rides').doc(rideId).get();
      if (rideDoc.exists) {
        final rideData = rideDoc.data() ?? {};
        final customerUid = rideData['customerUid'] as String?;
        final driverUid = rideData['driverUid'] as String?;
        final driverName = rideData['driverName'] as String?;
        String customerName = 'Customer';
        if (customerUid != null) {
          final custDoc = await _firestore.collection('customers').doc(customerUid).get();
          if (custDoc.exists) {
            customerName = (custDoc.data()?['fullName'] as String?) ?? 'Customer';
          }
        }
        if (customerUid != null && driverUid != null) {
          parentData['participantUids'] = [customerUid, driverUid];
          parentData['driverName'] = driverName ?? 'Driver';
          parentData['customerName'] = customerName;
          parentData['peerName'] = driverName ?? 'Driver';
          recipientUid = uid == customerUid ? driverUid : customerUid;
        }
      }
    } else {
      final participantUids = List<String>.from(parentDoc.data()?['participantUids'] ?? []);
      recipientUid = participantUids.firstWhere((id) => id != uid, orElse: () => '');
    }

    await _firestore.runTransaction((txn) async {
      txn.set(docRef, {
        'id': docRef.id,
        'rideId': rideId,
        'text': trimmed,
        'senderUid': uid,
        'createdAt': now,
      });

      final mergeData = <String, dynamic>{
        ...parentData,
        'rideId': rideId,
        'lastMessage': trimmed,
        'lastMessageAt': now,
        'lastSenderUid': uid,
      };

      if (recipientUid.isNotEmpty) {
        mergeData['unreadCounts.$recipientUid'] = FieldValue.increment(1);
        mergeData['unreadCount_$recipientUid'] = FieldValue.increment(1);
      }

      txn.set(parentRef, mergeData, SetOptions(merge: true));
    });
  }
}
