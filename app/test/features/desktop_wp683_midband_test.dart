// WP-683 GEDIK 1 — ISTATISTIK ORTA BANDI (`expanded`, 1008-1199).
//
// WP-673 ve WP-680 kapilari yalniz **1920 ve 2560** cizer. Ikisi de
// `statsChartColumns() == 2` bandidir. `StatsSectionColumns` ise sutun sayisi
// 1 oldugunda (yani 1008-1199 `expanded` bandinda ve 640-1007 `compact`
// bandinda) `_stack(sections)`i CIPLAK dondururdu: `Align`/`ConstrainedBox`
// yok, tavan yok. Yani iki kapi da yesilken bandin ortasinda kart genisligi
// pencereyle birlikte buyumeye devam ediyordu.
//
// Bu dosya o bandi olcer. Hem KISISEL (`PersonalStatsView`) hem GRUP
// (`ClassStatsView`) sekmesi ayni dosyayi kullanir, ikisi de olculur.
//
// ============================== DISIPLIN =====================================
//
// 1. Iddia CIZILEN kutudan okunur (`tester.getRect`). Kaynakta `maxWidth: 720`
//    yazmasi kanit degildir.
// 2. 🔴 Sahte yesil tuzagi: anahtar `Align`a konulursa kabin genisligi olculur,
//    tavanin degil. Bu yuzden `stats-section-column-0` anahtari tavani
//    UYGULAYAN kutunun (`SizedBox`/`Expanded`) uzerindedir; asagida ayrica
//    anahtarli kutunun ICINDEKI kartlar da olculur.
// 3. Mobil dal ayni dosyada sinanir.
//
// ==================== WP-683 ONCESI OLCULEN SAYILAR ==========================
//
// Ayni harness, `devicePixelRatio = 1`, gercek kabuk (`DesktopContent(1440)`):
//
// | sekme | pencere | sutun | en genis kart |
// |---|---:|---:|---:|
// | kisisel | 1008 | 1 | **960 px**  ← GEDIK |
// | kisisel | 1200 | 2 | 708 px |
// | kisisel | 1920 | 2 | 708 px |
// | kisisel | 2560 | 2 | 708 px |
// | grup    | 1008 | 1 | **960 px**  ← GEDIK |
// | grup    | 1200 | 2 | 708 px |
//
// (Kesin sayilar asagidaki `WP-683 (0)` tanilama testinin ciktisindadir.)
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/desktop/desktop_layout.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/desktop/desktop_page_scaffold.dart';
import 'package:online_study_room/features/stats/widgets/class_stats_view.dart';
import 'package:online_study_room/features/stats/widgets/personal_stats_view.dart';
import 'package:online_study_room/features/stats/widgets/stats_desktop_layout.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SPEC §2.3 "Grafik karti": maks **720**.
const double kChartCapPx = kStatsChartMaxWidth;

/// SPEC §1.2 orta bant: `expanded` = 1008-1199.
const double kMidBandLow = DesktopBreakpoints.expanded; // 1008
const double kMidBandHigh = DesktopBreakpoints.large - 1; // 1199

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> onPlatform(
    TargetPlatform platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  List<StudySession> seed() {
    final now = DateTime.now();
    return [
      for (var i = 0; i < 12; i++)
        StudySession(
          id: 's$i',
          userId: 'u1',
          start: now.subtract(Duration(days: i, hours: 3)),
          end: now.subtract(Duration(days: i, hours: 2)),
          durationSeconds: 3600,
          source: StudySource.live,
          subjectId: i.isEven ? 'm' : 'f',
        ),
    ];
  }

  /// Gercek kabuk: `stats_screen.dart` masaustu dali gorunumu
  /// `DesktopContent(maxWidth: 1440)` ile sarar. Bandi taklit etmeyen test
  /// bandin ICINDEKI sutun kararini olcemez.
  Widget shell({required Widget view, required bool desktop}) => desktop
      ? DesktopContent(
          maxWidth: DesktopBreakpoints.maxContentWidth,
          padding: EdgeInsets.zero,
          child: view,
        )
      : view;

  Future<void> pumpPersonal(
    WidgetTester tester, {
    required Size window,
    bool desktop = true,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window;
    addTearDown(tester.view.reset);
    final sessions = seed();
    await tester.pumpWidget(
      ProviderScope(
        // Ayni testte iki FARKLI kapsam pump edilirse Riverpod "override
        // sayisi degistirilemez" atar; yeni anahtar yeni durum demektir.
        key: UniqueKey(),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          userSessionsProvider.overrideWith((ref) => Stream.value(sessions)),
          userSubjectsProvider.overrideWith((ref) => Stream.value(const [])),
          dailyGoalMinutesProvider.overrideWithValue(120),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: shell(
              view: PersonalStatsView(sessions: sessions),
              desktop: desktop,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpGroup(
    WidgetTester tester, {
    required Size window,
    bool desktop = true,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    Profile member(String id, String name) =>
        Profile(id: id, displayName: name, createdAt: DateTime(2026, 1, 1));
    final view = ClassStatsView(
      stats: [
        DailyStat(userId: 'u1', day: today, seconds: 3600),
        DailyStat(userId: 'u2', day: today, seconds: 1800),
        DailyStat(
          userId: 'u1',
          day: today.subtract(const Duration(days: 1)),
          seconds: 2400,
        ),
      ],
      members: [member('u1', 'Ada'), member('u2', 'Bora'), member('u3', 'Cem')],
      currentUserId: 'u1',
      groupGoalMinutes: 120,
    );
    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: shell(view: view, desktop: desktop),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  List<Rect> rects(WidgetTester tester, Finder finder) => [
    for (final element in finder.evaluate())
      tester.getRect(find.byWidget(element.widget)),
  ];

  double widestCard(WidgetTester tester) {
    final cards = rects(
      tester,
      find.descendant(
        of: find.byType(StatsSectionColumns),
        matching: find.byType(Card),
      ),
    );
    expect(cards, isNotEmpty, reason: 'Bolum kartlarindan hicbiri cizilmedi.');
    return cards.map((c) => c.width).reduce((a, b) => a > b ? a : b);
  }

  /// Bolum sutunlarinin CIZILEN kutulari. Anahtar tavani uygulayan kutudadir.
  List<Rect> columnBoxes(WidgetTester tester) {
    final out = <Rect>[];
    for (var i = 0; i < 4; i++) {
      final f = find.byKey(ValueKey('$kStatsSectionColumnKeyPrefix$i'));
      if (f.evaluate().isEmpty) break;
      out.add(tester.getRect(f));
    }
    return out;
  }

  // ===========================================================================
  // 0) TANILAMA — dort genislikte olcum, rapordaki sayilarin kaynagi
  // ===========================================================================

  testWidgets('WP-683 (0) tanilama: dort genislikte olcum dokumu', (
    tester,
  ) async {
    final lines = <String>[];
    for (final width in const [1008.0, 1200.0, 1920.0, 2560.0]) {
      await onPlatform(TargetPlatform.windows, () async {
        await pumpPersonal(tester, window: Size(width, 1400));
        final cols = columnBoxes(tester);
        lines.add(
          'kisisel @${width.toStringAsFixed(0)}: sutun=${cols.length} '
          'sutunGenislik=${cols.map((c) => c.width.toStringAsFixed(0)).join('/')} '
          'enGenisKart=${widestCard(tester).toStringAsFixed(0)}',
        );
      });
      await onPlatform(TargetPlatform.windows, () async {
        await pumpGroup(tester, window: Size(width, 1400));
        final cols = columnBoxes(tester);
        lines.add(
          'grup     @${width.toStringAsFixed(0)}: sutun=${cols.length} '
          'sutunGenislik=${cols.map((c) => c.width.toStringAsFixed(0)).join('/')} '
          'enGenisKart=${widestCard(tester).toStringAsFixed(0)}',
        );
      });
    }
    // ignore: avoid_print
    print('--- WP-683 ORTA BANT OLCUMU ---\n${lines.join('\n')}');
    expect(lines, hasLength(8));
  });

  // ===========================================================================
  // 1) ORTA BANT — kisisel sekme
  // ===========================================================================

  for (final width in const [kMidBandLow, 1100.0, kMidBandHigh]) {
    testWidgets(
      'WP-683 (1) kisisel @${width.toStringAsFixed(0)}: tek sutun 720 px\'te '
      'tavanlanir',
      (tester) async => onPlatform(TargetPlatform.windows, () async {
        await pumpPersonal(tester, window: Size(width, 1400));

        final cols = columnBoxes(tester);
        expect(
          cols,
          hasLength(1),
          reason:
              'Orta bantta ($kMidBandLow-$kMidBandHigh) grafik sutunu 1 olmali '
              '(SPEC §3 A2). Bulunan: ${cols.length}.',
        );
        expect(
          cols.single.width,
          lessThanOrEqualTo(kChartCapPx),
          reason:
              'Tek sutun ${cols.single.width.toStringAsFixed(0)} px cizildi; '
              'SPEC §2.3 grafik karti tavani ${kChartCapPx.toStringAsFixed(0)} '
              'px. WP-683 oncesi bu bantta HIC tavan yoktu.',
        );

        final widest = widestCard(tester);
        expect(
          widest,
          lessThanOrEqualTo(kChartCapPx),
          reason:
              'En genis kart ${widest.toStringAsFixed(0)} px; tavan '
              '${kChartCapPx.toStringAsFixed(0)} px. WP-673/WP-680 kapilari '
              'yalniz 1920 ve 2560 cizdigi icin bu bandi kimse olcmuyordu.',
        );
      }),
    );
  }

  // ===========================================================================
  // 2) ORTA BANT — grup sekmesi (AYNI dosya, AYRI cagri yeri)
  // ===========================================================================

  for (final width in const [kMidBandLow, kMidBandHigh]) {
    testWidgets(
      'WP-683 (2) grup @${width.toStringAsFixed(0)}: tek sutun 720 px\'te '
      'tavanlanir',
      (tester) async => onPlatform(TargetPlatform.windows, () async {
        await pumpGroup(tester, window: Size(width, 1400));

        final cols = columnBoxes(tester);
        expect(cols, hasLength(1));
        expect(
          cols.single.width,
          lessThanOrEqualTo(kChartCapPx),
          reason:
              'Grup sekmesi tek sutunu ${cols.single.width.toStringAsFixed(0)} '
              'px. Kisisel sekmeyle AYNI dosyayi kullanir; iki cagri yeri de '
              'olculmelidir.',
        );
        expect(widestCard(tester), lessThanOrEqualTo(kChartCapPx));
      }),
    );
  }

  // ===========================================================================
  // 3) GERILEME — 1200/1920/2560 iki sutun davranisi BOZULMADI
  // ===========================================================================

  for (final width in const [1200.0, 1920.0, 2560.0]) {
    testWidgets(
      'WP-683 (3) kisisel @${width.toStringAsFixed(0)}: iki sutun yan yana, '
      'kart <= 720',
      (tester) async => onPlatform(TargetPlatform.windows, () async {
        await pumpPersonal(tester, window: Size(width, 1400));
        final cols = columnBoxes(tester);
        expect(cols, hasLength(2), reason: 'Iki sutun duzeni kayboldu.');
        expect(cols[1].left, greaterThanOrEqualTo(cols[0].right));
        expect((cols[0].top - cols[1].top).abs(), lessThan(1));
        for (final c in cols) {
          expect(c.width, lessThanOrEqualTo(kChartCapPx));
        }
        expect(widestCard(tester), lessThanOrEqualTo(kChartCapPx));
      }),
    );
  }

  // ===========================================================================
  // 4) ISLEV KAYBI YOK — orta bantta HICBIR bolum dusmedi
  // ===========================================================================

  testWidgets('WP-683 (4) 1008 ile 1920 AYNI bolum kumesini cizer', (
    tester,
  ) async {
    Set<String> titles(WidgetTester t) => {
      for (final element in find.byType(StatsSection).evaluate())
        (element.widget as StatsSection).title ?? '<basliksiz>',
    };

    var mid = <String>{};
    var wide = <String>{};
    await onPlatform(TargetPlatform.windows, () async {
      await pumpPersonal(tester, window: const Size(1008, 1400));
      mid = titles(tester);
    });
    await onPlatform(TargetPlatform.windows, () async {
      await pumpPersonal(tester, window: const Size(1920, 1400));
      wide = titles(tester);
    });
    expect(mid.length, greaterThan(5), reason: 'Orta bant taramasi cilizdi.');
    expect(
      mid,
      equals(wide),
      reason:
          'Orta bantta bolum dustu. yalniz 1008: ${mid.difference(wide)} '
          'yalniz 1920: ${wide.difference(mid)} — SPEC §7.',
    );
  });

  // ===========================================================================
  // 5) MOBIL REGRESYON — 390x844'te masaustu izgarasi ACILMAZ
  // ===========================================================================

  testWidgets(
    'WP-683 (5) 390x844 mobil: StatsSectionColumns hic monte olmaz',
    (tester) async => onPlatform(TargetPlatform.android, () async {
      await pumpPersonal(tester, window: const Size(390, 3000), desktop: false);
      expect(
        find.byType(StatsSectionColumns),
        findsNothing,
        reason: '720 px tavani mobil dala sizdi — SPEC §7.',
      );
      expect(find.byType(StatsTileGrid), findsNothing);
      final cards = rects(tester, find.byType(Card));
      final widest = cards.map((c) => c.width).reduce((a, b) => a > b ? a : b);
      // 390 - 2x16 kenar = 358 px; WP-680 kapisinin olctugu sayinin AYNISI.
      expect(
        widest,
        closeTo(358, 1),
        reason:
            'Mobil kart ${widest.toStringAsFixed(0)} px; WP-683 oncesi olculen '
            'deger 358 px. Masaustu tavani mobilde hicbir kutuyu kucultmemeli.',
      );
    }),
  );

  // ===========================================================================
  // 6) SOZLESME — merdiven SPEC §3 A2 tablosuyla birebir (orta bant dahil)
  // ===========================================================================

  test('WP-683 (6) statsChartColumns orta bantta 1, 1200\'den itibaren 2', () {
    expect(statsChartColumns(1007), 1);
    expect(statsChartColumns(1008), 1);
    expect(statsChartColumns(1199), 1);
    expect(statsChartColumns(1200), 2);
    expect(statsChartColumns(1600), 2);
  });
}
