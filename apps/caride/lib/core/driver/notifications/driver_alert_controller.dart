import 'dart:async';
import 'package:flutter/widgets.dart';

import 'package:caride/core/driver/models/ride_model.dart';
import 'package:caride/core/driver/utils/distance_helper.dart';
import 'package:caride/core/notifications/app_notification_service.dart';
import 'driver_alert_audio_service.dart';

/// Central controller managing incoming ride alerts, foreground modal presentation,
/// 45s auto-timeout, deduplication, and native notification/decline synchronization.
class DriverAlertController with WidgetsBindingObserver {
  DriverAlertController._({
    DriverAlertAudioService? audioService,
    AppNotificationService? notificationService,
    bool attachLifecycleObserver = true,
  }) : _audioService = audioService ?? DriverAlertAudioService.instance,
       _notificationService =
           notificationService ?? AppNotificationService.instance,
       _attachLifecycleObserver = attachLifecycleObserver {
    if (_attachLifecycleObserver) {
      try {
        WidgetsBinding.instance.addObserver(this);
        _lifecycleState =
            WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
      } catch (_) {}
    }
  }

  @visibleForTesting
  DriverAlertController({
    DriverAlertAudioService? audioService,
    AppNotificationService? notificationService,
    bool isForeground = true,
  }) : _audioService = audioService ?? DriverAlertAudioService.instance,
       _notificationService =
           notificationService ?? AppNotificationService.instance,
       _attachLifecycleObserver = false,
       _lifecycleState = isForeground
           ? AppLifecycleState.resumed
           : AppLifecycleState.paused;

  static final DriverAlertController instance = DriverAlertController._();

  static const Duration alertTtl = Duration(seconds: 45);
  static const Duration _dedupWindow = Duration(minutes: 5);

  final DriverAlertAudioService _audioService;
  final AppNotificationService _notificationService;
  final bool _attachLifecycleObserver;

  final Map<String, DateTime> _alertedRideIds = {};
  final Set<String> _declinedRideIds = {};

  final ValueNotifier<RideModel?> activeForegroundOffer =
      ValueNotifier<RideModel?>(null);
  final ValueNotifier<double?> activeOfferDistanceKm = ValueNotifier<double?>(
    null,
  );

  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;
  bool _isDriverOnline = false;
  String? _activeAlertRideId;
  Timer? _autoStopTimer;
  bool _initialized = false;

  StreamSubscription<Map<String, dynamic>>? _foregroundPushSub;
  StreamSubscription<String>? _cancelledPushSub;
  StreamSubscription<String>? _declinedPushSub;

  bool get isAppForeground => _lifecycleState == AppLifecycleState.resumed;
  bool get isDriverOnline => _isDriverOnline;
  String? get activeAlertRideId => _activeAlertRideId;
  bool isRideDeclined(String rideId) => _declinedRideIds.contains(rideId);

  @visibleForTesting
  void setLifecycleForTest(AppLifecycleState state) {
    _lifecycleState = state;
  }

  void setDriverOnline(bool online) {
    _isDriverOnline = online;
    if (!online) {
      stopAlert();
    }
  }

  /// Subscribes to native foreground ride alerts/cancellations and syncs
  /// any ride IDs previously declined from OS notifications.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    await syncDeclinedIdsFromNative();

    _foregroundPushSub ??= _notificationService.foregroundRideAlerts.listen((
      data,
    ) {
      _handleForegroundPushPayload(data);
    });
    _cancelledPushSub ??= _notificationService.cancelledRideIds.listen((
      rideId,
    ) {
      _alertedRideIds[rideId] = DateTime.now();
      stopAlert(rideId: rideId);
    });
    _declinedPushSub ??= _notificationService.declinedRideIds.listen((rideId) {
      _declinedRideIds.add(rideId);
      _alertedRideIds[rideId] = DateTime.now();
      stopAlert(rideId: rideId);
    });
  }

  Future<void> syncDeclinedIdsFromNative() async {
    final ids = await _notificationService.getDeclinedRideIds();
    for (final id in ids) {
      final cleaned = id.trim();
      if (cleaned.isNotEmpty) {
        _declinedRideIds.add(cleaned);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed) {
      unawaited(syncDeclinedIdsFromNative());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_audioService.stopAlert());
    }
  }

  /// Processes live ride stream updates hosted by [DriverMainShell].
  void onRidesUpdated(
    List<RideModel> rides, {
    double? driverLat,
    double? driverLng,
    bool isOnline = true,
  }) {
    _isDriverOnline = isOnline;
    _cleanOldDeduplicationEntries();

    if (!isOnline || rides.isEmpty) {
      stopAlert();
      return;
    }

    final now = DateTime.now();
    final pendingRides = rides.where((r) {
      final openStatus =
          r.status == 'searching' ||
          r.status == 'requested' ||
          r.status == 'bidding';
      final notExpired = r.expiresAt == null || r.expiresAt!.isAfter(now);
      return openStatus && notExpired && !_declinedRideIds.contains(r.id);
    }).toList();

    if (pendingRides.isEmpty) {
      stopAlert();
      return;
    }

    if (_activeAlertRideId != null) {
      RideModel? matching;
      for (final r in pendingRides) {
        if (r.id == _activeAlertRideId) {
          matching = r;
          break;
        }
      }
      if (matching == null) {
        stopAlert(rideId: _activeAlertRideId);
      } else if (activeForegroundOffer.value != null &&
          activeForegroundOffer.value!.id == matching.id) {
        // Refresh in-place with canonical Firestore RideModel data.
        activeForegroundOffer.value = matching;
        final updatedDist = _computeDistanceKm(matching, driverLat, driverLng);
        if (updatedDist != null) {
          activeOfferDistanceKm.value = updatedDist;
        }
      }
    }

    if (!isAppForeground) {
      return;
    }

    for (final ride in pendingRides) {
      if (!_alertedRideIds.containsKey(ride.id)) {
        final dist = _computeDistanceKm(ride, driverLat, driverLng);
        _triggerRideAlert(ride, dist);
        break;
      }
    }
  }

  void _handleForegroundPushPayload(Map<String, dynamic> data) {
    if (!_isDriverOnline || !isAppForeground) return;
    final rideId = data['rideId']?.toString().trim() ?? '';
    if (rideId.isEmpty || _declinedRideIds.contains(rideId)) return;

    final expiresAtMs = int.tryParse(data['expiresAtMs']?.toString() ?? '');
    if (expiresAtMs != null &&
        expiresAtMs > 0 &&
        DateTime.now().millisecondsSinceEpoch >= expiresAtMs) {
      return;
    }

    if (_alertedRideIds.containsKey(rideId)) return;

    final offerAmount =
        double.tryParse(data['customerOffer']?.toString() ?? '') ?? 0.0;
    final distanceKm = double.tryParse(data['distanceKm']?.toString() ?? '');

    final syntheticRide = RideModel(
      id: rideId,
      customerUid: '',
      status: 'searching',
      pickupLabel:
          data['pickupLabel']?.toString().trim().isNotEmpty == true
              ? data['pickupLabel'].toString().trim()
              : 'Pickup location',
      dropoffLabel:
          data['dropoffLabel']?.toString().trim().isNotEmpty == true
              ? data['dropoffLabel'].toString().trim()
              : 'Destination',
      rideType:
          data['rideType']?.toString().trim().isNotEmpty == true
              ? data['rideType'].toString().trim()
              : 'Regular',
      customerOffer: offerAmount,
      paymentMethod:
          data['paymentMethod']?.toString().trim().isNotEmpty == true
              ? data['paymentMethod'].toString().trim()
              : 'cash',
      expiresAt: expiresAtMs != null && expiresAtMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(expiresAtMs)
          : null,
    );

    _triggerRideAlert(syntheticRide, distanceKm);
  }

  double? _computeDistanceKm(
    RideModel ride,
    double? driverLat,
    double? driverLng,
  ) {
    if (driverLat == null ||
        driverLng == null ||
        ride.pickupLat == null ||
        ride.pickupLng == null) {
      return null;
    }
    return calculateDistance(
      driverLat,
      driverLng,
      ride.pickupLat!,
      ride.pickupLng!,
    );
  }

  void _triggerRideAlert(RideModel ride, double? distanceKm) {
    if (!isAppForeground) return;
    _autoStopTimer?.cancel();
    _activeAlertRideId = ride.id;
    _alertedRideIds[ride.id] = DateTime.now();
    activeOfferDistanceKm.value = distanceKm;
    activeForegroundOffer.value = ride;

    unawaited(_audioService.startAlert());

    Duration timeout = alertTtl;
    final expiresAt = ride.expiresAt;
    if (expiresAt != null) {
      final remaining = expiresAt.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        stopAlert(rideId: ride.id);
        return;
      }
      if (remaining < timeout) {
        timeout = remaining;
      }
    }

    _autoStopTimer = Timer(timeout, () {
      if (_activeAlertRideId == ride.id) {
        stopAlert(rideId: ride.id);
      }
    });
  }

  /// Stops ringtone audio and OS notification without closing the foreground modal.
  void silenceAudio({String? rideId}) {
    unawaited(_audioService.stopAlert());
    final targetId = rideId?.trim().isNotEmpty == true
        ? rideId!.trim()
        : _activeAlertRideId;
    if (targetId != null && targetId.isNotEmpty) {
      unawaited(_notificationService.cancelRideNotification(targetId));
    }
  }

  /// Marks a ride request as declined locally and natively so alerts stop
  /// and will not re-trigger for the same ride.
  Future<void> declineRide(String rideId) async {
    final cleaned = rideId.trim();
    if (cleaned.isEmpty) return;
    _declinedRideIds.add(cleaned);
    _alertedRideIds[cleaned] = DateTime.now();
    stopAlert(rideId: cleaned);
    await _notificationService.markRideDeclined(cleaned);
  }

  /// Silences and clears any alert state for a handled/resolved ride.
  void resolveRide(String rideId) {
    stopAlert(rideId: rideId);
  }

  /// Stops active ringtone, clears the foreground offer modal, and cancels any
  /// OS notification for [rideId] (or the currently active alert if omitted).
  void stopAlert({String? rideId}) {
    final targetId = rideId?.trim();
    if (targetId != null &&
        targetId.isNotEmpty &&
        _activeAlertRideId != null &&
        _activeAlertRideId != targetId) {
      unawaited(_notificationService.cancelRideNotification(targetId));
      return;
    }

    final cancelledId = targetId?.isNotEmpty == true
        ? targetId
        : _activeAlertRideId;

    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _activeAlertRideId = null;
    activeForegroundOffer.value = null;
    activeOfferDistanceKm.value = null;
    unawaited(_audioService.stopAlert());

    if (cancelledId != null && cancelledId.isNotEmpty) {
      unawaited(_notificationService.cancelRideNotification(cancelledId));
    }
  }

  void _cleanOldDeduplicationEntries() {
    final now = DateTime.now();
    _alertedRideIds.removeWhere(
      (_, timestamp) => now.difference(timestamp) > _dedupWindow,
    );
  }

  Future<void> dispose() async {
    stopAlert();
    if (_attachLifecycleObserver) {
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (_) {}
    }
    await _foregroundPushSub?.cancel();
    await _cancelledPushSub?.cancel();
    await _declinedPushSub?.cancel();
    _foregroundPushSub = null;
    _cancelledPushSub = null;
    _declinedPushSub = null;
    _initialized = false;
  }
}
