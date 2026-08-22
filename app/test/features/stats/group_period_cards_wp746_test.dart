// WP-746 — GRUP SEKMESI: donem basina kart kumesi + iki gercek hata.
//
// ============================== OLCULEN KUSUR ================================
//
// Alti donem dugmesi de asagiya AYNI kartlari seriyordu: tek gune bakarken
// "son 30 gun egilimi", yila bakarken "bugunun lideri", her donemde de donemden
// BAGIMSIZ "Tum zamanlar" karti. Ustune iki gercek hata:
//
//   (a) G3 hedef gostergesi daima BUGUNU anlatiyordu. "Dun"e gidilince baslik
//       dunu, gosterge bugunu yaziyordu (`userTotalsInRange(dayOf(now), now)`,
//       `groupDay[dayOf(now)]`, "bugunun lideri" — uc yerde birden `now`).
//   (b) G8 grup egilimi `offset`i yok sayiyordu: pencerenin SONU daima bugundu
//       (`lastNDays` varsayilani `DateTime.now()`). "Gecen ay"da baslik gecen
//       ayi yazar, grafik bu ayi cizerdi.
//
// ============================== DISIPLIN =====================================
//
// 1. SAAT ENJEKTE (`ClassStatsView.clock`). Enjekte edilmezse (a) vakasi gece
//    yarisi kendiliginden kirmiziya doner ve kapi guvenilmez olur.
// 2. Donem `statsPeriodProvider` uzerinden GERCEK API ile kurulur
//    (`setPeriod` + `shift`), sabit bir Notifier ile taklit edilmez.
// 3. 🔴 Riverpod 3 tuzagi: dinleyicisiz provider her `read`de yeniden build
//    olur ve `shift(-1)` sessizce kaybolur. `container.listen` ile CANLI
//    tutulur (deseni `stats_range_navigator_wp743_test.dart` kurdu).
// 4. Iddialar CIZILEN agactan okunur; tek istisna G8 penceresi, cunku o bir
//    tuvale cizilir — orada grafigin GIRDISI (`DailyLineChart.days`) okunur.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/stats_period.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/stats_period_provider.dart';
import 'package:online_study_room/features/classroom/widgets/group_avatar.dart';
import 'package:online_study_room/features/stats/charts/gauge_chart.dart';
import 'package:online_study_room/features/stats/widgets/class_stats_view.dart';
import 'package:online_study_room/features/stats/widgets/daily_line_chart.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tr = AppLocalizationsTr();

  // Sabit saat: 20 Agustos 2026, Persembe 14:00.
  final now = DateTime(2026, 8, 20, 14);
  final today = DateTime(2026, 8, 20);
  final yesterday = DateTime(2026, 8, 19);
  final lastMonthDay = DateTime(2026, 7, 15);

  // Grup gunluk hedefi 120 dk = 7200 sn.
  const goalMinutes = 120;

  Profile member(String id, String name) =>
      Profile(id: id, displayName: name, createdAt: DateTime(2026, 1, 1));

  final members = [
    member('u1', 'Ada'),
    member('u2', 'Bora'),
    member('u3', 'Cem'),
  ];

  // BUGUN grup toplami 5400 sn (%75), 3 uyeden 2'si aktif.
  // DUN   grup toplami 9000 sn (%125), 3 uyeden 1'i aktif.
  // Iki gunun HICBIR sayisi ortak degil; (a) vakasi tek bakista okunur.
  final stats = [
    DailyStat(userId: 'u1', day: today, seconds: 3600),
    DailyStat(userId: 'u2', day: today, seconds: 1800),
    DailyStat(userId: 'u1', day: yesterday, seconds: 9000),
    DailyStat(userId: 'u1', day: lastMonthDay, seconds: 5400),
  ];

  late ProviderContainer container;

  /// Donemi kurar ve gorunumu monte eder.
  ///
  /// [offset] `shift` ile uygulanir (dogrudan state yazilmaz): kullanicinin
  /// oka basmasiyla AYNI yol.
  Future<void> pump(
    WidgetTester tester, {
    required StatsPeriod period,
    int offset = 0,
    DateTime? customFrom,
    DateTime? customTo,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 8000);
    addTearDown(tester.view.reset);

    container = ProviderContainer();
    addTearDown(container.dispose);
    // 🔴 Riverpod 3: dinleyicisiz provider her `read`de yeniden dogar.
    container.listen(statsPeriodProvider, (_, _) {});

    final notifier = container.read(statsPeriodProvider.notifier);
    if (period == StatsPeriod.custom) {
      notifier.setCustomRange(customFrom!, customTo!);
    } else {
      notifier.setPeriod(period);
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

  /// Onaylanmis tabloyu BIREBIR dogrular: olmasi gerekenler var, olmamasi
  /// gerekenler yok. Ayrica her donemde gecerli iki "asla" kurali burada.
  void expectCardSet(
    WidgetTester tester,
    String label, {
    required bool gauge,
    required bool history,
    required bool trend,
    required bool allTime,
  }) {
    // --- HER donemde cizilenler -------------------------------------------
    expect(
      find.text(tr.statsSiralama),
      findsOneWidget,
      reason: '$label: G2 siralama her donemde cizilmeli.',
    );
    expect(
      find.text(tr.statsGrupToplami),
      findsWidgets,
      reason: '$label: G4 grup toplami her donemde cizilmeli.',
    );
    expect(
      find.text(tr.statsKisiBasiOrt),
      findsOneWidget,
      reason: '$label: G5 kisi basi ortalama her donemde cizilmeli.',
    );
    expect(
      find.text(tr.analyticsCardMemberDonut),
      findsOneWidget,
      reason: '$label: G6 uye katki payi her donemde cizilmeli.',
    );

    // --- Donem bagimli kartlar --------------------------------------------
    expect(
      find.byType(GaugeChart),
      gauge ? findsOneWidget : findsNothing,
      reason: '$label: G3 hedef gostergesi yalniz gun kumesinde.',
    );
    expect(
      find.text(tr.statsGunAktif),
      gauge ? findsOneWidget : findsNothing,
      reason: '$label: G3 gun ozeti gauge ile birlikte gelir/gider.',
    );
    expect(
      find.text(tr.analyticsCardLeaderboardHistory),
      history ? findsOneWidget : findsNothing,
      reason: '$label: G7 liderlik gecmisi tek gunde anlamsiz.',
    );
    expect(
      find.byType(DailyLineChart),
      trend ? findsOneWidget : findsNothing,
      reason: '$label: G8 grup egilimi tek gunde tek nokta olurdu.',
    );
    expect(
      find.text(tr.statsTumZamanlar),
      allTime ? findsOneWidget : findsNothing,
      reason:
          '$label: G9 donemden BAGIMSIZ; donem seridinin altinda her donemde '
          'durmasi onu donemin sonucu gibi gosterir.',
    );

    // --- Hicbir donemde olmayacaklar --------------------------------------
    expect(
      find.text(tr.statsKarsilastirmaTablosu),
      findsNothing,
      reason:
          '$label: G10 karsilastirma tablosu SILINDI (sutunlari sabitti, '
          'donem secimine hic tepki vermiyordu).',
    );
    expect(
      find.byType(GroupAvatar),
      findsNothing,
      reason: '$label: grup basligi satiri (avatar) silindi.',
    );
    expect(
      find.text(tr.statsDegistir),
      findsNothing,
      reason:
          '$label: "Degistir" dugmesi silindi — ayni islev WP-743\'te sekme '
          'basligina tasindi, iki cagri yeri kalmisti.',
    );
    expect(
      find.byIcon(Icons.swap_horiz),
      findsNothing,
      reason: '$label: grup degistirici ikonu silindi.',
    );
  }

  // ===========================================================================
  // 1) ONAYLANMIS TABLO — alti donem + uyarlanabilir ozel aralik
  // ===========================================================================

  group('WP-746 (1) donem basina kart kumesi', () {
    testWidgets('Gun: siralama + hedef gostergesi; gecmis/egilim/tum yok', (
      tester,
    ) async {
      await pump(tester, period: StatsPeriod.day);
      expectCardSet(
        tester,
        'Gun',
        gauge: true,
        history: false,
        trend: false,
        allTime: false,
      );
    });

    testWidgets('Hafta: gecmis + egilim var; hedef gostergesi ve tum yok', (
      tester,
    ) async {
      await pump(tester, period: StatsPeriod.week);
      expectCardSet(
        tester,
        'Hafta',
        gauge: false,
        history: true,
        trend: true,
        allTime: false,
      );
    });

    testWidgets('Ay: gecmis + egilim var; hedef gostergesi ve tum yok', (
      tester,
    ) async {
      await pump(tester, period: StatsPeriod.month);
      expectCardSet(
        tester,
        'Ay',
        gauge: false,
        history: true,
        trend: true,
        allTime: false,
      );
    });

    testWidgets('Yil: gecmis + egilim var; hedef gostergesi ve tum yok', (
      tester,
    ) async {
      await pump(tester, period: StatsPeriod.year);
      expectCardSet(
        tester,
        'Yil',
        gauge: false,
        history: true,
        trend: true,
        allTime: false,
      );
    });

    testWidgets('Tumu: tek "Tum zamanlar" cizen donem', (tester) async {
      await pump(tester, period: StatsPeriod.all);
      expectCardSet(
        tester,
        'Tumu',
        gauge: false,
        history: true,
        trend: true,
        allTime: true,
      );
    });

    testWidgets('Ozel (tek gun): GUN kumesine uyarlanir', (tester) async {
      await pump(
        tester,
        period: StatsPeriod.custom,
        customFrom: today,
        customTo: today,
      );
      expectCardSet(
        tester,
        'Ozel-1gun',
        gauge: true,
        history: false,
        trend: false,
        allTime: false,
      );
    });

    testWidgets('Ozel (51 gun): COK GUNLU kumeye uyarlanir', (tester) async {
      await pump(
        tester,
        period: StatsPeriod.custom,
        customFrom: DateTime(2026, 7, 1),
        customTo: today,
      );
      expectCardSet(
        tester,
        'Ozel-51gun',
        gauge: false,
        history: true,
        trend: true,
        allTime: false,
      );
    });

    testWidgets('Ozel (5 gun): COK GUNLU kumeye uyarlanir', (tester) async {
      await pump(
        tester,
        period: StatsPeriod.custom,
        customFrom: DateTime(2026, 8, 16),
        customTo: today,
      );
      expectCardSet(
        tester,
        'Ozel-5gun',
        gauge: false,
        history: true,
        trend: true,
        allTime: false,
      );
    });
  });

  // ===========================================================================
  // 2) GUN: siralama ANA karttir
  // ===========================================================================

  testWidgets(
    'WP-746 (2) Gun: siralama cizilir ve TUM kartlarin ustundedir',
    (tester) async {
      await pump(tester, period: StatsPeriod.day);

      final ranking = tester.getTopLeft(find.text(tr.statsSiralama)).dy;
      final cardTops = [
        for (final element in find.byType(Card).evaluate())
          tester.getRect(find.byWidget(element.widget)).top,
      ];
      expect(cardTops, isNotEmpty, reason: 'Hicbir kart cizilmedi.');
      expect(
        cardTops.reduce((a, b) => a < b ? a : b),
        greaterThan(ranking),
        reason:
            'Siralama gunun ANA karti (sahip karari: "gun ici calisma ranking '
            'list"); hicbir kart onun ustunde cizilemez.',
      );
      // Siralama gercekten DOLU: uc uye de satir aliyor.
      for (final name in const ['Bora', 'Cem']) {
        expect(find.text(name), findsOneWidget, reason: '$name satiri yok.');
      }
      expect(find.textContaining('(sen)'), findsWidgets);
    },
  );

  // ===========================================================================
  // 3) 🔴 G3 REGRESYONU — hedef gostergesi SECILI gunu anlatir
  // ===========================================================================

  testWidgets(
    'WP-746 (3) Gun + offset -1: hedef gostergesi DUNU anlatiyor, bugunu degil',
    (tester) async {
      await pump(tester, period: StatsPeriod.day, offset: -1);

      expect(
        container.read(statsPeriodProvider).offset,
        -1,
        reason: 'Gezinme uygulanmadi; test kendi onkosulunu kaybetti.',
      );

      // Dun grup toplami 9000 / 7200 = %125; bugun 5400 / 7200 = %75.
      // (Yuzde IKI yerde yazar: gauge'in kendi ortasi + kartin alt satiri.)
      expect(
        find.text('125%'),
        findsWidgets,
        reason:
            'Gosterge DUNUN yuzdesini yazmali. Duzeltme oncesi uc yerde birden '
            '`now` sabitti ve baslik dunu, gosterge bugunu anlatiyordu.',
      );
      expect(
        find.text('75%'),
        findsNothing,
        reason: 'BUGUNUN yuzdesi cizildi — gosterge hâlâ `now`a bagli.',
      );

      // Katilim: dun yalniz u1 calisti (1/3), bugun u1+u2 (2/3).
      expect(find.text('1/3'), findsOneWidget, reason: 'Dunun katilimi degil.');
      expect(find.text('2/3'), findsNothing, reason: 'Bugunun katilimi cizildi.');

      // Hedef tuttu: dun 9000 >= 7200.
      expect(
        find.text(tr.statsHedefTamam),
        findsOneWidget,
        reason: 'Dun hedef tutmustu; "hedefe kalan" bugune gore hesaplanmis.',
      );
    },
  );

  testWidgets('WP-746 (3b) Gun + offset 0: gosterge BUGUNU anlatir', (
    tester,
  ) async {
    await pump(tester, period: StatsPeriod.day);
    expect(find.text('75%'), findsWidgets);
    expect(find.text('125%'), findsNothing);
    expect(find.text('2/3'), findsOneWidget);
  });

  // ===========================================================================
  // 4) 🔴 G8 REGRESYONU — egilim penceresinin SONU donemin sonu
  // ===========================================================================

  List<DayTotal> trendWindow(WidgetTester tester) =>
      tester.widget<DailyLineChart>(find.byType(DailyLineChart)).days;

  testWidgets(
    'WP-746 (4) Ay + offset -1: grup egiliminin penceresi GECEN ayi kapsar',
    (tester) async {
      await pump(tester, period: StatsPeriod.month, offset: -1);

      expect(container.read(statsPeriodProvider).offset, -1);

      final window = trendWindow(tester);
      expect(window, hasLength(30));
      expect(
        window.last.day,
        DateTime(2026, 7, 31),
        reason:
            'Pencerenin sonu hâlâ bugun (2026-08-20). `lastNDays` varsayilani '
            '`DateTime.now()`tur; `today: to` verilmezse baslik gecen ayi '
            'yazarken grafik bu ayi cizer.',
      );
      final july15 = window.where((d) => d.day == lastMonthDay).toList();
      expect(july15, hasLength(1), reason: '15 Temmuz pencerede yok.');
      expect(
        july15.single.seconds,
        5400,
        reason: 'Gecen ayin verisi penceredeyken sifir okundu.',
      );
    },
  );

  testWidgets('WP-746 (4b) Ay + offset 0: pencere BUGUNDE biter', (
    tester,
  ) async {
    await pump(tester, period: StatsPeriod.month);
    final window = trendWindow(tester);
    expect(window.last.day, today);
    expect(
      window.where((d) => d.day == lastMonthDay),
      isEmpty,
      reason: '30 gunluk pencere 2026-07-22de baslar; 15 Temmuz disaridadir.',
    );
  });

  // ===========================================================================
  // 5) G9 — "Tum zamanlar" yalniz Tumu doneminde
  // ===========================================================================

  testWidgets('WP-746 (5) Tum zamanlar: Tumu\'de var, Hafta\'da yok', (
    tester,
  ) async {
    await pump(tester, period: StatsPeriod.all);
    expect(find.text(tr.statsTumZamanlar), findsOneWidget);
    expect(find.text(tr.statsEnYogunGun), findsOneWidget);
    expect(find.text(tr.statsEnIstikrarliUye), findsOneWidget);

    await pump(tester, period: StatsPeriod.week);
    expect(find.text(tr.statsTumZamanlar), findsNothing);
    expect(find.text(tr.statsEnYogunGun), findsNothing);
    expect(find.text(tr.statsEnIstikrarliUye), findsNothing);
  });
}
