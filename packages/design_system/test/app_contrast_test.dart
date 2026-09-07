import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppContrast', () {
    test('light mode text tokens are WCAG AA readable', () {
      expect(
        AppContrast.passesAa(AppColors.textPrimaryLight, AppColors.lightSurfaceRaised),
        isTrue,
      );
      expect(
        AppContrast.passesAa(AppColors.textSecondaryLight, AppColors.lightSurfaceRaised),
        isTrue,
      );
      expect(
        AppContrast.passesAa(Colors.white, AppColors.brand),
        isTrue,
      );
    });

    test('dark mode text tokens are WCAG AA readable', () {
      expect(
        AppContrast.passesAa(AppColors.textPrimaryDark, AppColors.darkSurfaceRaised),
        isTrue,
      );
      expect(
        AppContrast.passesAa(AppColors.textSecondaryDark, AppColors.darkSurfaceRaised),
        isTrue,
      );
      expect(
        AppContrast.passesAa(Colors.white, AppColors.brand),
        isTrue,
      );
    });
  });
}
