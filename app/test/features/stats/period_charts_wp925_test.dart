import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/stats/stats_period.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/stats_period_provider.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/stats/charts/area_line_chart.dart';
import 'package:online_study_room/features/stats/widgets/daily_bar_chart.dart';
import 'package:online_study_room/features/stats/widgets/period_chart_window.dart';
import 'package:online_study_room/features/stats/widgets/personal_period_cards.dart';
import 'package:online_study_room/features/stats/widgets/personal_stats_view.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-925: grafikler seçili dönemi çizer.
///
/// 🔴 Kusur (UX denetimi `s07`–`s10`, saat 23 Eylül 2026 Çarşamba):
/// - "Bu hafta" başlığı 21–27 Eyl derken "Günlük dağılım" 17–23 Eyl çiziyordu
///   (bugünde biten kayan 7 gün, takvim haftası değil).
/// - "Bu ay"da grafikler 25/8–23/9 çiziyordu.
/// - "Yıl"/"Tümü"de "Eğilim grafiği" son 30 günü çiziyordu.
///
/// Saat ENJEKTE edilir (`PersonalStatsView.clock`); gerçek saat okunmaz.
/// 23 Eylül 2026 12:00 İstanbul = 09:00 UTC.
final _now = DateTime.utc(2026, 9, 23, 9);

const _userId = 'u1';

const _subjects = <Subject>[
  Subject(id: 'mat', userId: _userId, name: 'Matematik', color: 'chart-1'),
];

/// 1 Ağustos – 23 Eylül her gün 1 saat (gün anahtarı takvim aritmetiğiyle).
List<StudySession> _sessions() {
  final out = <StudySession>[];
  var i = 0;
  for (
    var d = DateTime(2026, 8, 1);
    !d.isAfter(DateTime(2026, 9, 23));
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    out.add(
      StudySession(
        id: 's${i++}',
        userId: _userId,
        subjectId: 'mat',
        // 10:00 İstanbul = 07:00 UTC; cihaz saat diliminden bağımsız an.
        start: DateTime.utc(d.year, d.month, d.day, 7),
        end: DateTime.utc(d.year, d.month, d.day, 8),
        durationSeconds: 3600,
        source: StudySource.manual,
        recordedDay: d,
      ),
    );
  }
  return out;
}

Future<void> _pump(WidgetTester tester, StatsPeriod period) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      userSubjectsProvider.overrideWith((ref) => Stream.value(_subjects)),
      dailyGoalMinutesProvider.overrideWithValue(120),
    ],
  );
  addTearDown(container.dispose);
  container.read(statsPeriodProvider.notifier).setPeriod(period);

  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 2400);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: _Keep(
            child: PersonalStatsView(sessions: _sessions(), clock: () => _now),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// `statsPeriodProvider`i canlı tutar (Riverpod 3: dinleyicisiz provider her
/// `read`de yeniden kurulur).
class _Keep extends ConsumerWidget {
  const _Keep({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(statsPeriodProvider);
    return child;
  }
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 80,
  );
  await tester.pump();
}

void main() {
  testWidgets('"Bu hafta": Günlük dağılım başlıktaki takvim haftasını çizer '
      '(21–27 Eyl), kayan 7 günü değil', (tester) async {
    await _pump(tester, StatsPeriod.week);
    await _scrollTo(tester, find.byType(DailyBarChart));
    final days = tester.widget<DailyBarChart>(find.byType(DailyBarChart)).days;

    expect(days.first.day, DateTime(2026, 9, 21), reason: 'Pazartesi değil');
    expect(days.last.day, DateTime(2026, 9, 27), reason: 'Pazar değil');
    expect(days, hasLength(7));
    // Toplam kartıyla aynı veri: 21–23 çalışıldı, 24–27 henüz gelmedi.
    expect(days.fold<int>(0, (s, d) => s + d.seconds), 3 * 3600);
    expect(
      [for (final d in days.skip(3)) d.seconds],
      everyElement(0),
      reason: 'gelecek günler boş çubuk olmalı',
    );
  });

  testWidgets('"Bu ay": Günlük dağılım 1–30 Eyl, eğilim 1–23 Eyl (ağustos '
      'yok)', (tester) async {
    await _pump(tester, StatsPeriod.month);
    await _scrollTo(tester, find.byType(DailyBarChart));
    final days = tester.widget<DailyBarChart>(find.byType(DailyBarChart)).days;
    expect(days.first.day, DateTime(2026, 9, 1));
    expect(days.last.day, DateTime(2026, 9, 30));

    await _scrollTo(tester, find.byType(AreaLineChart));
    final trend = tester.widget<AreaLineChart>(find.byType(AreaLineChart));
    expect(trend.values, hasLength(23), reason: '1–23 Eylül günlük');
    expect(trend.labels.first, '1/9');
    expect(trend.labels.last, '23/9');
    expect(find.text('Günlük toplam'), findsOneWidget);
  });

  group('saf model (saat enjekte)', () {
    test('dönem takvim sonu: hafta Pazar, ay son gün, yıl 31 Aralık', () {
      DateTime end(StatsPeriod p, {int offset = 0}) => periodCalendarEnd(
        StatsPeriodSelection(period: p, offset: offset),
        now: _now,
      );
      expect(end(StatsPeriod.week), DateTime(2026, 9, 27));
      expect(end(StatsPeriod.week, offset: -1), DateTime(2026, 9, 20));
      expect(end(StatsPeriod.month), DateTime(2026, 9, 30));
      expect(end(StatsPeriod.month, offset: -7), DateTime(2026, 2, 28));
      expect(end(StatsPeriod.year), DateTime(2026, 12, 31));
      expect(end(StatsPeriod.day), DateTime(2026, 9, 23));
    });

    test('Yıl: eğilim HAFTALIK, yılın ilk gününden bugüne; önceki yıl '
        'sızmaz', () {
      final totals = <DateTime, int>{
        DateTime(2025, 12, 29): 7200, // önceki yıl, aynı ISO haftası
        DateTime(2026, 1, 1): 3600,
        DateTime(2026, 1, 4): 1800, // Pazar, ilk hafta
        DateTime(2026, 1, 5): 600, // ikinci hafta
        DateTime(2026, 9, 23): 900,
        DateTime(2026, 9, 24): 999, // gelecek
      };
      final trend = periodTrend(
        cardSet: PersonalCardSet.year,
        periodFrom: DateTime(2026, 1, 1),
        periodEnd: DateTime(2026, 12, 31),
        today: DateTime(2026, 9, 23),
        totals: totals,
      );
      expect(trend.bucket, TrendBucket.week);
      // 29 Ara 2025 haftasından 21 Eyl 2026 haftasına: 39 hafta.
      expect(trend.points, hasLength(39));
      expect(trend.points.first.start, DateTime(2025, 12, 29));
      expect(trend.points.first.seconds, 3600 + 1800);
      expect(trend.points[1].seconds, 600);
      expect(trend.points.last.start, DateTime(2026, 9, 21));
      expect(trend.points.last.seconds, 900);
    });

    test('Tümü: ilk kayıtlı aydan bugüne AYLIK', () {
      final totals = <DateTime, int>{
        DateTime(2025, 11, 20): 3600,
        DateTime(2026, 2, 3): 1200,
        DateTime(2026, 2, 27): 1200,
        DateTime(2026, 9, 1): 60,
      };
      final trend = periodTrend(
        cardSet: PersonalCardSet.all,
        periodFrom: DateTime(2000),
        periodEnd: DateTime(2026, 9, 23),
        today: DateTime(2026, 9, 23),
        totals: totals,
      );
      expect(trend.bucket, TrendBucket.month);
      expect(trend.points, hasLength(11)); // Kas 2025 – Eyl 2026
      expect(trend.points.first.start, DateTime(2025, 11, 1));
      expect(trend.points[3].start, DateTime(2026, 2, 1));
      expect(trend.points[3].seconds, 2400);
      expect(trend.points.last.seconds, 60);
    });

    test('Tümü: 3 aydan kısa geçmiş haftalık çizilir (tek nokta değil)', () {
      final trend = periodTrend(
        cardSet: PersonalCardSet.all,
        periodFrom: DateTime(2000),
        periodEnd: DateTime(2026, 9, 23),
        today: DateTime(2026, 9, 23),
        totals: {DateTime(2026, 9, 2): 3600, DateTime(2026, 9, 23): 60},
      );
      expect(trend.bucket, TrendBucket.week);
      expect(trend.points.first.start, DateTime(2026, 8, 31));
      expect(trend.points, hasLength(4));
    });
  });
}
