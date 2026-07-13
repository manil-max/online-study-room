import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/achievement_ledger_engine.dart';
import 'package:online_study_room/data/models/gamification_profile.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_achievement_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_gamification_repository.dart';

/// WP-56 wire-up senaryosu (Riverpod olmadan): ledger → cüzdan projeksiyonu.
void main() {
  test('oturum sonrası ledger XP yazar; ikinci çağrı çift XP vermez; cüzdan yansır',
      () async {
    final achievementRepo = InMemoryAchievementRepository();
    final gamRepo = InMemoryGamificationRepository();
    const userId = 'u-wire';

    final sessions = [
      StudySession(
        id: 's1',
        userId: userId,
        start: DateTime.utc(2026, 6, 1, 10),
        end: DateTime.utc(2026, 6, 1, 12),
        durationSeconds: 120 * 60,
        source: StudySource.live,
      ),
    ];

    final first = await achievementRepo.processEvent(
      eventType: 'session_completed',
      sessions: sessions,
      dailyGoalMinutes: 360,
      userId: userId,
    );
    expect(first.awarded, isNotEmpty);
    expect(first.totalXp, greaterThan(0));

    // Wire-up: motor çıktısını cüzdana uygula (istemci kural hesaplamaz).
    final now = DateTime.now();
    await gamRepo.updateProfile(
      GamificationProfile(
        userId: userId,
        streakFreezes: 1,
        xp: first.totalXp,
        crownRank: first.crownRank,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final second = await achievementRepo.processEvent(
      eventType: 'session_completed',
      sessions: sessions,
      dailyGoalMinutes: 360,
      userId: userId,
    );
    expect(second.awarded, isEmpty);
    expect(second.totalXp, first.totalXp);

    final profile = await gamRepo.watchProfile(userId).first;
    expect(profile.xp, first.totalXp);
    expect(profile.crownRank, first.crownRank);
    expect(profile.crownRank, crownRankForXp(first.totalXp));
  });
}
