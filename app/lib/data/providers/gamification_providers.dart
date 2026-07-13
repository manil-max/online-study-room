import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/stats/gamification.dart';
import '../../core/stats/study_stats.dart';
import '../models/achievement.dart';
import '../models/achievement_ledger.dart';
import '../models/gamification_profile.dart';
import '../models/study_session.dart';
import '../repositories/gamification_repository.dart';
import '../repositories/in_memory/in_memory_gamification_repository.dart';
import '../repositories/supabase/supabase_gamification_repository.dart';
import 'achievement_provider.dart';
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

/// WP-56 kapanış: başarı ilerlemesi **server-authoritative**.
///
/// - İstemci XP/tier hesaplayıp yazmaz.
/// - `process_achievement_event` (Supabase RPC) veya in_memory ledger.
/// - Aynı `event_key` ikinci kez XP vermez.
/// - Tetik: oturum listesi değişince / profil-başarım ekranı bu provider'ı izleyince.
///
/// [userSessionsProvider] yalnız **okunur** (Claude SAHİP study_providers — yazılmaz).
final gamificationProgressSyncProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return;

  // Oturumlar değişince yeniden değerlendir (idempotent). Değer in_memory
  // processEvent içinde ayrıca okunur; burada yalnız bağımlılık için await.
  await ref.watch(userSessionsProvider.future);

  final process = ref.read(processAchievementEventProvider);
  final result = await process(eventType: 'session_completed');

  // WP-57 polish: yeni ödüller confetti için state'e yazılır.
  if (result.awarded.isNotEmpty) {
    ref.read(lastAchievementAwardsProvider.notifier).setAwards(
          List.of(result.awarded),
        );
  }

  // Supabase: ledger trigger gamification_profiles + user_achievements günceller.
  // Offline/demo: ledger sonucunu yerel cüzdana yansıt (yine motor çıktısı; istemci kuralı yok).
  if (!SupabaseConfig.isConfigured) {
    await _applyInMemoryLedgerProjection(
      ref: ref,
      userId: user.id,
      totalXp: result.totalXp,
      crownRank: result.crownRank,
      awarded: result.awarded
          .map(
            (a) => (
              achievementId: a.achievementId,
              tier: a.tier,
            ),
          )
          .toList(),
    );
  }
});

/// Son process_achievement_event ile kazanılan rozetler (confetti / snack).
class LastAchievementAwards extends Notifier<List<AchievementAward>> {
  @override
  List<AchievementAward> build() => const [];

  void setAwards(List<AchievementAward> awards) => state = awards;

  void clear() => state = const [];
}

final lastAchievementAwardsProvider =
    NotifierProvider<LastAchievementAwards, List<AchievementAward>>(
      LastAchievementAwards.new,
    );

/// In-memory demo için ledger → gamification cüzdanı projeksiyonu.
Future<void> _applyInMemoryLedgerProjection({
  required Ref ref,
  required String userId,
  required int totalXp,
  required String crownRank,
  required List<({String achievementId, int tier})> awarded,
}) async {
  final gamRepo = ref.read(gamificationRepositoryProvider);
  final profile = await ref.read(gamificationProfileProvider(userId).future);

  if (profile.xp != totalXp || profile.crownRank != crownRank) {
    await gamRepo.updateProfile(
      profile.copyWith(xp: totalXp, crownRank: crownRank),
    );
  }

  if (awarded.isEmpty) return;

  final now = DateTime.now();
  await gamRepo.updateUserAchievements([
    for (final a in awarded)
      UserAchievement(
        id: '',
        userId: userId,
        achievementId: a.achievementId,
        tier: a.tier,
        progress: a.tier,
        unlockedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
  ]);
}

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
