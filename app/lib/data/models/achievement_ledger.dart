import 'package:flutter/foundation.dart';

/// Sözlük satırı — `achievements_dict` (server seed).
@immutable
class AchievementDictEntry {
  const AchievementDictEntry({
    required this.id,
    required this.category,
    required this.name,
    required this.description,
    required this.maxTier,
    required this.iconKey,
    required this.isSecret,
    required this.tiers,
  });

  final String id;
  final String category;
  final String name;
  final String description;
  final int maxTier;
  final String iconKey;
  final bool isSecret;
  final List<AchievementTierDef> tiers;

  factory AchievementDictEntry.fromMap(Map<String, dynamic> map) {
    final rawTiers = map['tiers'];
    final List<AchievementTierDef> tiers;
    if (rawTiers is List) {
      tiers = rawTiers
          .map((e) => AchievementTierDef.fromMap(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    } else {
      tiers = const [];
    }
    return AchievementDictEntry(
      id: map['id'] as String,
      category: map['category'] as String? ?? 'study',
      name: map['name'] as String? ?? map['id'] as String,
      description: map['description'] as String? ?? '',
      maxTier: map['max_tier'] as int? ?? tiers.length,
      iconKey: map['icon_key'] as String? ?? 'emoji_events',
      isSecret: map['is_secret'] as bool? ?? false,
      tiers: tiers,
    );
  }
}

@immutable
class AchievementTierDef {
  const AchievementTierDef({
    required this.tier,
    required this.threshold,
    required this.unit,
    required this.xp,
  });

  final int tier;
  final int threshold;
  final String unit;
  final int xp;

  factory AchievementTierDef.fromMap(Map<String, dynamic> map) {
    return AchievementTierDef(
      tier: map['tier'] as int,
      threshold: map['threshold'] as int,
      unit: map['unit'] as String? ?? '',
      xp: map['xp'] as int,
    );
  }
}

/// Tek ledger satırı / yeni ödül.
@immutable
class AchievementAward {
  const AchievementAward({
    required this.achievementId,
    required this.tier,
    required this.xp,
    this.name,
    this.isSecret = false,
  });

  final String achievementId;
  final int tier;
  final int xp;
  final String? name;
  final bool isSecret;

  factory AchievementAward.fromMap(Map<String, dynamic> map) {
    return AchievementAward(
      achievementId: map['achievement_id'] as String,
      tier: map['tier'] as int,
      xp: map['xp'] as int,
      name: map['name'] as String?,
      isSecret: map['is_secret'] as bool? ?? false,
    );
  }
}

/// `process_achievement_event` RPC yanıtı.
@immutable
class AchievementEventResult {
  const AchievementEventResult({
    required this.eventType,
    required this.awarded,
    required this.totalXp,
    required this.crownRank,
    this.metrics = const {},
  });

  final String eventType;
  final List<AchievementAward> awarded;
  final int totalXp;
  final String crownRank;
  final Map<String, dynamic> metrics;

  factory AchievementEventResult.fromMap(Map<String, dynamic> map) {
    final raw = map['awarded'];
    final awards = <AchievementAward>[];
    if (raw is List) {
      for (final e in raw) {
        awards.add(
          AchievementAward.fromMap(Map<String, dynamic>.from(e as Map)),
        );
      }
    }
    final metricsRaw = map['metrics'];
    return AchievementEventResult(
      eventType: map['event_type'] as String? ?? '',
      awarded: awards,
      totalXp: map['total_xp'] as int? ?? 0,
      crownRank: map['crown_rank'] as String? ?? 'bronze_beginner',
      metrics: metricsRaw is Map
          ? Map<String, dynamic>.from(metricsRaw)
          : const {},
    );
  }

  bool get hasNewAwards => awarded.isNotEmpty;
}
