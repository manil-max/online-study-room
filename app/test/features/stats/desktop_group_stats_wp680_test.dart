// WP-680 — GRUP ISTATISTIK SEKMESI: masaustu duzen kapisi.
//
// WP-673 istatistik ekranini masaustune tasidi ama `class_stats_view.dart`'a
// BILEREK dokunmadi (dosya CRLF, `stats/` altindaki digerleri LF; `Edit` araci
// dosyayi bastan CRLF'e cevirip alakasiz sozlesme testlerini kiriyordu). Bu
// dosya o bosluğu olcer.
//
// ============================== DISIPLIN =====================================
//
// 1. Her iddia CIZILEN kutudan okunur. Kaynakta `maxWidth: 600` yazmasi kanit
//    degildir — depo dersi: "kullanicinin GORDUGU satiri test et".
// 2. Etiket–deger mesafesi SAHTE bir tutamaktan degil, iki gercek metnin
//    global kenarlarindan olculur: etiketin SOL kenari ile degerin SAG kenari.
//    SPEC KURAL 2.2'nin lafzi budur.
// 3. Masaustu dali `debugDefaultTargetPlatformOverride` ile acilir, bayrak
//    govde bitmeden geri alinir.
// 4. Mobil dal AYNI dosyada olculur ve WP-191 dikey sirasi ayrica sinanir
//    (`test/features/class_stats_view_order_test.dart` ile ayni iddia).
//
// ==================== WP-680 ONCESI OLCULEN SAYILAR ==========================
//
// Ayni harness, `devicePixelRatio = 1`, SPEC §2.3'un 1440 px bandinin ICINDE:
//
// | pencere | en genis kart | metin araligi | sutun sayisi |
// |---|---:|---:|---:|
// | 1920 | **1408 px** | **1408 px** | **1** |
// | 2560 | **1408 px** | **1408 px** | **1** |
// | 390 (mobil) | 358 px | 358 px | 1 |
//
// Yani 1440'lik bant ZATEN uygulaniyordu — kusur bandin ICINDE sutun karari
// olmamasiydi. 1920 ile 2560 px pencere birbirinden ayirt edilemiyordu.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/desktop/desktop_layout.dart';
import 'package:online_study_room/core/stats/stats_period.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/stats_period_provider.dart';
import 'package:online_study_room/features/desktop/desktop_page_scaffold.dart';
import 'package:online_study_room/features/stats/charts/gauge_chart.dart';
import 'package:online_study_room/features/stats/widgets/class_stats_view.dart';
import 'package:online_study_room/features/stats/widgets/stats_desktop_layout.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';

/// SPEC §2.3 "Tek sayilik istatistik dosemesi".
const double kTileCapPx = kStatsTileMaxWidth; // 320

/// SPEC §2.3 "Grafik karti".
const double kChartCapPx = kStatsChartMaxWidth; // 720

/// SPEC KURAL 2.2 — etiket–deger satiri SERT tavani (80 karakter, WCAG 1.4.8).
const double kLabelValueCapPx = DesktopBreakpoints.maxLabelValueWidth; // 600

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tr = AppLocalizationsTr();

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

  Profile member(String id, String name) =>
      Profile(id: id, displayName: name, createdAt: DateTime(2026, 1, 1));

  /// Ekranin GERCEK kabugunu taklit eder.
  ///
  /// `desktop` dalinda gorunum [DesktopContent] ile 1440 px'e sikistirilir —
  /// `stats_screen.dart`'in masaustu dali tam olarak boyle sarar. Bu onemli:
  /// bandi taklit etmeyen bir test, bandin ICINDEKI sutun kararini olcemez
  /// (depo dersi: "kabuk yapisini taklit etmeyen test hatayi kacirir").
  /// WP-746: kart kumesi artik DONEME bagli, o yuzden harness donemi kurar.
  /// Saat de enjekte edilir; aksi halde gun siniri kapinin sonucunu degistirir.
  Future<void> pump(
    WidgetTester tester, {
    required Size window,
    required bool desktop,
    StatsPeriod period = StatsPeriod.week,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window;
    addTearDown(tester.view.reset);
    final now = DateTime(2026, 8, 20, 14);
    final today = DateTime(2026, 8, 20);
    final members = [
      member('u1', 'Ada'),
      member('u2', 'Bora'),
      member('u3', 'Cem'),
    ];
    final stats = [
      DailyStat(userId: 'u1', day: today, seconds: 3600),
      DailyStat(userId: 'u2', day: today, seconds: 1800),
      DailyStat(
        userId: 'u1',
        day: today.subtract(const Duration(days: 1)),
        seconds: 2400,
      ),
    ];
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // 🔴 Riverpod 3: dinleyicisiz provider her `read`de yeniden dogar.
    container.listen(statsPeriodProvider, (_, _) {});
    container.read(statsPeriodProvider.notifier).setPeriod(period);
    final view = ClassStatsView(
      stats: stats,
      members: members,
      currentUserId: 'u1',
      groupGoalMinutes: 120,
      clock: () => now,
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: desktop
                ? DesktopContent(
                    maxWidth: DesktopBreakpoints.maxContentWidth,
                    padding: EdgeInsets.zero,
                    child: view,
                  )
                : view,
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

  // ===========================================================================
  // 1) 1920 px — tek sutun 1408 px'lik seritler biter
  // ===========================================================================

  testWidgets(
    'WP-680 (1) 1920 masaustu: bolumler IKI sutuna akiyor, kart <= 720 px',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      await pump(tester, window: const Size(1920, 1400), desktop: true);

      final left = find.byKey(
        const ValueKey('${kStatsSectionColumnKeyPrefix}0'),
      );
      final right = find.byKey(
        const ValueKey('${kStatsSectionColumnKeyPrefix}1'),
      );
      expect(
        left,
        findsOneWidget,
        reason:
            'Grup sekmesi hala tek sutun. Duzeltme oncesi en genis kart '
            '1408 px idi ve 1920 ile 2560 px pencere ayni goruntuyu '
            'veriyordu.',
      );
      expect(right, findsOneWidget, reason: 'Ikinci sutun cizilmedi.');

      final l = tester.getRect(left);
      final r = tester.getRect(right);
      expect(
        r.left,
        greaterThanOrEqualTo(l.right),
        reason:
            'Sutunlar yan yana degil: sol ${l.left.toStringAsFixed(0)}..'
            '${l.right.toStringAsFixed(0)}, sag ${r.left.toStringAsFixed(0)}..'
            '${r.right.toStringAsFixed(0)}.',
      );
      expect((l.top - r.top).abs(), lessThan(1));

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
            'En genis kart ${widest.toStringAsFixed(0)} px; SPEC §2.3 grafik '
            'karti tavani ${kChartCapPx.toStringAsFixed(0)} px. Duzeltme '
            'oncesi 1408 px idi.',
      );
    }),
  );

  testWidgets(
    'WP-680 (2) 2560 masaustu: 1920 ile AYNI degil — bant 1440\'ta durur',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      await pump(tester, window: const Size(2560, 1400), desktop: true);
      final cards = rects(
        tester,
        find.descendant(
          of: find.byType(StatsSectionColumns),
          matching: find.byType(Card),
        ),
      );
      final widest = cards.map((c) => c.width).reduce((a, b) => a > b ? a : b);
      expect(widest, lessThanOrEqualTo(kChartCapPx));
      // Bant 1440'ta tavanlanir, ekrana yayilmaz.
      final columns = rects(tester, find.byType(StatsSectionColumns));
      expect(columns, isNotEmpty);
      expect(
        columns.first.width,
        lessThanOrEqualTo(DesktopBreakpoints.maxContentWidth),
      );
    }),
  );

  // ===========================================================================
  // 2) Tek sayilik dosemeler — SPEC §2.3 tavani 320
  // ===========================================================================

  testWidgets(
    'WP-680 (3) 1920: iki ozet dosemesi TEK satir ve her biri <= 320 px',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      await pump(tester, window: const Size(1920, 1400), desktop: true);

      final grid = find.byType(StatsTileGrid);
      expect(grid, findsOneWidget, reason: 'Doseme izgarasi acilmadi.');
      final tiles = rects(
        tester,
        find.descendant(of: grid, matching: find.byType(Card)),
      )..sort((a, b) => a.left.compareTo(b.left));
      expect(
        tiles.length,
        2,
        reason:
            'Iki ozet dosemesinden (grup toplami / kisi basi ort.) biri '
            'kayboldu — SPEC §7 islev kaybi.',
      );
      for (final box in tiles) {
        expect(
          box.width,
          lessThanOrEqualTo(kTileCapPx),
          reason:
              'Doseme ${box.width.toStringAsFixed(0)} px; SPEC §2.3 tavani '
              '${kTileCapPx.toStringAsFixed(0)} px. Duzeltme oncesi her bir '
              'doseme bandin YARISI (700 px) genisligindeydi ve icinde tek '
              'bir sure yaziyordu.',
        );
      }
      expect((tiles[0].top - tiles[1].top).abs(), lessThan(1));
      expect(tiles[1].left, greaterThanOrEqualTo(tiles[0].right));
    }),
  );

  // ===========================================================================
  // 3) SPEC KURAL 2.2 — etiket–deger satirlari 600 px'i asamaz
  // ===========================================================================

  testWidgets(
    'WP-680 (4) 1920: etiket-deger mesafeleri SERT tavan 600 px altinda',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      // WP-746: "Tum zamanlar" karti artik yalniz `all` doneminde cizilir;
      // (b) ve (c) iddialarinin olcecek satiri o donemde vardir.
      await pump(
        tester,
        window: const Size(1920, 1400),
        desktop: true,
        period: StatsPeriod.all,
      );

      // (a) 🔴 WP-746: grup basligi satiri (avatar + ad + "Degistir") SILINDI.
      // Eski iddia "band 600 px'i asmiyor" idi; yerine gecen iddia bandin HIC
      // olmadigidir — aksi halde silme geri alinsa kapi yesil kalirdi.
      expect(
        find.text(tr.statsDegistir),
        findsNothing,
        reason:
            'Grup degistirici WP-743\'te sekme basligina tasinmisti; buradaki '
            'ikinci cagri yeri WP-746\'da kaldirildi.',
      );
      expect(find.byIcon(Icons.swap_horiz), findsNothing);

      // (b) "Tum zamanlar" satiri: "En yogun gun" etiketi → tarih+sure degeri.
      final peakLabel = find.text(tr.statsEnYogunGun);
      expect(peakLabel, findsOneWidget);
      final peakRow = find.ancestor(of: peakLabel, matching: find.byType(Row));
      final peakSpan = tester.getSize(peakRow.first).width;
      expect(
        peakSpan,
        lessThanOrEqualTo(kLabelValueCapPx),
        reason:
            '"En yogun gun" satiri ${peakSpan.toStringAsFixed(0)} px. Sebep '
            '`Spacer()`: degeri kabin en sagina atar, 1408 px\'lik kartta '
            'aradaki mesafe ~1300 px oluyordu.',
      );

      // (c) HER etiket-deger bandi — siralama satirlari dahil.
      //
      // Tek tek isim aramak yerine bandlarin TAMAMI olculur: bir uye adini
      // aramak belirsizdir (ayni isim siralamada ve donut aciklamasinda gecer)
      // ve boyle bir olcum yeni eklenen bir satiri hic gormezdi.
      final bands = rects(
        tester,
        find.byKey(const ValueKey(kLabelValueBandKey)),
      );
      expect(
        bands.length,
        greaterThanOrEqualTo(5),
        reason:
            'Beklenen bandlar: 3 siralama satiri + "En yogun gun" + "En '
            'istikrarli uye". Bulunan: ${bands.length}.',
      );
      final widestBand = bands
          .map((b) => b.width)
          .reduce((a, b) => a > b ? a : b);
      expect(
        widestBand,
        lessThanOrEqualTo(kLabelValueCapPx),
        reason:
            'En genis etiket-deger bandi ${widestBand.toStringAsFixed(0)} px; '
            'SPEC KURAL 2.2 sert tavani ${kLabelValueCapPx.toStringAsFixed(0)}'
            ' px. Siralama satirinda `MainAxisAlignment.spaceBetween`, tum '
            'zamanlar satirinda `Spacer()` etiketle degeri kabin iki ucuna '
            'itiyordu.',
      );
    }),
  );

  // ===========================================================================
  // 4) ISLEV KAYBI YOK — her metrik masaustunde de cizilir
  // ===========================================================================

  testWidgets('WP-680 (5) masaustunde HICBIR metrik kaybolmadi', (
    tester,
  ) async {
    // SPEC §7: "masaustunde gorunen her veri gorunmeye devam eder."
    //
    // WP-746: "her veri" artik DONEME baglidir — hedef gostergesi yalniz
    // "Gun"de, tum-zamanlar metrikleri yalniz "Tumu"nde cizilir. Liste tek
    // parca olsaydi ya kapi kirmizi kalirdi ya da iddia gevsetilirdi; bunun
    // yerine iki donem AYRI AYRI olculur ve toplamda eski listenin
    // (karsilastirma tablosu ile grup basligi disinda) tamami korunur.
    final common = <String>[
      tr.statsSiralama,
      tr.statsGrupToplami,
      tr.statsKisiBasiOrt,
      tr.analyticsCardMemberDonut,
    ];
    final dayOnly = <String>[
      tr.statsGunAktif,
      tr.statsHedefeKalan,
      tr.statsGunLider,
    ];
    final allOnly = <String>[
      tr.analyticsCardLeaderboardHistory,
      tr.statsTumZamanlar,
      tr.statsAktifGun,
      tr.statsRekorSeri,
      tr.statsEnYogunGun,
      tr.statsEnIstikrarliUye,
    ];
    // 🔴 WP-746 ile SILINENLER: hicbir donemde cizilmemeli.
    final removed = <String>[
      tr.statsKarsilastirmaTablosu,
      tr.statsDegistir,
    ];

    await onPlatform(TargetPlatform.windows, () async {
      await pump(
        tester,
        window: const Size(1920, 1400),
        desktop: true,
        period: StatsPeriod.day,
      );
      for (final label in [...common, ...dayOnly]) {
        expect(
          find.text(label),
          findsWidgets,
          reason: 'Gun doneminde "$label" cizilmedi — SPEC §7 islev kaybi.',
        );
      }
      expect(find.byType(GaugeChart), findsOneWidget);
      for (final label in removed) {
        expect(find.text(label), findsNothing, reason: '"$label" silinmisti.');
      }
      for (final name in const ['Bora', 'Cem']) {
        expect(find.text(name), findsWidgets, reason: '$name kayboldu.');
      }
      expect(find.textContaining('(sen)'), findsWidgets);
    });

    await onPlatform(TargetPlatform.windows, () async {
      await pump(
        tester,
        window: const Size(1920, 1400),
        desktop: true,
        period: StatsPeriod.all,
      );
      for (final label in [...common, ...allOnly]) {
        expect(
          find.text(label),
          findsWidgets,
          reason: 'Tumu doneminde "$label" cizilmedi — SPEC §7 islev kaybi.',
        );
      }
      for (final label in removed) {
        expect(find.text(label), findsNothing, reason: '"$label" silinmisti.');
      }
      // Hedef gostergesi cok gunlu donemde cizilmez (WP-746 tablosu).
      expect(find.byType(GaugeChart), findsNothing);
    });
  });

  // ===========================================================================
  // 5) MOBIL REGRESYON — SPEC §7
  // ===========================================================================

  testWidgets(
    'WP-680 (6) 390x844 mobil: masaustu izgarasi ACILMAZ, WP-191 sirasi durur',
    (tester) async => onPlatform(TargetPlatform.android, () async {
      await pump(
        tester,
        window: const Size(390, 3000),
        desktop: false,
        period: StatsPeriod.day,
      );

      expect(
        find.byType(StatsTileGrid),
        findsNothing,
        reason: 'Masaustu izgarasi mobilde acildi — SPEC §7.',
      );
      expect(find.byType(StatsSectionColumns), findsNothing);

      // WP-191/746 dikey sirasi (Gun): siralama → hedef → ozet.
      // `class_stats_view_order_test.dart` ile AYNI iddia.
      double topOf(Finder f) => tester.getTopLeft(f.first).dy;
      final ranking = topOf(find.text(tr.statsSiralama));
      final goal = topOf(find.byType(GaugeChart));
      final summary = topOf(find.text(tr.statsKisiBasiOrt));

      expect(ranking, lessThan(goal), reason: 'siralama hedefin ustunde');
      expect(goal, lessThan(summary), reason: 'hedef ozetin ustunde');

      // En genis kart WP-680 oncesiyle AYNI: 358 px (390 - 2x16 kenar).
      final cards = rects(tester, find.byType(Card));
      final widest = cards.map((c) => c.width).reduce((a, b) => a > b ? a : b);
      expect(
        widest,
        closeTo(358, 1),
        reason:
            'Mobil kart genisligi ${widest.toStringAsFixed(0)} px; WP-680 '
            'oncesi olculen deger 358 px. 600 px\'lik etiket-deger bandi '
            'mobilde hicbir kutuyu kucultmemeli.',
      );
    }),
  );

  testWidgets(
    'WP-680 (6b) 390x844 mobil, Tumu: siralama → ozet → tum zamanlar',
    (tester) async => onPlatform(TargetPlatform.android, () async {
      await pump(
        tester,
        window: const Size(390, 4000),
        desktop: false,
        period: StatsPeriod.all,
      );
      double topOf(Finder f) => tester.getTopLeft(f.first).dy;
      final ranking = topOf(find.text(tr.statsSiralama));
      final summary = topOf(find.text(tr.statsKisiBasiOrt));
      final history = topOf(find.text(tr.analyticsCardLeaderboardHistory));
      final allTime = topOf(find.text(tr.statsTumZamanlar));

      expect(ranking, lessThan(summary));
      expect(summary, lessThan(history));
      expect(history, lessThan(allTime));
    }),
  );
}
