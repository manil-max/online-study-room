import 'package:flutter/foundation.dart';

@immutable
class GamificationProfile {
  const GamificationProfile({
    required this.userId,
    required this.streakFreezes,
    this.xp = 0,
    this.crownRank = 'bronze',
    this.selectedBadges = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory GamificationProfile.initial(String userId) {
    final now = DateTime.now();
    return GamificationProfile(
      userId: userId,
      streakFreezes: 1,
      createdAt: now,
      updatedAt: now,
    );
  }

  final String userId;
  final int streakFreezes;
  final int xp;
  final String crownRank;
  final List<String> selectedBadges;
  final DateTime createdAt;
  final DateTime updatedAt;

  GamificationProfile copyWith({
    int? streakFreezes, 
    int? xp,
    String? crownRank,
    List<String>? selectedBadges,
    DateTime? updatedAt
  }) {
    return GamificationProfile(
      userId: userId,
      streakFreezes: streakFreezes ?? this.streakFreezes,
      xp: xp ?? this.xp,
      crownRank: crownRank ?? this.crownRank,
      selectedBadges: selectedBadges ?? this.selectedBadges,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory GamificationProfile.fromMap(Map<String, dynamic> map) {
    return GamificationProfile(
      userId: map['user_id'] as String,
      streakFreezes: map['streak_freezes'] as int? ?? 1,
      xp: map['xp'] as int? ?? 0,
      crownRank: map['crown_rank'] as String? ?? 'bronze',
      selectedBadges: (map['selected_badges'] as List<dynamic>?)?.cast<String>() ?? [],
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'streak_freezes': streakFreezes,
      'xp': xp,
      'crown_rank': crownRank,
      'selected_badges': selectedBadges,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
