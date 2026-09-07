import 'package:url_launcher/url_launcher.dart';

class PhoneLauncher {
  static Future<bool> call(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '').trim();
    if (cleaned.isEmpty) return false;
    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      // Use launchUrl directly — canLaunchUrl is unreliable on Android 11+
      // when the tel: intent is not in the queries block.
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
