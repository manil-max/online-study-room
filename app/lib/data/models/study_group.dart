import 'package:flutter/foundation.dart';

/// Grubun varsayılan günlük hedefi (dakika). DB sütunu yokken/boşken kullanılır.
const int kDefaultGroupGoalMinutes = 360;
const int kDefaultGroupMemberLimit = 50;

/// Grubun katılım modeli. Yeni gruplar geriye uyumluluk ve veri gizliliği için
/// kapalı başlar; açık gruplar yalnız güvenli keşif özetiyle listelenir.
enum GroupVisibility {
  private('private'),
  public('public');

  const GroupVisibility(this.dbValue);

  final String dbValue;

  static GroupVisibility fromDb(Object? value) => switch (value) {
    'public' => GroupVisibility.public,
    _ => GroupVisibility.private,
  };
}

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
    this.visibility = GroupVisibility.private,
    this.memberLimit = kDefaultGroupMemberLimit,
  });

  final String id;
  final String name;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;

  /// Grubun ortak günlük hedefi (dakika): grubun o günkü TOPLAM çalışması bu
  /// değere ulaşırsa hedef tutulmuş sayılır. Admin değiştirir (§3.4/§3.7).
  final int dailyGoalMinutes;

  final GroupVisibility visibility;
  final int memberLimit;

  StudyGroup copyWith({
    String? name,
    String? inviteCode,
    int? dailyGoalMinutes,
    GroupVisibility? visibility,
    int? memberLimit,
  }) {
    return StudyGroup(
      id: id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      createdBy: createdBy,
      createdAt: createdAt,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      visibility: visibility ?? this.visibility,
      memberLimit: memberLimit ?? this.memberLimit,
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
          (map['daily_goal_minutes'] as num?)?.toInt() ??
          kDefaultGroupGoalMinutes,
      visibility: GroupVisibility.fromDb(map['visibility']),
      memberLimit:
          (map['member_limit'] as num?)?.toInt() ?? kDefaultGroupMemberLimit,
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
      'visibility': visibility.dbValue,
      'member_limit': memberLimit,
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
      other.dailyGoalMinutes == dailyGoalMinutes &&
      other.visibility == visibility &&
      other.memberLimit == memberLimit;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    inviteCode,
    createdBy,
    createdAt,
    dailyGoalMinutes,
    visibility,
    memberLimit,
  );
}

/// Üye olmayan kişilere gösterilebilecek tek grup şekli. Davet kodu, oluşturucu
/// kimliği, üye listesi ve çalışma verisi bilerek bu modele girmez.
@immutable
class PublicGroupSummary {
  const PublicGroupSummary({
    required this.id,
    required this.name,
    required this.dailyGoalMinutes,
    required this.memberCount,
    required this.memberLimit,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int dailyGoalMinutes;
  final int memberCount;
  final int memberLimit;
  final DateTime createdAt;

  factory PublicGroupSummary.fromMap(Map<String, dynamic> map) {
    return PublicGroupSummary(
      id: map['id'] as String,
      name: map['name'] as String,
      dailyGoalMinutes: (map['daily_goal_minutes'] as num).toInt(),
      memberCount: (map['member_count'] as num).toInt(),
      memberLimit: (map['member_limit'] as num).toInt(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PublicGroupSummary &&
      other.id == id &&
      other.name == name &&
      other.dailyGoalMinutes == dailyGoalMinutes &&
      other.memberCount == memberCount &&
      other.memberLimit == memberLimit &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    dailyGoalMinutes,
    memberCount,
    memberLimit,
    createdAt,
  );
}
