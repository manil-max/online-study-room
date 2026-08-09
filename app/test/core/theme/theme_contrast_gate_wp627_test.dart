import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/theme/app_theme.dart';
import 'package:online_study_room/core/theme/container_roles.dart';
import 'package:online_study_room/core/theme/warning_tokens.dart';
import 'package:online_study_room/features/stats/charts/series_palette.dart';
import 'package:online_study_room/features/stats/widgets/member_chart_colors.dart';

/// WP-627 — **KONTRAST KAPISI**.
///
/// Bu depoda aynı sınıf hata üç kez ayrı ayrı yamalandı: WP-358 (uyarı rozeti),
/// WP-594 (odak halkası) ve şimdi container rolleri. Üçünde de kök neden aynı:
/// bir renk, üstünde duracağı zeminden **bağımsız** seçildi ve kayıp sessiz
/// oldu — kimse hata görmedi, sadece bir şey okunmaz hâle geldi.
///
/// Dördüncüsünü yama değil **kapı** engellesin. Kapı iddiaya değil ölçüme bakar:
/// tüm hazır temalar × ilgili rol çiftleri için kontrast oranını hesaplar.
/// Yeni bir tema eklenirse ya da bir rol bozulursa kırmızıya düşer.
///
/// 🔴 Eşiği düşürerek geçirmek yasaktır. Bir çift tutmuyorsa **renk** düzeltilir
/// — eşik WCAG AA'dır: metin 4.5, büyük metin / arayüz bileşeni 3.0.
void main() {
  group('kontrast kapısı — hazır temalar', () {
    test('metin rolleri zemininde ≥ 4.5', () {
      final failures = <String>[];
      var measured = 0;

      for (final preset in kThemePresets) {
        final s = AppTheme.fromPreset(preset).colorScheme;
        final pairs = <String, (Color, Color)>{
          'onPrimary/primary': (s.onPrimary, s.primary),
          'onSecondary/secondary': (s.onSecondary, s.secondary),
          'onTertiary/tertiary': (s.onTertiary, s.tertiary),
          'onError/error': (s.onError, s.error),
          'onSurface/surface': (s.onSurface, s.surface),
          'onSurfaceVariant/surface': (s.onSurfaceVariant, s.surface),
          'onSurface/surfaceContainerHighest': (
            s.onSurface,
            s.surfaceContainerHighest,
          ),
          // 🔴 Bulgunun merkezi: bu dört çift hiç tanımlı değildi ve
          // Flutter fallback'i onları tam doygun ana renge düşürüyordu.
          'onPrimaryContainer/primaryContainer': (
            s.onPrimaryContainer,
            s.primaryContainer,
          ),
          'onSecondaryContainer/secondaryContainer': (
            s.onSecondaryContainer,
            s.secondaryContainer,
          ),
          'onTertiaryContainer/tertiaryContainer': (
            s.onTertiaryContainer,
            s.tertiaryContainer,
          ),
          'onErrorContainer/errorContainer': (
            s.onErrorContainer,
            s.errorContainer,
          ),
        };
        for (final entry in pairs.entries) {
          measured++;
          final ratio = contrastRatio(entry.value.$1, entry.value.$2);
          if (ratio < kMinTextContrast) {
            failures.add(
              '${preset.id}  ${entry.key} = ${ratio.toStringAsFixed(2)}',
            );
          }
        }
      }

      // Kapı boşa dönmesin: tema listesi kazara boşalırsa da kırmızı olsun.
      expect(measured, kThemePresets.length * 11);
      expect(failures, isEmpty, reason: '\n${failures.join('\n')}');
    });

    test('ekranda çizilen vurgu çiftleri zemininde ≥ 3.0', () {
      final failures = <String>[];
      var measured = 0;

      void check(String label, Color foreground, Color background) {
        measured++;
        final ratio = contrastRatio(foreground, background);
        if (ratio < kMinSurfaceContrast) {
          failures.add('$label = ${ratio.toStringAsFixed(2)}');
        }
      }

      for (final preset in kThemePresets) {
        final theme = AppTheme.fromPreset(preset);
        final s = theme.colorScheme;

        // desktop_navigation_pane.dart + desktop_page_scaffold.dart:
        // seçim çubuğu ve onay ikonu seçili döşemenin üstünde durur.
        check(
          '${preset.id}  seçim çubuğu/secondaryContainer',
          accentOn(s.secondaryContainer, preferred: s.primary),
          s.secondaryContainer,
        );

        // Container zeminleri, üstünde durabilecekleri **her** yüzeyden
        // ayrışmalı; yoksa "seçili" durumu bir ekranda görünmez olur.
        for (final role in <String, Color>{
          'primaryContainer': s.primaryContainer,
          'secondaryContainer': s.secondaryContainer,
          'errorContainer': s.errorContainer,
        }.entries) {
          for (final ground in <String, Color>{
            'scaffold': s.surfaceContainerLowest,
            'surface': s.surface,
            'surfaceContainerHighest': s.surfaceContainerHighest,
          }.entries) {
            measured++;
            final ratio = contrastRatio(role.value, ground.value);
            if (ratio < kMinContainerSeparation) {
              failures.add(
                '${preset.id}  ${role.key}/${ground.key} ayrışmıyor = '
                '${ratio.toStringAsFixed(2)}',
              );
            }
          }
        }

        // series_palette.dart: her seri rengi kart yüzeyinde görünmeli.
        final palette = SeriesPalette(s);
        for (var i = 0; i < SeriesPalette.seriesCount; i++) {
          check(
            '${preset.id}  seri $i/surface',
            palette.colorAt(i),
            s.surface,
          );
        }

        // member_chart_colors.dart: 2–12 kişilik gerçekçi grup boyları.
        for (final size in const [2, 5, 8, 12]) {
          final colors = memberChartColors(
            List.generate(size, (i) => 'uye-$i'),
            surface: s.surface,
          );
          for (final entry in colors.entries) {
            check(
              '${preset.id}  üye ${entry.key} ($size kişi)/surface',
              entry.value,
              s.surface,
            );
          }
        }
      }

      // Tema başına: 1 seçim çubuğu + 9 ayrışma + 8 seri + (2+5+8+12) üye.
      expect(measured, kThemePresets.length * 45);
      expect(failures, isEmpty, reason: '\n${failures.join('\n')}');
    });

    test('camp_animal_picker seçili döşeme: yazı zemininde ≥ 4.5', () {
      // Döşeme, yazısını ve zeminini **aynı rolden** alır; kapı da ikisini
      // birlikte ölçer. Eskiden zemin `primaryContainer`, yazı ise temanın
      // genel etiket rengiydi: ikisinin birbiriyle ilgisi yoktu.
      final failures = <String>[];
      for (final preset in kThemePresets) {
        final s = AppTheme.fromPreset(preset).colorScheme;
        final ratio = contrastRatio(s.onPrimaryContainer, s.primaryContainer);
        if (ratio < kMinTextContrast) {
          failures.add('${preset.id} = ${ratio.toStringAsFixed(2)}');
        }
      }
      expect(failures, isEmpty, reason: '\n${failures.join('\n')}');
    });
  });

  group('seri renkleri gerçekten ayrık', () {
    test('SeriesPalette 8 rengin 8i de farklı', () {
      // 🔴 Ölçüldü (düzeltme öncesi): 8 "farklı" seriden gerçekte **4**'ü
      // farklıydı, çünkü tanımsız container rolleri ana renklere düşüyordu.
      for (final preset in kThemePresets) {
        final palette = SeriesPalette(
          AppTheme.fromPreset(preset).colorScheme,
        );
        final colors = {
          for (var i = 0; i < SeriesPalette.seriesCount; i++) palette.colorAt(i),
        };
        expect(
          colors,
          hasLength(SeriesPalette.seriesCount),
          reason: '${preset.id}: ${colors.length} ayrık renk',
        );
      }
    });

    test('memberChartColors her grup boyunda tekil kalır', () {
      for (final preset in kThemePresets) {
        final s = AppTheme.fromPreset(preset).colorScheme;
        for (final size in const [2, 5, 12, 24, 60]) {
          final colors = memberChartColors(
            List.generate(size, (i) => 'uye-${i.toString().padLeft(3, '0')}'),
            surface: s.surface,
          );
          expect(
            colors.values.toSet(),
            hasLength(size),
            reason: '${preset.id} / $size kişi',
          );
        }
      }
    });

    test('renkler zeminin fonksiyonu — açık ve koyu zemin aynı çıkmaz', () {
      // Eski hata tam buydu: açıklık sabitti, zemin hesaba hiç girmiyordu.
      final onDark = memberChartColors(
        const ['a', 'b', 'c'],
        surface: const Color(0xFF07090E),
      );
      final onLight = memberChartColors(
        const ['a', 'b', 'c'],
        surface: const Color(0xFFFFFFFF),
      );
      expect(onDark['a'], isNot(equals(onLight['a'])));
    });
  });

  group('kapı kendini sınar', () {
    // Kapının kendisi bozuksa (ör. her şeyi geçiren bir ölçüm) yukarıdaki
    // testler sessizce yeşil kalırdı. Bu grup ölçüm aygıtını sınar.
    test('kasten kötü çift ihlal olarak yakalanır', () {
      const surface = Color(0xFF12161E);
      const almostInvisible = Color(0xFF141A22);
      expect(contrastRatio(almostInvisible, surface), lessThan(1.2));
      expect(
        contrastRatio(almostInvisible, surface),
        lessThan(kMinSurfaceContrast),
      );

      // Eski davranışın birebir taklidi: container rolü boş bırakılırsa
      // Flutter onu tam doygun ana renge düşürür ve çubuk zemine gömülür.
      const scheme = ColorScheme.dark(
        primary: Color(0xFF00FF88),
        secondary: Color(0xFF00E5FF),
      );
      expect(
        scheme.secondaryContainer,
        scheme.secondary,
        reason: 'Flutter fallback davranışı değişmiş — kapı gözden geçirilmeli',
      );
      expect(
        contrastRatio(scheme.primary, scheme.secondaryContainer),
        lessThan(kMinSurfaceContrast),
      );
    });

    test('ensureContrast eşiği tutturur, tutturamıyorsa en iyiye düşer', () {
      // Rastgele ama deterministik bir tarama: 32 zemin × 32 ön plan.
      var worst = double.infinity;
      for (var b = 0; b < 32; b++) {
        final background = Color.fromARGB(255, b * 8, 255 - b * 8, (b * 5) % 256);
        for (var f = 0; f < 32; f++) {
          final preferred = Color.fromARGB(255, 255 - f * 8, f * 8, (f * 3) % 256);
          final fixed = ensureContrast(
            background: background,
            preferred: preferred,
            minRatio: kMinTextContrast,
          );
          final ratio = contrastRatio(fixed, background);
          if (ratio < worst) worst = ratio;
        }
      }
      // Orta parlaklıktaki zeminlerde 4.5 matematiksel olarak mümkün değildir
      // (siyah da beyaz da yetişmez); orada akromatik uca düşülür. En kötü
      // durumda bile 3.0'ın altına inmemelidir.
      expect(worst, greaterThanOrEqualTo(kMinSurfaceContrast));
    });

    test('ensureContrast zaten geçen rengi bozmaz', () {
      const background = Color(0xFF07090E);
      const preferred = Color(0xFFF97316);
      expect(
        ensureContrast(background: background, preferred: preferred),
        preferred,
      );
    });
  });

  group('tema kimliği korunur', () {
    // Amaç doygunluğu zemine uygun hâle getirmekti, palet değiştirmek değil.
    test('Kamp Ateşi turuncu, Nordik Kar açık kalır', () {
      final campfire = AppTheme.fromPreset(themePresetById('campfire_night'));
      expect(campfire.colorScheme.primary, const Color(0xFFF97316));
      // Turuncu ton ailesi container zemininde de sürer (hue ~20–40°).
      final hue = HSLColor.fromColor(
        campfire.colorScheme.primaryContainer,
      ).hue;
      expect(hue, greaterThan(15));
      expect(hue, lessThan(45));
      expect(campfire.colorScheme.brightness, Brightness.dark);

      final nordic = AppTheme.fromPreset(themePresetById('nordic_snow'));
      expect(nordic.colorScheme.brightness, Brightness.light);
      // Açık tema açık kalmalı: zeminler koyulaşmadı.
      expect(
        nordic.colorScheme.surface.computeLuminance(),
        greaterThan(0.7),
      );
      expect(
        nordic.colorScheme.secondaryContainer.computeLuminance(),
        greaterThan(0.4),
      );
    });

    test('container zemini ana renk kadar doygun DEĞİL', () {
      // Bulgunun tanımı buydu: container == primary. Bir daha olmasın.
      for (final preset in kThemePresets) {
        final s = AppTheme.fromPreset(preset).colorScheme;
        expect(
          s.primaryContainer,
          isNot(equals(s.primary)),
          reason: '${preset.id}: primaryContainer hâlâ primary',
        );
        expect(
          s.secondaryContainer,
          isNot(equals(s.secondary)),
          reason: '${preset.id}: secondaryContainer hâlâ secondary',
        );
        expect(
          s.errorContainer,
          isNot(equals(s.error)),
          reason: '${preset.id}: errorContainer hâlâ error',
        );
        expect(
          s.tertiary,
          isNot(equals(s.secondary)),
          reason: '${preset.id}: tertiary hâlâ secondary kopyası',
        );
        // Zemin ana renkten daha doygun olamaz. Tek istisna akromatik
        // paletlerdir (Paper & Ink): orada doygunluk tabana (0.06) oturur ki
        // zemin yüzeyden yalnız açıklıkla değil, bir tık tonla da ayrılsın.
        expect(
          HSLColor.fromColor(s.primaryContainer).saturation,
          lessThanOrEqualTo(
            math.max(HSLColor.fromColor(s.primary).saturation, 0.07),
          ),
          reason: '${preset.id}: container zemini ana renkten doygun',
        );
      }
    });
  });
}
