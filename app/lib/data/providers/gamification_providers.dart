import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/stats/gamification.dart';
import '../../core/stats/study_stats.dart';
import '../models/gamification_profile.dart';
import '../repositories/gamification_repository.dart';
import '../repositories/in_memory/in_memory_gamification_repository.dart';
import '../repositories/supabase/supabase_gamification_repository.dart';
import 'auth_providers.dart';
import 'study_providers.dart';

final gamificationRepositoryProvider = Provider<GamificationRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseGamificationRepository(Supabase.instance.client);
  }
  final repo = InMemoryGamificationRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final gamificationProfileProvider =
    StreamProvider.family<GamificationProfile, String>((ref, userId) {
      return ref.watch(gamificationRepositoryProvider).watchProfile(userId);
    });

class GamificationSummary {
  const GamificationSummary({
    required this.profile,
    required this.freezeAwareStreak,
    required this.achievements,
    required this.crownTier,
    required this.totalSeconds,
    required this.sessionCount,
  });

  final GamificationProfile profile;
  final FreezeAwareStreak freezeAwareStreak;
  final List<AchievementStatus> achievements;
  final CrownTier crownTier;
  final int totalSeconds;
  final int sessionCount;

  int get unlockedAchievementCount =>
      achievements.where((a) => a.unlocked).length;
}

final gamificationSummaryProvider = Provider<AsyncValue<GamificationSummary?>>((
  ref,
) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const AsyncValue.data(null);

  final sessionsAsync = ref.watch(userSessionsProvider);
  final profileAsync = ref.watch(gamificationProfileProvider(user.id));
  final goalSeconds = ref.watch(dailyGoalMinutesProvider) * 60;

  if (sessionsAsync.hasError) {
    return AsyncValue.error(
      sessionsAsync.error!,
      sessionsAsync.stackTrace ?? StackTrace.current,
    );
  }
  if (profileAsync.hasError) {
    return AsyncValue.error(
      profileAsync.error!,
      profileAsync.stackTrace ?? StackTrace.current,
    );
  }
  final sessions = sessionsAsync.value;
  final profile = profileAsync.value;
  if (sessions == null || profile == null) {
    return const AsyncValue.loading();
  }

  final totals = dailyTotals(sessions);
  final freezeAwareStreak = currentStreakWithFreezes(
    totals: totals,
    goalSeconds: goalSeconds,
    availableFreezes: profile.streakFreezes,
  );
  final achievements = achievementsFor(
    sessionCount: sessions.length,
    totalSeconds: totalSeconds(sessions),
    streak: freezeAwareStreak.streak,
  );

  return AsyncValue.data(
    GamificationSummary(
      profile: profile,
      freezeAwareStreak: freezeAwareStreak,
      achievements: achievements,
      crownTier: crownTierFor(achievements),
      totalSeconds: totalSeconds(sessions),
      sessionCount: sessions.length,
    ),
  );
});
