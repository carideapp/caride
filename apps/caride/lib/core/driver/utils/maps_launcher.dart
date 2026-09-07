import 'package:url_launcher/url_launcher.dart';

class MapsLauncher {
  static Future<bool> openGoogleMaps({
    double? destinationLat,
    double? destinationLng,
    String? destinationLabel,
    double? originLat,
    double? originLng,
  }) async {
    final uri = _buildGoogleMapsUri(
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      destinationLabel: destinationLabel,
      originLat: originLat,
      originLng: originLng,
    );

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  static Uri _buildGoogleMapsUri({
    double? destinationLat,
    double? destinationLng,
    String? destinationLabel,
    double? originLat,
    double? originLng,
  }) {
    if (originLat != null && originLng != null && destinationLat != null && destinationLng != null) {
      return Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=$originLat,$originLng'
        '&destination=$destinationLat,$destinationLng'
        '&travelmode=driving',
      );
    } else if (destinationLat != null && destinationLng != null) {
      return Uri.parse(
        'https://www.google.com/maps/search/?api=1'
        '&query=$destinationLat,$destinationLng',
      );
    } else if (destinationLabel != null) {
      return Uri.parse(
        'https://www.google.com/maps/search/?api=1'
        '&query=${Uri.encodeComponent(destinationLabel)}',
      );
    }
    return Uri.parse('https://www.google.com/maps');
  }
}
