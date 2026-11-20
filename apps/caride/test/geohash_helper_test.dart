import 'package:caride/core/driver/utils/geohash_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GeohashHelper', () {
    test('encodes deterministic geohash strings at default and custom precision', () {
      const lat = 6.5244;
      const lng = 3.3792; // Lagos
      final h1 = GeohashHelper.encode(lat, lng);
      final h2 = GeohashHelper.encode(lat, lng);
      final h9 = GeohashHelper.encode(lat, lng, precision: 9);

      expect(h1, equals(h2));
      expect(h1.length, equals(7));
      expect(h9.length, equals(9));
      expect(h9.startsWith(h1), isTrue);
    });

    test('produces distinct prefixes for Lagos vs Abuja', () {
      final lagos = GeohashHelper.encode(6.5244, 3.3792, precision: 5);
      final abuja = GeohashHelper.encode(9.0765, 7.3986, precision: 5);
      expect(lagos, isNot(equals(abuja)));
    });
  });
}
