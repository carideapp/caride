import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum PendingTransferType {
  walletTopUp,
  rideBooking,
  carRental,
}

class PendingBankTransfer {
  const PendingBankTransfer({
    required this.reference,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    required this.amountNaira,
    required this.type,
    this.bookingId,
    required this.createdAt,
    this.expiresAt,
    this.isDismissed = false,
  });

  final String reference;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final double amountNaira;
  final PendingTransferType type;
  final String? bookingId;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isDismissed;

  bool get isExpired {
    final expiry = expiresAt ?? createdAt.add(const Duration(hours: 2));
    return DateTime.now().isAfter(expiry);
  }

  String get typeLabel {
    switch (type) {
      case PendingTransferType.walletTopUp:
        return 'Wallet Top-up';
      case PendingTransferType.rideBooking:
        return 'Ride Booking';
      case PendingTransferType.carRental:
        return 'Car Rental Payment';
    }
  }

  Map<String, dynamic> toJson() => {
        'reference': reference,
        'bankName': bankName,
        'accountName': accountName,
        'accountNumber': accountNumber,
        'amountNaira': amountNaira,
        'type': type.name,
        'bookingId': bookingId,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'isDismissed': isDismissed,
      };

  factory PendingBankTransfer.fromJson(Map<String, dynamic> json) {
    return PendingBankTransfer(
      reference: json['reference'] as String? ?? '',
      bankName: json['bankName'] as String? ?? '',
      accountName: json['accountName'] as String? ?? '',
      accountNumber: json['accountNumber'] as String? ?? '',
      amountNaira: (json['amountNaira'] as num?)?.toDouble() ?? 0.0,
      type: PendingTransferType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => PendingTransferType.walletTopUp,
      ),
      bookingId: json['bookingId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'] as String)
          : null,
      isDismissed: json['isDismissed'] as bool? ?? false,
    );
  }
}

class PendingBankTransferService {
  PendingBankTransferService._();
  static final PendingBankTransferService instance =
      PendingBankTransferService._();

  static const String _storageKey = 'caride_pending_bank_transfer_v1';
  final ValueNotifier<PendingBankTransfer?> pendingTransferNotifier =
      ValueNotifier(null);

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final pending = await getPendingTransfer();
    pendingTransferNotifier.value = pending;
  }

  Future<PendingBankTransfer?> getPendingTransfer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        pendingTransferNotifier.value = null;
        return null;
      }
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final transfer = PendingBankTransfer.fromJson(decoded);
      if (transfer.isExpired) {
        await clear();
        return null;
      }
      pendingTransferNotifier.value = transfer;
      return transfer;
    } catch (_) {
      return null;
    }
  }

  Future<void> save(PendingBankTransfer transfer) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(transfer.toJson()));
      pendingTransferNotifier.value = transfer;
    } catch (_) {}
  }

  Future<void> setDismissed(bool dismissed) async {
    final current = pendingTransferNotifier.value ?? await getPendingTransfer();
    if (current == null) return;
    final updated = PendingBankTransfer(
      reference: current.reference,
      bankName: current.bankName,
      accountName: current.accountName,
      accountNumber: current.accountNumber,
      amountNaira: current.amountNaira,
      type: current.type,
      bookingId: current.bookingId,
      createdAt: current.createdAt,
      expiresAt: current.expiresAt,
      isDismissed: dismissed,
    );
    await save(updated);
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      pendingTransferNotifier.value = null;
    } catch (_) {}
  }
}
