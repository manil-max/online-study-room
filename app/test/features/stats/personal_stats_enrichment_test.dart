import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/study_session.dart';
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
          home: Scaffold(
            body: PersonalStatsView(sessions: sessions),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(PersonalStatsView), findsOneWidget);
    // ListView tembel — hedefe kadar kaydır.
    await tester.scrollUntilVisible(
      find.byType(AreaLineChart),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(AreaLineChart), findsWidgets);
    await tester.scrollUntilVisible(
      find.byType(RadarStatChart),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.byType(RadarStatChart), findsOneWidget);
  });
}
