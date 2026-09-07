import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// Requests notification and "always" location access during app launch.
///
/// Foreground location is requested before [Permission.locationAlways], which
/// matches iOS and Android guidance. Denied states do not block startup.
Future<void> requestStartupPermissions() async {
  if (kIsWeb) return;

  await Permission.notification.request();

  final foreground = await Permission.location.request();
  if (foreground.isGranted || foreground.isLimited) {
    await Permission.locationAlways.request();
  }
}
