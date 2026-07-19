import 'package:flutter/foundation.dart';

enum AchievementRewardStatus { pending, claimed }

AchievementRewardStatus achievementRewardStatusFromString(String value) {
  return switch (value) {
    'claimed' => AchievementRewardStatus.claimed,
    _ => AchievementRewardStatus.pending,
  };
}

@immutable
class AchievementReward {
  const AchievementReward({
    required this.id,
    required this.userId,
    required this.achievementId,
    required this.tier,
    required this.xpAmount,
    required this.status,
    required this.createdAt,
    this.reason,
    this.claimedAt,
  });

  final String id;
  final String userId;
  final String achievementId;
  final int tier;
  final int xpAmount;
  final String? reason;
  final AchievementRewardStatus status;
  final DateTime createdAt;
  final DateTime? claimedAt;

  bool get isPending => status == AchievementRewardStatus.pending;

  AchievementReward copyWith({
    AchievementRewardStatus? status,
    DateTime? claimedAt,
  }) {
    return AchievementReward(
      id: id,
      userId: userId,
      achievementId: achievementId,
      tier: tier,
      xpAmount: xpAmount,
      reason: reason,
      status: status ?? this.status,
      createdAt: createdAt,
      claimedAt: claimedAt ?? this.claimedAt,
    );
  }

  factory AchievementReward.fromMap(Map<String, dynamic> map) {
    return AchievementReward(
      id: map['id'] as String,
      userId: map['user_id'] as String? ?? '',
      achievementId: map['achievement_id'] as String,
      tier: map['tier'] as int,
      xpAmount: map['xp_amount'] as int,
      reason: map['reason'] as String?,
      status: achievementRewardStatusFromString(
        map['status'] as String? ?? 'pending',
      ),
      createdAt: DateTime.parse(map['created_at'] as String),
      claimedAt: map['claimed_at'] == null
          ? null
          : DateTime.parse(map['claimed_at'] as String),
    );
  }
}

@immutable
class AchievementRewardCursor {
  const AchievementRewardCursor({required this.createdAt, required this.id});

  final DateTime createdAt;
  final String id;
}

@immutable
class AchievementRewardPage {
  const AchievementRewardPage({required this.rewards, this.nextCursor});

  final List<AchievementReward> rewards;
  final AchievementRewardCursor? nextCursor;
}

@immutable
class AchievementRewardSummary {
  const AchievementRewardSummary({
    required this.pendingCount,
    required this.pendingXp,
  });

  final int pendingCount;
  final int pendingXp;

  factory AchievementRewardSummary.fromMap(Map<String, dynamic> map) {
    return AchievementRewardSummary(
      pendingCount: map['pending_count'] as int? ?? 0,
      pendingXp: map['pending_xp'] as int? ?? 0,
    );
  }

  static const empty = AchievementRewardSummary(pendingCount: 0, pendingXp: 0);
}

@immutable
class AchievementRewardClaimResult {
  const AchievementRewardClaimResult({
    required this.claimedCount,
    required this.xpGranted,
    this.claimedRewardIds = const [],
    this.status,
  });

  final int claimedCount;
  final int xpGranted;
  final List<String> claimedRewardIds;
  final String? status;

  bool get changed => claimedCount > 0;

  factory AchievementRewardClaimResult.fromSingleMap(Map<String, dynamic> map) {
    final status = map['status'] as String?;
    final rewardId = map['reward_id'] as String?;
    final claimed = status == 'claimed';
    return AchievementRewardClaimResult(
      claimedCount: claimed ? 1 : 0,
      xpGranted: map['xp_granted'] as int? ?? 0,
      claimedRewardIds: claimed && rewardId != null ? [rewardId] : const [],
      status: status,
    );
  }

  factory AchievementRewardClaimResult.fromAllMap(Map<String, dynamic> map) {
    final ids = (map['claimed_reward_ids'] as List? ?? const [])
        .map((id) => id.toString())
        .toList(growable: false);
    return AchievementRewardClaimResult(
      claimedCount: map['claimed_count'] as int? ?? 0,
      xpGranted: map['xp_granted'] as int? ?? 0,
      claimedRewardIds: ids,
    );
  }
}
