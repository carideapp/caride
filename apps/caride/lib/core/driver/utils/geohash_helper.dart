/// Pure-Dart base32 Geohash encoder compatible with `geofire-common`.
abstract final class GeohashHelper {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Encodes [latitude] and [longitude] into a base32 geohash of [precision].
  static String encode(double latitude, double longitude, {int precision = 7}) {
    var minLat = -90.0;
    var maxLat = 90.0;
    var minLng = -180.0;
    var maxLng = 180.0;

    var isEvenBit = true;
    var bit = 0;
    var ch = 0;
    final buffer = StringBuffer();

    while (buffer.length < precision) {
      if (isEvenBit) {
        final mid = (minLng + maxLng) / 2;
        if (longitude >= mid) {
          ch |= 1 << (4 - bit);
          minLng = mid;
        } else {
          maxLng = mid;
        }
      } else {
        final mid = (minLat + maxLat) / 2;
        if (latitude >= mid) {
          ch |= 1 << (4 - bit);
          minLat = mid;
        } else {
          maxLat = mid;
        }
      }

      isEvenBit = !isEvenBit;
      if (bit < 4) {
        bit++;
      } else {
        buffer.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return buffer.toString();
  }
}
