// WP-835 — İLK AÇILIŞTA GELEN TEMA.
//
// Sahip geri bildirimi (gerçek cihaz, temiz kurulum): "default gelen tema kötü;
// kapak/ikon renklerine benzer sıcak, canlı bir ilk kullanım istiyorum."
//
// Eski davranış: tema kaydı hiç yokken `theme_palette` 'navy'ye düşüyor ve
// `migratePaletteIdToPreset('navy')` soğuk `ocean_glass` (#0A192F lacivert /
// #64FFDA turkuaz) veriyordu. Yani ilk kullanıcı tasarlanmış bir karşılama
// değil, bir göç eşlemesinin yan ürününü görüyordu.
//
// WP-841 (sahip kararı, aday karelerine bakarak): karşılama **açık** olsun —
// "3. seçenekteki (`soft_cream`) gibi ama logodaki turuncu renkte". Karşılama
// ailesi bu yüzden koyu `campfire_night` değil açık `campfire_day`; mod da
// ailenin parlaklığını izlediği için artık `light` başlar.
//
// Bu dosyanın ölçtüğü iki şey:
//   1. Temiz kurulum sıcak `campfire_day` ailesiyle, aile renk kaynağıyla
//      açılır ve bu seçim diske yazılır (ikinci açılışta geri dönmez).
//   2. 🔴 Tema tarafına tek bir kayıt bile yazmış kurulumda HİÇBİR ŞEY
//      değişmez: yalnız palet, aile+palet, aktif özel tema ve "yalnız göç
//      bayrağı" biçimlerinin dördü de aynen korunur.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/theme/app_theme.dart';
import 'package:online_study_room/core/theme/theme_settings.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_draft.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _Install = ({ProviderContainer container, SharedPreferences prefs});

Future<_Install> _install(Map<String, Object> seed) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  return (
    container: ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    ),
    prefs: prefs,
  );
}

/// `build()` içindeki kalıcı yazmalar `unawaited`; kuyruğu boşalt.
Future<void> _drainWrites() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Aktif özel teması olan bir kurulumun prefs biçimi.
String _customThemeJson() {
  final theme = ThemeDraft.fromPreset(
    slotId: 'custom_1',
    name: 'Özelim',
    preset: themePresetById('neon_focus'),
  ).toCustomTheme().copyWith(isDefined: true, updatedAt: DateTime(2026, 7, 1));
  return jsonEncode(theme.toMap());
}

void main() {
  group('temiz kurulum', () {
    test('sıcak karşılama ailesiyle ve aile renk kaynağıyla açılır', () async {
      final install = await _install({});
      addTearDown(install.container.dispose);

      final settings = install.container.read(themeSettingsProvider);

      expect(settings.familyId, kFirstRunFamilyId);
      expect(settings.familyId, 'campfire_day');
      expect(settings.colorSource, ThemeColorSource.family);
      // Eski hata tam buradaydı: aile yerine palet renkleri uygulanıyordu.
      expect(settings.usePaletteColors, isFalse);
      // Karşılama gerçekten ateş rengi: logodaki turuncu + kor vurgu.
      expect(settings.family.colors.primary, const Color(0xFFF97316));
      expect(settings.family.colors.accent, const Color(0xFFC2410C));
      // ...ve WP-841'den beri AÇIK: krem kağıt zemin, koyu değil.
      expect(settings.family.brightness, Brightness.light);
      expect(settings.family.colors.scaffold, const Color(0xFFFDF8F1));
      expect(
        settings.family.colors.scaffold.computeLuminance(),
        greaterThan(0.8),
      );
      // Soğuk eski varsayılan geri gelmesin.
      expect(settings.familyId, isNot('ocean_glass'));
      // Sahibin beğenmediği koyu aday da geri gelmesin.
      expect(settings.familyId, isNot('campfire_night'));
      // `soft_cream` ezilmedi: sahip onun iskeletini istedi, rengini değil.
      final softCream = themePresetById('soft_cream');
      expect(softCream.colors.primary, const Color(0xFFC4A484));
      expect(softCream.colors.accent, const Color(0xFFB8A9C9));
    });

    test('mod ailenin parlaklığını izler', () async {
      final install = await _install({});
      addTearDown(install.container.dispose);

      final settings = install.container.read(themeSettingsProvider);
      final brightness = themePresetById(kFirstRunFamilyId).brightness;

      expect(
        settings.mode,
        brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
      );
      // WP-841: karşılama ailesi açık, dolayısıyla kural gerçekten açık modu
      // üretiyor. (Yukarıdaki koşullu ifade aile koyuyken de yeşil kalırdı.)
      expect(brightness, Brightness.light);
      expect(settings.mode, ThemeMode.light);
    });

    test('seçim diske yazılır; ikinci açılışta aynı tema gelir', () async {
      final install = await _install({});
      addTearDown(install.container.dispose);

      expect(
        install.container.read(themeSettingsProvider).familyId,
        kFirstRunFamilyId,
      );
      await _drainWrites();

      expect(install.prefs.getString('theme_family'), kFirstRunFamilyId);
      expect(install.prefs.getString('theme_color_source'), 'family');
      // Mod ailenin parlaklığı: açık aile koyu modda açılmaz (WP-841).
      expect(install.prefs.getString('theme_mode'), ThemeMode.light.name);

      // İkinci açılış: aynı prefs, yeni container. Kayıt yazılmasaydı burada
      // `migratePaletteIdToPreset('navy')` yine ocean_glass döndürürdü.
      final second = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(install.prefs)],
      );
      addTearDown(second.dispose);

      final settings = second.read(themeSettingsProvider);
      expect(settings.familyId, kFirstRunFamilyId);
      expect(settings.colorSource, ThemeColorSource.family);
    });
  });

  group('mevcut kurulum aynen korunur', () {
    test('yalnız palet kaydı olan kurulum', () async {
      final install = await _install({'theme_palette': 'emerald'});
      addTearDown(install.container.dispose);

      final settings = install.container.read(themeSettingsProvider);

      // WP-302 göçünün verdiği aile: emerald → forest_study.
      expect(settings.familyId, 'forest_study');
      expect(settings.paletteId, 'emerald');
      expect(settings.familyId, isNot(kFirstRunFamilyId));
      await _drainWrites();
      expect(install.prefs.getString('theme_palette'), 'emerald');
      expect(install.prefs.getString('theme_family'), isNull);
    });

    test('aile + palet kaydı olan kurulum', () async {
      final install = await _install({
        'theme_family': 'nordic_snow',
        'theme_palette': 'navy',
        'theme_color_source': 'family',
        'theme_mode': 'light',
      });
      addTearDown(install.container.dispose);

      final settings = install.container.read(themeSettingsProvider);

      expect(settings.familyId, 'nordic_snow');
      expect(settings.paletteId, 'navy');
      expect(settings.colorSource, ThemeColorSource.family);
      expect(settings.mode, ThemeMode.light);
      await _drainWrites();
      expect(install.prefs.getString('theme_family'), 'nordic_snow');
      expect(install.prefs.getString('theme_mode'), 'light');
    });

    test('aktif özel teması olan kurulum', () async {
      final install = await _install({
        'theme_palette': 'custom_1',
        'theme_color_source': 'palette',
        'custom_themes_v2': <String>[_customThemeJson()],
        'custom_themes_migrated_v1': true,
        'active_custom_theme_id': 'custom_1',
      });
      addTearDown(install.container.dispose);

      final settings = install.container.read(themeSettingsProvider);

      expect(settings.activeCustomThemeId, 'custom_1');
      expect(settings.activeCustomTheme?.name, 'Özelim');
      expect(settings.colorSource, ThemeColorSource.palette);
      expect(settings.familyId, isNot(kFirstRunFamilyId));
      await _drainWrites();
      expect(install.prefs.getString('theme_family'), isNull);
    });

    test('yalnız göç bayrağı taşıyan eski kurulum', () async {
      // Temayı hiç seçmemiş ama uygulamayı bir kez açmış kullanıcı: gördüğü
      // tema sürüm güncellemesiyle değişmez.
      final install = await _install({
        'theme_color_source': 'family',
        'palette_source_migrated_v1': true,
      });
      addTearDown(install.container.dispose);

      final settings = install.container.read(themeSettingsProvider);

      expect(settings.familyId, 'ocean_glass');
      expect(settings.colorSource, ThemeColorSource.family);
      expect(settings.familyId, isNot(kFirstRunFamilyId));
    });
  });
}
