import 'package:flutter/foundation.dart';

import '../../core/stats/istanbul_calendar.dart';

/// Sürenin nasıl kaydedildiği. İstatistikte ayrım YAPILMAZ (bkz. project.md §3.5);
/// yalnızca kayıt amaçlı tutulur.
enum StudySource { live, manual }

/// Tek bir çalışma oturumu. Supabase `study_sessions` tablosuna karşılık gelir.
/// Oturum yalnızca kullanıcıya aittir; grup istatistiği group_members join'iyle hesaplanır.
@immutable
class StudySession {
  const StudySession({
    required this.id,
    required this.userId,
    required this.start,
    required this.end,
    required this.durationSeconds,
    required this.source,
    this.subjectId,
  });

  final String id;
  final String userId;
  final String? subjectId;
  final DateTime start;
  final DateTime end;
  final int durationSeconds;
  final StudySource source;

  /// Oturumun ait olduğu takvim günü (Europe/Istanbul, saat sıfır).
  /// UTC `start` parse edilse bile `dailyTotals` / `dayOf` ile aynı anahtarı üretir.
  DateTime get day => istanbulDay(start);

  factory StudySession.fromMap(Map<String, dynamic> map) {
    return StudySession(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      subjectId: map['subject_id'] as String?,
      start: DateTime.parse(map['start_time'] as String),
      end: DateTime.parse(map['end_time'] as String),
      durationSeconds: map['duration_seconds'] as int,
      source: StudySource.values.byName(map['source'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    // WP-107: timestamptz round-trip için her zaman UTC yaz (cihaz TZ kayması yok).
    return {
      'id': id,
      'user_id': userId,
      'subject_id': subjectId,
      'start_time': start.toUtc().toIso8601String(),
      'end_time': end.toUtc().toIso8601String(),
      'duration_seconds': durationSeconds,
      'source': source.name,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is StudySession &&
      other.id == id &&
      other.userId == userId &&
      other.subjectId == subjectId &&
      other.start == start &&
      other.end == end &&
      other.durationSeconds == durationSeconds &&
      other.source == source;

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        subjectId,
        start,
        end,
        durationSeconds,
        source,
      );
}
