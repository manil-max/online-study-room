// WP-940 — KISISEL ISTATISTIK EKRANI SADELESTI.
//
// UX denetimi: ekran fazla uzundu. "Ay"da 9 bolum vardi ve ucu ayni seriyi
// cizerdi:
// - "Gunluk dagilim" (cubuk) ile "Egilim grafigi" (cizgi) "Ay"da AYNI gunluk
//   seriydi; Yil/Tumu'de "Secili tarih araligi" ayni seriyi ucuncu kez
//   (gunluk cizgi) ciziyordu.
// - "Ozet" radari birbiriyle ilgisiz, aciklamasiz 0–1 skorlari ayni eksen
//   takimina koyuyordu ("Rekorlar" ekseni aslinda tutarlilikti).
// - "Oturum dagilimi · Ay" basliginin hemen altinda katlanir satir ayni
//   basligi ikinci kez yaziyordu.
//
// Bu dosya uc seyi kilitler: (1) bolum SIRASI kullanisa gore, (2) radar hicbir
// donemde yok, (3) hicbir bolum basligi ekranda iki kez yazilmaz.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';
import 'package:online_study_room/core/stats/stats_period.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/analytics_query_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/stats_period_provider.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_analytics_query_repository.dart';
import 'package:online_study_room/features/stats/charts/area_line_chart.dart';
import 'package:online_study_room/features/stats/widgets/personal_stats_view.dart';
import 'package:online_study_room/features/stats/widgets/stats_desktop_layout.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _userId = 'u1';

/// Uzun gecmis: Yil/Tumu sicak pencerenin (90 gun) gerisine uzansin.
const _historyDays = 420;

final _profile = Profile(
  id: _userId,
  displayName: 'Test',
  createdAt: DateTime(2020),
);

const _subjects = <Subject>[
  Subject(id: 'mat', userId: _userId, name: 'Matematik', color: 'chart-1'),
];

({List<StudySession> all, List<StudySession> hot}) _history() {
  final today = istanbulDay(DateTime.now());
  final all = <StudySession>[];
  final hot = <StudySession>[];
  for (var i = 0; i < _historyDays; i++) {
    // Takvim aritmetigi: `subtract(Duration(days:))` yaz saatinde kayar.
    final day = DateTime(today.year, today.month, today.day - i);
    final session = StudySession(
      id: 's$i',
      userId: _userId,
      subjectId: 'mat',
      start: day.add(const Duration(hours: 10)),
      end: day.add(const Duration(hours: 11)),
      durationSeconds: 3600,
      source: StudySource.manual,
      recordedDay: day,
    );
    all.add(session);
    if (i < 90) hot.add(session);
  }
  return (all: all, hot: hot);
}

class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Riverpod 3: dinleyicisiz provider her `read`de yeniden kurulur.
    ref.watch(authStateProvider);
    ref.watch(statsPeriodProvider);
    final sessions =
        ref.watch(userSessionsProvider).value ?? const <StudySession>[];
    return PersonalStatsView(sessions: sessions);
  }
}

void main() {
  final tr = AppLocalizationsTr();

  Future<void> pump(WidgetTester tester, StatsPeriod period) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final data = _history();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith((ref) => Stream.value(_profile)),
        userSessionsProvider.overrideWith((ref) => Stream.value(data.hot)),
        userSubjectsProvider.overrideWith((ref) => Stream.value(_subjects)),
        dailyGoalMinutesProvider.overrideWithValue(120),
        analyticsQueryRepositoryProvider.overrideWithValue(
          InMemoryAnalyticsQueryRepository(
            sessionSource: (_) async => data.all,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(statsPeriodProvider.notifier).setPeriod(period);

    // Cok yuksek viewport: tum bolumler ayni karede monte olur, boylece
    // `StatsSection` agac sirasi = ekrandaki sira.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 9000);
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
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(container.read(statsPeriodProvider).period, period);
  }

  List<String> titles() => [
    for (final element in find.byType(StatsSection).evaluate())
      (element.widget as StatsSection).title ?? '<basliksiz>',
  ];

  String head(String title) => title.split(' · ').first;

  final expectedOrder = <StatsPeriod, List<String>>{
    StatsPeriod.day: [
      tr.statsOturumCizelgesi,
      tr.statsDersBazindaDagilimSon,
      tr.statsCalismaSaatleri,
      tr.statsOturumDagilimi,
    ],
    StatsPeriod.week: [
      tr.statsGunlukDagilim,
      tr.statsSeciliHaftaVsOnceki,
      tr.statsDersBazindaDagilimSon,
      tr.statsCalismaSaatleri,
      tr.statsOturumDagilimi,
    ],
    StatsPeriod.month: [
      tr.statsGunlukDagilim,
      tr.statsDersBazindaDagilimSon,
      tr.statsCalismaSaatleri,
      tr.homeCalismaTakvimi,
      tr.statsHaftalikRitim,
      tr.statsOturumDagilimi,
    ],
    StatsPeriod.year: [
      tr.homeEgilimGrafigi,
      tr.statsAylikDagilim,
      tr.statsDersBazindaDagilimSon,
      tr.statsCalismaSaatleri,
      tr.homeCalismaTakvimi,
      tr.statsHaftalikRitim,
    ],
    StatsPeriod.all: [
      tr.homeEgilimGrafigi,
      tr.statsDersBazindaDagilimSon,
      tr.statsCalismaSaatleri,
      tr.homeCalismaTakvimi,
      tr.statsHaftalikRitim,
      tr.statsRekorlar,
    ],
  };

  for (final entry in expectedOrder.entries) {
    testWidgets('WP-940 ${entry.key.name}: bolum sirasi kullanisa gore, '
        'radar yok, baslik tekrari yok', (tester) async {
      await pump(tester, entry.key);
      final drawn = titles();

      // (1) Sira — ana zaman grafigi en ustte, oturum dagilimi en altta.
      expect(
        [for (final t in drawn) head(t)],
        entry.value,
        reason: 'Bolum sirasi/kumesi sapti: $drawn',
      );

      // (2) "Ozet" radari hicbir donemde cizilmez.
      expect(find.byType(RadarChart), findsNothing);
      expect(find.text('Özet'), findsNothing);

      // (3) Her baslik ekranda TEK kez yazilir; katlanir satir ya da kart ici
      // etiket bolum basligini tekrarlamaz.
      for (final title in drawn) {
        expect(find.text(title), findsOneWidget, reason: '"$title" basligi');
        if (head(title) != title) {
          expect(
            find.text(head(title)),
            findsNothing,
            reason: '"${head(title)}" bolum basliginin altinda tekrar ediyor',
          );
        }
      }
    });
  }

  testWidgets('WP-940 "Ay": tek ana zaman grafigi (egilim cizgisi yok)', (
    tester,
  ) async {
    await pump(tester, StatsPeriod.month);
    expect(find.byType(AreaLineChart), findsNothing);
  });

  testWidgets('WP-940 "Yil": egilim karti donem toplamini ve calisilan gun '
      'sayisini tasir; ayri "Secili tarih araligi" karti yok', (tester) async {
    await pump(tester, StatsPeriod.year);
    expect(find.byType(AreaLineChart), findsOneWidget);
    expect(find.text('Seçili tarih aralığı'), findsNothing);

    final from = DateTime(istanbulDay(DateTime.now()).year, 1, 1);
    final today = istanbulDay(DateTime.now());
    final days =
        DateTime.utc(
          today.year,
          today.month,
          today.day,
        ).difference(DateTime.utc(from.year, from.month, from.day)).inDays +
        1;
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.byType(AreaLineChart),
          matching: find.byType(Card),
        ),
        matching: find.textContaining('· ${tr.commonDayCount(days)}'),
      ),
      findsOneWidget,
      reason: 'Yilin her gunu calisildi: satir "$days gün" demeli',
    );
  });

  testWidgets('WP-940 oturum dagilimi katli satiri oturum sayisini yazar', (
    tester,
  ) async {
    await pump(tester, StatsPeriod.week);
    final toggle = find.byKey(const Key('stats-session-scatter-toggle'));
    expect(toggle, findsOneWidget);
    expect(
      find
          .descendant(of: toggle, matching: find.byType(Text))
          .evaluate()
          .map((e) => (e.widget as Text).data),
      contains(tr.commonSessionCount(_daysThisWeek())),
    );
  });
}

/// Bu haftanin Pazartesi'sinden bugune gun sayisi (fikstur her gun 1 oturum).
int _daysThisWeek() => istanbulDay(DateTime.now()).weekday;
