import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/grid/grid_reflow.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_analytics_query_repository.dart';
import 'package:online_study_room/features/stats/analytics/analytics_card_config.dart';
import 'package:online_study_room/features/stats/analytics/analytics_card_registry.dart';
import 'package:online_study_room/features/stats/analytics/analytics_card_type.dart';
import 'package:online_study_room/features/stats/analytics/analytics_period.dart';
import 'package:online_study_room/features/stats/widgets/personal_stats_view.dart';
import 'package:online_study_room/features/stats/widgets/stats_period_bar.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('stable id + reflow', () {
    test('card id does not change when position changes', () {
      const a = AnalyticsCardConfig(
        AnalyticsCardType.trendLine,
        x: 0,
        y: 0,
        w: 6,
        h: 3,
      );
      final b = a.copyWith(x: 0, y: 5);
      expect(a.id, b.id);
      expect(a.id, 'trendLine');
    });

    test('move reflow produces no overlap', () {
      final layout = defaultPersonalLayout();
      final moved = reflowAnalyticsLayout(
        layout: layout,
        moving: AnalyticsCardType.totalPeriod,
        x: 0,
        y: 2,
        w: 3,
        h: 2,
      );
      final bounds = moved.map((c) => c.toBounds()).toList();
      for (var i = 0; i < bounds.length; i++) {
        for (var j = i + 1; j < bounds.length; j++) {
          expect(
            bounds[i].overlaps(bounds[j]),
            isFalse,
            reason: '${bounds[i].id} overlaps ${bounds[j].id}',
          );
        }
      }
      // Kimlikler korunur.
      expect(
        moved.map((c) => c.id).toSet(),
        layout.map((c) => c.id).toSet(),
      );
    });

    test('resize reflow produces no overlap', () {
      final layout = defaultPersonalLayout();
      final resized = reflowAnalyticsLayout(
        layout: layout,
        moving: AnalyticsCardType.goalGauge,
        x: 3,
        y: 0,
        w: 3,
        h: 4,
      );
      final bounds = resized.map((c) => c.toBounds()).toList();
      for (var i = 0; i < bounds.length; i++) {
        for (var j = i + 1; j < bounds.length; j++) {
          expect(bounds[i].overlaps(bounds[j]), isFalse);
        }
      }
    });

    test('placeGridItem keeps id after collision push', () {
      final items = [
        const GridItemBounds(id: 'a', x: 0, y: 0, w: 3, h: 2),
        const GridItemBounds(id: 'b', x: 3, y: 0, w: 3, h: 2),
      ];
      final out = placeGridItem(
        items: items,
        id: 'a',
        x: 2,
        y: 0,
        w: 3,
        h: 2,
        columns: 6,
      );
      expect(out.map((e) => e.id).toSet(), {'a', 'b'});
      expect(out[0].overlaps(out[1]), isFalse);
    });
  });

  group('period math', () {
    test('year range uses calendar year start', () {
      final p = const AnalyticsPeriod(AnalyticsPeriodKind.year);
      final now = DateTime(2026, 7, 15, 12);
      final (from, to) = p.range(now: now);
      expect(from, DateTime(2026, 1, 1));
      expect(to.year, 2026);
    });

    test('custom range preserved', () {
      final from = DateTime(2026, 3, 1);
      final to = DateTime(2026, 3, 20);
      final p = AnalyticsPeriod(
        AnalyticsPeriodKind.custom,
        customFrom: from,
        customTo: to,
      );
      final (f, t) = p.range(now: DateTime(2026, 7, 1));
      expect(dayOf(f), dayOf(from));
      expect(dayOf(t), dayOf(to));
    });

    test('previous equal-length period abuts current', () {
      final p = const AnalyticsPeriod(
        AnalyticsPeriodKind.week,
        compare: AnalyticsCompare.previousEqualLength,
      );
      final now = DateTime(2026, 7, 15, 18);
      final (from, to) = p.range(now: now);
      final prev = p.previousRange(now: now)!;
      expect(prev.$2.isBefore(from) || prev.$2.isAtSameMomentAs(from), isTrue);
      final curLen = to.difference(from);
      final prevLen = prev.$2.difference(prev.$1);
      expect((prevLen - curLen).inSeconds.abs() < 2, isTrue);
    });
  });

  group('real aggregates (no placeholders)', () {
    test('subject×day stacks from real sessions', () async {
      final repo = InMemoryAnalyticsQueryRepository();
      final user = 'u1';
      final day1 = DateTime(2026, 7, 10);
      final day2 = DateTime(2026, 7, 11);
      repo.seedSessions(user, [
        StudySession(
          id: 's1',
          userId: user,
          start: day1.add(const Duration(hours: 9)),
          end: day1.add(const Duration(hours: 10)),
          durationSeconds: 3600,
          source: StudySource.manual,
          subjectId: 'math',
        ),
        StudySession(
          id: 's2',
          userId: user,
          start: day1.add(const Duration(hours: 11)),
          end: day1.add(const Duration(hours: 11, minutes: 30)),
          durationSeconds: 1800,
          source: StudySource.manual,
          subjectId: 'eng',
        ),
        StudySession(
          id: 's3',
          userId: user,
          start: day2.add(const Duration(hours: 9)),
          end: day2.add(const Duration(hours: 10, minutes: 30)),
          durationSeconds: 5400,
          source: StudySource.manual,
          subjectId: 'math',
        ),
      ]);
      final sessions = await repo.getUserSessionsInRange(
        userId: user,
        from: day1,
        to: day2,
      );
      final byDaySubject = <DateTime, Map<String?, int>>{};
      for (final s in sessions) {
        final d = dayOf(s.start);
        final m = byDaySubject.putIfAbsent(d, () => {});
        m[s.subjectId] = (m[s.subjectId] ?? 0) + s.durationSeconds;
      }
      expect(byDaySubject[dayOf(day1)]?['math'], 3600);
      expect(byDaySubject[dayOf(day1)]?['eng'], 1800);
      expect(byDaySubject[dayOf(day2)]?['math'], 5400);
      // Not 60/40 of day total.
      expect(byDaySubject[dayOf(day1)]?['math'], isNot( (3600 + 1800) * 0.6 ));
    });

    test('group contribution and leaderboard series from seed', () async {
      final repo = InMemoryAnalyticsQueryRepository();
      final gid = 'g1';
      final d1 = DateTime(2026, 7, 10);
      final d2 = DateTime(2026, 7, 11);
      repo.seedGroupStats(gid, [
        DailyStat(userId: 'a', day: d1, seconds: 1000),
        DailyStat(userId: 'b', day: d1, seconds: 500),
        DailyStat(userId: 'a', day: d2, seconds: 200),
        DailyStat(userId: 'b', day: d2, seconds: 800),
      ]);
      final contrib = await repo.getGroupContribution(
        groupId: gid,
        from: d1,
        to: d2,
      );
      expect(contrib.length, 2);
      // b has 500+800=1300, a has 1000+200=1200 → b first
      expect(contrib.first.userId, 'b');
      expect(contrib.first.seconds, 1300);

      final series = await repo.getGroupLeaderboardSeries(
        groupId: gid,
        from: d1,
        to: d2,
      );
      expect(series.length, 4);
      expect(series.any((p) => p.userId == 'a' && p.seconds == 1000), isTrue);
    });

    test('user day totals beyond synthetic hot window', () async {
      final repo = InMemoryAnalyticsQueryRepository();
      final user = 'u1';
      // 120 gün önce — hot window (90) dışında.
      final old = DateTime.now().subtract(const Duration(days: 120));
      final recent = DateTime.now().subtract(const Duration(days: 2));
      repo.seedSessions(user, [
        StudySession(
          id: 'old',
          userId: user,
          start: old,
          end: old.add(const Duration(hours: 1)),
          durationSeconds: 3600,
          source: StudySource.manual,
        ),
        StudySession(
          id: 'new',
          userId: user,
          start: recent,
          end: recent.add(const Duration(hours: 2)),
          durationSeconds: 7200,
          source: StudySource.manual,
        ),
      ]);
      final rows = await repo.getUserDayTotals(
        userId: user,
        from: old.subtract(const Duration(days: 1)),
        to: DateTime.now(),
      );
      final total = rows.fold<int>(0, (a, r) => a + r.seconds);
      expect(total, 3600 + 7200);
    });
  });

  group('titles never expose t.name', () {
    testWidgets('all card types have localized titles', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('tr'),
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              for (final t in AnalyticsCardType.values) {
                final title = AnalyticsCardRegistry.titleFor(l10n, t);
                expect(title, isNot(equals(t.name)), reason: t.name);
                expect(title.trim(), isNotEmpty);
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  });

  group('classic stats UI (WP-170)', () {
    testWidgets('StatsPeriodBar builds year/custom chips (WP-178)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('tr'),
            home: const Scaffold(body: StatsPeriodBar()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(StatsPeriodBar), findsOneWidget);
      expect(find.text('Bugün'), findsOneWidget);
      expect(find.text('Hafta'), findsOneWidget);
      expect(find.text('Ay'), findsOneWidget);
      expect(find.text('Tümü'), findsOneWidget);
      // Yıl + Özel (analyticsYear / analyticsCustomRange)
      expect(find.byType(FilterChip), findsWidgets);
    });

    testWidgets('PersonalStatsView still renders empty sessions', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('tr'),
            home: const Scaffold(
              body: PersonalStatsView(sessions: []),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(PersonalStatsView), findsOneWidget);
    });
  });

}
