import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/stats_period.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/stats_period_provider.dart';
import 'package:online_study_room/features/stats/charts/gauge_chart.dart';
import 'package:online_study_room/features/stats/widgets/class_stats_view.dart';
import 'package:online_study_room/features/stats/widgets/daily_line_chart.dart';

Profile _profile(String id, String name) =>
    Profile(id: id, displayName: name, createdAt: DateTime(2026, 1, 1));

void main() {
  // WP-746: dikey sira artik DONEME baglidir (hedef gostergesi yalniz "Gun"de,
  // liderlik gecmisi/egilim/tum zamanlar yalniz cok gunlu donemlerde). Bu
  // yuzden test tek bir sira degil, iki donemin sirasini olcer. Sabit saat
  // enjekte edilir; aksi halde gun siniri testin sonucunu degistirir.
  final now = DateTime(2026, 8, 20, 14);
  final today = DateTime(2026, 8, 20);
  final yesterday = DateTime(2026, 8, 19);

  final members = [_profile('u1', 'Ada'), _profile('u2', 'Bora')];
  final stats = [
    DailyStat(userId: 'u1', day: today, seconds: 3600),
    DailyStat(userId: 'u2', day: today, seconds: 1800),
    DailyStat(userId: 'u1', day: yesterday, seconds: 2400),
  ];

  Future<ProviderContainer> pump(
    WidgetTester tester,
    StatsPeriod period,
  ) async {
    tester.view.physicalSize = const Size(2400, 12000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final container = ProviderContainer();
    addTearDown(container.dispose);
    // 🔴 Riverpod 3: dinleyicisiz provider her `read`de yeniden dogar.
    container.listen(statsPeriodProvider, (_, _) {});
    container.read(statsPeriodProvider.notifier).setPeriod(period);

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
              groupGoalMinutes: 120,
              clock: () => now,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    return container;
  }

  testWidgets('ClassStatsView WP-191/746 Gun: sıralama en üstte, sonra hedef', (
    tester,
  ) async {
    await pump(tester, StatsPeriod.day);

    double topOf(Finder f) => tester.getTopLeft(f.first).dy;

    final ranking = topOf(find.text('Sıralama'));
    final goal = topOf(find.byType(GaugeChart));
    final summary = topOf(find.text('Kişi başı ort.'));
    final donut = topOf(find.text('Üye katkı payı'));

    expect(ranking < goal, isTrue, reason: 'sıralama hedefin üstünde');
    expect(goal < summary, isTrue, reason: 'hedef özetin üstünde');
    expect(summary < donut, isTrue, reason: 'özet katkı payının üstünde');

    expect(find.textContaining('(sen)'), findsWidgets);
    expect(find.text('Bora'), findsWidgets);
  });

  testWidgets('ClassStatsView WP-746 Tümü: sıra sıralama → özet → katkı → '
      'geçmiş → eğilim → tüm zamanlar', (tester) async {
    await pump(tester, StatsPeriod.all);

    double topOf(Finder f) => tester.getTopLeft(f.first).dy;

    final ranking = topOf(find.text('Sıralama'));
    final summary = topOf(find.text('Kişi başı ort.'));
    final donut = topOf(find.text('Üye katkı payı'));
    final history = topOf(find.text('Liderlik geçmişi'));
    final trend = topOf(find.byType(DailyLineChart));
    final allTime = topOf(find.text('Tüm zamanlar'));

    expect(ranking < summary, isTrue);
    expect(summary < donut, isTrue);
    expect(donut < history, isTrue);
    expect(history < trend, isTrue);
    expect(trend < allTime, isTrue);

    // 🔴 WP-746: başlık eskiden üç şeyi aynı anda iddia ediyordu —
    // 'Grup eğilimi (son 30 gün) · 7 gün · Hafta'. Pencerenin uzunluğu tek
    // sayıdır.
    expect(find.text('Grup günlük trendi · 30 gün'), findsOneWidget);

    // Hedef göstergesi çok günlü dönemde çizilmez.
    expect(find.byType(GaugeChart), findsNothing);
  });
}
