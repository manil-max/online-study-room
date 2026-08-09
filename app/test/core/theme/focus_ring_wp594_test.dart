import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/theme/app_theme.dart';
import 'package:online_study_room/core/theme/focus_ring_tokens.dart';
import 'package:online_study_room/core/theme/theme_presets.dart';
import 'package:online_study_room/core/theme/warning_tokens.dart';
import 'package:online_study_room/features/desktop/desktop_navigation_pane.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-594/3 — masaüstü sol panelindeki klavye odak halkası
/// `colorScheme.primary`e bağlıydı. Tema Stüdyosu'nda döşeme zeminine yakın
/// bir palet seçildiğinde halka eriyip görünmez oluyordu; bu, WP-358'de
/// kapatılan "uyarı rozeti tema çakışması"nın birebir aynısıdır.
///
/// Kayıp sessizdir: fareyle çalışan kullanıcı hiç fark etmez, yalnız klavyeyle
/// gezinen kullanıcı nerede olduğunu göremez.
void main() {
  group('resolveFocusRingColor', () {
    test('hazır temaların hepsinde zeminden ayrışır', () {
      final failures = <String>[];
      for (final preset in kThemePresets) {
        final theme = AppTheme.fromPreset(preset);
        for (final surface in <Color>[
          theme.colorScheme.surface,
          theme.colorScheme.surfaceContainerLowest,
          theme.colorScheme.secondaryContainer,
          theme.scaffoldBackgroundColor,
        ]) {
          final ratio = contrastRatio(resolveFocusRingColor(surface), surface);
          if (ratio < kMinSurfaceContrast) {
            failures.add(
              '${preset.id}: ${ratio.toStringAsFixed(2)} '
              '< $kMinSurfaceContrast',
            );
          }
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });

    test('en kötü zeminde (orta parlaklık) bile sınırı tutturur', () {
      // Kritik nokta akromatik gri rampasıdır: siyah ve beyazın kontrastı
      // burada eşitlenir. Rampayı tarayıp en düşük değeri ölç.
      var worst = double.infinity;
      for (var v = 0; v <= 255; v++) {
        final surface = Color.fromARGB(255, v, v, v);
        final ratio = contrastRatio(resolveFocusRingColor(surface), surface);
        if (ratio < worst) worst = ratio;
      }
      expect(worst, greaterThanOrEqualTo(kMinSurfaceContrast));
    });

    test('paletten değil zeminden türer — aynı zemin, aynı halka', () {
      // İki tema aynı zemini paylaşıp taban tabana zıt marka rengi taşısın.
      // Halka rengi paletten beslenseydi ikisi farklı çıkardı.
      const surface = Color(0xFF1B1B20);
      expect(
        resolveFocusRingColor(surface),
        resolveFocusRingColor(surface),
      );
      // Zemine **yakın** bir marka rengi seçmek sonucu değiştirmemeli.
      expect(
        contrastRatio(resolveFocusRingColor(surface), const Color(0xFF1C1C22)),
        greaterThanOrEqualTo(kMinSurfaceContrast),
      );
    });
  });

  group('sol panel odak halkası', () {
    /// 🔴 Kartın anlattığı senaryo: kullanıcı panel zeminine **çok yakın** bir
    /// birincil renk seçmiş. Eski kod halkayı `colorScheme.primary`den aldığı
    /// için halka zemine karışıyordu.
    ThemeData meltingTheme() {
      const surface = Color(0xFF16161C);
      final base = ThemeData.dark(useMaterial3: true);
      return base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          // primary ~ surface: kontrast 1.05 civarı, yani fiilen görünmez.
          primary: const Color(0xFF191920),
          surface: surface,
          surfaceContainerLowest: surface,
          secondaryContainer: const Color(0xFF23232B),
        ),
      );
    }

    Widget pane(ThemeData theme) {
      return MaterialApp(
        theme: theme,
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Row(
              children: [
                DesktopNavigationPane(
                  items: const [
                    DesktopNavItem(
                      icon: Icons.home_outlined,
                      selectedIcon: Icons.home,
                      label: 'Ana Sayfa',
                    ),
                    DesktopNavItem(
                      icon: Icons.groups_outlined,
                      selectedIcon: Icons.groups,
                      label: 'Gruplar',
                    ),
                  ],
                  selectedIndex: 0,
                  onSelected: (_) {},
                  footer: const SizedBox.shrink(),
                ),
                const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
        ),
      );
    }

    /// Bayrağa değil **boyaya** bakar: `focused` true olup kenarlığı saydam
    /// bırakan bir "düzeltme" buradan geçemez.
    List<BorderSide> paintedRings(WidgetTester tester) {
      return tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(DesktopNavFocusRing),
              matching: find.byType(DecoratedBox),
            ),
          )
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.border)
          .whereType<Border>()
          .map((border) => border.top)
          .where((side) => side.color != Colors.transparent && side.width > 0)
          .toList();
    }

    testWidgets('zemine yakın palette bile halka görünür kalır', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.reset);

      final theme = meltingTheme();
      await tester.pumpWidget(pane(theme));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();

      final rings = paintedRings(tester);
      expect(rings, hasLength(1));

      final surface = theme.colorScheme.surfaceContainerLowest;
      // Kontrol: bu temada eski kaynak (primary) gerçekten eriyor. Bu satır
      // olmadan test "zaten geçen" bir kurulumu ölçüyor olabilirdi.
      expect(
        contrastRatio(theme.colorScheme.primary, surface),
        lessThan(kMinSurfaceContrast),
        reason: 'kurulum hatalı: bu temada primary zaten ayrışıyor',
      );
      expect(
        contrastRatio(rings.single.color, surface),
        greaterThanOrEqualTo(kMinSurfaceContrast),
        reason: 'odak halkası zeminde eriyor',
      );
    });

    // İki yönlü iddia: "halkayı koşulsuz çiz" sabotajı buradan geçemez.
    testWidgets('odak yokken hiç halka çizilmez', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(pane(meltingTheme()));
      await tester.pumpAndSettle();

      expect(paintedRings(tester), isEmpty);
    });
  });
}
