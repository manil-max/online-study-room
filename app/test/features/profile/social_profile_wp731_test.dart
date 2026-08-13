import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/achievement.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/profile/widgets/achievement_showcase.dart';
import 'package:online_study_room/features/profile/widgets/profile_stats_panel.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

Widget _app(Widget child, {List<Override> overrides = const []}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

UserAchievement _earnedTitle() {
  final now = DateTime(2026, 8, 13);
  return UserAchievement(
    id: 'earned-marathon',
    userId: 'other',
    achievementId: 'marathon_total',
    tier: 1,
    progress: 1,
    unlockedAt: now,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  testWidgets('başkasının güncel hedef serisi rekor seriden ayrı gösterilir', (
    tester,
  ) async {
    final today = DateTime.now();
    final day = DateTime(today.year, today.month, today.day);
    final member = Profile(
      id: 'other',
      displayName: 'Komşu',
      createdAt: DateTime(2026),
      dailyGoalMinutes: 60,
    );
    final stats = <DailyStat>[
      // Güncel seri: bugünle biten dört gün.
      for (var offset = 0; offset < 4; offset++)
        DailyStat(
          userId: member.id,
          day: day.subtract(Duration(days: offset)),
          seconds: 90 * 60,
        ),
      // Rekor seri: daha eski ve güncel seriden ayrı beş gün.
      for (var offset = 8; offset < 13; offset++)
        DailyStat(
          userId: member.id,
          day: day.subtract(Duration(days: offset)),
          seconds: 90 * 60,
        ),
    ];

    await tester.pumpWidget(
      _app(
        ProfileStatsPanel(userId: 'other', isSelf: false, clock: () => day),
        overrides: [
          groupMembersProvider.overrideWith((ref) => Stream.value([member])),
          groupDailyStatsProvider.overrideWith((ref) => Stream.value(stats)),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Günlük seri'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const Key('profile-stat-goal-streak')))
          .data,
      '4 gün',
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('profile-stat-record-streak')))
          .data,
      '5 gün',
    );
    expect(
      find.byKey(const Key('profile-stat-streak-unavailable')),
      findsNothing,
    );
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('ünvan $width dp ekranda uzun adın hemen altına sarılır', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: width,
            child: ProfileIdentityHeading(
              displayName: 'Çok Uzun Bir Kullanıcı Adı ve Soyadı',
              userAchievements: [_earnedTitle()],
              titleAchievementId: 'marathon_total',
            ),
          ),
        ),
      );

      final name = tester.getRect(
        find.byKey(const Key('social-profile-display-name')),
      );
      final title = tester.getRect(
        find.byKey(const ValueKey('profile-title-chip')),
      );
      expect(title.top, greaterThanOrEqualTo(name.bottom));
      expect(title.center.dx, closeTo(name.center.dx, 1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('ünvan 412 dp ekranda kısa adın sağında kalır', (tester) async {
    await tester.pumpWidget(
      _app(
        SizedBox(
          width: 412,
          child: ProfileIdentityHeading(
            displayName: 'Ada',
            userAchievements: [_earnedTitle()],
            titleAchievementId: 'marathon_total',
          ),
        ),
      ),
    );

    final name = tester.getRect(
      find.byKey(const Key('social-profile-display-name')),
    );
    final title = tester.getRect(
      find.byKey(const ValueKey('profile-title-chip')),
    );
    expect(title.left, greaterThan(name.right));
    expect(title.center.dy, closeTo(name.center.dy, 2));
    expect(tester.takeException(), isNull);
  });
}
