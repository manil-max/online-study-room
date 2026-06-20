import 'package:flutter/foundation.dart';

/// Canlı çalışma durumu (bkz. project.md §3.5).
enum PresenceStatus { studying, onBreak, offline }

/// Bir kullanıcının canlı sınıftaki anlık durumu. Supabase Realtime `presence` ile
/// yayılır; istatistik için kalıcı değildir.
@immutable
class Presence {
  const Presence({
    required this.userId,
    required this.status,
    required this.todaySeconds,
    this.startedAt,
    this.subjectId,
  });

  final String userId;
  final PresenceStatus status;

  /// Mevcut çalışma/mola durumunun başladığı an (anlık süre buradan hesaplanır).
  final DateTime? startedAt;

  /// Kullanıcının bugünkü toplam çalışma süresi (saniye).
  final int todaySeconds;

  final String? subjectId;

  bool get isStudying => status == PresenceStatus.studying;

  Presence copyWith({
    PresenceStatus? status,
    DateTime? startedAt,
    int? todaySeconds,
    String? subjectId,
  }) {
    return Presence(
      userId: userId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      todaySeconds: todaySeconds ?? this.todaySeconds,
      subjectId: subjectId ?? this.subjectId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Presence &&
      other.userId == userId &&
      other.status == status &&
      other.startedAt == startedAt &&
      other.todaySeconds == todaySeconds &&
      other.subjectId == subjectId;

  @override
  int get hashCode =>
      Object.hash(userId, status, startedAt, todaySeconds, subjectId);
}
