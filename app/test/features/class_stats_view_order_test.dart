import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/features/stats/charts/gauge_chart.dart';
import 'package:online_study_room/features/stats/widgets/class_stats_view.dart';

Profile _profile(String id, String name) =>
    Profile(id: id, displayName: name, createdAt: DateTime(2026, 1, 1));

void main() {
  testWidgets('ClassStatsView WP-191: sıralama en üstte, sonra hedef/özet',
      (tester) async {
    tester.view.physicalSize = const Size(2400, 9000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final members = [_profile('u1', 'Ada'), _profile('u2', 'Bora')];
    final stats = [
      DailyStat(userId: 'u1', day: today, seconds: 3600),
      DailyStat(userId: 'u2', day: today, seconds: 1800),
      DailyStat(userId: 'u1', day: yesterday, seconds: 2400),
    ];

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ClassStatsView(
              stats: stats,
              members: members,
              currentUserId: 'u1',
              groupName: 'Test Grubu',
              groupGoalMinutes: 120,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    double topOf(String text) => tester.getTopLeft(find.text(text).first).dy;

    // WP-203 sıra: sıralama → hedef gauge (tek) → özet → grup eğilimi →
    // all time → karşılaştırma. (Mükerrer hedef kartı ve bar trend kaldırıldı.)
    final ranking = topOf('Sıralama');
    final goal = tester.getTopLeft(find.byType(GaugeChart)).dy;
    final summary = topOf('Kişi başı ort.');
    final longTrend = topOf('Grup eğilimi (son 30 gün) · 7 gün · Hafta');
    final allTime = topOf('Tüm zamanlar');
    final comparison = topOf('Karşılaştırma tablosu');

    expect(ranking < goal, isTrue, reason: 'sıralama hedefin üstünde');
    expect(goal < summary, isTrue, reason: 'hedef özetin üstünde');
    expect(summary < longTrend, isTrue, reason: 'özet trendin üstünde');
    expect(longTrend < allTime, isTrue);
    expect(allTime < comparison, isTrue);

    expect(find.textContaining('(sen)'), findsWidgets);
    expect(find.text('Bora'), findsWidgets);
  });
}
