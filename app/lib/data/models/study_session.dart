import 'package:flutter/foundation.dart';

/// Sürenin nasıl kaydedildiği. İstatistikte ayrım YAPILMAZ (bkz. project.md §3.5);
/// yalnızca kayıt amaçlı tutulur.
enum StudySource { live, manual }

/// Tek bir çalışma oturumu. Supabase `study_sessions` tablosuna karşılık gelir.
@immutable
class StudySession {
  const StudySession({
    required this.id,
    required this.userId,
    required this.groupId,
    required this.start,
    required this.end,
    required this.durationSeconds,
    required this.source,
    this.subjectId,
  });

  final String id;
  final String userId;
  final String groupId;
  final String? subjectId;
  final DateTime start;
  final DateTime end;
  final int durationSeconds;
  final StudySource source;

  /// Oturumun ait olduğu gün (saat bilgisi sıfırlanmış), istatistik gruplaması için.
  DateTime get day => DateTime(start.year, start.month, start.day);

  factory StudySession.fromMap(Map<String, dynamic> map) {
    return StudySession(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      groupId: map['group_id'] as String,
      subjectId: map['subject_id'] as String?,
      start: DateTime.parse(map['start_time'] as String),
      end: DateTime.parse(map['end_time'] as String),
      durationSeconds: map['duration_seconds'] as int,
      source: StudySource.values.byName(map['source'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'group_id': groupId,
      'subject_id': subjectId,
      'start_time': start.toIso8601String(),
      'end_time': end.toIso8601String(),
      'duration_seconds': durationSeconds,
      'source': source.name,
    };
  }

  @override
  bool operator ==(Object other) =>
      other is StudySession &&
      other.id == id &&
      other.userId == userId &&
      other.groupId == groupId &&
      other.subjectId == subjectId &&
      other.start == start &&
      other.end == end &&
      other.durationSeconds == durationSeconds &&
      other.source == source;

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        groupId,
        subjectId,
        start,
        end,
        durationSeconds,
        source,
      );
}
