import 'dart:async';

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
import 'achievement_reward_provider.dart';
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

/// WP-56 + WP-105: başarı ilerlemesi **server-authoritative**.
///
/// - İstemci XP/tier hesaplayıp yazmaz.
/// - `process_achievement_event` (Supabase RPC) veya in_memory ledger.
/// - Aynı `event_key` ikinci kez XP vermez.
/// - **WP-105:** Kabuk-ömürlü [achievementProgressLifecycleProvider] oturum
///   listesi değişince debounce ile tetikler (profil ekranı gerekmez).
/// - Profil vitrini hâlâ bu provider'ı izleyebilir (confetti / anlık yenileme).
///
/// [userSessionsProvider] yalnız **okunur**.
final gamificationProgressSyncProvider = FutureProvider.autoDispose<void>((
  ref,
) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return;

  await ref.watch(userSessionsProvider.future);
  await runAchievementSessionCompletedSync(ref);
});

/// Oturum tamamlandı olayı: RPC + confetti + (demo) cüzdan projeksiyonu.
///
/// WP-105: lifecycle ve profil sync aynı yolu kullanır; mükerrer çağrı
/// sunucu `event_key` ile idempotent.
Future<AchievementEventResult?> runAchievementSessionCompletedSync(Ref ref) async {
  final user = ref.read(authStateProvider).value;
  if (user == null) return null;

  // WP-176: process başarılıysa sonucu yutma — yan etki (confetti/projeksiyon)
  // hata verse bile event sonucu döner (test + sayaç akışı).
  final AchievementEventResult result;
  try {
    final process = ref.read(processAchievementEventProvider);
    result = await process(eventType: 'session_completed');
  } catch (_) {
    // Çevrimdışı / kimlik hazır değil: sessiz geç (sayaç akışını bozma).
    return null;
  }

  try {
    if (result.awarded.isNotEmpty) {
      ref.read(lastAchievementAwardsProvider.notifier).setAwards(
            List.of(result.awarded),
          );
    }

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
  } catch (_) {
    // Yan etki başarısız; process sonucu yine de geçerli.
  }
  return result;
}

/// WP-105: HomeShell ömrü boyunca oturum listesini dinler; profil açılmadan
/// `session_completed` fırlatır. Debounce + count/sum coalesce RPC spam'ini keser.
class AchievementProgressLifecycle {
  AchievementProgressLifecycle(this._ref);

  final Ref _ref;
  Timer? _debounce;
  ProviderSubscription<AsyncValue<List<StudySession>>>? _sessionsSub;
  bool _started = false;
  int? _lastCount;
  int? _lastSum;

  void start() {
    if (_started) return;
    _started = true;
    _sessionsSub = _ref.listen(
      userSessionsProvider,
      (prev, next) {
        final sessions = next.asData?.value;
        if (sessions == null) return;
        final count = sessions.length;
        final sum = sessions.fold<int>(0, (a, s) => a + s.durationSeconds);
        if (_lastCount == count && _lastSum == sum) return;
        _lastCount = count;
        _lastSum = sum;
        _schedule();
      },
      fireImmediately: true,
    );
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () async {
      await runAchievementSessionCompletedSync(_ref);
      // Olay bazlı ödül yenileme (poll yerine, beta-v41 WP-G): oturum bitince
      // yeni pending candidate'lar banner/badge'e yansısın; sürekli 4 sn poll yok.
      _ref.invalidate(pendingAchievementRewardSummaryProvider);
      _ref.invalidate(pendingAchievementRewardsProvider);
    });
  }

  void dispose() {
    _debounce?.cancel();
    _debounce = null;
    _sessionsSub?.close();
    _sessionsSub = null;
    _started = false;
  }
}

/// Kabukta `ref.watch` ile diri tutulur (presence lifecycle gibi).
final achievementProgressLifecycleProvider =
    Provider<AchievementProgressLifecycle>((ref) {
  final life = AchievementProgressLifecycle(ref)..start();
  ref.onDispose(life.dispose);
  return life;
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
