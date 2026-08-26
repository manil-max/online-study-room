// WP-758 — "leaderboard history de sorun var" (sahip, Galaxy S23, v71).
//
// ============================== OLCULEN KUSUR ================================
//
// WP-747 pencerenin SONUNU (`endDay`) donemin sonuna bagladi. Pencerenin
// UZUNLUGU ise hâlâ `trendDays`ti (7 ya da sabit 30) ve secili donemle hicbir
// iliskisi yoktu. Sonuc: ayni ekranda alt alta duran iki widget AYNI soruya
// FARKLI cevap veriyor.
//
//   • "Hafta" (VARSAYILAN donem) Carsamba gunu 3 gunluk bir donemdir
//     (Pzt–Car). Grafik ise 7 gun ciziyordu: ONCEKI haftanin Per/Cum/Cmt/Paz'i
//     yarisa giriyordu. Ustteki "Siralama" listesi o gunleri saymaz.
//     → Liste "🥇 Cem" derken grafigin son noktasi "1. Ada" diyordu.
//
//   • "Yil" / "Tumu" / "Ozel" 30 gunluk bir KUYRUK ciziyordu ve kumulatif
//     toplam o kuyrugun basinda SIFIRLANIYORDU: donemin ilk aylari grafikte
//     yok sayiliyordu. Yine ayni celiski — liste yilin liderini, grafik son 30
//     gunun liderini gosteriyordu.
//
//   • "Ozel aralik"ta pencere SABIT 30 gundu: 3 gunluk bir aralik secildiginde
//     grafik araligin 27 gun ONCESINI de siralamaya katiyordu.
//
// ============================== DISIPLIN =====================================
//
// 1. SAAT ENJEKTE + anlar `DateTime.utc` ile kurulur: CI (UTC) ile bu makine
//    (UTC+3) ayni Istanbul gununu gormeli.
// 2. Iddia CIZILEN grafikten (`LineChartData.lineBarsData`) VE ekrandaki
//    siralama satirindan okunur; iki kaynak birbirine karsi tutulur
//    (`hunter §3` — dogruluk kaynagi dogruyken ekran yanlis olabilir).
// 3. Her testin verisi KENDI penceresini ayirt edecek sekilde kurulur: ortak
//    veri kullanildiginda (ilk kurulumda oldu) bir iddia kusur duruyorken de
//    yesil kaliyordu.
// 4. 🔴 Riverpod 3: dinleyicisiz provider her `read`de yeniden dogar,
//    `setPeriod`/`shift` sessizce kaybolur — `container.listen` ile canli tut.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/stats_period.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/stats_period_provider.dart';
import 'package:online_study_room/features/stats/widgets/class_stats_view.dart';
import 'package:online_study_room/features/stats/widgets/leaderboard_rank_chart.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tr = AppLocalizationsTr();

  // 26 Agustos 2026 **Carsamba**, Istanbul 14:00 (UTC 11:00).
  // Haftanin baslangici Pzt 24 Agustos → secili donem UC gundur.
  final wednesday = DateTime.utc(2026, 8, 26, 11);
  // 24 Agustos 2026 **Pazartesi**, Istanbul 09:00 → secili hafta TEK gundur.
  final monday = DateTime.utc(2026, 8, 24, 6);

  const goalMinutes = 120;

  Profile member(String id, String name) =>
      Profile(id: id, displayName: name, createdAt: DateTime(2026, 1, 1));

  final members = [
    member('u1', 'Ada'),
    member('u2', 'Bora'),
    member('u3', 'Cem'),
  ];

  DailyStat stat(String id, DateTime day, int seconds) =>
      DailyStat(userId: id, day: day, seconds: seconds);

  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    required List<DailyStat> stats,
    required DateTime now,
    StatsPeriod? period,
    int offset = 0,
    (DateTime, DateTime)? custom,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 8000);
    addTearDown(tester.view.reset);

    container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(statsPeriodProvider, (_, _) {});

    final notifier = container.read(statsPeriodProvider.notifier);
    if (custom != null) {
      notifier.setCustomRange(custom.$1, custom.$2);
    } else {
      notifier.setPeriod(period!);
      for (var i = 0; i < -offset; i++) {
        notifier.shift(-1);
      }
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ClassStatsView(
              stats: stats,
              members: members,
              currentUserId: 'u1',
              groupGoalMinutes: goalMinutes,
              clock: () => now,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
  }

  List<LineChartBarData> historyBars(WidgetTester tester) {
    final chart = find.descendant(
      of: find.byType(LeaderboardRankChart),
      matching: find.byType(LineChart),
    );
    expect(
      chart,
      findsOneWidget,
      reason: 'Liderlik gecmisi grafigi cizilmedi (kart bos dala mi dustu?).',
    );
    return tester.widget<LineChart>(chart).data.lineBarsData;
  }

  /// Grafigin SON gununde birinci cizilen uyenin adi.
  ///
  /// `plottedY`: rank 1 → n (en ust). Uc uye var, yani y = 3 birinciliktir.
  String chartLeader(List<LineChartBarData> bars) {
    var best = 0;
    for (var i = 1; i < bars.length; i++) {
      if (bars[i].spots.last.y > bars[best].spots.last.y) best = i;
    }
    return members[best].displayName;
  }

  /// EKRANDAKI "Siralama" listesinin 🥇 satirindaki isim — kullanicinin
  /// grafikle ALT ALTA gordugu ikinci cevap.
  ///
  /// `textContaining`: kendi satirin "Ada (Sen)" gibi sarilir.
  String listLeader(WidgetTester tester) {
    final goldRow = find
        .ancestor(of: find.text('🥇'), matching: find.byType(Row))
        .first;
    for (final m in members) {
      if (find
          .descendant(
            of: goldRow,
            matching: find.textContaining(m.displayName),
          )
          .evaluate()
          .isNotEmpty) {
        return m.displayName;
      }
    }
    fail('🥇 satirinda uye adi bulunamadi.');
  }

  // ===========================================================================
  // 1) 🔴 Pencere donemin ONUNE tasmaz — hafta grafigi gecen haftayi saymaz
  // ===========================================================================

  testWidgets(
    'WP-758 (1) Hafta (Carsamba): pencere donemin ILK gununde baslar',
    (tester) async {
      await pump(
        tester,
        now: wednesday,
        period: StatsPeriod.week,
        stats: [
          // GECEN hafta (Cuma) — secili donemin disinda.
          stat('u1', DateTime(2026, 8, 21), 9000),
          // Bu hafta (Sali).
          stat('u3', DateTime(2026, 8, 25), 5000),
        ],
      );

      final bars = historyBars(tester);
      expect(
        bars.first.spots,
        hasLength(3),
        reason:
            'Secili hafta Pzt 24 – Car 26, yani UC gun. Grafik 7 gun ciziyorsa '
            'pencere donemin ONUNE tasiyor ve gecen haftanin gunlerini '
            'siralamaya katiyor.',
      );

      expect(
        chartLeader(bars),
        listLeader(tester),
        reason:
            'Grafigin son gunundeki lider ile hemen ustteki "Siralama" '
            'listesinin 🥇 satiri AYNI kisi olmali; ikisi de ayni donemi '
            'anlatiyor.',
      );
      expect(
        chartLeader(bars),
        'Cem',
        reason:
            'Bu hafta yalniz Cem calisti (25 Agustos). Ada cikiyorsa 21 '
            'Agustos (GECEN hafta) grafige sizmis demektir.',
      );
    },
  );

  // ===========================================================================
  // 2) 🔴 Pencere donemden KISA olabilir (okunabilirlik tavani) ama kumulatif
  //    donem basindan TOHUMLANIR — grafik donemin siralamasini anlatir
  // ===========================================================================

  testWidgets('WP-758 (2) Yil: 30 gunluk kuyruk YILIN liderini gosterir', (
    tester,
  ) async {
    await pump(
      tester,
      now: wednesday,
      period: StatsPeriod.year,
      stats: [
        // Yilin icinde ama son 30 gunun DISINDA.
        stat('u1', DateTime(2026, 3, 10), 20000),
        // Son 30 gunun icinde.
        stat('u3', DateTime(2026, 8, 25), 5000),
      ],
    );

    final bars = historyBars(tester);
    expect(
      bars.first.spots,
      hasLength(30),
      reason:
          'Okunabilirlik tavani: 238 gunluk bir eksen cizilmez, en fazla 30 '
          'gun gosterilir.',
    );

    expect(
      chartLeader(bars),
      listLeader(tester),
      reason:
          'Yilin lideri Ada (10 Mart, 20000 sn). Kuyruk 30 gun olsa bile '
          'grafik YILIN siralamasini anlatmali; kumulatif kuyrugun basinda '
          'sifirlanirsa grafik son 30 gunun lideri Cem\'i gosterir.',
    );
    expect(chartLeader(bars), 'Ada');
  });

  // ===========================================================================
  // 3) 🔴 OZEL ARALIK — `trendDays` orada SABIT 30'du, aralik ne olursa olsun
  // ===========================================================================

  testWidgets('WP-758 (3) Ozel aralik (3 gun): grafik araligin disina cikmaz', (
    tester,
  ) async {
    await pump(
      tester,
      now: wednesday,
      custom: (DateTime(2026, 8, 24), DateTime(2026, 8, 26)),
      stats: [
        // Aralik disinda, ama sabit 30 gunluk pencerenin ICINDE.
        stat('u1', DateTime(2026, 8, 10), 9000),
        stat('u3', DateTime(2026, 8, 25), 5000),
      ],
    );

    final bars = historyBars(tester);
    expect(
      bars.first.spots,
      hasLength(3),
      reason:
          'Kullanici 24–26 Agustos secti. Grafik SABIT 30 gun ciziyorsa '
          'araligin 27 gun oncesini de siralamaya katiyor.',
    );
    expect(
      chartLeader(bars),
      listLeader(tester),
      reason: 'Secili aralikta yalniz Cem calisti (25 Agustos).',
    );
    expect(chartLeader(bars), 'Cem');
  });

  // ===========================================================================
  // 4) SINIR — donemin ILK gunu: pencere tek gune duser, kart yine de CIZILIR
  // ===========================================================================

  testWidgets('WP-758 (4) Hafta (Pazartesi): tek gunluk pencere cizilir', (
    tester,
  ) async {
    await pump(
      tester,
      now: monday,
      period: StatsPeriod.week,
      stats: [
        // GECEN hafta (Cuma).
        stat('u1', DateTime(2026, 8, 21), 9000),
        // Haftanin tek gunu.
        stat('u2', DateTime(2026, 8, 24), 600),
      ],
    );

    expect(tester.takeException(), isNull);
    final bars = historyBars(tester);
    expect(
      bars.first.spots,
      hasLength(1),
      reason: 'Haftanin ilk gunu: donem tek gundur, pencere de tek gun olmali.',
    );
    expect(chartLeader(bars), listLeader(tester));
    expect(
      chartLeader(bars),
      'Bora',
      reason:
          'Bu haftanin tek gununde yalniz Bora calisti. Ada cikiyorsa gecen '
          'haftanin Cuma gunu grafige sizmis demektir.',
    );
  });

  // ===========================================================================
  // 5) 🔴 BOS KART — donemde calisma VAR ama 30 gunluk kuyrukta YOK
  // ===========================================================================

  testWidgets('WP-758 (5) Yil: calisma yilin basindaysa kart BOS kalmaz', (
    tester,
  ) async {
    await pump(
      tester,
      now: wednesday,
      period: StatsPeriod.year,
      // Yilin TEK calismasi son 30 gunun disinda.
      stats: [stat('u1', DateTime(2026, 3, 10), 20000)],
    );

    expect(
      find.descendant(
        of: find.byType(LeaderboardRankChart),
        matching: find.text(tr.statsBuDonemdeHenuzCalisma),
      ),
      findsNothing,
      reason:
          'Kuyrukta veri olmayinca kart "bu donemde henuz calisma yok" '
          'diyordu; oysa yil BOS DEGIL: 10 Mart gunu 20000 sn var. Kullanici '
          'yilina bakip bos kart goruyordu.',
    );

    final bars = historyBars(tester);
    expect(bars, hasLength(3));
    expect(chartLeader(bars), listLeader(tester));
    expect(chartLeader(bars), 'Ada');
  });

  // ===========================================================================
  // 6) SINIR DURUMLARI — tek uye / sifir saniye
  // ===========================================================================

  testWidgets('WP-758 (6a) Donemde hic calisma yoksa kart bos metni gosterir', (
    tester,
  ) async {
    await pump(
      tester,
      now: wednesday,
      period: StatsPeriod.week,
      // 0 saniyelik satirlar: veri "var" ama sure yok.
      stats: [
        stat('u1', DateTime(2026, 8, 25), 0),
        stat('u2', DateTime(2026, 8, 25), 0),
      ],
    );

    expect(tester.takeException(), isNull);
    expect(
      find.descendant(
        of: find.byType(LeaderboardRankChart),
        matching: find.byType(LineChart),
      ),
      findsNothing,
      reason: 'Butun uyeler 0 sn iken siralama yarisi cizilmez.',
    );
    expect(
      find.descendant(
        of: find.byType(LeaderboardRankChart),
        matching: find.byType(Text),
      ),
      findsOneWidget,
      reason: 'Bos dal tek bir aciklama metni cizer.',
    );
  });

  testWidgets('WP-758 (6b) Tek uyeli grup: grafik cizilir, cokme yok', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 8000);
    addTearDown(tester.view.reset);

    container = ProviderContainer();
    addTearDown(container.dispose);
    container.listen(statsPeriodProvider, (_, _) {});
    container.read(statsPeriodProvider.notifier).setPeriod(StatsPeriod.week);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ClassStatsView(
              stats: [stat('u1', DateTime(2026, 8, 25), 5000)],
              members: [members.first],
              currentUserId: 'u1',
              groupGoalMinutes: goalMinutes,
              clock: () => wednesday,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    expect(tester.takeException(), isNull);
    final bars = historyBars(tester);
    expect(bars, hasLength(1));
    expect(bars.first.spots, hasLength(3));
    expect(
      bars.first.spots.last.y,
      1.0,
      reason: 'Tek uye her zaman birincidir (n = 1 → plottedY = 1).',
    );
  });
}
