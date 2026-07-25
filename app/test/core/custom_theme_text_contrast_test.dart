import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/theme/app_theme.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_contrast.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_draft.dart';

/// WP-308: sahip "bazı yazılar okunmuyor… metin ve metin 2 açık ayarlı ama
/// zemine gömülü" dedi.
///
/// Kök neden: `CustomTheme` tipografiyi **tek** kopya saklıyor (açık varyantın
/// metin rengi pişmiş hâlde) ve `main.dart` aynı kopyayı hem açık hem koyu
/// `ThemeData`'ya veriyor. Tazeleme olmadan koyu modda başlık/gövde/etiket açık
/// varyantın koyu metin rengiyle çiziliyordu.
void main() {
  final draft = ThemeDraft.fromPreset(
    slotId: 'custom_1',
    name: 'Test',
    preset: themePresetById('campfire_night'),
  );

  // Kullanıcı seçimi: koyu varyantta neredeyse siyah zemin + açık bej metin.
  final tuned = draft.copyWith(
    darkColors: draft.darkColors.copyWith(
      scaffold: const Color(0xFF090909),
      surface1: const Color(0xFF121212),
      textPrimary: const Color(0xFFF3E2B7),
      textSecondary: const Color(0xFFD6C79F),
    ),
    lightColors: draft.lightColors.copyWith(
      scaffold: const Color(0xFFFDFCF8),
      textPrimary: const Color(0xFF16130C),
      textSecondary: const Color(0xFF4A4335),
    ),
    counterpartEdited: true,
  );

  group('WP-308 kayıtlı özel tema metin rengi', () {
    // Kaydet → oku turu: tipografi açık varyantın rengiyle diske yazılır.
    final saved = tuned.toCustomTheme();

    ThemeData themeFor(Brightness brightness) => AppTheme.fromCustomTokens(
      colors: brightness == Brightness.dark
          ? saved.darkColors
          : saved.lightColors,
      typography: saved.typography,
      shapes: saved.shapes,
      atmosphere: saved.atmosphere,
      feel: saved.feel,
      brightness: brightness,
    );

    test('koyu modda başlıklar kullanıcının açık metin rengini kullanır', () {
      final dark = themeFor(Brightness.dark);
      const expected = Color(0xFFF3E2B7);
      // Ekran görüntüsünde gömülü görünen yüzeyler bu slotlardan besleniyor.
      expect(dark.textTheme.titleMedium!.color, expected);
      expect(dark.textTheme.titleLarge!.color, expected);
      expect(dark.textTheme.headlineSmall!.color, expected);
      expect(dark.textTheme.bodyMedium!.color, expected);
      expect(dark.textTheme.labelMedium!.color, expected);
    });

    test('açık modda metin rengi açık varyantın kendi rengidir', () {
      final light = themeFor(Brightness.light);
      expect(light.textTheme.titleMedium!.color, const Color(0xFF16130C));
    });

    test('her iki varyantta da başlık zeminle AA eşiğini geçer', () {
      for (final brightness in Brightness.values) {
        final theme = themeFor(brightness);
        final colors = brightness == Brightness.dark
            ? saved.darkColors
            : saved.lightColors;
        expect(
          meetsContrastAa(theme.textTheme.titleMedium!.color!, colors.scaffold),
          isTrue,
          reason: '$brightness başlığı zemine gömülüyor',
        );
      }
    });
  });
}
