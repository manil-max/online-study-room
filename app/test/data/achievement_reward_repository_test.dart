import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/achievement_reward.dart';
import 'package:online_study_room/data/repositories/achievement_reward_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_achievement_reward_repository.dart';

AchievementReward _reward({
  required String id,
  required String userId,
  required DateTime createdAt,
  String achievementId = 'steel_will',
  int tier = 1,
  int xp = 50,
}) {
  return AchievementReward(
    id: id,
    userId: userId,
    achievementId: achievementId,
    tier: tier,
    xpAmount: xp,
    status: AchievementRewardStatus.pending,
    createdAt: createdAt,
  );
}

void main() {
  test('claim tek sefer XP verir; retry ikinci XP yazmaz', () async {
    final repo = InMemoryAchievementRewardRepository();
    addTearDown(repo.dispose);
    repo.seedPendingReward(
      _reward(id: 'r1', userId: 'u1', createdAt: DateTime.utc(2026, 7, 19)),
    );

    final first = await repo.claimReward(userId: 'u1', rewardId: 'r1');
    final retry = await repo.claimReward(userId: 'u1', rewardId: 'r1');

    expect(first.claimedCount, 1);
    expect(first.xpGranted, 50);
    expect(retry.claimedCount, 0);
    expect(retry.xpGranted, 0);
    expect(repo.claimedXp, 50);
  });

  test('başka kullanıcı reward claim edemez', () async {
    final repo = InMemoryAchievementRewardRepository();
    addTearDown(repo.dispose);
    repo.seedPendingReward(
      _reward(id: 'r1', userId: 'u1', createdAt: DateTime.utc(2026, 7, 19)),
    );

    final result = await repo.claimReward(userId: 'u2', rewardId: 'r1');

    expect(result.status, 'not_found');
    expect(repo.claimedXp, 0);
    expect((await repo.getPendingSummary(userId: 'u1')).pendingCount, 1);
  });

  test('claim-all 50 ile bounded ve kalan sayfa korunur', () async {
    // Sayfalama sınırı sözleşmesini izole etmek için her kayıt ayrı bir
    // achievement kimliği taşır; production'da bunlar sözlük FK'siyle doğrulanır.
    final uniqueRewards = [
      for (var i = 0; i < 101; i++)
        _reward(
          id: 'r${i.toString().padLeft(3, '0')}',
          userId: 'u1',
          createdAt: DateTime.utc(2026, 7, 19).add(Duration(minutes: i)),
          achievementId: 'achievement_$i',
          xp: 10,
        ),
    ];
    final repo = InMemoryAchievementRewardRepository(
      initialRewards: uniqueRewards,
    );
    addTearDown(repo.dispose);

    final firstPage = await repo.listPendingRewards(userId: 'u1', limit: 100);
    final claimed = await repo.claimAll(userId: 'u1');

    expect(firstPage.rewards, hasLength(100));
    expect(firstPage.nextCursor, isNotNull);
    expect(claimed.claimedCount, 50);
    expect(claimed.xpGranted, 500);
    expect((await repo.getPendingSummary(userId: 'u1')).pendingCount, 51);
  });

  test(
    'capability yalnız bilinen reward inbox sürümü için kaydedilir',
    () async {
      final repo = InMemoryAchievementRewardRepository();
      addTearDown(repo.dispose);

      await repo.recordCapability(
        userId: 'u1',
        capability: kRewardInboxCapability,
      );
      expect(
        () => repo.recordCapability(userId: 'u1', capability: 'forged'),
        throwsA(isA<AchievementRewardException>()),
      );
    },
  );
}
