import 'package:flutter/foundation.dart';

/// Canlı çalışma durumu (bkz. project.md §3.5).
enum PresenceStatus { studying, onBreak, offline }

/// Bir kullanıcının canlı sınıftaki anlık durumu. Supabase `presence` tablosuna
/// karşılık gelir; Realtime ile yayılır.
@immutable
class Presence {
  const Presence({
    required this.userId,
    required this.status,
    required this.todaySeconds,
    this.groupId,
    this.startedAt,
    this.subjectId,
  });

  final String userId;

  /// Kullanıcının içinde bulunduğu sınıf (presence sorguları sınıfa göre süzülür).
  final String? groupId;

  final PresenceStatus status;

  /// Mevcut çalışma/mola durumunun başladığı an (anlık süre buradan hesaplanır).
  final DateTime? startedAt;

  /// Kullanıcının bugünkü toplam çalışma süresi (saniye).
  final int todaySeconds;

  final String? subjectId;

  bool get isStudying => status == PresenceStatus.studying;

  Presence copyWith({
    String? groupId,
    PresenceStatus? status,
    DateTime? startedAt,
    int? todaySeconds,
    String? subjectId,
  }) {
    return Presence(
      userId: userId,
      groupId: groupId ?? this.groupId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      todaySeconds: todaySeconds ?? this.todaySeconds,
      subjectId: subjectId ?? this.subjectId,
    );
  }

  factory Presence.fromMap(Map<String, dynamic> map) {
    final started = map['started_at'] as String?;
    return Presence(
      userId: map['user_id'] as String,
      groupId: map['group_id'] as String?,
      status: PresenceStatus.values.byName(map['status'] as String),
      startedAt: started == null ? null : DateTime.parse(started),
      todaySeconds: (map['today_seconds'] as int?) ?? 0,
      subjectId: map['subject_id'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'group_id': groupId,
      'status': status.name,
      'started_at': startedAt?.toIso8601String(),
      'today_seconds': todaySeconds,
      'subject_id': subjectId,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) =>
      other is Presence &&
      other.userId == userId &&
      other.groupId == groupId &&
      other.status == status &&
      other.startedAt == startedAt &&
      other.todaySeconds == todaySeconds &&
      other.subjectId == subjectId;

  @override
  int get hashCode =>
      Object.hash(userId, groupId, status, startedAt, todaySeconds, subjectId);
}
