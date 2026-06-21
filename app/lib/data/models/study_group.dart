import 'package:flutter/foundation.dart';

/// Grubun varsayılan günlük hedefi (dakika). DB sütunu yokken/boşken kullanılır.
const int kDefaultGroupGoalMinutes = 360;

/// Çalışma sınıfı (grup). Supabase `groups` tablosuna karşılık gelir (bkz. project.md §6).
@immutable
class StudyGroup {
  const StudyGroup({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
    this.dailyGoalMinutes = kDefaultGroupGoalMinutes,
  });

  final String id;
  final String name;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;

  /// Grubun ortak günlük hedefi (dakika): grubun o günkü TOPLAM çalışması bu
  /// değere ulaşırsa hedef tutulmuş sayılır. Admin değiştirir (§3.4/§3.7).
  final int dailyGoalMinutes;

  StudyGroup copyWith({
    String? name,
    String? inviteCode,
    int? dailyGoalMinutes,
  }) {
    return StudyGroup(
      id: id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      createdBy: createdBy,
      createdAt: createdAt,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
    );
  }

  factory StudyGroup.fromMap(Map<String, dynamic> map) {
    return StudyGroup(
      id: map['id'] as String,
      name: map['name'] as String,
      inviteCode: map['invite_code'] as String,
      createdBy: map['created_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      dailyGoalMinutes:
          (map['daily_goal_minutes'] as int?) ?? kDefaultGroupGoalMinutes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'invite_code': inviteCode,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'daily_goal_minutes': dailyGoalMinutes,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is StudyGroup &&
      other.id == id &&
      other.name == name &&
      other.inviteCode == inviteCode &&
      other.createdBy == createdBy &&
      other.createdAt == createdAt &&
      other.dailyGoalMinutes == dailyGoalMinutes;

  @override
  int get hashCode => Object.hash(
      id, name, inviteCode, createdBy, createdAt, dailyGoalMinutes);
}
