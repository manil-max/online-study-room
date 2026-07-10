import 'package:flutter/foundation.dart';

@immutable
class GamificationProfile {
  const GamificationProfile({
    required this.userId,
    required this.streakFreezes,
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
  final DateTime createdAt;
  final DateTime updatedAt;

  GamificationProfile copyWith({int? streakFreezes, DateTime? updatedAt}) {
    return GamificationProfile(
      userId: userId,
      streakFreezes: streakFreezes ?? this.streakFreezes,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory GamificationProfile.fromMap(Map<String, dynamic> map) {
    return GamificationProfile(
      userId: map['user_id'] as String,
      streakFreezes: map['streak_freezes'] as int? ?? 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'streak_freezes': streakFreezes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
