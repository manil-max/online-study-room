// WP-745 — KISISEL SEKMESININ DONEM BASINA KART KUMESI.
//
// Sahibin sikayeti: alti donem dugmesi de asagiya **ayni 25 karti** seriyor,
// yalniz sayilar degisiyor. Bu dosya kumeyi TABLO olarak kilitler ve ayni turda
// duzeltilen dort olcum hatasinin nobetcisini kurar.
//
// ============================== DISIPLIN =====================================
//
// 1. Bolum kimligi = [StatsSection.title]'in " · " oncesi bası. Baslik kapsam
//    eki tasir ("· Ay · 90 gun"); iddia karta bakar, ekine degil.
// 2. `ListView` TEMBELDIR: mobilde ilk karede yalniz birkac bolum monte olur.
//    Bu yuzden liste SONUNA KADAR kaydirilir ve gorulen basliklarin BIRLESIMI
//    alinir (WP-673 kapisinin ogrettigi desen).
// 3. Iddialar iki yonludur: o donemde OLMASI gerekenler var, OLMAMASI
//    gerekenler yok. Tek yonlu ("su kart var") bir kapi, bugunku kusuru —
//    her donemde HER kart — hic goremez.
// 4. Saat, saf model testlerinde ENJEKTE edilir. Widget tarafinda
//    `PersonalStatsView` `DateTime.now()` okur; oradaki iddialar bu yuzden gun
//    sinirindan bagimsiz **takvim aritmetigiyle** (`DateTime(y, m, d - i)`)
//    kurulur, `subtract(Duration(days:))` ile degil.
//
// ==================== DUZELTME ONCESI OLCULEN DAVRANIS =======================
//
// - "Gun"de "Gunluk ortalama" doseme, "Toplam" ile BIREBIR ayni sayiyi
//   veriyordu (`dailyAverageSeconds` paydasi 1 gun).
// - "Hafta"da offset -1 iken S1 "Gunluk dagilim" penceresi BUGUNDE bitiyordu
//   (`lastNDays` `offset`i hic okumaz): baslik gecen haftayi, grafik bu haftayi
//   anlatiyordu.
// - "Ay"da offset -1 iken S6 sacilim grafigi BOMBOS cikiyordu: veri once doneme
//   suzuluyor, sonra `SessionScatterChart` icinde bugunden geriye 30 gune
//   TEKRAR kirpiliyordu; iki pencere hic kesismiyordu.
// - Ekranda IKI ayri tarih araligi kontrolu vardi: ust donem seridi ve S11
//   `_RangeCard`'in kendi takvimi (basligi da S10 ile birebir ayniydi).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';
import 'package:online_study_room/core/stats/stats_period.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/analytics_query_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/stats_period_provider.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_analytics_query_repository.dart';
import 'package:online_study_room/features/stats/widgets/daily_bar_chart.dart';
import 'package:online_study_room/features/stats/widgets/personal_period_cards.dart';
import 'package:online_study_room/features/stats/widgets/personal_stats_view.dart';
import 'package:online_study_room/features/stats/widgets/session_scatter_chart.dart';
import 'package:online_study_room/features/stats/widgets/stats_desktop_layout.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _userId = 'u1';

/// Gecmisin uzunlugu (gun). "Yil"/"Tumu" sicak pencerenin (90 gun) gerisine
/// uzansin diye bilerek uzun.
const _historyDays = 420;
const _secondsPerDay = 3600;

final _profile = Profile(
  id: _userId,
  displayName: 'Test',
  createdAt: DateTime(2020),
);

const _subjects = <Subject>[
  Subject(id: 'matematik', userId: _userId, name: 'Matematik', color: 'chart-1'),
];

/// [i] gun once. Takvim aritmetigi: yaz saati uygulayan bir kosum makinesinde
/// `subtract(Duration(days:))` gun anahtarini 23:00'a kaydirir.
DateTime _dayBefore(DateTime todayKey, int i) =>
    DateTime(todayKey.year, todayKey.month, todayKey.day - i);

StudySession _session(DateTime day, int index) => StudySession(
  id: 's$index',
  userId: _userId,
  subjectId: 'matematik',
  start: day.add(const Duration(hours: 10)),
  end: day.add(const Duration(hours: 11)),
  durationSeconds: _secondsPerDay,
  source: StudySource.manual,
  // Gun anahtari sunucu damgasindan gelir (bkz. `StudySession.day`).
  recordedDay: day,
);

/// Sunucudaki tam gecmis ve istemcideki sicak pencere.
({List<StudySession> all, List<StudySession> hot}) _history() {
  final todayKey = istanbulDay(DateTime.now());
  final all = <StudySession>[];
  final hot = <StudySession>[];
  for (var i = 0; i < _historyDays; i++) {
    final session = _session(_dayBefore(todayKey, i), i);
    all.add(session);
    if (i < 90) hot.add(session);
  }
  return (all: all, hot: hot);
}

class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🔴 Riverpod 3 tuzagi: dinleyicisiz provider her `read`de yeniden kurulur.
    // `authStateProvider` burada IZLENMEZSE analitik yolu taze bir `null`
    // kullanici gorup bos doner ve "Yil"/"Tumu" iddialari sessizce yalanci olur.
    ref.watch(authStateProvider);
    final sessions =
        ref.watch(userSessionsProvider).value ?? const <StudySession>[];
    return PersonalStatsView(sessions: sessions);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tr = AppLocalizationsTr();

  // ── Beklenen kart kumeleri (gorev tablosuyla BIREBIR) ────────────────────
  final expected = <PersonalCardSet, Set<String>>{
    PersonalCardSet.day: {
      tr.statsOturumCizelgesi,
      tr.statsCalismaSaatleri,
      tr.statsDersBazindaDagilimSon,
      tr.statsOturumDagilimi,
    },
    PersonalCardSet.week: {
      tr.statsCalismaSaatleri,
      tr.statsDersBazindaDagilimSon,
      tr.statsOturumDagilimi,
      tr.statsGunlukDagilim,
      tr.statsSeciliHaftaVsOnceki,
      tr.analyticsCardInsight,
    },
    PersonalCardSet.month: {
      tr.statsCalismaSaatleri,
      tr.statsDersBazindaDagilimSon,
      tr.statsOturumDagilimi,
      tr.statsGunlukDagilim,
      tr.homeEgilimGrafigi,
      tr.homeCalismaTakvimi,
      tr.statsHaftalikRitim,
      tr.analyticsCardInsight,
    },
    PersonalCardSet.year: {
      tr.statsCalismaSaatleri,
      tr.statsDersBazindaDagilimSon,
      tr.statsAylikDagilim,
      tr.homeEgilimGrafigi,
      tr.statsSeciliTarihAraligi,
      tr.homeCalismaTakvimi,
      tr.statsHaftalikRitim,
      tr.analyticsCardInsight,
    },
    PersonalCardSet.all: {
      tr.statsCalismaSaatleri,
      tr.statsDersBazindaDagilimSon,
      tr.statsAylikDagilim,
      tr.homeEgilimGrafigi,
      tr.statsSeciliTarihAraligi,
      tr.homeCalismaTakvimi,
      tr.statsHaftalikRitim,
      tr.analyticsCardInsight,
      tr.statsRekorlar,
    },
  };

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required StatsPeriod period,
    int offset = 0,
    DateTime? customFrom,
    DateTime? customTo,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final data = _history();
    final repo = InMemoryAnalyticsQueryRepository(
      sessionSource: (_) async => data.all,
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith((ref) => Stream.value(_profile)),
        userSessionsProvider.overrideWith((ref) => Stream.value(data.hot)),
        userSubjectsProvider.overrideWith((ref) => Stream.value(_subjects)),
        dailyGoalMinutesProvider.overrideWithValue(120),
        analyticsQueryRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(statsPeriodProvider.notifier);
    if (period == StatsPeriod.custom) {
      notifier.setCustomRange(customFrom!, customTo!);
    } else {
      notifier.setPeriod(period);
      if (offset != 0) notifier.shift(offset);
    }

    // Yuksek viewport: bolumlerin cogu ilk karede monte olsun (kaydirma yine de
    // yapilir, bu yalniz tarama maliyetini dusurur).
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 2400);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: _Host()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pump(const Duration(milliseconds: 20));

    // 🔴 On kosul: donem GERCEKTEN uygulandi mi. Riverpod 3'te dinleyicisiz bir
    // provider her `read`de yeniden kurulur; bu satir olmadan tum kume
    // iddialari sessizce "varsayilan hafta"yi olcerdi.
    final applied = container.read(statsPeriodProvider);
    expect(applied.period, period, reason: 'Donem uygulanmadi.');
    if (period != StatsPeriod.custom) {
      expect(applied.offset, offset, reason: 'Gezinme offseti uygulanmadi.');
    }
    return container;
  }

  /// Basliklarin " · " oncesi basi (kapsam eki iddiaya girmez).
  String head(String title) => title.split(' · ').first;

  Future<Set<String>> collectSections(WidgetTester tester) async {
    final titles = <String>{};
    void grab() {
      for (final element in find.byType(StatsSection).evaluate()) {
        final title = (element.widget as StatsSection).title;
        titles.add(title == null ? '<basliksiz>' : head(title));
      }
    }

    grab();
    for (var i = 0; i < 40; i++) {
      await tester.drag(
        find.byType(ListView).first,
        const Offset(0, -400),
        warnIfMissed: false,
      );
      await tester.pump();
      grab();
    }
    return titles;
  }

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      240,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 80,
    );
    await tester.pumpAndSettle();
  }

  // ===========================================================================
  // 0) SAF MODEL — donem → kume esleme (saat ENJEKTE edilir)
  // ===========================================================================

  test('WP-745 (0) her donem kendi kumesine eslenir', () {
    final now = DateTime(2026, 8, 22, 14);
    PersonalCardSet setOf(StatsPeriod p) =>
        PersonalCardSet.of(StatsPeriodSelection(period: p), now: now);

    expect(setOf(StatsPeriod.day), PersonalCardSet.day);
    expect(setOf(StatsPeriod.week), PersonalCardSet.week);
    expect(setOf(StatsPeriod.month), PersonalCardSet.month);
    expect(setOf(StatsPeriod.year), PersonalCardSet.year);
    expect(setOf(StatsPeriod.all), PersonalCardSet.all);
  });

  test('WP-745 (0) "Ozel" UYARLANABILIR: gun sayisina gore kume secer', () {
    final now = DateTime(2026, 8, 22, 14);
    PersonalCardSet custom(DateTime from, DateTime to) => PersonalCardSet.of(
      StatsPeriodSelection(
        period: StatsPeriod.custom,
        customFrom: from,
        customTo: to,
      ),
      now: now,
    );

    // 1 gun → gun kumesi.
    expect(
      custom(DateTime(2026, 8, 10), DateTime(2026, 8, 10)),
      PersonalCardSet.day,
    );
    // 2 gun ve 31 gun → ay kumesi (sinirlar dahil).
    expect(
      custom(DateTime(2026, 8, 9), DateTime(2026, 8, 10)),
      PersonalCardSet.month,
    );
    expect(
      custom(DateTime(2026, 7, 11), DateTime(2026, 8, 10)),
      PersonalCardSet.month,
    );
    // 32 gun ve uzeri → yil kumesi.
    expect(
      custom(DateTime(2026, 7, 10), DateTime(2026, 8, 10)),
      PersonalCardSet.year,
    );
    expect(
      custom(DateTime(2026, 6, 12), DateTime(2026, 8, 10)),
      PersonalCardSet.year,
    );
  });

  test('WP-745 (0) statsDaySpan iki ucu da sayar', () {
    expect(statsDaySpan(DateTime(2026, 8, 10), DateTime(2026, 8, 10)), 1);
    expect(statsDaySpan(DateTime(2026, 8, 10), DateTime(2026, 8, 11)), 2);
    expect(statsDaySpan(DateTime(2026, 7, 11), DateTime(2026, 8, 10)), 31);
    // Yaz saati gecisi olan bir haftada bile gun sayisi tamdir (UTC normalize).
    expect(statsDaySpan(DateTime(2026, 3, 28), DateTime(2026, 4, 3)), 7);
  });

  // ===========================================================================
  // 1) TABLO — her donem YALNIZ kendi kartlarini serer
  // ===========================================================================

  for (final entry in <StatsPeriod, PersonalCardSet>{
    StatsPeriod.day: PersonalCardSet.day,
    StatsPeriod.week: PersonalCardSet.week,
    StatsPeriod.month: PersonalCardSet.month,
    StatsPeriod.year: PersonalCardSet.year,
    StatsPeriod.all: PersonalCardSet.all,
  }.entries) {
    testWidgets('WP-745 (1) ${entry.key.name}: kart kumesi tabloyla birebir', (
      tester,
    ) async {
      await pump(tester, period: entry.key);
      final drawn = await collectSections(tester);
      final want = expected[entry.value]!;
      expect(
        drawn,
        equals(want),
        reason:
            'Kart kumesi tablodan sapti. fazla: ${drawn.difference(want)} '
            'eksik: ${want.difference(drawn)}',
      );
    });
  }

  // ===========================================================================
  // 2) OZET DOSEMELERI — "Gun"de anlamsiz olanlar CIZILMEZ
  // ===========================================================================

  testWidgets('WP-745 (2) "Gun": Toplam var, "Gunluk ortalama" YOK', (
    tester,
  ) async {
    await pump(tester, period: StatsPeriod.day);

    expect(find.text(tr.statsToplam), findsOneWidget);
    expect(
      find.text(tr.statsGunlukOrtalama),
      findsNothing,
      reason:
          'Gunde paydası 1 gundur: "Gunluk ortalama" "Toplam" ile BIREBIR ayni '
          'sayiyi verir, iki doseme tek bilgi olur.',
    );
    expect(
      find.text(tr.statsHaftaIci),
      findsNothing,
      reason: 'Tek gun ya hafta icidir ya hafta sonu; biri hep sifir olurdu.',
    );
    expect(find.text(tr.statsHaftaSonu), findsNothing);

    // Yerlerini gune gercekten ait olan uc olcu alir.
    expect(find.text(tr.statsOturumSayisi), findsOneWidget);
    expect(find.text(tr.statsEnUzunOturum), findsOneWidget);
    expect(find.text(tr.statsHedefDurumu), findsOneWidget);
  });

  testWidgets('WP-745 (2) "Hafta": dort klasik doseme yerinde', (tester) async {
    await pump(tester, period: StatsPeriod.week);

    expect(find.text(tr.statsToplam), findsOneWidget);
    expect(find.text(tr.statsGunlukOrtalama), findsOneWidget);
    expect(find.text(tr.statsHaftaIci), findsOneWidget);
    expect(find.text(tr.statsHaftaSonu), findsOneWidget);
    // Gune ozel dosemeler haftaya SIZMAZ.
    expect(find.text(tr.statsOturumSayisi), findsNothing);
    expect(find.text(tr.statsEnUzunOturum), findsNothing);
    expect(find.text(tr.statsHedefDurumu), findsNothing);
  });

  // ===========================================================================
  // 3) S11 — ikinci tarih secici HICBIR donemde yok
  // ===========================================================================

  for (final period in StatsPeriod.values) {
    testWidgets(
      'WP-745 (3) ${period.name}: ikinci tarih araligi kontrolu CIZILMEZ',
      (tester) async {
        final now = istanbulDay(DateTime.now());
        await pump(
          tester,
          period: period,
          customFrom: _dayBefore(now, 5),
          customTo: now,
        );
        final titles = await collectSections(tester);

        // `_RangeCard`in tek kontrolu "Sec" dugmesiydi; kart kalksa da dugme
        // kalsaydi ikinci takvim hala ekranda olurdu.
        expect(
          find.text(tr.statsSec),
          findsNothing,
          reason:
              'Ust donem seridiyle celisen ikinci bir tarih araligi kontrolu '
              'hala ciziliyor.',
        );
        expect(find.text(tr.statsGrafikIcin45Gunden), findsNothing);
        // "Secili tarih aralligi" basligi eskiden IKI kez vardi (S10 + S11).
        expect(
          titles.where((t) => t == tr.statsSeciliTarihAraligi).length,
          lessThanOrEqualTo(1),
          reason: 'Ayni baslik iki kartta birden duruyor.',
        );
      },
    );
  }

  // ===========================================================================
  // 4) OZEL (custom) — uyarlanabilirlik EKRANDA
  // ===========================================================================

  testWidgets('WP-745 (4) "Ozel" 1 gunluk aralik GUN kumesini getirir', (
    tester,
  ) async {
    final today = istanbulDay(DateTime.now());
    await pump(
      tester,
      period: StatsPeriod.custom,
      customFrom: today,
      customTo: today,
    );
    expect(
      await collectSections(tester),
      equals(expected[PersonalCardSet.day]!),
    );
  });

  testWidgets('WP-745 (4) "Ozel" 60 gunluk aralik YIL kumesini getirir', (
    tester,
  ) async {
    final today = istanbulDay(DateTime.now());
    await pump(
      tester,
      period: StatsPeriod.custom,
      customFrom: _dayBefore(today, 59),
      customTo: today,
    );
    expect(
      await collectSections(tester),
      equals(expected[PersonalCardSet.year]!),
    );
  });

  // ===========================================================================
  // 5) 🔴 OFFSET GERILEMESI — S1'in cizdigi pencere gecen haftayi kapsar
  // ===========================================================================

  testWidgets(
    'WP-745 (5) "Hafta" offset -1: "Gunluk dagilim" GECEN haftayi cizer, '
    'bugunu DEGIL',
    (tester) async {
      await pump(tester, period: StatsPeriod.week, offset: -1);

      await scrollTo(tester, find.byType(DailyBarChart));
      final chart = tester.widget<DailyBarChart>(find.byType(DailyBarChart));
      final days = chart.days;
      expect(days, hasLength(7));

      final thisMonday = startOfWeek(DateTime.now());
      final prevMonday = DateTime(
        thisMonday.year,
        thisMonday.month,
        thisMonday.day - 7,
      );
      final prevSunday = DateTime(
        thisMonday.year,
        thisMonday.month,
        thisMonday.day - 1,
      );

      expect(
        isSameDay(days.first.day, prevMonday),
        isTrue,
        reason:
            'Pencerenin BASI ${days.first.day} — beklenen $prevMonday. '
            'Duzeltme oncesi pencere daima bugunde bitiyordu (lastNDays '
            '`offset`i hic okumaz).',
      );
      expect(
        isSameDay(days.last.day, prevSunday),
        isTrue,
        reason: 'Pencerenin SONU ${days.last.day} — beklenen $prevSunday.',
      );
      expect(
        days.any((d) => isSameDay(d.day, istanbulDay(DateTime.now()))),
        isFalse,
        reason:
            'Grafik BUGUNU ciziyor: baslik gecen haftayi, grafik bu haftayi '
            'anlatiyor (WP-745 (1) numarali kusur).',
      );
    },
  );

  // ===========================================================================
  // 6) 🔴 CIFT KIRPMA — "Ay" offset -1'de sacilim grafigi BOS DEGIL
  // ===========================================================================

  testWidgets('WP-745 (6) "Ay" offset -3: sacilim grafigi BOS degil', (
    tester,
  ) async {
    // 🔴 offset -1 KASTEN kullanilmadi: ayin ilk gunlerinde "gecen ay"in son
    // haftasi hala son 30 gunun icindedir, yani sabit 30 gunluk kirpma o
    // takvim penceresinde tesadufen dogru sonuc verir ve iddia hicbir sey
    // olcmezdi (olculdu: sabotajda YESIL kaldi). -3 her takvimde 30 gunun
    // otesindedir (en kisa hal: subat + ocak = 58 gun).
    final container = await pump(
      tester,
      period: StatsPeriod.month,
      offset: -3,
    );
    final (periodFrom, _) = container
        .read(statsPeriodProvider)
        .range(now: DateTime.now());

    // Kart varsayilan KATLI (WP urun karari) — acmadan icindeki grafik monte
    // olmaz. Baslik metni tam esitle bulunur: bolum basligi kapsam eki tasir.
    await scrollTo(tester, find.text(tr.statsOturumDagilimi));
    await tester.tap(find.text(tr.statsOturumDagilimi));
    await tester.pumpAndSettle();

    final scatter = tester.widget<SessionScatterChart>(
      find.byType(SessionScatterChart),
    );
    // Grafigin KENDI kirpmasi: penceresinin SONUNDAN geriye `days` gun. Veri
    // ZATEN doneme suzulmustu; ikinci pencere donemin basini disarida
    // birakirsa grafik bombos cizilir.
    //
    // 🔴 WP-765: pencerenin ucunu artik GRAFIK soyluyor (`endDay`); once daima
    // bugundu ve bu satir o varsayimi tekrar ediyordu. Iddia degismedi
    // (pencere donemin basini kesmemeli), yalnizca tureti guncellendi.
    final scatterEnd = istanbulDay(scatter.endDay ?? DateTime.now());
    final startDay = DateTime(
      scatterEnd.year,
      scatterEnd.month,
      scatterEnd.day - (scatter.days - 1),
    );
    expect(
      startDay.isAfter(dayOf(periodFrom)),
      isFalse,
      reason:
          'Grafigin penceresi $startDay, donem ise ${dayOf(periodFrom)} '
          'tarihinde basliyor: ikinci kirpma donemi kesiyor (days=${scatter.days}).',
    );
    final visible = scatter.sessions
        .where((s) => !s.day.isBefore(startDay) && !s.day.isAfter(scatterEnd))
        .toList();
    expect(
      visible,
      isNotEmpty,
      reason:
          'Grafigin penceresi ($startDay …) donemin oturumlarini disarida '
          'birakiyor: days=${scatter.days}.',
    );
    expect(
      find.descendant(
        of: find.byType(SessionScatterChart),
        matching: find.text(tr.statsBuDonemdeCalismaKaydin),
      ),
      findsNothing,
      reason: 'Gezinilen ayda sacilim grafigi bombos cikiyor.',
    );
  });
}
