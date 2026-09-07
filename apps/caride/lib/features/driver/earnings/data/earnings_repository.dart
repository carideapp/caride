import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:caride/core/driver/models/earnings_model.dart';

class EarningsRepository {
  EarningsRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  Stream<double> streamWalletBalance() {
    final uid = _uid;
    if (uid == null) return Stream.value(0.0);
    return _firestore
        .collection('drivers')
        .doc(uid)
        .snapshots()
        .map((snap) => (snap.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0);
  }

  Stream<List<EarningsEntry>> streamEarnings() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('walletTransactions')
        .where('uid', isEqualTo: uid)
        .where('type', isEqualTo: 'credit')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(EarningsEntry.fromDoc).toList());
  }

  Stream<double> streamTodayEarnings() {
    final uid = _uid;
    if (uid == null) return Stream.value(0.0);

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _firestore
        .collection('walletTransactions')
        .where('uid', isEqualTo: uid)
        .where('type', isEqualTo: 'credit')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .snapshots()
        .map((snap) => snap.docs.fold<double>(
              0.0,
              (acc, doc) => acc + ((doc.data()['amountNaira'] as num?)?.toDouble() ?? 0),
            ));
  }

  Future<double> getTodayEarnings() async {
    final uid = _uid;
    if (uid == null) return 0;

    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final snap = await _firestore
        .collection('walletTransactions')
        .where('uid', isEqualTo: uid)
        .where('type', isEqualTo: 'credit')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .get();

    return snap.docs.fold<double>(
      0.0,
      (acc, doc) => acc + ((doc.data()['amountNaira'] as num?)?.toDouble() ?? 0),
    );
  }

  Future<double> getWeeklyEarnings() async {
    final uid = _uid;
    if (uid == null) return 0;

    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weekStart = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    final snap = await _firestore
        .collection('walletTransactions')
        .where('uid', isEqualTo: uid)
        .where('type', isEqualTo: 'credit')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(weekStart))
        .get();

    return snap.docs.fold<double>(
      0.0,
      (acc, doc) => acc + ((doc.data()['amountNaira'] as num?)?.toDouble() ?? 0),
    );
  }

  Future<double> getMonthlyEarnings() async {
    final uid = _uid;
    if (uid == null) return 0;

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final snap = await _firestore
        .collection('walletTransactions')
        .where('uid', isEqualTo: uid)
        .where('type', isEqualTo: 'credit')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .get();

    return snap.docs.fold<double>(
      0.0,
      (acc, doc) => acc + ((doc.data()['amountNaira'] as num?)?.toDouble() ?? 0),
    );
  }
}
