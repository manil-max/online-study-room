import 'package:flutter/foundation.dart';

/// Kullanıcının veritabanında tutulan başarı ilerlemesi
@immutable
class UserAchievement {
  const UserAchievement({
    required this.id,
    required this.userId,
    required this.achievementId,
    this.tier = 1,
    this.progress = 0,
    this.unlockedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String achievementId;
  final int tier;
  final int progress;
  final DateTime? unlockedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isUnlocked => unlockedAt != null;

  UserAchievement copyWith({
    int? tier,
    int? progress,
    DateTime? unlockedAt,
    DateTime? updatedAt,
  }) {
    return UserAchievement(
      id: id,
      userId: userId,
      achievementId: achievementId,
      tier: tier ?? this.tier,
      progress: progress ?? this.progress,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory UserAchievement.fromMap(Map<String, dynamic> map) {
    return UserAchievement(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      achievementId: map['achievement_id'] as String,
      tier: map['tier'] as int? ?? 1,
      progress: map['progress'] as int? ?? 0,
      unlockedAt: map['unlocked_at'] != null
          ? DateTime.parse(map['unlocked_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'achievement_id': achievementId,
      'tier': tier,
      'progress': progress,
      'unlocked_at': unlockedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Supabase upsert'i için yazılabilir alanlar.
  /// Yeni kayıtta boş bir id göndermeyiz; PostgreSQL `gen_random_uuid()` ile
  /// üretir. Çakışma anahtarı `(user_id, achievement_id)`dir.
  Map<String, dynamic> toUpsertMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'achievement_id': achievementId,
      'tier': tier,
      'progress': progress,
      'unlocked_at': unlockedAt?.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

enum AchievementCategory { study, focus, social, fun }

/// Hardcoded olarak tanımlanan başarı kuralları
@immutable
class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.title,
    required this.descriptionTemplate, // Örn: "{count} saat çalış"
    required this.category,
    required this.icon,
    required this.maxTier,
    required this.tierRequirements, // tier -> hedef değer eşleşmesi
    required this.xpRewards, // tier -> XP ödülü eşleşmesi
  });

  final String id;
  final String title;
  final String descriptionTemplate;
  final AchievementCategory category;
  final String icon; // Asset yolu veya material icon adı (String)
  final int maxTier;
  final List<int> tierRequirements;
  final List<int> xpRewards;

  String getDescription(int target) {
    return descriptionTemplate.replaceAll('{count}', target.toString());
  }
}
