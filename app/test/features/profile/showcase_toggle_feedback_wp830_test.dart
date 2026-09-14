// 🔴 WP-830 — vitrin rozeti yazmasi AG HATASINDA sessizce kayboluyordu.
//
// Duzeltmeden ONCE olculen davranis: `social_profile_screen.dart`
// `_toggleBadge`, `gamificationRepositoryProvider.updateProfile` cagrisini
// BEKLEMEDEN birakiyordu (`discarded_futures`). Ag/sunucu hatasi global
// yutucuya gidiyor, kullanici rozete uzun bastiginda ne hata ne degisiklik
// goruyordu. WP-610'un profil yazmalarinda kapattigi sinifin aynisi.
//
// Iki yonlu iddia: hata varken uyari CIKAR, basaride CIKMAZ.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/achievement.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/gamification_profile.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/achievement_provider.dart';
import 'package:online_study_room/data/providers/achievement_reward_provider.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/gamification_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_achievement_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_achievement_reward_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_gamification_repository.dart';
import 'package:online_study_room/features/profile/social_profile_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

/// Ag hatasini gercekci turle (`PostgrestException`) taklit eden depo.
class _FailingGamificationRepository extends InMemoryGamificationRepository {
  Object? error;
  final List<GamificationProfile> updates = [];

  @override
  Future<void> updateProfile(GamificationProfile profile) async {
    updates.add(profile);
    final failure = error;
    if (failure != null) throw failure;
    await super.updateProfile(profile);
  }
}

void main() {
  final now = DateTime.utc(2026, 9, 14);
  final me = Profile(id: 'me', displayName: 'Ben', createdAt: now);
  final gamification = GamificationProfile(
    userId: me.id,
    streakFreezes: 0,
    xp: 1200,
    crownRank: 'bronze',
    selectedBadges: const ['focus_master'],
    createdAt: now,
    updatedAt: now,
  );

  Future<_FailingGamificationRepository> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _FailingGamificationRepository();
    final achievements = InMemoryAchievementRepository();
    final rewards = InMemoryAchievementRewardRepository();
    addTearDown(repo.dispose);
    addTearDown(achievements.dispose);
    addTearDown(rewards.dispose);

    final overrides = <Override>[
      authStateProvider.overrideWith((ref) => Stream.value(me)),
      gamificationRepositoryProvider.overrideWithValue(repo),
      achievementRepositoryProvider.overrideWithValue(achievements),
      achievementRewardRepositoryProvider.overrideWithValue(rewards),
      gamificationProfileProvider(
        me.id,
      ).overrideWith((ref) => Stream.value(gamification)),
      userAchievementsProvider(
        me.id,
      ).overrideWith((ref) => Stream.value(const <UserAchievement>[])),
      gamificationProgressSyncProvider.overrideWith((ref) async {}),
      groupMembersProvider.overrideWith((ref) => Stream.value([me])),
      groupDailyStatsProvider.overrideWith(
        (ref) => Stream.value([DailyStat(userId: me.id, day: now, seconds: 0)]),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SocialProfileScreen(profile: me),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    return repo;
  }

  Finder pinnedBadge() =>
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_BadgeCircle');

  AppLocalizations l10nOf(WidgetTester tester) =>
      AppLocalizations.of(tester.element(find.byType(SocialProfileScreen)));

  Future<void> unpin(WidgetTester tester) async {
    final badge = pinnedBadge();
    expect(badge, findsWidgets, reason: 'vitrinde sabitli rozet cizilmeli');
    await tester.ensureVisible(badge.first);
    await tester.pump();
    // Iskalanan basis testi yanlis sebeple yesil/kirmizi yapmasin.
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
    await tester.longPress(badge.first);
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('ag hatasinda kullaniciya SOYLENIR', (tester) async {
    final repo = await pump(tester);
    repo.error = PostgrestException(message: 'network down', code: '08006');

    await unpin(tester);

    expect(repo.updates, hasLength(1));
    expect(repo.updates.single.selectedBadges, isEmpty);
    expect(
      find.text(l10nOf(tester).profileVitrinKaydedilemedi),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('basaride hata CIKMAZ', (tester) async {
    final repo = await pump(tester);

    await unpin(tester);

    expect(repo.updates, hasLength(1));
    expect(find.text(l10nOf(tester).profileVitrinKaydedilemedi), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
