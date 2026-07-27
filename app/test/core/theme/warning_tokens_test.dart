import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/theme/app_theme.dart';
import 'package:online_study_room/core/theme/warning_tokens.dart';

/// WP-358 (V49-2): uyarı rengi hangi tema seçilirse seçilsin zeminden ayrışmalı.
///
/// Bu testin varlık sebebi somut bir cihaz bulgusudur: kırmızı ağırlıklı temada
/// uyarı rozeti kayboluyordu, çünkü renk `ColorScheme.error`den geliyordu.
/// Aşağıdaki tarama, aynı hatanın **yeni bir tema eklendiğinde** sessizce geri
/// gelmesini engeller.
void main() {
  group('contrastRatio', () {
    test('siyah/beyaz uç değerleri WCAG sınırlarını verir', () {
      expect(contrastRatio(Colors.black, Colors.white), closeTo(21.0, 0.01));
      expect(contrastRatio(Colors.white, Colors.white), closeTo(1.0, 0.01));
    });

    test('simetriktir — sıra sonucu değiştirmez', () {
      const a = Color(0xFF123456);
      const b = Color(0xFFEEDDCC);
      expect(contrastRatio(a, b), closeTo(contrastRatio(b, a), 0.0001));
    });
  });

  group('resolveWarningColors', () {
    test('15 hazır temanın hepsinde zemine karşı AA sınırını tutturur', () {
      expect(kThemePresets.length, 15, reason: 'preset sayısı değiştiyse bu testi gözden geçir');

      final failures = <String>[];
      for (final preset in kThemePresets) {
        final theme = AppTheme.fromPreset(preset);
        final surface = theme.colorScheme.surface;
        final warning = resolveWarningColors(surface);

        final surfaceRatio = contrastRatio(warning.container, surface);
        if (surfaceRatio < kMinSurfaceContrast) {
          failures.add(
            '${preset.id}: dolgu/zemin ${surfaceRatio.toStringAsFixed(2)} '
            '< $kMinSurfaceContrast',
          );
        }

        final textRatio = contrastRatio(warning.onContainer, warning.container);
        if (textRatio < kMinTextContrast) {
          failures.add(
            '${preset.id}: metin/dolgu ${textRatio.toStringAsFixed(2)} '
            '< $kMinTextContrast',
          );
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('scaffold zemininde de sınırı tutturur', () {
      final failures = <String>[];
      for (final preset in kThemePresets) {
        final theme = AppTheme.fromPreset(preset);
        final scaffold = theme.scaffoldBackgroundColor;
        final ratio = contrastRatio(
          resolveWarningColors(scaffold).container,
          scaffold,
        );
        if (ratio < kMinSurfaceContrast) {
          failures.add('${preset.id}: ${ratio.toStringAsFixed(2)}');
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('kırmızı ağırlıklı zeminde uyarı kaybolmaz — bulgunun kendisi', () {
      // V49-2'nin somut senaryosu: koyu ve açık kırmızı yüzeyler.
      const redSurfaces = <Color>[
        Color(0xFF3B0A0A),
        Color(0xFF7F1D1D),
        Color(0xFFB91C1C),
        Color(0xFFEF4444),
        Color(0xFFFECACA),
      ];
      for (final surface in redSurfaces) {
        final warning = resolveWarningColors(surface);
        expect(
          contrastRatio(warning.container, surface),
          greaterThanOrEqualTo(kMinSurfaceContrast),
          reason: 'kırmızı zemin $surface üstünde uyarı ayrışmıyor',
        );
      }
    });

    test('saftır — aynı zemin her zaman aynı sonucu verir', () {
      const surface = Color(0xFF101418);
      final a = resolveWarningColors(surface);
      final b = resolveWarningColors(surface);
      expect(a.container, b.container);
      expect(a.onContainer, b.onContainer);
      expect(a.border, b.border);
    });

    test('kenar rengi dolgudan ayrışır', () {
      for (final surface in <Color>[
        const Color(0xFF0B0B0B),
        const Color(0xFFFDFDFD),
      ]) {
        final warning = resolveWarningColors(surface);
        expect(warning.border, isNot(warning.container));
      }
    });
  });
}
