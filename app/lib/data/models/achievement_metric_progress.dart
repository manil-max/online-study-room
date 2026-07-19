import 'package:flutter/foundation.dart';

/// Self-only projection of a real achievement metric. This is intentionally
/// separate from `user_achievements.progress`, which remains the claimed tier.
@immutable
class AchievementMetricProgress {
  const AchievementMetricProgress({
    required this.userId,
    required this.achievementId,
    required this.metricValue,
    required this.sourceVersion,
    required this.updatedAt,
  });

  final String userId;
  final String achievementId;
  final int metricValue;
  final String sourceVersion;
  final DateTime updatedAt;

  factory AchievementMetricProgress.fromMap(Map<String, dynamic> map) {
    return AchievementMetricProgress(
      userId: map['user_id'] as String,
      achievementId: map['achievement_id'] as String,
      metricValue: (map['metric_value'] as num?)?.toInt() ?? 0,
      sourceVersion: map['source_version'] as String? ?? 'unknown',
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() => {
    'user_id': userId,
    'achievement_id': achievementId,
    'metric_value': metricValue,
    'source_version': sourceVersion,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is AchievementMetricProgress &&
      other.userId == userId &&
      other.achievementId == achievementId &&
      other.metricValue == metricValue &&
      other.sourceVersion == sourceVersion &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      Object.hash(userId, achievementId, metricValue, sourceVersion, updatedAt);
}
