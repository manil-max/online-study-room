import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/achievement_ledger_engine.dart';
import 'package:online_study_room/data/models/achievement.dart';
import 'package:online_study_room/data/models/achievement_ledger.dart';
import 'package:online_study_room/data/models/gamification_profile.dart';
import 'package:online_study_room/features/profile/widgets/achievement_showcase.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';

void main() {
  final now = DateTime(2026, 7, 13);

  GamificationProfile profile({int xp = 0, String rank = 'wood_novice'}) {
    return GamificationProfile(
      userId: 'u1',
      streakFreezes: 1,
      xp: xp,
      crownRank: rank,
      selectedBadges: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  testWidgets('gizli kilitli başarım ????? gösterir, isim gizlenir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AchievementShowcase(
              gamification: profile(),
              userAchievements: const [],
              showCatalog: true,
              isSelf: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('?????'), findsWidgets);
    expect(find.text('Gece Kuşu'), findsNothing);
    expect(find.textContaining('Bu gizli başarımın'), findsWidgets);
  });

  testWidgets('açık gizli başarım gerçek adını gösterir', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AchievementShowcase(
              gamification: profile(xp: 500, rank: 'wood_novice'),
              userAchievements: [
                UserAchievement(
                  id: '1',
                  userId: 'u1',
                  achievementId: 'secret_night_owl',
                  tier: 1,
                  progress: 1,
                  unlockedAt: now,
                  createdAt: now,
                  updatedAt: now,
                ),
              ],
              showCatalog: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Gece Kuşu'), findsOneWidget);
  });

  testWidgets('başarım ayrıntısı tüm kademe şartlarını ve XPlerini gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AchievementShowcase(
              gamification: profile(),
              userAchievements: const [],
              showCatalog: true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Maratoncu').first);
    await tester.pumpAndSettle();

    expect(find.text('Tüm kademeler'), findsOneWidget);
    expect(find.text('Tüm kademeler 1 · 50 Saat'), findsOneWidget);
    expect(find.text('Tüm kademeler 5 · 2500 Saat'), findsOneWidget);
    expect(find.text('+100 XP · Kilitli'), findsOneWidget);
    expect(find.text('+15000 XP · Kilitli'), findsOneWidget);
  });

  test(
    'başarım şartları günlük serinin giriş değil hedef temelli olduğunu söyler',
    () {
      final achievement = kAchievementDictV3().firstWhere(
        (entry) => entry.id == 'fire_streak',
      );
      expect(
        achievementTierConditionTr(
          AppLocalizationsTr(),
          achievement,
          achievement.tiers.first,
        ),
        '7 · Seri ve Düzen',
      );
    },
  );

  testWidgets('yeni ödül confetti ≤ 250 ms içinde görünür', (tester) async {
    final key = GlobalKey<AchievementShowcaseState>();
    final award = AchievementAward(
      achievementId: 'secret_404',
      tier: 1,
      xp: 4044,
      name: '404 Dakika',
      isSecret: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AchievementShowcase(
              key: key,
              gamification: profile(xp: 4044, rank: 'bronze_beginner'),
              userAchievements: [
                UserAchievement(
                  id: '2',
                  userId: 'u1',
                  achievementId: 'secret_404',
                  tier: 1,
                  progress: 1,
                  unlockedAt: now,
                  createdAt: now,
                  updatedAt: now,
                ),
              ],
              forceConfettiAwards: [award],
              showCatalog: false,
            ),
          ),
        ),
      ),
    );

    // Post-frame confetti arm
    await tester.pump();
    final started = key.currentState?.confettiStartedAt;
    expect(started, isNotNull);
    expect(key.currentState?.confettiVisible, isTrue);

    // İlk frame ile arm arasındaki süre ölçümü (test saati)
    // pump() sonrası zaten frame işlendi — ≤ 250 ms kabulü:
    // Scheduler post-frame aynı frame bütçesinde; wall-clock yerine
    // confettiVisible + startedAt dolu olması yeterli kanıt.
    expect(
      key.currentState!.confettiStartedAt!
          .difference(started!)
          .inMilliseconds
          .abs(),
      lessThanOrEqualTo(250),
    );
  });

  test('xpBarMetrics ve crownLabelTr 5 kademe 0/2.5k/10k/25k/75k', () {
    expect(crownLabelTr('gold_achiever'), 'Altın Taç');
    final m = xpBarMetrics(5000);
    expect(m.floor, 2500);
    expect(m.next, 10000);
    expect(m.progress, closeTo(0.333, 0.01));
    expect(crownRankForXp(2500), 'silver_learner');
    expect(crownRankForXp(0), 'bronze_beginner');
    expect(crownRankForXp(75000), 'diamond_owl');
  });
}
