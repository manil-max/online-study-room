import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/theme/theme_settings.dart';
import 'package:online_study_room/core/theme/app_theme.dart';
import 'package:online_study_room/core/theme/custom_theme.dart';
import 'package:flutter/material.dart';

void main() {
  test('ThemeSettingsNotifier loads custom palettes and defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );

    final settings = container.read(themeSettingsProvider);
    expect(settings.paletteId, 'navy'); // Default
    expect(settings.customPalettes.length, 3);
    expect(settings.customPalettes[0].id, 'custom_1');
  });

  test('saveCustomPalette updates custom palette', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );

    final notifier = container.read(themeSettingsProvider.notifier);
    notifier.saveCustomPalette(
      0,
      const AppPalette(
        id: 'dummy',
        name: 'Yeni Palet',
        primary: Colors.red,
        onPrimary: Colors.white,
        accent: Colors.blue,
        onAccent: Colors.white,
      ),
    );

    final settings = container.read(themeSettingsProvider);
    expect(settings.customPalettes[0].name, 'Yeni Palet');
    expect(settings.customPalettes[0].primary, Colors.red);
    expect(
      settings.customPalettes[0].id,
      'custom_1',
    ); // zorunlu id override edildi mi kontrol et
  });

  test('setPalette navy does not force campfire_night family colors', () async {
    SharedPreferences.setMockInitialValues({
      'theme_family': 'deep_amoled',
      'theme_palette': 'emerald',
      'theme_color_source': 'family',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );

    final notifier = container.read(themeSettingsProvider.notifier);
    notifier.setPalette('navy');
    final settings = container.read(themeSettingsProvider);

    expect(settings.paletteId, 'navy');
    expect(settings.colorSource, ThemeColorSource.palette);
    expect(settings.usePaletteColors, isTrue);
    // Eski bug: family campfire_night (turuncu) oluyordu
    expect(settings.familyId, isNot('campfire_night'));
    expect(settings.palette.primary, paletteById('navy').primary);
  });

  test('WP-302: yerleşik palete bağlı kurulum aileye taşınır', () async {
    SharedPreferences.setMockInitialValues({
      'theme_family': 'deep_amoled',
      'theme_palette': 'emerald',
      'theme_color_source': 'palette',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final settings = container.read(themeSettingsProvider);
    // "Hazır Paletler" listesi kaldırıldı; palet kaynağında kalan kurulumda
    // Görünüm ekranında hiçbir kart seçili görünmezdi.
    expect(settings.colorSource, ThemeColorSource.family);
    expect(settings.usePaletteColors, isFalse);
    // Kullanıcının kendi seçtiği aile korunur, palet eşlemesi ezmez.
    expect(settings.familyId, 'deep_amoled');
    // Kalıcı yazma `build()`'i bloklamasın diye unawaited; kuyruğu boşalt.
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(prefs.getString('theme_color_source'), 'family');
    expect(prefs.getBool('palette_source_migrated_v1'), isTrue);
  });

  test('WP-302: custom_* palet göçü bu yoldan geçmez', () async {
    SharedPreferences.setMockInitialValues({
      'theme_palette': 'custom_1',
      'theme_color_source': 'palette',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    final settings = container.read(themeSettingsProvider);
    // Özel paletler WP-288 göçüyle özel temaya dönüşür; iki göç birbirini
    // ezerse kullanıcının kendi teması kaybolur.
    expect(settings.colorSource, ThemeColorSource.palette);
    expect(prefs.getBool('palette_source_migrated_v1'), isNot(true));
  });

  test('setFamily switches to atmosphere family colors', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    final notifier = container.read(themeSettingsProvider.notifier);
    notifier.setFamily('campfire_night');
    final settings = container.read(themeSettingsProvider);
    expect(settings.colorSource, ThemeColorSource.family);
    expect(settings.usePaletteColors, isFalse);
    expect(settings.familyId, 'campfire_night');
  });

  test('legacy custom palette migrates once and remains active', () async {
    SharedPreferences.setMockInitialValues({
      'theme_palette': 'custom_1',
      'theme_color_source': 'palette',
      'custom_palettes': [
        '{"id":"custom_1","name":"Eski tema","primary":4294901760,"onPrimary":4294967295,"accent":4278190335,"onAccent":4278190080}',
      ],
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );

    final settings = container.read(themeSettingsProvider);
    expect(settings.activeCustomTheme?.id, 'custom_1');
    expect(settings.customThemes[0].isDefined, isTrue);
    expect(
      settings.customThemes[0].lightColors.primary,
      const Color(0xFFFF0000),
    );
    expect(
      settings.customThemes[0].darkColors.primary,
      const Color(0xFFFF0000),
    );
  });

  test('custom theme save, activate and delete keep fixed slots', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    final notifier = container.read(themeSettingsProvider.notifier);
    final first = container.read(themeSettingsProvider).customThemes.first;

    expect(
      await notifier.saveCustomTheme(first.copyWith(name: 'Yeni tema')),
      ThemeSaveResult.saved,
    );
    expect(
      await notifier.setActiveCustomTheme('custom_1'),
      ThemeSaveResult.saved,
    );
    expect(
      container.read(themeSettingsProvider).activeCustomTheme?.name,
      'Yeni tema',
    );
    expect(await notifier.deleteCustomTheme('custom_1'), ThemeSaveResult.saved);
    final settings = container.read(themeSettingsProvider);
    expect(settings.customThemes.length, 3);
    expect(settings.customThemes[0].id, 'custom_1');
    expect(settings.customThemes[0].isDefined, isFalse);
    expect(settings.activeCustomTheme, isNull);
  });

  test(
    'future schema stays read-only and raw JSON is not overwritten',
    () async {
      final seed =
          CustomTheme(
              id: 'custom_1',
              name: 'Yeni sürüm',
              isDefined: true,
              updatedAt: DateTime(2026, 7, 24),
              lightColors: AppTheme.light(
                kAppPalettes.first,
              ).extension<AppColors>()!,
              darkColors: AppTheme.dark(
                kAppPalettes.first,
              ).extension<AppColors>()!,
              typography: AppTheme.light(
                kAppPalettes.first,
              ).extension<AppTypography>()!,
              shapes: AppTheme.light(
                kAppPalettes.first,
              ).extension<AppShapes>()!,
              atmosphere: AppTheme.light(
                kAppPalettes.first,
              ).extension<AppAtmosphere>()!,
              feel: AppTheme.light(kAppPalettes.first).extension<AppFeel>()!,
            ).toMap()
            ..['schemaVersion'] = 99
            ..['futureField'] = 'koru';
      SharedPreferences.setMockInitialValues({
        'custom_themes_v2': [jsonEncode(seed)],
        'custom_themes_migrated_v1': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      final theme = container.read(themeSettingsProvider).customThemes.first;
      expect(theme.isReadOnly, isTrue);
      expect(
        await container
            .read(themeSettingsProvider.notifier)
            .saveCustomTheme(theme),
        ThemeSaveResult.rejected,
      );
      expect(prefs.getStringList('custom_themes_v2')!.single, jsonEncode(seed));
    },
  );
}
