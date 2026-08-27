// WP-765 — "BASLIK BIR DONEMI SOYLUYOR, GRAFIK BASKASINI CIZIYOR" ARTIKLARI.
//
// Bu depoda tekrar eden kusur sinifi: kullanici ust seritten bir donem seciyor,
// baslik o donemi yaziyor, altindaki grafik BASKA bir araligi ciziyor. WP-745
// dordunu kapatti; iki tanesi acik kalmisti ve KODDAN dogrulandi:
//
// 1) `SessionScatterChart` `endDay` ALMIYORDU. Pencereyi daima
//    `DateTime.now()`da bitirip `days` kadar geriye sayiyordu
//    (`session_scatter_chart.dart` eski 49-51). Cagiran taraf da bu yuzden
//    `days`i "donemin basindan BUGUNE" diye uzatmisti
//    (`personal_stats_view.dart` eski `statsDaySpan(from, now)`), yani eksen
//    donemden GENIS ciziliyordu.
//    OLCULEN HAL (bugun 27 Agustos, "Ay" offset -1 = Temmuz): days = 58,
//    eksen 1 Tem … 27 Agu. Alt eksen adimi ceil(58/3) = 20 → cizilen etiketler
//    "1 Tem · 21 Tem · 10 Agu". Sonuncusu donemin DISINDA. Ustelik butun
//    noktalar x ∈ [0, 30] araligina, yani grafigin sol yarisina sikisiyordu;
//    sag %47 kalici olarak bostu.
//
// 2) S9 radarin "Gunluk hedef" ekseni donem ne olursa olsun BUGUNU okuyordu:
//    `personal_stats_view.dart` eski `final today = secondsOnDay(sessions, now)`
//    → `_PersonalRadar.today` → `tempo = today / goalSeconds`. "Gecen ay"
//    seciliyken bugun hic calisilmadiysa kose tabana yapisiyordu
//    (`RadarEntry` alt kirpmasi 0.05), oysa o ay hedefin ustunde kapanmis
//    olabilir.
//
// ============================== DISIPLIN =====================================
//
// * Iddialar KULLANICININ GORDUGU seyi olcer: alt eksende YAZAN tarihler,
//   cizilen noktalarin eksendeki yeri ve radarin cizdigi kose degeri. Saf
//   fonksiyon iddiasi tek basina yeterli degil — bu depoda "dogruluk kaynagi
//   dogru ama ekran yanlis" tekrar eden kusur.
// * Fikstur ISTANBUL gununden kurulur (`dayOf`), cihazin yerel gununden DEGIL.
//   UTC bir kosucuda (CI) 21:00-24:00 arasi Istanbul ertesi gundedir; yerel
//   gunden kurulan fikstur her gece uc saat kirmizi yanar (olculdu:
//   `leaderboard_row_fit_wp659_test.dart`).
// * Gun aritmetigi `DateTime(y, m, d - i)` ile yapilir; `Duration.inDays` ile
//   gun sayilmaz (yaz saatinde 23/25 saatlik gunler var).
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
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
import 'package:online_study_room/features/stats/widgets/personal_period_cards.dart';
import 'package:online_study_room/features/stats/widgets/personal_stats_view.dart';
import 'package:online_study_room/features/stats/widgets/session_scatter_chart.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _userId = 'u1';

/// Tek saat okumasi: iddialar ile fikstur ayni ana baglanir.
final DateTime _now = DateTime.now();

/// Gecmisin uzunlugu (gun). offset -3 sicak pencerenin (90 gun) gerisine
/// dussun diye bilerek uzun.
const _historyDays = 420;

/// Sicak pencere (istemcinin elindeki liste) gun sayisi.
const _hotDays = 89;

/// Her calisilan gun BIR saat. Radar iddiasi bu sabitten turer:
/// gunluk ortalama 3600 sn, hedef 7200 sn → tempo tam 0.5.
const _secondsPerDay = 3600;
const _goalMinutes = 120;

final _profile = Profile(
  id: _userId,
  displayName: 'Test',
  createdAt: DateTime(2020),
);

const _subjects = <Subject>[
  Subject(id: 'matematik', userId: _userId, name: 'Matematik', color: 'chart-1'),
];

/// [i] gun once — takvim aritmetigi (`Duration` ile gun sayilmaz).
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
  recordedDay: day,
);

/// Sunucudaki tam gecmis + istemcideki sicak pencere.
///
/// 🔴 BUGUN bilerek BOSTUR (`i` 1'den baslar). Radar iddiasinin ayirt edici
/// gucu buradan gelir: duzeltme oncesi "Gunluk hedef" kosesi bugunu okudugu
/// icin sifira (kirpmayla 0.05'e) dusuyor, dogrusunda donemin gunluk
/// ortalamasini okuyup 0.5 veriyor.
({List<StudySession> all, List<StudySession> hot}) _history() {
  final todayKey = dayOf(_now);
  final all = <StudySession>[];
  final hot = <StudySession>[];
  for (var i = 1; i <= _historyDays; i++) {
    final session = _session(_dayBefore(todayKey, i), i);
    all.add(session);
    if (i <= _hotDays) hot.add(session);
  }
  return (all: all, hot: hot);
}

class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Riverpod 3 tuzagi: dinleyicisiz provider her `read`de yeniden kurulur.
    // `authStateProvider` izlenmezse analitik yolu taze bir `null` kullanici
    // gorup bos doner ve uzun donem iddialari sessizce yalanci olur.
    ref.watch(authStateProvider);
    final sessions =
        ref.watch(userSessionsProvider).value ?? const <StudySession>[];
    return PersonalStatsView(sessions: sessions);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final tr = AppLocalizationsTr();

  /// Alt eksendeki tarih etiketi `'${d.day} ${aylar[d.month - 1]}'` biciminde
  /// yazilir; ay adi → ay numarasi.
  final monthNumberByName = <String, int>{
    tr.statsOca: 1,
    tr.statsSub: 2,
    tr.statsMar: 3,
    tr.statsNis: 4,
    tr.statsMay: 5,
    tr.statsHaz: 6,
    tr.statsTem: 7,
    tr.statsAgu: 8,
    tr.statsEyl: 9,
    tr.statsEki: 10,
    tr.statsKas: 11,
    tr.statsAra: 12,
  };

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    required StatsPeriod period,
    int offset = 0,
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
        dailyGoalMinutesProvider.overrideWithValue(_goalMinutes),
        analyticsQueryRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(statsPeriodProvider.notifier);
    notifier.setPeriod(period);
    if (offset != 0) notifier.shift(offset);

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

    // On kosul: donem GERCEKTEN uygulandi mi (yoksa tum iddialar sessizce
    // "varsayilan hafta"yi olcer).
    final applied = container.read(statsPeriodProvider);
    expect(applied.period, period, reason: 'Donem uygulanmadi.');
    expect(applied.offset, offset, reason: 'Gezinme offseti uygulanmadi.');
    return container;
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

  /// Sacilim grafiginin ALT EKSENINDE gercekten yazan tarihler (gun, ay).
  /// Y ekseni etiketleri ciplak sayidir, bosluk tasimaz — karismaz.
  List<({int day, int month})> bottomAxisDates(WidgetTester tester) {
    final result = <({int day, int month})>[];
    final texts = find.descendant(
      of: find.byType(SessionScatterChart),
      matching: find.byType(Text),
    );
    for (final element in texts.evaluate()) {
      final raw = (element.widget as Text).data;
      if (raw == null) continue;
      final parts = raw.split(' ');
      if (parts.length != 2) continue;
      final day = int.tryParse(parts[0]);
      final month = monthNumberByName[parts[1]];
      if (day == null || month == null) continue;
      result.add((day: day, month: month));
    }
    return result;
  }

  // ===========================================================================
  // 1) SACILIM — eksen donemin SONUNDA biter
  // ===========================================================================

  // offset -1 ile -3 birlikte kosulur: -1 "gecen ay"in gunluk kullanimidir;
  // -3 ise takvimin HER gununde 30 gunun otesindedir, yani ayin ilk
  // gunlerinde tesadufen dogru cikma ihtimalini kapatir (WP-745'in olcumu).
  for (final offset in [-1, -3]) {
    testWidgets(
      'WP-765 (1) "Ay" offset $offset: sacilim ekseni donemin DISINA tasmaz',
      (tester) async {
        final container = await pump(
          tester,
          period: StatsPeriod.month,
          offset: offset,
        );
        final (from, to) = container
            .read(statsPeriodProvider)
            .range(now: _now);
        final periodFrom = dayOf(from);
        final periodTo = dayOf(to);
        final periodSpan = statsDaySpan(periodFrom, periodTo);

        // Kart varsayilan KATLI (WP urun karari): acmadan grafik monte olmaz.
        // Bolum basligi kapsam eki tasidigi icin tam esitlik yalniz katlanir
        // baslige uyar.
        await scrollTo(tester, find.text(tr.statsOturumDagilimi));
        await tester.tap(find.text(tr.statsOturumDagilimi));
        await tester.pumpAndSettle();
        await scrollTo(tester, find.byType(SessionScatterChart));

        final scatter = tester.widget<SessionScatterChart>(
          find.byType(SessionScatterChart),
        );

        // (a) KULLANICININ GORDUGU tarihler: alt eksende yazan her etiket
        // donemin icinde olmali.
        final labels = bottomAxisDates(tester);
        expect(
          labels,
          isNotEmpty,
          reason: 'Alt eksende hic tarih etiketi cizilmemis.',
        );
        final periodDays = <String>{
          for (var i = 0; i < periodSpan; i++)
            () {
              final d = DateTime(
                periodFrom.year,
                periodFrom.month,
                periodFrom.day + i,
              );
              return '${d.day}.${d.month}';
            }(),
        };
        for (final label in labels) {
          expect(
            periodDays.contains('${label.day}.${label.month}'),
            isTrue,
            reason:
                'Alt eksende "${label.day}.${label.month}" yaziyor ama donem '
                '$periodFrom … $periodTo. Baslik bir donemi soyluyor, grafik '
                'baskasini ciziyor.',
          );
        }

        // (b) KULLANICININ GORDUGU geometri: donemin son gunu sag kenardadir.
        // Fikstur her gune bir oturum koydugu icin en sagdaki nokta donemin
        // son gunudur; eksen bugune kadar uzatilirsa grafigin sag yarisi
        // kalici olarak bos kalir.
        final data = tester
            .widget<ScatterChart>(find.byType(ScatterChart))
            .data;
        expect(data.scatterSpots, isNotEmpty, reason: 'Sacilim BOS cizildi.');
        final lastSpotX = data.scatterSpots
            .map((s) => s.x)
            .reduce((a, b) => a > b ? a : b);
        expect(
          data.maxX - lastSpotX,
          lessThanOrEqualTo(1.5),
          reason:
              'Eksen ${data.maxX} noktasina kadar uzuyor ama son oturum '
              '$lastSpotX'
              'te: grafigin sagi donem disi bos alan.',
        );

        // (c) Destekleyici: pencerenin iki ucu da DONEMDEN gelir — tek kaynak
        // `StatsPeriodSelection.range()`. Yukaridaki iki iddia zaten ekrani
        // olcer; bu blok kusurun NEREDE oldugunu tek satirda soyler.
        expect(
          scatter.endDay,
          isNotNull,
          reason:
              'Grafik hala bitis gunu almiyor: pencere `DateTime.now()`da '
              'bitiyor, donemin son gununde degil.',
        );
        expect(
          dayOf(scatter.endDay!),
          periodTo,
          reason:
              'Pencerenin SONU ${scatter.endDay} — donem ise $periodTo '
              'gununde bitiyor.',
        );
        expect(
          scatter.days,
          periodSpan,
          reason:
              'Pencere ${scatter.days} gun genis, donem $periodSpan gun. '
              'Duzeltme oncesi uzunluk donemin basindan BUGUNE sayiliyordu.',
        );
      },
    );
  }

  // ===========================================================================
  // 2) RADAR — "Gunluk hedef" kosesi DONEMI okur, bugunu degil
  // ===========================================================================

  testWidgets(
    'WP-765 (2) "Ay" offset -1: radarin "Gunluk hedef" kosesi donemi okur',
    (tester) async {
      // Fiksturde BUGUN bostur; gecen ayin her gunu 1 saattir.
      // Duzeltme oncesi: tempo = bugunun saniyesi / hedef = 0 → kirpmayla 0.05.
      // Dogrusu: donemin gunluk ortalamasi (3600) / hedef (7200) = 0.5.
      await pump(tester, period: StatsPeriod.month, offset: -1);

      await scrollTo(tester, find.byType(RadarChart));
      final data = tester.widget<RadarChart>(find.byType(RadarChart)).data;

      // Iddia dogru kosayi olctugunden emin ol: 0. eksen "Gunluk hedef".
      expect(
        data.getTitle?.call(0, 0).text,
        tr.homeGunlukHedef,
        reason: 'Radarin 0. ekseni "Gunluk hedef" degil; iddia kaymis.',
      );

      final tempo = data.dataSets.first.dataEntries.first.value;
      expect(
        tempo,
        greaterThan(0.05),
        reason:
            'Kose tabanda ($tempo): eksen hala BUGUNU okuyor. Fiksturde bugun '
            'bos, gecen ay ise her gun 1 saat.',
      );
      expect(
        tempo,
        closeTo(0.5, 0.02),
        reason:
            'Beklenen 0.5 (gunluk ortalama 3600 sn / hedef 7200 sn), olculen '
            '$tempo.',
      );
    },
  );
}
