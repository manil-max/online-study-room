import 'package:flutter/foundation.dart';

/// Varsayılan günlük hedef (dakika) — 6 saat. Bkz. project.md §3.7.
const int kDefaultDailyGoalMinutes = 360;

/// Kullanıcı profili. Supabase `profiles` tablosuna karşılık gelir (bkz. project.md §6).
@immutable
class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    required this.createdAt,
    this.avatarUrl,
    this.dailyGoalMinutes = kDefaultDailyGoalMinutes,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final DateTime createdAt;

  /// Günlük çalışma hedefi (dakika). Seri (streak) ve hedef ilerleme buna bağlı.
  final int dailyGoalMinutes;

  Profile copyWith({
    String? displayName,
    String? avatarUrl,
    int? dailyGoalMinutes,
  }) {
    return Profile(
      id: id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
    );
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      displayName: map['display_name'] as String,
      avatarUrl: map['avatar_url'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      dailyGoalMinutes:
          (map['daily_goal_minutes'] as int?) ?? kDefaultDailyGoalMinutes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'created_at': createdAt.toIso8601String(),
      'daily_goal_minutes': dailyGoalMinutes,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.id == id &&
      other.displayName == displayName &&
      other.avatarUrl == avatarUrl &&
      other.createdAt == createdAt &&
      other.dailyGoalMinutes == dailyGoalMinutes;

  @override
  int get hashCode =>
      Object.hash(id, displayName, avatarUrl, createdAt, dailyGoalMinutes);
}
