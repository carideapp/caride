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
    this.type = 'ride',
    this.peerPhoto,
    this.vehicleTitle,
    this.fleetId,
    this.bookingId,
    this.customerUid,
    this.customerName,
    this.fleetName,
  });

  final String rideId;
  final String name;
  final String preview;
  final DateTime timestamp;
  final String driverUid;
  final int unread;
  final String type; // 'ride' or 'rental'
  final String? peerPhoto;
  final String? vehicleTitle;
  final String? fleetId;
  final String? bookingId;
  final String? customerUid;
  final String? customerName;
  final String? fleetName;
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

  Stream<List<ChatThread>> watchThreads({String? filterType}) {
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
          final threads = <ChatThread>[];

          for (final doc in snap.docs) {
            final data = doc.data();
            final type = (data['type'] as String?) ?? 'ride';

            if (filterType != null) {
              if (filterType == 'rental' && type != 'rental') continue;
              if (filterType == 'ride' && type == 'rental') continue;
            }

            final participantUids = List<String>.from(data['participantUids'] ?? []);
            final peerUid = participantUids.firstWhere((id) => id != uid, orElse: () => '');
            final unreadMap = data['unreadCounts'] as Map<String, dynamic>?;
            final unreadCount = (unreadMap?[uid] as num?)?.toInt() ??
                (data['unreadCount_$uid'] as num?)?.toInt() ??
                (data['unreadCount'] as num?)?.toInt() ??
                0;

            String resolvedName = 'User';
            String? resolvedPhoto;

            if (type == 'rental') {
              final customerUid = data['customerUid'] as String?;
              if (uid == customerUid) {
                resolvedName = (data['fleetName'] as String?) ?? (data['peerName'] as String?) ?? 'Fleet Partner';
                resolvedPhoto = (data['fleetLogo'] as String?) ??
                    (data['fleetLogoUrl'] as String?) ??
                    (data['logoUrl'] as String?) ??
                    (data['fleetPhotoUrl'] as String?) ??
                    (data['profilePictureUrl'] as String?) ??
                    (data['photoUrl'] as String?) ??
                    (data['coverPhotoUrl'] as String?);
              } else {
                resolvedName = (data['customerName'] as String?) ?? (data['peerName'] as String?) ?? 'Customer';
                resolvedPhoto = (data['customerPhoto'] as String?) ??
                    (data['customerPhotoUrl'] as String?) ??
                    (data['photoUrl'] as String?) ??
                    (data['profilePictureUrl'] as String?);
              }
            } else {
              final customerUid = data['customerUid'] as String?;
              if (uid == customerUid) {
                resolvedName = (data['driverName'] as String?) ?? (data['peerName'] as String?) ?? 'Driver';
              } else {
                resolvedName = (data['customerName'] as String?) ?? (data['peerName'] as String?) ?? 'Rider';
              }
            }

            threads.add(
              ChatThread(
                rideId: doc.id,
                name: resolvedName,
                preview: (data['lastMessage'] as String?) ?? 'No messages yet',
                timestamp: (data['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.fromMillisecondsSinceEpoch(0),
                unread: unreadCount,
                driverUid: peerUid,
                type: type,
                peerPhoto: resolvedPhoto,
                vehicleTitle: data['vehicleTitle'] as String?,
                fleetId: data['fleetId'] as String?,
                bookingId: data['bookingId'] as String?,
                customerUid: data['customerUid'] as String?,
                customerName: data['customerName'] as String?,
                fleetName: data['fleetName'] as String?,
              ),
            );
          }

          return threads;
        });
  }

  /// Creates or retrieves a rental chat thread for a booking.
  Future<String> startOrGetRentalThread({
    required String bookingId,
    required String fleetId,
    required String fleetName,
    required String customerUid,
    required String customerName,
    required String vehicleTitle,
    String? customerPhoto,
    String? vehicleImage,
    String? fleetOwnerUid,
    String? fleetLogo,
  }) async {
    final currentUid = _auth.currentUser?.uid;
    if (currentUid == null) return '';

    String resolvedOwnerUid = fleetOwnerUid ?? '';
    String? resolvedFleetLogo = fleetLogo;
    if (resolvedOwnerUid.isEmpty || resolvedFleetLogo == null || resolvedFleetLogo.isEmpty) {
      try {
        final fleetDoc = await _firestore.collection('fleets').doc(fleetId).get();
        final fData = fleetDoc.data();
        if (resolvedOwnerUid.isEmpty) {
          resolvedOwnerUid = (fData?['ownerUid'] as String?) ?? fleetId;
        }
        resolvedFleetLogo ??= (fData?['logoUrl'] as String?) ??
            (fData?['profilePictureUrl'] as String?) ??
            (fData?['photoUrl'] as String?) ??
            (fData?['coverPhotoUrl'] as String?);
      } catch (_) {
        if (resolvedOwnerUid.isEmpty) resolvedOwnerUid = fleetId;
      }
    }

    final threadId = 'rental_$bookingId';
    final threadRef = _firestore.collection('rideMessages').doc(threadId);
    final snap = await threadRef.get();

    final participantUids = [customerUid, resolvedOwnerUid];

    if (!snap.exists) {
      await threadRef.set({
        'type': 'rental',
        'bookingId': bookingId,
        'fleetId': fleetId,
        'fleetName': fleetName,
        'fleetLogo': resolvedFleetLogo,
        'customerUid': customerUid,
        'customerName': customerName,
        'customerPhoto': customerPhoto,
        'vehicleTitle': vehicleTitle,
        'vehicleImage': vehicleImage,
        'participantUids': participantUids,
        'lastMessage': 'Rental booking created: $vehicleTitle',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCounts': {
          customerUid: 0,
          resolvedOwnerUid: 0,
        },
      });
    } else if (resolvedFleetLogo != null && resolvedFleetLogo.isNotEmpty) {
      // Ensure existing thread has fleetLogo if it was missing
      final existingData = snap.data();
      if (existingData?['fleetLogo'] == null) {
        threadRef.update({'fleetLogo': resolvedFleetLogo}).catchError((_) {});
      }
    }

    return threadId;
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
      final docRef = _firestore.collection('rideMessages').doc(rideId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) return;

      await docRef.update({
        'unreadCounts.$uid': 0,
        'unreadCount_$uid': 0,
        'unreadCount': 0,
      });
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
