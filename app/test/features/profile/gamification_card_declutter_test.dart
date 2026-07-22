import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/stats/gamification.dart';
import 'package:online_study_room/core/stats/progression_visuals.dart';
import 'package:online_study_room/core/widgets/crowned_avatar.dart';
import 'package:online_study_room/data/models/achievement.dart';
import 'package:online_study_room/data/models/gamification_profile.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/gamification_providers.dart';
import 'package:online_study_room/features/profile/widgets/gamification_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-187/192: level/quest/streak yok; taç XP barı + CrownedAvatar var.
void main() {
  testWidgets('GamificationCard omits level quest streak; has crown XP bar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.utc(2026, 7, 18);

    final profile = Profile(id: 'u1', displayName: 'Test', createdAt: now);
    final gamification = GamificationProfile(
      userId: 'u1',
      streakFreezes: 2,
      xp: 1200,
      crownRank: 'gold_achiever',
      selectedBadges: const [],
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream.value(profile)),
          gamificationSummaryProvider.overrideWith((ref) {
            return AsyncValue.data(
              GamificationSummary(
                profile: gamification,
                freezeAwareStreak: const FreezeAwareStreak(
                  streak: 1,
                  freezesUsed: 0,
                  protectedDays: [],
                ),
                achievements: const [],
                crownTier: CrownTier.gold,
                totalSeconds: 3600,
                sessionCount: 3,
              ),
            );
          }),
          userAchievementsProvider.overrideWith(
            (ref, userId) => Stream.value(const []),
          ),
          gamificationProgressSyncProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(body: GamificationCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GamificationCard), findsOneWidget);
    expect(find.text('Achievements'), findsOneWidget);
    expect(find.byType(CrownedAvatar), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.textContaining('Next crown'), findsOneWidget);
    expect(find.textContaining('XP'), findsOneWidget);

    // Level/quest/streak hâlâ yok
    expect(find.textContaining('Level'), findsNothing);
    expect(find.text('Quests'), findsNothing);
    expect(find.textContaining('day streak'), findsNothing);
    expect(find.textContaining('streak freezes'), findsNothing);
  });

  testWidgets('unlocked secret showcase badge keeps the secret purple', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.utc(2026, 7, 18);
    final profile = Profile(id: 'u1', displayName: 'Test', createdAt: now);
    final gamification = GamificationProfile(
      userId: 'u1',
      streakFreezes: 1,
      xp: 500,
      crownRank: 'wood_novice',
      selectedBadges: const ['secret_night_owl'],
      createdAt: now,
      updatedAt: now,
    );
    final secret = UserAchievement(
      id: 'secret-achievement',
      userId: 'u1',
      achievementId: 'secret_night_owl',
      tier: 1,
      progress: 1,
      unlockedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream.value(profile)),
          gamificationSummaryProvider.overrideWith(
            (ref) => AsyncValue.data(
              GamificationSummary(
                profile: gamification,
                freezeAwareStreak: const FreezeAwareStreak(
                  streak: 0,
                  freezesUsed: 0,
                  protectedDays: [],
                ),
                achievements: const [],
                crownTier: CrownTier.none,
                totalSeconds: 0,
                sessionCount: 0,
              ),
            ),
          ),
          userAchievementsProvider.overrideWith(
            (ref, userId) => Stream.value([secret]),
          ),
          gamificationProgressSyncProvider.overrideWith((ref) async {}),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: const Scaffold(body: GamificationCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final badge = tester.widget<Container>(
      find.byKey(const ValueKey('profile_badge_secret_night_owl')),
    );
    final decoration = badge.decoration! as BoxDecoration;
    expect(decoration.border, isA<Border>());
    expect(
      (decoration.border! as Border).top.color,
      kSecretAchievementColor.withValues(alpha: 0.45),
    );
  });
}
