import '../models/achievement_reward.dart';

const kRewardInboxCapability = 'reward_inbox_v1';
const kDefaultAchievementRewardPageSize = 50;
const kMaxAchievementRewardPageSize = 100;
const kMaxClaimAllAchievementRewards = 50;

class AchievementRewardException implements Exception {
  const AchievementRewardException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Reward inbox yalnız server claim RPC'leriyle ledger'a yazar.
abstract class AchievementRewardRepository {
  Future<AchievementRewardPage> listPendingRewards({
    required String userId,
    int limit = kDefaultAchievementRewardPageSize,
    AchievementRewardCursor? cursor,
  });

  Future<AchievementRewardSummary> getPendingSummary({required String userId});

  Future<AchievementRewardClaimResult> claimReward({
    required String userId,
    required String rewardId,
  });

  Future<AchievementRewardClaimResult> claimAll({
    required String userId,
    int limit = kDefaultAchievementRewardPageSize,
  });

  /// Capability yalnız rollout/UX sinyalidir; XP yetkisi değildir.
  Future<void> recordCapability({
    required String userId,
    required String capability,
  });
}
