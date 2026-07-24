import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/theme/app_theme.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_contrast.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_draft.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_feel_catalog.dart';

ThemeDraft _draft({String slot = 'custom_1'}) => ThemeDraft.fromPreset(
  slotId: slot,
  name: 'Test',
  preset: themePresetById('campfire_night'),
);

void main() {
  group('ThemeDraft.fromPreset', () {
    test('açık ve koyu için iki ayrı tam renk seti üretir (ADR-1/R16)', () {
      final draft = _draft();
      expect(draft.lightColors.scaffold, isNot(draft.darkColors.scaffold));
      expect(draft.editing, Brightness.dark);
    });

    test('hazır ailenin biçim ve hareket karakterini devralır', () {
      final preset = themePresetById('campfire_night');
      final draft = _draft();
      expect(draft.shapes.radiusMd, preset.shapes.radiusMd);
      expect(draft.feel.motion.normal, preset.motion.normal);
    });
  });

  group('karşı varyant türetmesi', () {
    test('elle düzenlenmediyse renk değişimi karşı varyantı tazeler', () {
      final draft = _draft();
      final before = draft.lightColors.primary;
      final next = draft.withEditedColors(
        draft.darkColors.copyWith(primary: const Color(0xFF00E5FF)),
      );
      expect(next.darkColors.primary, const Color(0xFF00E5FF));
      expect(next.lightColors.primary, isNot(before));
    });

    test('karşı varyant elle düzenlendiyse artık ezilmez', () {
      final draft = _draft().withCounterpartColors(
        _draft().lightColors.copyWith(scaffold: const Color(0xFFFFF7E6)),
      );
      final next = draft.withEditedColors(
        draft.darkColors.copyWith(primary: const Color(0xFF12C281)),
      );
      expect(next.lightColors.scaffold, const Color(0xFFFFF7E6));
    });

    test('yeniden türet komutu elle düzenlemeyi geri alır', () {
      final draft = _draft()
          .withCounterpartColors(
            _draft().lightColors.copyWith(scaffold: const Color(0xFFFFF7E6)),
          )
          .withRederivedCounterpart();
      expect(draft.counterpartEdited, isFalse);
      expect(draft.lightColors.scaffold, isNot(const Color(0xFFFFF7E6)));
    });

    test('türetilen varyantta metin ve vurgu AA eşiğini geçer', () {
      final source = _draft().darkColors;
      final derived = deriveCounterpartColors(source, Brightness.light);
      expect(meetsContrastAa(derived.textPrimary, derived.scaffold), isTrue);
      expect(meetsContrastAa(derived.textSecondary, derived.scaffold), isTrue);
      expect(
        meetsContrastAa(derived.primary, derived.surface1, large: true),
        isTrue,
      );
      expect(meetsContrastAa(derived.onPrimary, derived.primary), isTrue);
    });
  });

  group('DraftTypography', () {
    test('token üretimi her zaman açık font ailesi yazar', () {
      // `app_theme.dart` yalnız fontFamily != null olan token'ı ek TextTheme
      // slotlarına taşır; aile null kalırsa kalınlık/aralık seçimi ölü kalırdı.
      final tokens = const DraftTypography().toTokens(const Color(0xFFFFFFFF));
      expect(tokens.title.fontFamily, isNotNull);
      expect(tokens.body.fontFamily, isNotNull);
      expect(tokens.label.fontFamily, isNotNull);
      expect(tokens.displayClock.fontFamily, isNotNull);
    });

    test('ölçek ve aralık seçimleri token boyutlarına yansır', () {
      final base = const DraftTypography().toTokens(const Color(0xFFFFFFFF));
      final scaled = const DraftTypography(
        scale: 1.3,
        letterSpacing: 1.0,
      ).toTokens(const Color(0xFFFFFFFF));
      expect(scaled.title.fontSize, greaterThan(base.title.fontSize!));
      expect(scaled.body.letterSpacing, 1.0);
    });

    test('kayıtlı token\'lardan sihirbaz durumu geri okunur (round-trip)', () {
      const source = DraftTypography(
        titleFamily: kFontFamilySerif,
        bodyFamily: kFontFamilyMono,
        clockFamily: kFontFamilySans,
        weightStep: 2,
        scale: 1.15,
        letterSpacing: 0.5,
      );
      final restored = DraftTypography.fromTokens(
        source.toTokens(const Color(0xFF000000)),
      );
      expect(restored.titleFamily, kFontFamilySerif);
      expect(restored.bodyFamily, kFontFamilyMono);
      expect(restored.clockFamily, kFontFamilySans);
      expect(restored.weightStep, 2);
      expect(restored.scale, closeTo(1.15, 0.001));
      expect(restored.letterSpacing, closeTo(0.5, 0.001));
    });
  });

  group('his seçimi', () {
    test('şekil ve atmosfer karakterini birlikte ayarlar (ölü anahtar yok)', () {
      final zen = _draft().withFeel(feelOptionById('zen').feel);
      final neon = _draft().withFeel(feelOptionById('neon').feel);
      expect(zen.shapes.radiusMd, greaterThan(neon.shapes.radiusMd));
      expect(neon.atmosphere.glowStrength, greaterThan(0));
      expect(zen.feel.feelId, 'zen');
    });

    test('doku isteyen hisler gren gücü taşır', () {
      expect(feelOptionById('vintage').feel.grainStrength, greaterThan(0));
      expect(feelOptionById('carton').feel.grainKind, 'carton');
      expect(feelOptionById('modern').feel.grainStrength, 0);
    });
  });

  group('CustomTheme dönüşümü', () {
    test('kaydet → oku turunda tüm katmanlar korunur', () {
      final draft = _draft()
          .withFeel(feelOptionById('paper').feel)
          .copyWith(name: 'Defter');
      final restored = ThemeDraft.fromCustomTheme(draft.toCustomTheme());

      expect(restored.name, 'Defter');
      expect(restored.slotId, draft.slotId);
      expect(restored.feel.feelId, 'paper');
      expect(restored.shapes.radiusMd, draft.shapes.radiusMd);
      expect(restored.lightColors.primary, draft.lightColors.primary);
      expect(restored.darkColors.scaffold, draft.darkColors.scaffold);
      // Kayıtlı temada iki varyant da gerçektir; türetme onları ezmemeli.
      expect(restored.counterpartEdited, isTrue);
    });

    test('üretilen ThemeData seçilen token\'ları gerçekten taşır', () {
      final draft = _draft().copyWith(
        typography: const DraftTypography(
          titleFamily: kFontFamilySerif,
          bodyFamily: kFontFamilySerif,
          scale: 1.2,
        ),
      );
      final theme = draft.themeFor(Brightness.dark);

      expect(theme.textTheme.titleLarge!.fontFamily, kFontFamilySerif);
      // R17: ek slotlar da tema kontrolünde olmalı, 4 slotta kalmamalı.
      expect(theme.textTheme.headlineMedium!.fontFamily, kFontFamilySerif);
      expect(theme.textTheme.bodySmall!.fontFamily, kFontFamilySerif);
      expect(theme.textTheme.labelSmall!.fontFamily, kFontFamilySerif);
      expect(theme.extension<AppFeel>(), isNotNull);
      expect(theme.extension<AppAtmosphere>(), isNotNull);
    });
  });
}
