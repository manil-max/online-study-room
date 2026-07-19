import 'dart:async';

import '../../models/achievement_reward.dart';
import '../achievement_reward_repository.dart';

/// Offline/demo eşdeğeri. XP yazımı burada yalnız test edilebilir claim sonucu
/// olarak tutulur; üretimde tek otorite Supabase RPC + xp_ledger'dır.
class InMemoryAchievementRewardRepository
    implements AchievementRewardRepository {
  InMemoryAchievementRewardRepository({
    Iterable<AchievementReward> initialRewards = const [],
  }) : _rewards = {for (final reward in initialRewards) reward.id: reward};

  final Map<String, AchievementReward> _rewards;
  final Set<String> _claimedEventKeys = <String>{};
  final Set<String> _capabilities = <String>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();
  int _claimedXp = 0;

  int get claimedXp => _claimedXp;

  @override
  Future<AchievementRewardPage> listPendingRewards({
    required String userId,
    int limit = kDefaultAchievementRewardPageSize,
    AchievementRewardCursor? cursor,
  }) async {
    if (limit < 1 || limit > kMaxAchievementRewardPageSize) {
      throw const AchievementRewardException('Ödül sayfa limiti geçersiz.');
    }
    final rewards = _pendingFor(userId);
    final afterCursor = cursor == null
        ? rewards
        : rewards.where((reward) => _isAfterCursor(reward, cursor)).toList();
    final page = afterCursor.take(limit).toList(growable: false);
    return AchievementRewardPage(
      rewards: page,
      nextCursor: afterCursor.length > page.length && page.isNotEmpty
          ? AchievementRewardCursor(
              createdAt: page.last.createdAt,
              id: page.last.id,
            )
          : null,
    );
  }

  @override
  Future<AchievementRewardSummary> getPendingSummary({
    required String userId,
  }) async {
    final rewards = _pendingFor(userId);
    return AchievementRewardSummary(
      pendingCount: rewards.length,
      pendingXp: rewards.fold(0, (sum, reward) => sum + reward.xpAmount),
    );
  }

  @override
  Future<AchievementRewardClaimResult> claimReward({
    required String userId,
    required String rewardId,
  }) async {
    final reward = _rewards[rewardId];
    if (reward == null || reward.userId != userId) {
      return const AchievementRewardClaimResult(
        claimedCount: 0,
        xpGranted: 0,
        status: 'not_found',
      );
    }
    if (!reward.isPending) {
      return const AchievementRewardClaimResult(
        claimedCount: 0,
        xpGranted: 0,
        status: 'already_claimed',
      );
    }

    final eventKey = _eventKey(reward);
    final alreadyBanked = !_claimedEventKeys.add(eventKey);
    final now = DateTime.now().toUtc();
    _rewards[reward.id] = reward.copyWith(
      status: AchievementRewardStatus.claimed,
      claimedAt: now,
    );
    if (!alreadyBanked) _claimedXp += reward.xpAmount;
    _changes.add(null);

    return AchievementRewardClaimResult(
      claimedCount: alreadyBanked ? 0 : 1,
      xpGranted: alreadyBanked ? 0 : reward.xpAmount,
      claimedRewardIds: alreadyBanked ? const [] : [reward.id],
      status: alreadyBanked ? 'already_banked' : 'claimed',
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
    var count = 0;
    var xp = 0;
    final ids = <String>[];
    for (final reward in _pendingFor(userId).take(limit)) {
      final result = await claimReward(userId: userId, rewardId: reward.id);
      count += result.claimedCount;
      xp += result.xpGranted;
      ids.addAll(result.claimedRewardIds);
    }
    return AchievementRewardClaimResult(
      claimedCount: count,
      xpGranted: xp,
      claimedRewardIds: ids,
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
    _capabilities.add('$userId|$capability');
  }

  /// Sadece repository testleri için trusted pending enjeksiyonu.
  void seedPendingReward(AchievementReward reward) {
    if (!reward.isPending) {
      throw ArgumentError.value(reward, 'reward', 'Ödül pending olmalı.');
    }
    _rewards[reward.id] = reward;
    _changes.add(null);
  }

  List<AchievementReward> _pendingFor(String userId) {
    final rewards =
        _rewards.values
            .where((reward) => reward.userId == userId && reward.isPending)
            .toList()
          ..sort((a, b) {
            final byCreated = b.createdAt.compareTo(a.createdAt);
            return byCreated != 0 ? byCreated : b.id.compareTo(a.id);
          });
    return rewards;
  }

  bool _isAfterCursor(
    AchievementReward reward,
    AchievementRewardCursor cursor,
  ) {
    final byCreated = reward.createdAt.compareTo(cursor.createdAt);
    return byCreated < 0 ||
        (byCreated == 0 && reward.id.compareTo(cursor.id) < 0);
  }

  String _eventKey(AchievementReward reward) =>
      '${reward.userId}|${reward.achievementId}|tier_${reward.tier}';

  void dispose() => _changes.close();
}
