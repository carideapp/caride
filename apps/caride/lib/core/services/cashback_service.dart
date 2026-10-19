import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';

class TripCashbackConfig {
  const TripCashbackConfig({
    required this.isActive,
    required this.percent,
    required this.minFare,
    required this.destination,
  });

  final bool isActive;
  final double percent;
  final double minFare;
  final String destination; // 'main_wallet' or 'subsidy_wallet'

  bool get isSubsidyWallet => destination == 'subsidy_wallet';
}

class CashbackService {
  CashbackService._();
  static final CashbackService instance = CashbackService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetches the configured first ride cashback settings from config/referralSettings.
  Future<({bool isActive, double amount})> getCashbackConfig() async {
    try {
      final snap = await _firestore.collection('config').doc('referralSettings').get();
      if (!snap.exists) {
        return (isActive: true, amount: 500.0);
      }
      final data = snap.data() ?? {};
      final isActive = data['isFirstRideCashbackActive'] != false;
      final amount = (data['firstRideCashbackAmount'] as num?)?.toDouble() ?? 500.0;
      return (isActive: isActive, amount: amount > 0 ? amount : 500.0);
    } catch (e) {
      developer.log('Error reading cashback config: $e', name: 'CashbackService');
      return (isActive: true, amount: 500.0);
    }
  }

  /// Streams the current first ride cashback settings for real-time reactive UI.
  Stream<({bool isActive, double amount})> watchCashbackConfig() {
    return _firestore
        .collection('config')
        .doc('referralSettings')
        .snapshots()
        .map((snap) {
      if (!snap.exists) {
        return (isActive: true, amount: 500.0);
      }
      final data = snap.data() ?? {};
      final isActive = data['isFirstRideCashbackActive'] != false;
      final amount = (data['firstRideCashbackAmount'] as num?)?.toDouble() ?? 500.0;
      return (isActive: isActive, amount: amount > 0 ? amount : 500.0);
    });
  }

  /// Fetches the configured trip percentage cashback settings from config/referralSettings.
  Future<TripCashbackConfig> getTripCashbackConfig() async {
    try {
      final snap = await _firestore.collection('config').doc('referralSettings').get();
      if (!snap.exists) {
        return const TripCashbackConfig(
          isActive: true,
          percent: 5.0,
          minFare: 5000.0,
          destination: 'main_wallet',
        );
      }
      final data = snap.data() ?? {};
      final isActive = data['isTripCashbackActive'] != false;
      final percent = (data['tripCashbackPercent'] as num?)?.toDouble() ?? 5.0;
      final minFare = (data['tripCashbackMinFare'] as num?)?.toDouble() ?? 5000.0;
      final destination = (data['tripCashbackDestination'] as String?) ?? 'main_wallet';
      return TripCashbackConfig(
        isActive: isActive,
        percent: percent,
        minFare: minFare,
        destination: destination,
      );
    } catch (e) {
      developer.log('Error reading trip cashback config: $e', name: 'CashbackService');
      return const TripCashbackConfig(
        isActive: true,
        percent: 5.0,
        minFare: 5000.0,
        destination: 'main_wallet',
      );
    }
  }

  /// Streams the current trip percentage cashback settings for real-time UI.
  Stream<TripCashbackConfig> watchTripCashbackConfig() {
    return _firestore
        .collection('config')
        .doc('referralSettings')
        .snapshots()
        .map((snap) {
      if (!snap.exists) {
        return const TripCashbackConfig(
          isActive: true,
          percent: 5.0,
          minFare: 5000.0,
          destination: 'main_wallet',
        );
      }
      final data = snap.data() ?? {};
      final isActive = data['isTripCashbackActive'] != false;
      final percent = (data['tripCashbackPercent'] as num?)?.toDouble() ?? 5.0;
      final minFare = (data['tripCashbackMinFare'] as num?)?.toDouble() ?? 5000.0;
      final destination = (data['tripCashbackDestination'] as String?) ?? 'main_wallet';
      return TripCashbackConfig(
        isActive: isActive,
        percent: percent,
        minFare: minFare,
        destination: destination,
      );
    });
  }

  /// Evaluates and atomically awards the fixed first ride cashback to a customer's wallet.
  /// Guaranteed idempotent: will only ever award once per customer UID.
  Future<bool> awardFirstRideCashbackIfEligible({
    required String customerUid,
    required String rideId,
  }) async {
    if (customerUid.isEmpty) return false;

    try {
      // 1. Check promotion settings
      final config = await getCashbackConfig();
      if (!config.isActive || config.amount <= 0) {
        developer.log('First ride cashback disabled or amount <= 0', name: 'CashbackService');
        return false;
      }

      final customerRef = _firestore.collection('customers').doc(customerUid);

      // 2. Run Firestore transaction to ensure atomic idempotency
      return await _firestore.runTransaction<bool>((tx) async {
        final custDoc = await tx.get(customerRef);
        if (!custDoc.exists) {
          developer.log('Customer doc $customerUid does not exist', name: 'CashbackService');
          return false;
        }

        final data = custDoc.data() ?? {};
        final alreadyAwarded = data['hasReceivedFirstRideCashback'] == true;
        if (alreadyAwarded) {
          developer.log('Customer $customerUid already received first ride cashback.', name: 'CashbackService');
          return false;
        }

        final currentBalance = (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
        final newBalance = currentBalance + config.amount;

        // Update customer profile
        tx.update(customerRef, {
          'walletBalance': newBalance,
          'hasReceivedFirstRideCashback': true,
          'firstRideCashbackAmount': config.amount,
          'firstRideCashbackRideId': rideId,
          'firstRideCashbackAwardedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Create wallet transaction record
        final walletTxRef = _firestore.collection('walletTransactions').doc();
        tx.set(walletTxRef, {
          'uid': customerUid,
          'type': 'credit',
          'rawType': 'cashback',
          'amountNaira': config.amount,
          'description': 'First Ride Cashback',
          'method': 'Cashback',
          'status': 'completed',
          'rideId': rideId,
          'reference': rideId,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // Also record in credit_transactions for audit history
        final creditTxRef = _firestore.collection('credit_transactions').doc();
        tx.set(creditTxRef, {
          'uid': customerUid,
          'type': 'referral_reward',
          'amountNaira': config.amount,
          'rideId': rideId,
          'description': 'First Ride Cashback Reward',
          'createdAt': FieldValue.serverTimestamp(),
        });

        developer.log(
          'Awarded ₦${config.amount} first ride cashback to customer $customerUid for ride $rideId',
          name: 'CashbackService',
        );
        return true;
      });
    } catch (e, st) {
      developer.log(
        'Failed to award first ride cashback: $e',
        name: 'CashbackService',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  /// Evaluates and atomically awards the percentage cashback on a completed trip from ₦5,000 above.
  /// Destination can be either customer main wallet balance or CaRide Subsidy Wallet balance (creditBalance).
  /// Guaranteed idempotent: uses a dedicated idempotency marker on the ride doc or ledger to avoid duplicate awards.
  Future<bool> awardTripCashbackIfEligible({
    required String customerUid,
    required String rideId,
    required double fareAmount,
  }) async {
    if (customerUid.isEmpty || rideId.isEmpty) return false;

    try {
      // 1. Fetch trip cashback configuration
      final config = await getTripCashbackConfig();
      if (!config.isActive || config.percent <= 0) {
        developer.log('Trip cashback disabled or percent <= 0', name: 'CashbackService');
        return false;
      }

      final minFare = config.minFare > 0 ? config.minFare : 5000.0;
      if (fareAmount < minFare) {
        developer.log(
          'Trip fare ₦$fareAmount is below minimum threshold ₦$minFare for ride $rideId',
          name: 'CashbackService',
        );
        return false;
      }

      // 2. Calculate cashback amount (rounded to 2 decimal places)
      final rawCashback = (fareAmount * config.percent) / 100.0;
      final cashbackAmount = double.parse(rawCashback.toStringAsFixed(2));
      if (cashbackAmount <= 0) return false;

      final customerRef = _firestore.collection('customers').doc(customerUid);
      final rideRef = _firestore.collection('rides').doc(rideId);

      // 3. Atomically check idempotency & award in Firestore transaction
      return await _firestore.runTransaction<bool>((tx) async {
        final rideSnap = await tx.get(rideRef);
        if (rideSnap.exists && rideSnap.data()?['tripCashbackAwarded'] == true) {
          developer.log('Trip cashback already awarded for ride $rideId', name: 'CashbackService');
          return false;
        }

        final custDoc = await tx.get(customerRef);
        if (!custDoc.exists) {
          developer.log('Customer doc $customerUid does not exist', name: 'CashbackService');
          return false;
        }

        final custData = custDoc.data() ?? {};
        final percentFormatted = config.percent % 1 == 0
            ? config.percent.toInt().toString()
            : config.percent.toString();

        if (config.isSubsidyWallet) {
          // --- Destination: CaRide Subsidy Wallet (creditBalance) ---
          final currentCredit = (custData['creditBalance'] as num?)?.toDouble() ?? 0.0;
          final newCredit = currentCredit + cashbackAmount;

          tx.update(customerRef, {
            'creditBalance': newCredit,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Ledger record in credit_transactions
          final creditTxRef = _firestore.collection('credit_transactions').doc();
          tx.set(creditTxRef, {
            'uid': customerUid,
            'type': 'trip_cashback',
            'amountNaira': cashbackAmount,
            'rideId': rideId,
            'fareAmount': fareAmount,
            'cashbackPercent': config.percent,
            'destination': 'subsidy_wallet',
            'description': '$percentFormatted% Cashback for ₦${fareAmount.toStringAsFixed(0)} Trip',
            'createdAt': FieldValue.serverTimestamp(),
          });
        } else {
          // --- Destination: Customer Main Wallet Balance (walletBalance) ---
          final currentBalance = (custData['walletBalance'] as num?)?.toDouble() ?? 0.0;
          final newBalance = currentBalance + cashbackAmount;

          tx.update(customerRef, {
            'walletBalance': newBalance,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          // Ledger record in walletTransactions
          final walletTxRef = _firestore.collection('walletTransactions').doc();
          tx.set(walletTxRef, {
            'uid': customerUid,
            'type': 'credit',
            'rawType': 'cashback',
            'amountNaira': cashbackAmount,
            'description': '$percentFormatted% Trip Cashback (₦${fareAmount.toStringAsFixed(0)} trip)',
            'method': 'Cashback',
            'status': 'completed',
            'rideId': rideId,
            'reference': 'cashback_$rideId',
            'cashbackPercent': config.percent,
            'destination': 'main_wallet',
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Also record in credit_transactions for central admin audit
          final creditTxRef = _firestore.collection('credit_transactions').doc();
          tx.set(creditTxRef, {
            'uid': customerUid,
            'type': 'trip_cashback',
            'amountNaira': cashbackAmount,
            'rideId': rideId,
            'fareAmount': fareAmount,
            'cashbackPercent': config.percent,
            'destination': 'main_wallet',
            'description': '$percentFormatted% Trip Cashback credited to Main Wallet',
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        // Mark ride as awarded
        tx.update(rideRef, {
          'tripCashbackAwarded': true,
          'tripCashbackAmount': cashbackAmount,
          'tripCashbackPercent': config.percent,
          'tripCashbackDestination': config.destination,
          'tripCashbackAwardedAt': FieldValue.serverTimestamp(),
        });

        developer.log(
          'Awarded ₦$cashbackAmount ($percentFormatted%) trip cashback to customer $customerUid into ${config.destination} for ride $rideId (Fare: ₦$fareAmount)',
          name: 'CashbackService',
        );
        return true;
      });
    } catch (e, st) {
      developer.log(
        'Failed to award trip cashback: $e',
        name: 'CashbackService',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }
}
