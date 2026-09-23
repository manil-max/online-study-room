import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
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
import 'package:online_study_room/features/stats/widgets/chart_axis.dart';
import 'package:online_study_room/features/stats/widgets/personal_stats_view.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_en.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-926: istatistikte birimler tutarlı.
///
/// 🔴 Kusur (UX denetimi `s08`–`s10`):
/// - "Seçili tarih aralığı" başlığı "83sa 52dk · **22d**" — gün birimi koda
///   İngilizce "d" olarak sabit yazılmıştı (`personal_stats_view.dart:466`).
/// - Grafik ekseni saati "6**s** / 4s / 2s" yazıyordu (`statsSaatKisa` = "s");
///   uygulamanın geri kalanı (`formatHuman`) "sa". Türkçede "s" saniye de
///   okunabilir.
/// - Eğilim grafiğinin tepesinde "6s" ile "6.1s" üst üste: üst sınır
///   (`veriMaks × 1.15`) aralığın katı değildi, fl_chart sınır için ikinci bir
///   etiket üretiyordu (WP-499'da çubuk/çizgi grafikte kapatılan hatanın
///   `AreaLineChart`taki eşi).

final _now = DateTime.utc(2026, 9, 23, 9); // 12:00 İstanbul
const _userId = 'u1';

void main() {
  final tr = AppLocalizationsTr();
  final en = AppLocalizationsEn();

  test('kısa saat birimi uygulamanın geri kalanıyla aynı: TR "sa", EN "h"', () {
    expect(tr.statsSaatKisa, 'sa');
    expect(en.statsSaatKisa, 'h');
    expect(tr.statsDakikaKisa, 'dk');
    expect(chartYLabel(120, tr, useHours: true), '2sa');
    expect(chartYLabel(90, tr, useHours: true), '1.5sa');
  });

  testWidgets('AreaLineChart: Y ekseninde tek tepe etiketi, çakışma yok', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 320,
              height: 140,
              child: AreaLineChart(
                // Denetimdeki seri: tepe ~5.3 saat → eski üst sınır 6.1.
                values: const [0, 1.2, 4.1, 5.3, 3.9, 4.6],
                labels: const ['1', '2', '3', '4', '5', '6'],
                yUnit: tr.statsSaatKisa,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final texts = <String>[];
    final rects = <Rect>[];
    for (final element in find.byType(Text).evaluate()) {
      final text = (element.widget as Text).data;
      if (text == null || !text.endsWith('sa')) continue;
      texts.add(text);
      rects.add(tester.getRect(find.byElementPredicate((e) => e == element)));
    }
    expect(texts, isNotEmpty);
    expect(
      texts.toSet(),
      hasLength(texts.length),
      reason: 'aynı etiket iki kez: $texts',
    );
    expect(
      texts.where((t) => t.contains('.')),
      isEmpty,
      reason: 'tepe etiketi aralığın katı değil: $texts',
    );
    for (var a = 0; a < rects.length; a++) {
      for (var b = a + 1; b < rects.length; b++) {
        final o = rects[a].intersect(rects[b]);
        expect(
          o.width > 0.5 && o.height > 0.5,
          isFalse,
          reason: '${texts[a]} ile ${texts[b]} üst üste',
        );
      }
    }
  });

  testWidgets('"Tümü" / Seçili tarih aralığı: gün sayısı yerelleştirilmiş '
      '("54 gün", "54d" değil)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // 1 Ağustos – 23 Eylül 2026 her gün 1 saat = 54 gün.
    final sessions = <StudySession>[];
    var i = 0;
    for (
      var d = DateTime(2026, 8, 1);
      !d.isAfter(DateTime(2026, 9, 23));
      d = DateTime(d.year, d.month, d.day + 1)
    ) {
      sessions.add(
        StudySession(
          id: 's${i++}',
          userId: _userId,
          subjectId: 'mat',
          start: DateTime.utc(d.year, d.month, d.day, 7),
          end: DateTime.utc(d.year, d.month, d.day, 8),
          durationSeconds: 3600,
          source: StudySource.manual,
          recordedDay: d,
        ),
      );
    }
    final repo = InMemoryAnalyticsQueryRepository(
      sessionSource: (_) async => sessions,
    );
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            Profile(id: _userId, displayName: 'T', createdAt: DateTime(2020)),
          ),
        ),
        userSessionsProvider.overrideWith((ref) => Stream.value(sessions)),
        userSubjectsProvider.overrideWith(
          (ref) => Stream.value(const <Subject>[
            Subject(id: 'mat', userId: _userId, name: 'Mat', color: 'chart-1'),
          ]),
        ),
        dailyGoalMinutesProvider.overrideWithValue(120),
        analyticsQueryRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);
    container.read(statsPeriodProvider.notifier).setPeriod(StatsPeriod.all);

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
            body: Consumer(
              builder: (context, ref, _) {
                ref.watch(authStateProvider);
                ref.watch(statsPeriodProvider);
                return PersonalStatsView(sessions: sessions, clock: () => _now);
              },
            ),
          ),
        ),
      ),
    );
    for (var k = 0; k < 5; k++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.scrollUntilVisible(
      find.textContaining('· 54 gün'),
      240,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 80,
    );
    expect(find.textContaining('· 54 gün'), findsOneWidget);
    expect(find.textContaining(RegExp(r'\d+d$')), findsNothing);
  });
}
