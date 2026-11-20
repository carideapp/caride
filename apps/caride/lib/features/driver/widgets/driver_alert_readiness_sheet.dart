import 'dart:async';

import 'package:caride/core/driver/notifications/driver_alert_audio_service.dart';
import 'package:caride/core/driver/services/driver_floating_overlay_service.dart';
import 'package:caride/core/notifications/app_notification_service.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Non-blocking driver alert diagnostics & ringtone test bottom sheet.
class DriverAlertReadinessSheet extends StatefulWidget {
  const DriverAlertReadinessSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DriverAlertReadinessSheet(),
    );
  }

  /// Checks whether any high-reliability alert permission/setting needs attention.
  static Future<bool> hasAttentionNeeded() async {
    if (kIsWeb) return false;
    try {
      final notifStatus = await Permission.notification.status;
      if (!notifStatus.isGranted) return true;

      final locPerm = await Geolocator.checkPermission();
      if (locPerm != LocationPermission.always) return true;

      if (defaultTargetPlatform == TargetPlatform.android) {
        final batteryOk = await AppNotificationService.instance
            .isBatteryOptimizationIgnored();
        final overlayOk = await DriverFloatingOverlayService.instance
            .hasOverlayPermission();
        if (!batteryOk || !overlayOk) return true;
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await AppNotificationService.instance
            .getIosNotificationReadiness();
        if (ios.isNotEmpty) {
          final auth = ios['authorizationStatus'];
          final sound = ios['soundSetting'];
          final lock = ios['lockScreenSetting'];
          if ((auth != 'authorized' && auth != 'provisional') ||
              sound == 'disabled' ||
              lock == 'disabled') {
            return true;
          }
        }
      }
    } catch (_) {}
    return false;
  }

  @override
  State<DriverAlertReadinessSheet> createState() =>
      _DriverAlertReadinessSheetState();
}

class _DriverAlertReadinessSheetState extends State<DriverAlertReadinessSheet>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _testingSound = false;
  bool _notificationsGranted = false;
  bool _locationAlways = false;
  bool _locationEnabled = true;
  bool _batteryUnrestricted = true;
  bool _overlayGranted = false;
  Map<String, String> _iosSettings = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshStatus());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(DriverAlertAudioService.instance.stopAlert());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshStatus());
    }
  }

  Future<void> _refreshStatus() async {
    bool notifOk = true;
    bool locAlways = true;
    bool locEnabled = true;
    bool batteryOk = true;
    bool overlayOk = true;
    Map<String, String> iosInfo = const {};

    try {
      final notifStatus = await Permission.notification.status;
      notifOk = notifStatus.isGranted;
    } catch (_) {}

    try {
      locEnabled = await Geolocator.isLocationServiceEnabled();
      final locPerm = await Geolocator.checkPermission();
      locAlways = locPerm == LocationPermission.always;
    } catch (_) {}

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      batteryOk = await AppNotificationService.instance
          .isBatteryOptimizationIgnored();
      overlayOk = await DriverFloatingOverlayService.instance
          .hasOverlayPermission();
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      iosInfo = await AppNotificationService.instance
          .getIosNotificationReadiness();
      final auth = iosInfo['authorizationStatus'];
      if (auth != null && auth.isNotEmpty) {
        notifOk = auth == 'authorized' || auth == 'provisional';
      }
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _notificationsGranted = notifOk;
      _locationAlways = locAlways;
      _locationEnabled = locEnabled;
      _batteryUnrestricted = batteryOk;
      _overlayGranted = overlayOk;
      _iosSettings = iosInfo;
    });
  }

  Future<void> _runTestRingtone() async {
    if (_testingSound) {
      await DriverAlertAudioService.instance.stopAlert();
      if (mounted) setState(() => _testingSound = false);
      return;
    }
    setState(() => _testingSound = true);
    await DriverAlertAudioService.instance.playTestRingtone(
      duration: const Duration(seconds: 4),
    );
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _testingSound = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF121821) : Colors.white;
    final tileColor = isDark
        ? const Color(0xFF1A222E)
        : const Color(0xFFF6F8FA);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final secondaryText = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF475569);

    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    final iosTimeSensitive = _iosSettings['timeSensitiveSetting'];
    final iosLockScreen = _iosSettings['lockScreenSetting'];
    final iosSound = _iosSettings['soundSetting'];
    final iosReady =
        iosSound != 'disabled' &&
        iosLockScreen != 'disabled' &&
        (iosTimeSensitive == null || iosTimeSensitive != 'disabled');

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxxl),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Ride Alert Readiness',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Make sure incoming ride requests ring loudly even when your screen is off or you are in another app.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: secondaryText,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.brand),
                  ),
                )
              else ...[
                _ReadinessTile(
                  icon: Icons.notifications_active_outlined,
                  title: isAndroid
                      ? 'Incoming Ride Alert Channel'
                      : 'Notification Permission',
                  subtitle: _notificationsGranted
                      ? (isAndroid
                            ? 'Enabled — verify ringtone & heads-up banners are allowed.'
                            : 'Allowed for CaRide.')
                      : 'Allow notifications so ride requests wake your screen.',
                  isReady: _notificationsGranted,
                  actionLabel: _notificationsGranted ? 'Review' : 'Enable',
                  tileColor: tileColor,
                  borderColor: borderColor,
                  secondaryText: secondaryText,
                  onAction: () async {
                    if (isAndroid) {
                      await AppNotificationService.instance
                          .openNotificationChannelSettings();
                    } else {
                      final status = await Permission.notification.request();
                      if (!status.isGranted) {
                        await openAppSettings();
                      }
                    }
                    await _refreshStatus();
                  },
                ),
                if (isIos) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _ReadinessTile(
                    icon: Icons.access_alarm_rounded,
                    title: 'Time Sensitive, Sound & Lock Screen',
                    subtitle: iosReady
                        ? 'Lock screen banners, sound, and Time Sensitive alerts enabled.'
                        : 'Enable Sounds, Lock Screen, and Time Sensitive Notifications in iOS Settings.',
                    isReady: iosReady,
                    actionLabel: iosReady ? 'Settings' : 'Fix',
                    tileColor: tileColor,
                    borderColor: borderColor,
                    secondaryText: secondaryText,
                    onAction: () async {
                      await openAppSettings();
                      await _refreshStatus();
                    },
                  ),
                ],
                if (isAndroid) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _ReadinessTile(
                    icon: Icons.battery_charging_full_rounded,
                    title: 'Unrestricted Battery Usage',
                    subtitle: _batteryUnrestricted
                        ? 'Unrestricted — Android will not delay background ride pushes.'
                        : 'Set CaRide Battery to Unrestricted so alerts arrive instantly.',
                    isReady: _batteryUnrestricted,
                    actionLabel: _batteryUnrestricted ? 'Review' : 'Fix',
                    tileColor: tileColor,
                    borderColor: borderColor,
                    secondaryText: secondaryText,
                    onAction: () async {
                      await AppNotificationService.instance
                          .openBatterySettings();
                      await _refreshStatus();
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ReadinessTile(
                    icon: Icons.picture_in_picture_alt_rounded,
                    title: 'Display Over Other Apps',
                    subtitle: _overlayGranted
                        ? 'Floating CaRide offer bubble active while outside the app.'
                        : 'Show incoming ride cards over Google Maps & other apps.',
                    isReady: _overlayGranted,
                    actionLabel: _overlayGranted ? 'Enabled' : 'Allow',
                    tileColor: tileColor,
                    borderColor: borderColor,
                    secondaryText: secondaryText,
                    onAction: _overlayGranted
                        ? null
                        : () async {
                            await DriverFloatingOverlayService.instance
                                .requestOverlayPermission();
                            await _refreshStatus();
                          },
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                _ReadinessTile(
                  icon: Icons.my_location_rounded,
                  title: 'Background Location ("Always")',
                  subtitle: !_locationEnabled
                      ? 'Turn on device Location services to stay matchable.'
                      : _locationAlways
                      ? 'Always allowed — keeps your pickup radius fresh while driving.'
                      : 'Allow "Always" location so nearby requests reach you reliably.',
                  isReady: _locationEnabled && _locationAlways,
                  actionLabel: (_locationEnabled && _locationAlways)
                      ? 'OK'
                      : 'Settings',
                  tileColor: tileColor,
                  borderColor: borderColor,
                  secondaryText: secondaryText,
                  onAction: (_locationEnabled && _locationAlways)
                      ? null
                      : () async {
                          await Geolocator.openAppSettings();
                          await _refreshStatus();
                        },
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: _testingSound
                      ? 'Stop Test Ringtone'
                      : 'Test Ride Ringtone',
                  showShadow: false,
                  icon: _testingSound
                      ? Icons.stop_rounded
                      : Icons.volume_up_rounded,
                  onPressed: _runTestRingtone,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Make sure Media / Ringtone volume is turned up and silent switch is off.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: secondaryText,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadinessTile extends StatelessWidget {
  const _ReadinessTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isReady,
    required this.actionLabel,
    required this.tileColor,
    required this.borderColor,
    required this.secondaryText,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isReady;
  final String actionLabel;
  final Color tileColor;
  final Color borderColor;
  final Color secondaryText;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = isReady ? AppColors.brand : const Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: tileColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: statusColor),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: isReady ? AppColors.brand : statusColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 6),
              child: Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: statusColor,
              ),
            ),
        ],
      ),
    );
  }
}
