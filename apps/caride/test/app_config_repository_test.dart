import 'package:caride/core/config/app_config_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppDefaults.fromMap', () {
    test('returns null when missing keys', () {
      expect(AppDefaults.fromMap(const {}), isNull);
      expect(AppDefaults.fromMap({'defaultMapCenterLat': 1}), isNull);
      expect(AppDefaults.fromMap({'defaultMapCenterLng': 2}), isNull);
    });

    test('parses lat/lng', () {
      final result = AppDefaults.fromMap({
        'defaultMapCenterLat': 6.5,
        'defaultMapCenterLng': 3.3,
      });

      expect(result, isNotNull);
      expect(result!.defaultMapCenterLat, 6.5);
      expect(result.defaultMapCenterLng, 3.3);
    });
  });
}

