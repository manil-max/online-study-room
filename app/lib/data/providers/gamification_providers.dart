import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/stats/achievement_engine.dart';
import '../../core/stats/gamification.dart';
import '../../core/stats/study_stats.dart';
import '../models/achievement.dart';
import '../models/gamification_profile.dart';
import '../models/study_session.dart';
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
      final repo = ref.watch(gamificationRepositoryProvider);
      return repo.watchProfile(userId);
    });

final userAchievementsProvider =
    StreamProvider.family<List<UserAchievement>, String>((ref, userId) {
      final repo = ref.watch(gamificationRepositoryProvider);
      return repo.watchUserAchievements(userId);
    });

/// Profil açıldığında mevcut oturumları kalıcı başarı ilerlemesine işler.
/// Hesaplama yalnızca değişiklik olduğunda yazar; stream güncellemelerinin
/// sonsuz bir yazma döngüsü oluşturmasını engeller.
final gamificationProgressSyncProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return;

  final sessions = await ref.watch(userSessionsProvider.future);
  final profile = await ref.watch(gamificationProfileProvider(user.id).future);
  final achievements = await ref.watch(
    userAchievementsProvider(user.id).future,
  );
  final result = AchievementEngine.calculateProgression(
    profile: profile,
    currentAchievements: achievements,
    allSessions: sessions,
  );
  final repository = ref.read(gamificationRepositoryProvider);
  final profileChanged =
      result.newProfile.xp != profile.xp ||
      result.newProfile.crownRank != profile.crownRank;

  // Profil satırı önce yazılır; eski kullanıcılar için de güvenli başlangıçtır.
  if (profileChanged || achievements.isEmpty) {
    await repository.updateProfile(result.newProfile);
  }
  if (result.newAchievements.isNotEmpty) {
    await repository.updateUserAchievements(result.newAchievements);
  }
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
    final profile = GamificationProfile.initial(user.id);
    final sessions = sessionsAsync.value;
    if (sessions == null) return const AsyncValue.loading();

    return AsyncValue.data(
      _buildGamificationSummary(
        profile: profile,
        sessions: sessions,
        goalSeconds: goalSeconds,
      ),
    );
  }
  final sessions = sessionsAsync.value;
  final profile = profileAsync.value;
  if (sessions == null || profile == null) {
    return const AsyncValue.loading();
  }

  return AsyncValue.data(
    _buildGamificationSummary(
      profile: profile,
      sessions: sessions,
      goalSeconds: goalSeconds,
    ),
  );
});

GamificationSummary _buildGamificationSummary({
  required GamificationProfile profile,
  required List<StudySession> sessions,
  required int goalSeconds,
}) {
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

  return GamificationSummary(
    profile: profile,
    freezeAwareStreak: freezeAwareStreak,
    achievements: achievements,
    crownTier: crownTierFor(achievements),
    totalSeconds: totalSeconds(sessions),
    sessionCount: sessions.length,
  );
}
