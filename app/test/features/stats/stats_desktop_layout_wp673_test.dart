// WP-673 — ISTATISTIK EKRANI MASAUSTU DUZENI: kanit katmani.
//
// Sahibin 3 numarali sikayeti: "ozet kartlari ~800 px genisliginde ve icinde
// tek bir 2s yaziyor". WP-671 kapisi
// (`test/features/desktop/desktop_stretch_contract_test.dart`) bu kusuru
// GOREMEZ: o kosum taze bir hesabin BOS durumunu cizer, dolayisiyla dort ozet
// karti hic boyanmaz. Bu dosya kapinin gormedigi yeri olcer — VERI DOLU
// istatistik ekranini.
//
// ============================== DISIPLIN =====================================
//
// 1. Iddialarin hepsi CIZILEN kutudan okunur (`tester.getRect`). Kaynakta
//    `maxWidth: 320` yazmasi kanit degildir (depo dersi: "dogruluk kaynagi
//    dogruyken ekran bos olabilir").
// 2. Masaustu dali `debugDefaultTargetPlatformOverride` ile acilir; bayrak
//    govde BITMEDEN geri alinir (kapinin `onWindows` sarmalayicisiyla ayni
//    tuzak: `tearDown` gec kalir).
// 3. Mobil dal AYNI dosyada olculur. "Masaustunu duzelttim" iddiasinin bedeli
//    mobilin bozulmamasidir (SPEC §7).
//
// ====================== DUZELTME ONCESI OLCULEN SAYILAR ======================
//
// 1920x1080 pencerede (WP-673 oncesi kod, ayni harness):
//   - dort ozet karti IKI satirda (2x2), her biri **936 px** genisliginde,
//     icindeki en genis metin ~110 px.
//   - butun bolum kartlari tek sutun, **1888 px** genisliginde.
// Yani bir kart ekranin yarisini kapliyor ve icinde tek bir sayi duruyordu.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/stats/widgets/personal_stats_view.dart';
import 'package:online_study_room/features/stats/widgets/stats_desktop_layout.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SPEC §2.3 "Tek sayilik istatistik dosemesi": **320 px**.
const double kTileCapPx = kStatsTileMaxWidth;

/// SPEC §2.3 "Grafik karti": **720 px**.
const double kChartCapPx = kStatsChartMaxWidth;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tr = AppLocalizationsTr();

  /// Bayrak govde icinde geri alinir; `tearDown` `_verifyInvariants`tan sonra
  /// kosar ve "foundation debug variable was changed by the test" atar.
  Future<void> onPlatform(
    TargetPlatform? platform,
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

  Future<void> pumpStats(WidgetTester tester, {required Size window}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window;
    addTearDown(tester.view.reset);
    final sessions = seed();

    await tester.pumpWidget(
      ProviderScope(
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
          home: Scaffold(body: PersonalStatsView(sessions: sessions)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
  }

  /// Bir sonlandiricinin CIZILEN kutulari (global koordinat).
  List<Rect> rects(WidgetTester tester, Finder finder) => [
    for (final element in finder.evaluate())
      tester.getRect(find.byWidget(element.widget)),
  ];

  testWidgets(
    'WP-673 (1) 1920 masaustu: dort ozet dosemesi TEK satir, her biri <= 320 px',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      await pumpStats(tester, window: const Size(1920, 1080));

      final grid = find.byType(StatsTileGrid);
      expect(
        grid,
        findsOneWidget,
        reason:
            'Masaustu dali acilmadi: dort ozet karti hala elle 2x2 diziliyor.',
      );

      final tiles = find.descendant(of: grid, matching: find.byType(Card));
      expect(
        tiles,
        findsNWidgets(4),
        reason: 'Dort ozet dosemesinden biri kayboldu (SPEC §7: islev kaybi).',
      );

      final boxes = rects(tester, tiles)
        ..sort((a, b) => a.left.compareTo(b.left));
      for (final box in boxes) {
        expect(
          box.width,
          lessThanOrEqualTo(kTileCapPx),
          reason:
              'Doseme ${box.width.toStringAsFixed(0)} px boyandi; SPEC §2.3 '
              'tavani ${kTileCapPx.toStringAsFixed(0)} px. Duzeltme oncesi bu '
              'sayi 936 px idi ("800 px kart, icinde tek bir 2s").',
        );
      }
      for (final box in boxes.skip(1)) {
        expect(
          (box.top - boxes.first.top).abs(),
          lessThan(1),
          reason:
              'Doseme ${box.top.toStringAsFixed(0)} px yukseklikte, ilki '
              '${boxes.first.top.toStringAsFixed(0)} px: 1920 px pencerede '
              'dort doseme TEK satirda olmali (SPEC §3 A2), 2x2 degil.',
        );
      }
      // Yan yana dizilen dosemeler birbirini ORTMEZ.
      for (var i = 1; i < boxes.length; i++) {
        expect(
          boxes[i].left,
          greaterThanOrEqualTo(boxes[i - 1].right),
          reason: 'Dosemeler cakisiyor; izgara oluğu kaybolmus.',
        );
      }
    }),
  );

  testWidgets(
    'WP-673 (2) 1920 masaustu: bolumler IKI sutuna akiyor, kart <= 720 px',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      await pumpStats(tester, window: const Size(1920, 1080));

      final left = find.byKey(const ValueKey('${kStatsSectionColumnKeyPrefix}0'));
      final right = find.byKey(
        const ValueKey('${kStatsSectionColumnKeyPrefix}1'),
      );
      expect(
        left,
        findsOneWidget,
        reason: 'Bolum sutunlari yok: ekran hala tek sutun.',
      );
      expect(right, findsOneWidget, reason: 'Ikinci sutun cizilmedi.');

      final l = tester.getRect(left);
      final r = tester.getRect(right);
      expect(
        r.left,
        greaterThanOrEqualTo(l.right),
        reason:
            'Iki sutun yan yana degil: sol ${l.left.toStringAsFixed(0)}..'
            '${l.right.toStringAsFixed(0)}, sag ${r.left.toStringAsFixed(0)}..'
            '${r.right.toStringAsFixed(0)}.',
      );
      expect((l.top - r.top).abs(), lessThan(1));
      for (final column in [l, r]) {
        expect(
          column.width,
          lessThanOrEqualTo(kChartCapPx),
          reason:
              'Sutun ${column.width.toStringAsFixed(0)} px; SPEC §2.3 grafik '
              'karti tavani ${kChartCapPx.toStringAsFixed(0)} px. Duzeltme '
              'oncesi kartlar 1888 px genisligindeydi.',
        );
      }

      // Kart yuzeylerinin HICBIRI grafik tavanini asmaz.
      final cards = rects(
        tester,
        find.descendant(
          of: find.byType(StatsSectionColumns),
          matching: find.byType(Card),
        ),
      );
      expect(cards, isNotEmpty);
      final widest = cards.map((c) => c.width).reduce((a, b) => a > b ? a : b);
      expect(
        widest,
        lessThanOrEqualTo(kChartCapPx),
        reason:
            'En genis kart ${widest.toStringAsFixed(0)} px; tavan '
            '${kChartCapPx.toStringAsFixed(0)} px.',
      );
    }),
  );

  testWidgets(
    'WP-673 (3) 390x844 mobil: eski 2x2 duzen aynen duruyor, izgara ACILMAZ',
    (tester) async => onPlatform(TargetPlatform.android, () async {
      await pumpStats(tester, window: const Size(390, 844));

      expect(
        find.byType(StatsTileGrid),
        findsNothing,
        reason:
            'Masaustu izgarasi mobilde acildi — SPEC §7 "mobil dal degismez".',
      );
      expect(find.byType(StatsSectionColumns), findsNothing);

      Rect tile(String label) => tester.getRect(
        find
            .ancestor(of: find.text(label).first, matching: find.byType(Card))
            .first,
      );
      final total = tile(tr.statsToplam);
      final avg = tile(tr.statsGunlukOrtalama);
      final weekday = tile(tr.statsHaftaIci);
      final weekend = tile(tr.statsHaftaSonu);

      expect(
        (total.top - avg.top).abs(),
        lessThan(1),
        reason: 'Mobilde ilk satir hala "Toplam + Gunluk ortalama" olmali.',
      );
      expect(
        (weekday.top - weekend.top).abs(),
        lessThan(1),
        reason: 'Mobilde ikinci satir hala "Hafta ici + Hafta sonu" olmali.',
      );
      expect(
        weekday.top,
        greaterThan(total.bottom),
        reason: 'Mobil duzen 2x2 olmali; tek satira dusmus.',
      );
      // 390 px'te iki kart ekrani boler; 320 tavani MOBILE uygulanmaz.
      expect(total.width, greaterThan(kTileCapPx / 2));
    }),
  );

  testWidgets(
    'WP-673 (4) hicbir bolum kaybolmadi: mobil ve masaustu AYNI bolum kumesi',
    (tester) async {
      // Bolum kimligi = [StatsSection.title] (basliksiz bolum icin `null`).
      // Widget SAYMAK yetmez: mobilde `ListView` tembeldir, ilk karede yalniz
      // uc bolum monte olur. Bu yuzden mobil taraf SONUNA KADAR kaydirilir ve
      // gorulen basliklarin BIRLESIMI alinir.
      Set<String> titles(WidgetTester t) => {
        for (final element in find.byType(StatsSection).evaluate())
          (element.widget as StatsSection).title ?? '<basliksiz>',
      };

      final mobile = <String>{};
      await onPlatform(TargetPlatform.android, () async {
        await pumpStats(tester, window: const Size(390, 844));
        mobile.addAll(titles(tester));
        for (var i = 0; i < 60; i++) {
          await tester.drag(
            find.byType(ListView).first,
            const Offset(0, -400),
            warnIfMissed: false,
          );
          await tester.pump();
          mobile.addAll(titles(tester));
        }
      });

      var desktop = <String>{};
      await onPlatform(TargetPlatform.windows, () async {
        await pumpStats(tester, window: const Size(1920, 1080));
        desktop = titles(tester);
      });

      expect(mobile.length, greaterThan(5), reason: 'Mobil tarama caliskadi.');
      expect(
        desktop,
        equals(mobile),
        reason:
            'Masaustu bolum kumesi mobilden farkli. '
            'yalniz mobilde: ${mobile.difference(desktop)} '
            'yalniz masaustunde: ${desktop.difference(mobile)} '
            'SPEC §7: masaustunde gorunen her veri gorunmeye devam eder.',
      );
    },
  );

  test('WP-673 (5) sutun merdiveni SPEC §3 A2 tablosuyla birebir', () {
    // compact 640-1007 → 2, expanded 1008-1199 → 4, large 1200-1599 → 4,
    // xlarge ≥1600 → 6.
    expect(statsTileColumns(800), 2);
    expect(statsTileColumns(1008), 4);
    expect(statsTileColumns(1200), 4);
    expect(statsTileColumns(1600), 6);
    expect(statsTileColumns(2560), 6);
    // Grafik: `large` ve ustunde 2 sutun.
    expect(statsChartColumns(1008), 1);
    expect(statsChartColumns(1199), 1);
    expect(statsChartColumns(1200), 2);
    expect(statsChartColumns(2560), 2);
  });
}
