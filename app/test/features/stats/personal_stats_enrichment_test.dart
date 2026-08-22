import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/stats/stats_period.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/providers/stats_period_provider.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/stats/charts/area_line_chart.dart';
import 'package:online_study_room/features/stats/charts/radar_stat_chart.dart';
import 'package:online_study_room/features/stats/widgets/personal_stats_view.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PersonalStatsView mounts area/radar sections (WP-203)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final sessions = [
      for (var i = 0; i < 5; i++)
        StudySession(
          id: 's$i',
          userId: 'u1',
          start: now.subtract(Duration(days: i, hours: 2)),
          end: now.subtract(Duration(days: i, hours: 1)),
          durationSeconds: 3600,
          source: StudySource.live,
          subjectId: i.isEven ? 'm' : 'f',
        ),
    ];

    // 🔴 WP-745: kart kümesi artık DÖNEME bağlı. "Hafta"da alan (area) grafiği
    // çizilmez — S5 "Eğilim grafiği" o dönemde S1 "Günlük dağılım" ile aynı 7
    // günü çiziyordu (aynı veri, iki grafik) ve kaldırıldı. Bu testin ölçtüğü
    // şey "area/radar monte oluyor mu"dur; o yüzden iddia gevşetilmedi, dönem
    // area grafiğinin YAŞADIĞI döneme (Ay) sabitlendi.
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        userSessionsProvider.overrideWith((ref) => Stream.value(sessions)),
        userSubjectsProvider.overrideWith((ref) => Stream.value(const [])),
        dailyGoalMinutesProvider.overrideWithValue(120),
      ],
    );
    addTearDown(container.dispose);
    container.read(statsPeriodProvider.notifier).setPeriod(StatsPeriod.month);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PersonalStatsView(sessions: sessions),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PersonalStatsView), findsOneWidget);
    // Ön koşul: dönem gerçekten uygulandı (Riverpod 3'te dinleyicisiz provider
    // her `read`de yeniden kurulur; aksi hâlde ölçüm sessizce "Hafta"ya döner).
    expect(container.read(statsPeriodProvider).period, StatsPeriod.month);
    // ListView tembel — hedefe kadar kaydır.
    await tester.scrollUntilVisible(
      find.byType(AreaLineChart),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(AreaLineChart), findsWidgets);
  });

  testWidgets('RadarStatChart renders complete insight values', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 200,
            child: RadarStatChart(
              values: [0.2, 0.4, 0.6, 0.8, 1],
              labels: ['Tempo', 'Seri', 'Ders', 'Süre', 'Denge'],
            ),
          ),
        ),
      ),
    );
    expect(find.byType(RadarStatChart), findsOneWidget);
  });
}
