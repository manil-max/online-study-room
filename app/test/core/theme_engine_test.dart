import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/theme/app_theme.dart';

void main() {
  group('ThemePreset / WP-54', () {
    test('12 hazır tema tanımlı ve id benzersiz', () {
      expect(kThemePresets.length, 12);
      final ids = kThemePresets.map((p) => p.id).toSet();
      expect(ids.length, 12);
      expect(ids.contains('campfire_night'), isTrue);
      expect(ids.contains('material_you'), isTrue);
    });

    test('themePresetById bilinmeyende campfire fallback', () {
      final p = themePresetById('yok_boyle_bir_tema');
      expect(p.id, kThemePresets.first.id);
    });

    test('migratePaletteIdToPreset eski navy → campfire', () {
      expect(migratePaletteIdToPreset('navy'), 'campfire_night');
      expect(migratePaletteIdToPreset('ocean'), 'ocean_glass');
      expect(migratePaletteIdToPreset('custom_1'), 'campfire_night');
    });

    test('AppTheme.fromPreset tüm extension katmanlarını ekler', () {
      for (final preset in kThemePresets) {
        final theme = AppTheme.fromPreset(preset);
        expect(theme.extension<AppColors>(), isNotNull, reason: preset.id);
        expect(theme.extension<AppTypography>(), isNotNull, reason: preset.id);
        expect(theme.extension<AppShapes>(), isNotNull, reason: preset.id);
        expect(theme.extension<AppAtmosphere>(), isNotNull, reason: preset.id);
        expect(theme.extension<AppMotion>(), isNotNull, reason: preset.id);
        expect(theme.scaffoldBackgroundColor, preset.colors.scaffold);
      }
    });

    test('eski AppPalette dark yolu hâlâ ThemeData üretir', () {
      final theme = AppTheme.dark(kAppPalettes.first);
      expect(theme.extension<AppColors>(), isNotNull);
      expect(theme.colorScheme.primary, kAppPalettes.first.primary);
    });

    test('fromFamily karşı parlaklıkta primary DNA taşır', () {
      final darkFamily = themePresetById('campfire_night');
      final light = AppTheme.fromFamily(darkFamily, Brightness.light);
      final dark = AppTheme.fromFamily(darkFamily, Brightness.dark);
      expect(dark.brightness, Brightness.dark);
      expect(light.brightness, Brightness.light);
      expect(dark.colorScheme.primary, darkFamily.colors.primary);
      // Light modda da aile primary korunur (seçim yok sayılmaz).
      expect(light.extension<AppColors>()!.primary, darkFamily.colors.primary);
    });

    test('AppColors.lerp ve AppShapes.lerp', () {
      final a = kThemePresets[0].colors;
      final b = kThemePresets[2].colors;
      final mid = a.lerp(b, 0.5);
      expect(mid.primary, isNot(equals(a.primary)));
      final s = AppShapes.soft.lerp(AppShapes.sharpBox, 1.0);
      expect(s.sharp, isTrue);
    });

    testWidgets('context.appColors extension erişimi', (tester) async {
      late AppColors colors;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.fromPreset(themePresetById('deep_amoled')),
          home: Builder(
            builder: (context) {
              colors = context.appColors;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(colors.scaffold, const Color(0xFF000000));
      expect(colors.primary, const Color(0xFF00FF88));
    });
  });
}
