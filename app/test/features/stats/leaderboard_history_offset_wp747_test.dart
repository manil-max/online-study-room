// WP-747 — DIKIS WP'si: WP-746'nin ADIYLA BILDIREREK birakabildigi iki kusur.
//
// ============================== OLCULEN KUSUR ================================
//
// (1) G7 LIDERLIK GECMISI donemi yok sayiyordu. Pencerenin SONU widget'in
//     ICINDE hesaplaniyordu (`leaderboard_rank_chart.dart`: `final end =
//     dayOf(DateTime.now())`) ve disaridan verilemiyordu. "Gecen ay"a
//     gidildiginde baslik gecen ayi yazar, grafik BU ayin siralama yarisini
//     cizerdi. Ayni kusurun egilim grafigindeki hâli WP-746'da `today: to` ile
//     kapanmisti; buradaki kapanamadi cunku widget disaridan gun almiyordu.
//
// (2) G3 hedef gostergesinin ETIKETLERI "Bugun aktif" / "Bugun lider" idi.
//     WP-746 kartin VERISINI secili gune bagladi ama ARB ona yasakti: "Dun"e
//     gidildiginde DOGRU veri YANLIS baslikla cikiyordu.
//
// ============================== DISIPLIN =====================================
//
// 1. SAAT ENJEKTE (`ClassStatsView.clock`) — aksi hâlde iddialar gece yarisi
//    kendiliginden kirmiziya doner (deseni WP-746 kurdu).
// 2. Donem `statsPeriodProvider`in GERCEK API'siyle kurulur (`setPeriod` +
//    `shift`), sabit bir Notifier ile taklit edilmez.
// 3. 🔴 Riverpod 3 tuzagi: dinleyicisiz provider her `read`de yeniden build
//    olur ve `shift(-1)` sessizce kaybolur. `container.listen` ile canli tut.
// 4. 🔴 Iddia CIZILEN grafikten okunur, yalniz widget parametresinden degil:
//    `LineChart`in `LineChartData.lineBarsData` noktalari alinir. Sadece
//    `endDay` parametresine bakan bir test, parametre baglanip da grafik
//    tarafindan kullanilmasa yesil kalirdi.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/stats_period.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
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

  // Sabit saat: 20 Agustos 2026, Persembe 14:00.
  final now = DateTime(2026, 8, 20, 14);
  final today = DateTime(2026, 8, 20);
  final yesterday = DateTime(2026, 8, 19);

  const goalMinutes = 120; // 7200 sn

  Profile member(String id, String name) =>
      Profile(id: id, displayName: name, createdAt: DateTime(2026, 1, 1));

  final members = [
    member('u1', 'Ada'),
    member('u2', 'Bora'),
    member('u3', 'Cem'),
  ];

  // 🔴 Veri iki pencereyi AYIRACAK sekilde yerlestirildi:
  //
  //   Ay + offset -1 → pencere 2026-07-02 … 2026-07-31 (30 gun, `to` = 31 Tem)
  //   Ay + offset  0 → pencere 2026-07-22 … 2026-08-20 (30 gun, `to` = bugun)
  //
  // Pencereler UST USTE biner (22–31 Temmuz), o yuzden "hangi gun var" iddiasi
  // ayirt edici degildir. Ayirt edici olan LIDER:
  //
  //   gecen ay penceresi → Ada  (yalniz 5 Temmuz'daki 9000 sn icerde)
  //   bu ay penceresi    → Cem  (yalniz 19 Agustos'taki 9000 sn icerde)
  //
  // 🔴 Ilk kurulumda dunku 9000 sn Ada'ya yazilmisti ve Ada HER IKI pencerede
  // de lider cikiyordu: nobetci, kusur duruyorken bile yesil kalirdi. Testin
  // kendi olcum kabiliyeti bolum 2 tarafindan yakalandi.
  final stats = [
    DailyStat(userId: 'u1', day: DateTime(2026, 7, 5), seconds: 9000),
    DailyStat(userId: 'u2', day: DateTime(2026, 8, 15), seconds: 3600),
    // Gun kumesi iddialari icin (bolum 4): dun yalniz Cem calisti (1/3),
    // grup toplami 9000 / 7200 = %125.
    DailyStat(userId: 'u3', day: yesterday, seconds: 9000),
    // Bugun Ada + Bora calisti (2/3).
    DailyStat(userId: 'u1', day: today, seconds: 1800),
    DailyStat(userId: 'u2', day: today, seconds: 1800),
  ];

  late ProviderContainer container;

  Future<void> pump(
    WidgetTester tester, {
    required StatsPeriod period,
    int offset = 0,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 8000);
    addTearDown(tester.view.reset);

    container = ProviderContainer();
    addTearDown(container.dispose);
    // 🔴 Riverpod 3: dinleyicisiz provider her `read`de yeniden dogar.
    container.listen(statsPeriodProvider, (_, _) {});

    final notifier = container.read(statsPeriodProvider.notifier);
    notifier.setPeriod(period);
    for (var i = 0; i < -offset; i++) {
      notifier.shift(-1);
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

  /// Liderlik gecmisi grafiginin GERCEKTEN cizilen serileri.
  ///
  /// `find.byType(LineChart)` tek basina yetmez: ayni ekranda grup egilimi
  /// grafigi de bir `LineChart` cizer. Arama liderlik grafiginin altina
  /// daraltilir.
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

  /// [id] uyesinin penceredeki SON gunde aldigi cizim yuksekligi.
  ///
  /// `plottedY`: rank 1 → n (en ust), rank n → 1. Uc uye oldugu icin
  /// **y = 3 birinciligi**, y = 2 ikinciligi anlatir.
  double lastY(List<LineChartBarData> bars, String id) {
    final index = members.indexWhere((m) => m.id == id);
    expect(index, isNonNegative);
    return bars[index].spots.last.y;
  }

  // ===========================================================================
  // 1) 🔴 NOBETCI — liderlik gecmisi penceresi GEZINILEN donemi kapsar
  // ===========================================================================

  testWidgets(
    'WP-747 (1) Ay + offset -1: liderlik gecmisi GECEN ayi cizer, bu ayi degil',
    (tester) async {
      await pump(tester, period: StatsPeriod.month, offset: -1);

      expect(
        container.read(statsPeriodProvider).offset,
        -1,
        reason: 'Gezinme uygulanmadi; test kendi onkosulunu kaybetti.',
      );

      final chart = tester.widget<LeaderboardRankChart>(
        find.byType(LeaderboardRankChart),
      );
      expect(
        chart.endDay == null ? null : dayOf(chart.endDay!),
        DateTime(2026, 7, 31),
        reason:
            'Pencerenin sonu donemin sonuna baglanmadi. `endDay` verilmezse '
            'grafik kendi icinde `DateTime.now()` kullanir.',
      );

      final bars = historyBars(tester);
      expect(bars, hasLength(3));
      expect(
        bars.first.spots,
        hasLength(30),
        reason: 'Ay donemi 30 gunluk pencere cizer.',
      );

      // Gecen ay penceresinde (2 – 31 Temmuz) yalniz Ada calisti (5 Temmuz,
      // 9000 sn). Bora'nin 15 Agustos'u ve Cem'in 19 Agustos'u DISARIDADIR,
      // yani ikisi de sifirda ve sirayi uye sirasi belirler.
      expect(
        lastY(bars, 'u1'),
        3.0,
        reason:
            'Gecen ayin lideri Ada olmali. y = 1 ise grafik hâlâ BU ayi '
            '(22 Tem – 20 Agu) ciziyor: orada Cem 19 Agustos ile one geciyor.',
      );
      expect(
        lastY(bars, 'u2'),
        2.0,
        reason: 'Bora gecen ay hic calismadi; ikincilik beraberlikten gelir.',
      );
      expect(
        lastY(bars, 'u3'),
        1.0,
        reason:
            'Cem gecen ay hic calismadi. Birinci cizildiyse pencere BU ayin '
            'penceresidir — nobetcinin olctugu kusur tam olarak budur.',
      );
    },
  );

  // ===========================================================================
  // 2) REGRESYON NOBETCISI — offset 0 pencereyi BUGUNDE bitirir
  // ===========================================================================

  testWidgets('WP-747 (2) Ay + offset 0: pencere BUGUNDE biter', (
    tester,
  ) async {
    await pump(tester, period: StatsPeriod.month);

    final chart = tester.widget<LeaderboardRankChart>(
      find.byType(LeaderboardRankChart),
    );
    expect(chart.endDay == null ? null : dayOf(chart.endDay!), today);

    final bars = historyBars(tester);
    // Bu ay penceresinde (22 Tem – 20 Agu): Cem 9000, Bora 3600 + 1800 =
    // 5400, Ada 1800. Ada'nin 5 Temmuz'daki 9000 sn'si pencerenin DISINDADIR.
    expect(
      lastY(bars, 'u3'),
      3.0,
      reason: 'Bu ayin lideri Cem olmali (9000 > 5400 > 1800).',
    );
    expect(lastY(bars, 'u2'), 2.0);
    expect(
      lastY(bars, 'u1'),
      1.0,
      reason:
          'Ada bu pencerede sonuncu; birinci cizildiyse gecen ayin verisi '
          'sizmis demektir.',
    );
  });

  // ===========================================================================
  // 3) `endDay` OPSIYONEL — verilmezse eski davranis birebir korunur
  // ===========================================================================

  testWidgets(
    'WP-747 (3) endDay verilmezse pencere bugunde biter (eski davranis)',
    (tester) async {
      final colors = <String, Color>{
        'u1': Colors.red,
        'u2': Colors.green,
        'u3': Colors.blue,
      };
      // Saat enjekte edilemeyen tek dal bu; veri bu yuzden GERCEK bugune yazilir.
      final realToday = dayOf(DateTime.now());
      final data = [DailyStat(userId: 'u2', day: realToday, seconds: 4200)];

      Future<List<LineChartBarData>> render(DateTime? endDay) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 800,
                height: 600,
                child: LeaderboardRankChart(
                  members: members,
                  memberColors: colors,
                  stats: data,
                  days: 7,
                  endDay: endDay,
                  currentUserId: 'u1',
                  emptyLabel: 'bos',
                  namelessLabel: 'isimsiz',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return tester
            .widget<LineChart>(find.byType(LineChart))
            .data
            .lineBarsData;
      }

      final implicit = await render(null);
      final explicit = await render(realToday);
      expect(
        [for (final b in implicit) b.spots.map((s) => '${s.x}:${s.y}').toList()],
        [for (final b in explicit) b.spots.map((s) => '${s.x}:${s.y}').toList()],
        reason:
            '`endDay` opsiyonel: verilmeyince pencere eskisi gibi bugunde '
            'bitmeli. Baska cagiranlar bu davranisa guveniyor.',
      );
      // Bora bugun calisti → pencere bugunu KAPSIYOR (grafik bos degil).
      expect(implicit, hasLength(3));
      expect(implicit[1].spots.last.y, 3.0);
    },
  );

  // ===========================================================================
  // 4) 🔴 ETIKETLER — kart "Bugun" iddiasinda bulunmaz
  // ===========================================================================

  testWidgets('WP-747 (4) Gun + offset -1: ekranda "Bugun" gecmiyor', (
    tester,
  ) async {
    await pump(tester, period: StatsPeriod.day, offset: -1);

    expect(container.read(statsPeriodProvider).offset, -1);

    expect(
      find.textContaining('Bugün'),
      findsNothing,
      reason:
          'Dune bakilirken ekranda "Bugun" gecemez. WP-746 kartin VERISINI '
          'dune bagladi, etiketleri kalmisti: dogru veri yanlis baslikla '
          'cikiyordu.',
    );
    expect(
      find.text(tr.statsBugunKatilim),
      findsNothing,
      reason: '"Bugün aktif" etiketi hâlâ cizilmis.',
    );
    expect(
      find.text(tr.statsBugunLider),
      findsNothing,
      reason: '"Bugün lider" etiketi hâlâ cizilmis.',
    );

    // Yerine gecen donem-notr etiketler GERCEKTEN cizilmeli (etiketin sessizce
    // kaybolmasi da bir kusur olurdu).
    expect(find.text(tr.statsGunAktif), findsOneWidget);
    expect(find.text(tr.statsGunLider), findsOneWidget);

    // Veri hâlâ DUNU anlatiyor (WP-746 kazanimi bu WP'de bozulmadi):
    // dun yalniz u1 calisti (1/3) ve 9000 / 7200 = %125.
    expect(find.text('1/3'), findsOneWidget);
    expect(find.text('125%'), findsWidgets);
  });

  testWidgets(
    'WP-747 (4b) Gun + offset 0: etiket ayni, ekran yine "Bugun" demiyor',
    (tester) async {
      await pump(tester, period: StatsPeriod.day);

      expect(
        find.textContaining('Bugün'),
        findsNothing,
        reason:
            'Etiket donem-notr; bugune bakarken de "Bugun" yazmasi gerekmez '
            '(hangi gune bakildigini gezinme cubugu yazar).',
      );
      expect(find.text(tr.statsGunAktif), findsOneWidget);
      expect(find.text(tr.statsGunLider), findsOneWidget);
      // Bugun u1 + u2 calisti.
      expect(find.text('2/3'), findsOneWidget);
    },
  );
}
