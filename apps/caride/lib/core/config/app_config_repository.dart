import 'package:cloud_firestore/cloud_firestore.dart';

class AppDefaults {
  const AppDefaults({
    required this.defaultMapCenterLat,
    required this.defaultMapCenterLng,
  });

  final double defaultMapCenterLat;
  final double defaultMapCenterLng;

  static AppDefaults? fromMap(Map<String, dynamic> data) {
    final lat = data['defaultMapCenterLat'];
    final lng = data['defaultMapCenterLng'];
    if (lat is! num || lng is! num) return null;
    return AppDefaults(
      defaultMapCenterLat: lat.toDouble(),
      defaultMapCenterLng: lng.toDouble(),
    );
  }
}

class WalletTopUpConfig {
  const WalletTopUpConfig({
    required this.minAmountNaira,
    required this.quickAmountsNaira,
  });

  final double minAmountNaira;
  final List<double> quickAmountsNaira;

  static const WalletTopUpConfig defaults = WalletTopUpConfig(
    minAmountNaira: 100,
    quickAmountsNaira: [5000, 10000, 20000],
  );

  factory WalletTopUpConfig.fromMap(Map<String, dynamic> data) {
    final rawMin = data['minAmountNaira'];
    final minAmountNaira = (rawMin is num)
        ? rawMin.toDouble()
        : WalletTopUpConfig.defaults.minAmountNaira;

    final rawQuick = data['quickAmountsNaira'];
    final List<double> quickAmountsNaira;
    if (rawQuick is List) {
      final values = rawQuick
          .whereType<num>()
          .map((n) => n.toDouble())
          .where((v) => v > 0)
          .toList(growable: false);
      quickAmountsNaira =
          values.isEmpty ? WalletTopUpConfig.defaults.quickAmountsNaira : values;
    } else {
      quickAmountsNaira = WalletTopUpConfig.defaults.quickAmountsNaira;
    }

    return WalletTopUpConfig(
      minAmountNaira: minAmountNaira,
      quickAmountsNaira: quickAmountsNaira,
    );
  }
}

class AppConfigRepository {
  AppConfigRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<AppDefaults?> watchAppDefaults() {
    return _firestore.collection('config').doc('appDefaults').snapshots().map(
      (doc) {
        final data = doc.data();
        if (data == null) return null;
        return AppDefaults.fromMap(data);
      },
    );
  }

  static const List<String> fallbackCancelReasons = [
    'Driver is taking too long',
    'No driver available',
    'Driver asked me to cancel',
    'Incorrect pickup location',
    'Changed my mind',
    'Driver requested cash payment',
  ];

  Stream<List<String>> watchCancelRideReasons() {
    return _firestore.collection('config').doc('cancelRideReasons').snapshots().map(
      (doc) {
        final data = doc.data();
        final reasons = data?['reasons'];
        if (reasons is! List) return fallbackCancelReasons;
        final list = reasons.whereType<String>().where((s) => s.trim().isNotEmpty).toList(growable: false);
        return list.isEmpty ? fallbackCancelReasons : list;
      },
    );
  }

  Stream<WalletTopUpConfig> watchWalletTopUpConfig() {
    return _firestore.collection('config').doc('walletTopUp').snapshots().map(
      (doc) {
        final data = doc.data();
        if (data == null) return WalletTopUpConfig.defaults;
        return WalletTopUpConfig.fromMap(data);
      },
    );
  }

  Stream<DriverSettingsConfig> watchDriverSettings() {
    return _firestore.collection('config').doc('driverSettings').snapshots().map(
      (doc) {
        final data = doc.data();
        if (data == null) return DriverSettingsConfig.defaults;
        return DriverSettingsConfig.fromMap(data);
      },
    );
  }

  Future<DriverSettingsConfig> getDriverSettings() async {
    try {
      final doc = await _firestore.collection('config').doc('driverSettings').get();
      final data = doc.data();
      if (data == null) return DriverSettingsConfig.defaults;
      return DriverSettingsConfig.fromMap(data);
    } catch (_) {
      return DriverSettingsConfig.defaults;
    }
  }
}

class DriverSettingsConfig {
  const DriverSettingsConfig({
    required this.maxNegativeBalanceNaira,
  });

  final double maxNegativeBalanceNaira;

  static const DriverSettingsConfig defaults = DriverSettingsConfig(
    maxNegativeBalanceNaira: 3000.0,
  );

  factory DriverSettingsConfig.fromMap(Map<String, dynamic> data) {
    final maxNeg = (data['maxNegativeBalanceNaira'] as num?)?.toDouble() ??
        DriverSettingsConfig.defaults.maxNegativeBalanceNaira;
    return DriverSettingsConfig(maxNegativeBalanceNaira: maxNeg);
  }
}
