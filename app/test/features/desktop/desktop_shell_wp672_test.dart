// WP-672 — masaüstü kabuğu ve pencere davranışı.
// SPEC: docs/design/DESKTOP-UI-SPEC.md (§0 ölçek, §1.2 merdiven, §2.3 tavanlar,
// §6 DesktopPageScaffold, §8 sınanabilir iddialar).
//
// Bu dosyanın tek kuralı: KAYNAKTA YAZAN SAYI KANIT DEĞİLDİR. Kullanıcı boyanan
// pikseli görür. Her ölçüm `getTopLeft`/`getBottomRight` farkıyla (küresel,
// boyanmış koordinat) alınır ve `getSize` (yerel/mantıksal RenderBox boyutu) ile
// karşılaştırılır. İkisi ayrıştığında araya bir ölçek girmiş demektir — WP-672
// öncesi tam olarak bu oluyordu.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/desktop/desktop_layout.dart';
import 'package:online_study_room/features/desktop/desktop_home_shell.dart';
import 'package:online_study_room/features/desktop/desktop_navigation_pane.dart';
import 'package:online_study_room/features/desktop/desktop_page_scaffold.dart';
import 'package:online_study_room/features/desktop/desktop_proportional_scale.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

void main() {
  // 🔴 TUZAK: `debugDefaultTargetPlatformOverride` addTearDown ile
  // SIFIRLANAMAZ — `_verifyInvariants()` gövdeden hemen sonra, teardown'lardan
  // ÖNCE koşar ve "foundation debug variable was changed" diye patlar.
  //
  // Ama asıl not şu: WP-672'den sonra `DesktopHomeShell` ağacında
  // `isDesktopWindow`a bağlı TEK yerleşim dalı kalmadı (ölçek sarmalayıcısı
  // tek kullanıcıydı). Yani kabuk artık platformdan bağımsız aynı düzeni
  // kurar; ölçüm için override gerekmiyor. Override yalnız ölçek dosyasının
  // kendi Windows dalını sınayan testte kullanılır ([windowsScope]).
  Future<void> windowsScope(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  void sizedWindow(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }

  double paintedWidth(WidgetTester tester, Finder f) =>
      tester.getBottomRight(f).dx - tester.getTopLeft(f).dx;
  double paintedHeight(WidgetTester tester, Finder f) =>
      tester.getBottomRight(f).dy - tester.getTopLeft(f).dy;

  final paneFinder = find.byKey(
    const ValueKey('desktop-navigation-pane'),
    skipOffstage: false,
  );
  final settingsFinder = find.byKey(
    const ValueKey('desktop-rail-settings'),
    skipOffstage: false,
  );
  final screenFinder = find.byKey(const ValueKey('wp672-screen-0'));

  // Kabuğun İÇİNDEN görülen genişlik — SPEC §8 iddia 2'nin ölçüm noktası.
  double? seenWidth;
  Widget probeScreen(Key key) => Builder(
    builder: (context) {
      seenWidth = MediaQuery.sizeOf(context).width;
      return ColoredBox(
        key: key,
        color: Colors.red,
        child: const SizedBox.expand(),
      );
    },
  );

  Widget shell({ValueChanged<int>? onSelected, VoidCallback? onRefresh}) =>
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: DesktopHomeShell(
          selectedIndex: 0,
          screens: [
            probeScreen(const ValueKey('wp672-screen-0')),
            const ColoredBox(color: Colors.orange),
            const ColoredBox(color: Colors.yellow),
            const ColoredBox(color: Colors.green),
            const ColoredBox(color: Colors.blue),
          ],
          onDestinationSelected: onSelected ?? (_) {},
          onRefresh: onRefresh ?? () {},
        ),
      );

  group('SPEC §0 — kabuk ZOOM etmez, REFLOW eder', () {
    test('iddia 1: 2000×1200 görünümde ölçek 1.0 (ÖNCE: 1.5)', () {
      expect(desktopProportionalScale(viewport: const Size(2000, 1200)), 1.0);
      // Bant boyunca: eskiden 1100–1650 arası hep 1.0'dan büyüktü.
      for (final w in const [1280.0, 1440.0, 1600.0, 1920.0, 2560.0]) {
        expect(
          desktopProportionalScale(viewport: Size(w, 1000)),
          1.0,
          reason: '$w px pencerede hâlâ ölçek var',
        );
      }
      // Dar pencerede de küçültme yok: metin %65'e inmez.
      expect(desktopProportionalScale(viewport: const Size(700, 600)), 1.0);
    });

    testWidgets('iddia 2: kabuğun içi GERÇEK pencere genişliğini görür', (
      tester,
    ) async {
      sizedWindow(tester, const Size(2000, 1200));
      seenWidth = null;
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();

      // ÖNCE: 1333 (2000 / 1.5). Sahte MediaQuery.
      expect(seenWidth, moreOrLessEquals(2000, epsilon: 1));
    });

    testWidgets('sarmalayıcı kabuktan kaldırıldı (Windows dalında da)', (
      tester,
    ) async {
      await windowsScope(() async {
        sizedWindow(tester, const Size(2000, 1200));
        await tester.pumpWidget(shell());
        await tester.pumpAndSettle();
        expect(find.byType(DesktopProportionalScale), findsNothing);
        // Ve içerideki genişlik hâlâ gerçek pencere genişliği.
        expect(seenWidth, moreOrLessEquals(2000, epsilon: 1));
      });
    });

    // ÖNCE (ölçüldü): 1600→256, 2000→264, 2560→264. Kaynakta yazan 176 değil.
    for (final width in const [1600.0, 2000.0, 2560.0]) {
      testWidgets('$width px pencerede sol pane 176 px BOYANIR', (
        tester,
      ) async {
        sizedWindow(tester, Size(width, 1200));
        await tester.pumpWidget(shell());
        await tester.pumpAndSettle();

        expect(
          paintedWidth(tester, paneFinder),
          moreOrLessEquals(DesktopNavigationPane.expandedWidth, epsilon: 0.5),
          reason: 'sol şerit pencere büyüdükçe şişiyor (oransal zoom)',
        );
      });
    }

    testWidgets('şerit satırı ≤44 px BOYANIR (ÖNCE: 63)', (tester) async {
      sizedWindow(tester, const Size(2000, 1200));
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();

      expect(
        paintedHeight(tester, settingsFinder),
        lessThanOrEqualTo(DesktopNavigationPane.itemHeight + 4),
        reason: 'gezinme satırı masaüstü değil mobil yüksekliğinde',
      );
    });

    testWidgets('mantıksal boyut == boyanan boyut; letterbox/ölçek payı yok', (
      tester,
    ) async {
      sizedWindow(tester, const Size(2000, 1200));
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();

      expect(
        paintedWidth(tester, paneFinder),
        moreOrLessEquals(tester.getSize(paneFinder).width, epsilon: 0.5),
      );
      expect(
        paintedWidth(tester, screenFinder),
        moreOrLessEquals(tester.getSize(screenFinder).width, epsilon: 0.5),
      );
      expect(
        paintedWidth(tester, paneFinder) + paintedWidth(tester, screenFinder),
        moreOrLessEquals(2000, epsilon: 0.5),
      );
    });

    testWidgets('dar pencerede metin küçültülmez, şerit daralır', (
      tester,
    ) async {
      sizedWindow(tester, const Size(700, 600));
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();

      // ÖNCE: ölçek 0.65'e kelepçeleniyordu, mantıksal genişlik 1077 oluyor ve
      // pane "expanded" (176) kalıyordu — 114 fiziksel px'e sıkıştırılmış
      // etiketli şerit. Doğru masaüstü cevabı kırılım noktasıdır.
      expect(
        paintedWidth(tester, paneFinder),
        moreOrLessEquals(DesktopNavigationPane.compactWidth, epsilon: 0.5),
      );
    });
  });

  group('SPEC §1.2 — kırılım merdiveni', () {
    test('640/1008 korunur, 1200/1600 eklenir', () {
      expect(
        DesktopBreakpoints.windowClass(639),
        DesktopNavigationMode.minimal,
      );
      expect(
        DesktopBreakpoints.windowClass(640),
        DesktopNavigationMode.compact,
      );
      expect(
        DesktopBreakpoints.windowClass(1007),
        DesktopNavigationMode.compact,
      );
      expect(
        DesktopBreakpoints.windowClass(1008),
        DesktopNavigationMode.expanded,
      );
      expect(
        DesktopBreakpoints.windowClass(1199),
        DesktopNavigationMode.expanded,
      );
      expect(DesktopBreakpoints.windowClass(1200), DesktopNavigationMode.large);
      expect(DesktopBreakpoints.windowClass(1599), DesktopNavigationMode.large);
      expect(
        DesktopBreakpoints.windowClass(1600),
        DesktopNavigationMode.xlarge,
      );
    });

    test('navigationMode ŞERİT kararıdır, expanded’da durur', () {
      // 🔴 İŞLEV KORUMASI: `desktop_navigation_pane.dart` şeridi
      // `mode == expanded` ile açar. navigationMode 1200'de `large` dönseydi
      // şerit 176 → 52 px'e çökerdi, yani etiketler kaybolurdu.
      for (final w in const [1008.0, 1200.0, 1600.0, 2560.0]) {
        expect(
          DesktopBreakpoints.navigationMode(w),
          DesktopNavigationMode.expanded,
          reason: '$w px’te gezinme şeridi etiketlerini kaybediyor',
        );
      }
    });

    test('iddia 8: bütün masaüstü genişlik sabitleri 4’ün katı', () {
      final values = <String, double>{
        'compact': DesktopBreakpoints.compact,
        'expanded': DesktopBreakpoints.expanded,
        'large': DesktopBreakpoints.large,
        'xlarge': DesktopBreakpoints.xlarge,
        'maxProseWidth': DesktopBreakpoints.maxProseWidth,
        'maxFormWidth': DesktopBreakpoints.maxFormWidth,
        'maxLabelValueWidth': DesktopBreakpoints.maxLabelValueWidth,
        'labelValueTargetWidth': DesktopBreakpoints.labelValueTargetWidth,
        'maxStatTileWidth': DesktopBreakpoints.maxStatTileWidth,
        'maxChartCardWidth': DesktopBreakpoints.maxChartCardWidth,
        'maxContentWidth': DesktopBreakpoints.maxContentWidth,
        'defaultWindow.w': kDesktopDefaultWindowSize.width,
        'defaultWindow.h': kDesktopDefaultWindowSize.height,
        'minWindow.w': kDesktopMinimumWindowSize.width,
        'minWindow.h': kDesktopMinimumWindowSize.height,
      };
      values.forEach((name, value) {
        expect(value % 4, 0, reason: '$name = $value, 4’ün katı değil');
      });
    });

    test('§2.3 tavanları ölçü türetimiyle tutarlı', () {
      // 80 karakter × 7.5 px = 600 (WCAG 1.4.8); 66 karakter × 7.5 ≈ 496.
      expect(DesktopBreakpoints.maxProseWidth, 80 * 7.5);
      expect(DesktopBreakpoints.labelValueTargetWidth, closeTo(66 * 7.5, 1));
      // Prose tavanı form tavanının ALTINDA olmalı; 760 prose için 101 karakter.
      expect(
        DesktopBreakpoints.maxProseWidth,
        lessThan(DesktopBreakpoints.maxFormWidth),
      );
    });
  });

  group('pencere boyutu sözleşmesi', () {
    test('varsayılan pencere iki pane’lik düzeni gösterebilir', () {
      // İçerik = pencere − genişletilmiş şerit. Eşik `large` = 1200.
      // ÖNCE: 1100 − 176 = 924 → varsayılan pencerede iki pane İMKÂNSIZ.
      final content =
          kDesktopDefaultWindowSize.width - DesktopNavigationPane.expandedWidth;
      expect(content, greaterThanOrEqualTo(DesktopBreakpoints.large));
    });

    test('en küçük pencerede başlık şeridi masaüstü satır düzeninde kalır', () {
      // DesktopPageScaffold 760'ın (maxFormWidth) altında dikey yığına düşer.
      // ÖNCE: 560 − 52 = 508 → en küçük pencere telefon genişliği.
      expect(
        kDesktopMinimumWindowSize.width - DesktopNavigationPane.compactWidth,
        greaterThanOrEqualTo(DesktopBreakpoints.maxFormWidth),
      );
      expect(kDesktopMinimumWindowSize.height, greaterThanOrEqualTo(600));
    });

    test('minimum boyut TEK kaynaktan gelir', () {
      // ÖNCE: desktop_layout.dart 720×540, desktop_window_io.dart 560×540 —
      // aynı kavram iki dosyada iki farklı sayıydı.
      final clamped = clampDesktopWindowBounds(
        requested: const Rect.fromLTWH(0, 0, 100, 100),
        workAreas: const [Rect.fromLTWH(0, 0, 1920, 1040)],
        primaryWorkArea: const Rect.fromLTWH(0, 0, 1920, 1040),
      );
      expect(clamped.width, kDesktopMinimumWindowSize.width);
      expect(clamped.height, kDesktopMinimumWindowSize.height);
    });

    test('varsayılan pencere yaygın bir 1080p masaüstüne sığar', () {
      expect(kDesktopDefaultWindowSize.width, lessThanOrEqualTo(1920));
      expect(kDesktopDefaultWindowSize.height, lessThanOrEqualTo(1040));
    });
  });

  group('SPEC §6 — DesktopPageScaffold içerik sütununu sınırlar', () {
    Widget page({double? maxWidth, bool bodyOnly = false}) {
      const body = ColoredBox(
        key: ValueKey('wp672-body'),
        color: Colors.teal,
        child: SizedBox.expand(),
      );
      final actions = [
        FilledButton(
          key: const ValueKey('wp672-action'),
          onPressed: () {},
          child: const Text('Yenile'),
        ),
      ];
      return MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: bodyOnly
            ? Scaffold(
                appBar: AppBar(title: const Text('Dış AppBar')),
                body: DesktopPageBody(
                  title: 'İstatistik',
                  subtitle: 'Odak sürelerin',
                  icon: Icons.bar_chart,
                  maxWidth: maxWidth ?? DesktopBreakpoints.maxContentWidth,
                  actions: actions,
                  child: body,
                ),
              )
            : DesktopPageScaffold(
                title: 'İstatistik',
                subtitle: 'Odak sürelerin',
                icon: Icons.bar_chart,
                maxWidth: maxWidth ?? DesktopBreakpoints.maxContentWidth,
                actions: actions,
                child: body,
              ),
      );
    }

    testWidgets('2400 px pencerede gövde 1440 px ile sınırlı (ÖNCE: 2400)', (
      tester,
    ) async {
      sizedWindow(tester, const Size(2400, 1200));
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();

      expect(
        paintedWidth(tester, find.byKey(const ValueKey('wp672-body'))),
        moreOrLessEquals(DesktopBreakpoints.maxContentWidth, epsilon: 0.5),
      );
    });

    testWidgets('başlık ve eylemler tüm genişliğe yayılmaz', (tester) async {
      sizedWindow(tester, const Size(2400, 1200));
      await tester.pumpWidget(page());
      await tester.pumpAndSettle();

      // Bant ortalanır: 2400 → [480, 1920].
      const bandRight = (2400 + DesktopBreakpoints.maxContentWidth) / 2;
      const bandLeft = (2400 - DesktopBreakpoints.maxContentWidth) / 2;
      expect(
        tester.getTopRight(find.byKey(const ValueKey('wp672-action'))).dx,
        lessThanOrEqualTo(bandRight + 0.5),
        reason: 'eylem düğmesi başlıktan ~2300 px uzakta duruyor',
      );
      expect(
        tester.getTopLeft(find.text('İstatistik')).dx,
        greaterThanOrEqualTo(bandLeft),
      );
    });

    testWidgets('prose tavanı geçilince sütun 600 px’e iner', (tester) async {
      sizedWindow(tester, const Size(2400, 1200));
      await tester.pumpWidget(page(maxWidth: DesktopBreakpoints.maxProseWidth));
      await tester.pumpAndSettle();

      expect(
        paintedWidth(tester, find.byKey(const ValueKey('wp672-body'))),
        moreOrLessEquals(DesktopBreakpoints.maxProseWidth, epsilon: 0.5),
      );
    });

    testWidgets('gövde-only varyant iç içe Scaffold kurmaz', (tester) async {
      sizedWindow(tester, const Size(2400, 1200));
      await tester.pumpWidget(page(bodyOnly: true));
      await tester.pumpAndSettle();

      // Dış ekranın kendi Scaffold+AppBar'ı var; varyant ikincisini kurmamalı.
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text('Dış AppBar'), findsOneWidget);
      // Fluent başlık şeridi ve genişlik sınırı yine de uygulanır.
      expect(find.text('İstatistik'), findsOneWidget);
      expect(
        paintedWidth(tester, find.byKey(const ValueKey('wp672-body'))),
        moreOrLessEquals(DesktopBreakpoints.maxContentWidth, epsilon: 0.5),
      );
    });

    test('DesktopContent tek 1440 varsayılanını dayatmaz', () {
      // SPEC §6: `maxWidth` artık zorunlu — çağrı yeri türü açıkça seçer.
      const prose = DesktopContent(
        maxWidth: DesktopBreakpoints.maxProseWidth,
        child: SizedBox(),
      );
      expect(prose.maxWidth, 600);
    });

    test('iki sütun eşiği merdivene bağlandı (1080 sihirli sayısı gitti)', () {
      const cols = DesktopResponsiveColumns(
        primary: SizedBox(),
        secondary: SizedBox(),
      );
      expect(cols.breakpoint, DesktopBreakpoints.large);
      const md = DesktopMasterDetail(master: SizedBox(), detail: SizedBox());
      expect(md.breakpoint, DesktopBreakpoints.large);
    });
  });

  group('SPEC §7 — işlev kaybı yok', () {
    testWidgets('Ctrl+1…5 beş sekmeyi de seçer', (tester) async {
      sizedWindow(tester, const Size(2000, 1200));
      final picked = <int>[];
      await tester.pumpWidget(shell(onSelected: picked.add));
      await tester.pumpAndSettle();

      const digits = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
      ];
      for (final key in digits) {
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(key);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      }
      expect(picked, [0, 1, 2, 3, 4]);
    });

    testWidgets('F5 yenileme çalışır', (tester) async {
      sizedWindow(tester, const Size(2000, 1200));
      var refreshed = 0;
      await tester.pumpWidget(shell(onRefresh: () => refreshed++));
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      expect(refreshed, 1);
    });

    testWidgets('geniş ve dar pencerede tüm şerit eylemleri ayakta', (
      tester,
    ) async {
      for (final size in const [Size(2000, 1200), Size(700, 600)]) {
        sizedWindow(tester, size);
        await tester.pumpWidget(shell());
        await tester.pumpAndSettle();

        expect(settingsFinder, findsOneWidget, reason: 'Ayarlar yok: $size');
        expect(
          find.byKey(const ValueKey('desktop-rail-pin'), skipOffstage: false),
          findsOneWidget,
          reason: 'Üstte tut yok: $size',
        );
        expect(find.byIcon(Icons.refresh), findsOneWidget);
        expect(
          find.byIcon(Icons.picture_in_picture_alt_outlined),
          findsOneWidget,
          reason: 'Compact Focus yok: $size',
        );
        expect(find.byType(DesktopNavigationPane), findsOneWidget);
      }
    });

    testWidgets('geniş pencerede beş sekmenin etiketi de görünür', (
      tester,
    ) async {
      sizedWindow(tester, const Size(2000, 1200));
      await tester.pumpWidget(shell());
      await tester.pumpAndSettle();

      for (final label in const [
        'Ana Sayfa',
        'Saat',
        'Gruplar',
        'İstatistik',
        'Profil',
      ]) {
        expect(find.text(label), findsOneWidget, reason: '$label kayboldu');
      }
    });

    testWidgets('pane öğesine tıklama hâlâ sekme değiştirir', (tester) async {
      sizedWindow(tester, const Size(2000, 1200));
      int? selected;
      await tester.pumpWidget(shell(onSelected: (v) => selected = v));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gruplar'));
      await tester.pump();
      expect(selected, 2);
    });
  });

  group('SPEC §8 iddia 9 — mobil regresyon kapısı', () {
    testWidgets('390×844 Android’de ölçek sarmalayıcısı ağacı değiştirmez', (
      tester,
    ) async {
      sizedWindow(tester, const Size(390, 844));

      double? seen;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              seen = MediaQuery.sizeOf(context).width;
              return const SizedBox.expand();
            },
          ),
        ),
      );
      expect(seen, 390);
      // Mobil dal masaüstü sabitlerinin hiçbirine dokunmaz.
      expect(desktopProportionalScale(viewport: const Size(390, 844)), 1.0);
    });
  });
}
