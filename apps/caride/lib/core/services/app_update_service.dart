import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show ImageFilter;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// App Update Notification service for CaRide.
/// Checks configured latest version in Firestore `config/appUpdate` against installed version,
/// and displays a modern update prompt dialog on Home screens.
class AppUpdateService {
  AppUpdateService._();

  static const String currentInstalledVersion = '1.0.0';
  static bool _dismissedThisSession = false;
  static bool _dialogShowing = false;

  /// Checks if an update is available and presents the update popup if necessary.
  static Future<void> checkAndShowUpdateDialog(BuildContext context) async {
    try {
      if (_dialogShowing) return;

      final docSnap = await FirebaseFirestore.instance
          .collection('config')
          .doc('appUpdate')
          .get();

      if (!docSnap.exists) return;
      final data = docSnap.data();
      if (data == null) return;

      final bool isEnabled = data['isEnabled'] as bool? ?? false;
      if (!isEnabled) return;

      final String targetPlatform = (data['platform'] as String? ?? 'all').toLowerCase();
      final bool matchesPlatform = _matchesCurrentPlatform(targetPlatform);
      if (!matchesPlatform) return;

      final String latestVersion = data['latestVersion'] as String? ?? '1.0.0';
      final bool needsUpdate = isVersionOlder(currentInstalledVersion, latestVersion);
      if (!needsUpdate) return;

      final bool isMandatory = data['isMandatory'] as bool? ?? false;
      if (!isMandatory && _dismissedThisSession) return;

      final String title = data['title'] as String? ?? 'New Update Available';
      final String message = data['message'] as String? ??
          'A new version of CaRide is available. Please update your app to enjoy the latest improvements and features.';
      final String androidUrl = data['androidUrl'] as String? ?? '';
      final String iosUrl = data['iosUrl'] as String? ?? '';

      if (!context.mounted) return;

      _dialogShowing = true;
      await showDialog<void>(
        context: context,
        barrierDismissible: !isMandatory,
        barrierColor: Colors.black.withValues(alpha: 0.35),
        builder: (dialogContext) {
          return PopScope(
            canPop: !isMandatory,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Dialog(
                backgroundColor: Colors.transparent,
                child: GlassSurface(
                radius: AppRadius.xl,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.brandGlass,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.system_update_rounded,
                        color: AppColors.brand,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      title,
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      message,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        if (!isMandatory) ...[
                          Expanded(
                            child: SecondaryButton(
                              label: 'Later',
                              onPressed: () {
                                _dismissedThisSession = true;
                                Navigator.pop(dialogContext);
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                        ],
                        Expanded(
                          child: PrimaryButton(
                            label: 'Update Now',
                            onPressed: () async {
                              final String storeUrl = Platform.isIOS ? iosUrl : androidUrl;
                              final Uri? uri = Uri.tryParse(storeUrl.isNotEmpty ? storeUrl : (androidUrl.isNotEmpty ? androidUrl : iosUrl));
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                if (dialogContext.mounted) {
                                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                                    const SnackBar(
                                      content: Text('Could not open store link.'),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      );
    } catch (e) {
      debugPrint('[AppUpdateService] Error checking for app update: $e');
    } finally {
      _dialogShowing = false;
    }
  }

  static bool _matchesCurrentPlatform(String targetPlatform) {
    if (targetPlatform == 'all') return true;
    if (kIsWeb) return true;
    if (Platform.isAndroid && targetPlatform == 'android') return true;
    if (Platform.isIOS && targetPlatform == 'ios') return true;
    return false;
  }

  /// Compares semantic version strings (e.g. "1.0.0" vs "1.0.1").
  /// Returns `true` if [installed] is strictly older than [latest].
  static bool isVersionOlder(String installed, String latest) {
    try {
      final cleanInstalled = installed.split('+').first.trim();
      final cleanLatest = latest.split('+').first.trim();

      final installedParts = cleanInstalled.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final latestParts = cleanLatest.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLength = installedParts.length > latestParts.length
          ? installedParts.length
          : latestParts.length;

      for (int i = 0; i < maxLength; i++) {
        final inst = i < installedParts.length ? installedParts[i] : 0;
        final lat = i < latestParts.length ? latestParts[i] : 0;
        if (inst < lat) return true;
        if (inst > lat) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
