import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/theme/theme_settings.dart';
import 'package:online_study_room/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

void main() {
  test('ThemeSettingsNotifier loads custom palettes and defaults', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
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
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );

    final notifier = container.read(themeSettingsProvider.notifier);
    notifier.saveCustomPalette(0, const AppPalette(
      id: 'dummy',
      name: 'Yeni Palet',
      primary: Colors.red,
      onPrimary: Colors.white,
      accent: Colors.blue,
      onAccent: Colors.white,
    ));

    final settings = container.read(themeSettingsProvider);
    expect(settings.customPalettes[0].name, 'Yeni Palet');
    expect(settings.customPalettes[0].primary, Colors.red);
    expect(settings.customPalettes[0].id, 'custom_1'); // zorunlu id override edildi mi kontrol et
  });
}
