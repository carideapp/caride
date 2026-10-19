import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

enum WalletTxType { credit, debit }

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.rawType,
    required this.reference,
    required this.amountNaira,
    required this.method,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final WalletTxType type;
  final String rawType;
  final String reference;
  final double amountNaira;
  final String method;
  final String description;
  final DateTime createdAt;

  factory WalletTransaction.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final typeStr = (data['type'] as String?)?.trim().toLowerCase() ?? '';
    final descStr = (data['description'] as String?)?.trim().toLowerCase() ?? '';
    final isCredit = typeStr == 'credit' || 
                     typeStr == 'referral' || 
                     typeStr == 'cashback' ||
                     descStr.contains('referral') ||
                     descStr.contains('cashback');
                     
    return WalletTransaction(
      id: doc.id,
      type: isCredit ? WalletTxType.credit : WalletTxType.debit,
      rawType: typeStr,
      reference: (data['reference'] as String?) ?? (data['rideId'] as String?) ?? '',
      amountNaira: (data['amountNaira'] as num?)?.toDouble() ?? 0,
      method: (data['method'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory WalletTransaction.fromRentalBookingDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final vehicleTitle = (data['vehicleTitle'] as String?) ??
        (data['vehicleName'] as String?) ??
        'Rental Vehicle';
    final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
    final paymentMethodRaw =
        (data['paymentMethod'] as String? ?? '').toLowerCase();

    String methodLabel = 'Card';
    if (paymentMethodRaw == 'wallet') {
      methodLabel = 'Wallet';
    } else if (paymentMethodRaw == 'bank_transfer' ||
        paymentMethodRaw == 'banktransfer') {
      methodLabel = 'Bank Transfer';
    }

    DateTime created = DateTime.now();
    final c = data['updatedAt'] ?? data['createdAt'];
    if (c != null) {
      if (c is String) {
        created = DateTime.tryParse(c) ?? DateTime.now();
      } else if (c is Timestamp) {
        created = c.toDate();
      }
    }

    return WalletTransaction(
      id: 'rental_${doc.id}',
      type: WalletTxType.debit,
      rawType: 'rental_payment',
      reference: doc.id,
      amountNaira: amount,
      method: methodLabel,
      description: 'Rental Payment - $vehicleTitle',
      createdAt: created,
    );
  }
}

class WalletTransactionRepository {
  WalletTransactionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Streams the latest wallet transactions and rental booking payments for this user.
  Stream<List<WalletTransaction>> watchTransactions(String uid) {
    if (uid.isEmpty) return Stream.value(const []);

    final controller = StreamController<List<WalletTransaction>>.broadcast();
    final List<StreamSubscription> subs = [];
    final Map<String, WalletTransaction> txMap = {};

    void emitLatest() {
      final list = txMap.values.toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!controller.isClosed) {
        controller.add(list);
      }
    }

    // 1. Listen to walletTransactions where uid == uid
    subs.add(
      _firestore
          .collection('walletTransactions')
          .where('uid', isEqualTo: uid)
          .snapshots()
          .listen((snap) {
        for (final doc in snap.docs) {
          final tx = WalletTransaction.fromDoc(doc);
          txMap[tx.id] = tx;
        }
        emitLatest();
      }, onError: (_) {}),
    );

    // 2. Listen to rental_bookings where customerId == uid
    subs.add(
      _firestore
          .collection('rental_bookings')
          .where('customerId', isEqualTo: uid)
          .snapshots()
          .listen((snap) {
        for (final doc in snap.docs) {
          final data = doc.data();
          final paymentStatus =
              (data['paymentStatus'] as String? ?? '').toLowerCase();
          final status = (data['status'] as String? ?? '').toLowerCase();
          final isPaid = paymentStatus == 'paid' ||
              status == 'confirmed' ||
              status == 'in_progress' ||
              status == 'inprogress' ||
              status == 'completed';

          if (isPaid) {
            final tx = WalletTransaction.fromRentalBookingDoc(doc);
            txMap[tx.id] = tx;
          }
        }
        emitLatest();
      }, onError: (_) {}),
    );

    controller.onCancel = () {
      for (final s in subs) {
        s.cancel();
      }
    };

    return controller.stream;
  }
}

