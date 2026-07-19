import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/achievement_reward.dart';
import '../achievement_reward_repository.dart';

class SupabaseAchievementRewardRepository
    implements AchievementRewardRepository {
  SupabaseAchievementRewardRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<AchievementRewardPage> listPendingRewards({
    required String userId,
    int limit = kDefaultAchievementRewardPageSize,
    AchievementRewardCursor? cursor,
  }) async {
    _validatePageLimit(limit);
    // userId auth.uid() yerine gönderilmez; RPC'de oturumdan türetilir.
    final raw = await _client.rpc(
      'list_pending_achievement_rewards',
      params: {
        'p_limit': limit,
        'p_cursor_created_at': cursor?.createdAt.toUtc().toIso8601String(),
        'p_cursor_id': cursor?.id,
      },
    );
    final rewards = (raw as List)
        .map(
          (row) =>
              AchievementReward.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
    final nextCursor = rewards.length == limit && rewards.isNotEmpty
        ? AchievementRewardCursor(
            createdAt: rewards.last.createdAt,
            id: rewards.last.id,
          )
        : null;
    return AchievementRewardPage(rewards: rewards, nextCursor: nextCursor);
  }

  @override
  Future<AchievementRewardSummary> getPendingSummary({
    required String userId,
  }) async {
    final raw = await _client.rpc('pending_achievement_reward_summary');
    return AchievementRewardSummary.fromMap(
      Map<String, dynamic>.from(raw as Map),
    );
  }

  @override
  Future<AchievementRewardClaimResult> claimReward({
    required String userId,
    required String rewardId,
  }) async {
    final raw = await _client.rpc(
      'claim_achievement_reward',
      params: {'p_reward_id': rewardId},
    );
    return AchievementRewardClaimResult.fromSingleMap(
      Map<String, dynamic>.from(raw as Map),
    );
  }

  @override
  Future<AchievementRewardClaimResult> claimAll({
    required String userId,
    int limit = kDefaultAchievementRewardPageSize,
  }) async {
    if (limit < 1 || limit > kMaxClaimAllAchievementRewards) {
      throw const AchievementRewardException('Toplu ödül limiti geçersiz.');
    }
    final raw = await _client.rpc(
      'claim_all_achievement_rewards',
      params: {'p_limit': limit},
    );
    return AchievementRewardClaimResult.fromAllMap(
      Map<String, dynamic>.from(raw as Map),
    );
  }

  @override
  Future<void> recordCapability({
    required String userId,
    required String capability,
  }) async {
    if (capability != kRewardInboxCapability) {
      throw const AchievementRewardException('Bilinmeyen başarım özelliği.');
    }
    await _client.rpc(
      'record_achievement_capability',
      params: {'p_capability': capability},
    );
  }

  void _validatePageLimit(int limit) {
    if (limit < 1 || limit > kMaxAchievementRewardPageSize) {
      throw const AchievementRewardException('Ödül sayfa limiti geçersiz.');
    }
  }
}
