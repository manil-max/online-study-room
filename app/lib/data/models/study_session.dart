import 'package:flutter/foundation.dart';

import '../../core/stats/istanbul_calendar.dart';

/// Sürenin nasıl kaydedildiği. İstatistikte ayrım YAPILMAZ (bkz. project.md §3.5);
/// yalnızca kayıt amaçlı tutulur.
enum StudySource { live, manual }

enum LiveRunStatus { running, paused, finalized, cancelled }

enum LiveStartOrigin { dartApp, nativeWidget, nativeNotification }

enum LiveRolloutOutcome {
  verifiedFinalize,
  unverifiedFallback,
  finalizeFailure,
}

@immutable
class LiveStudyRun {
  const LiveStudyRun({
    required this.id,
    required this.runToken,
    required this.userId,
    required this.status,
    required this.clientBuild,
    required this.startedAt,
    this.groupIdSnapshot,
    this.subjectIdSnapshot,
    this.finalizedAt,
    this.sessionId,
  });

  final String id;
  final String runToken;
  final String userId;
  final String? groupIdSnapshot;
  final String? subjectIdSnapshot;
  final LiveRunStatus status;
  final int clientBuild;
  final DateTime startedAt;
  final DateTime? finalizedAt;
  final String? sessionId;

  factory LiveStudyRun.fromMap(Map<String, dynamic> map) => LiveStudyRun(
    id: map['id'] as String,
    runToken: map['run_token'] as String,
    userId: map['user_id'] as String,
    groupIdSnapshot: map['group_id_snapshot'] as String?,
    subjectIdSnapshot: map['subject_id_snapshot'] as String?,
    status: LiveRunStatus.values.byName(map['status'] as String),
    clientBuild: (map['client_build'] as num).toInt(),
    startedAt: DateTime.parse(map['started_at'] as String),
    finalizedAt: map['finalized_at'] == null
        ? null
        : DateTime.parse(map['finalized_at'] as String),
    sessionId: map['session_id'] as String?,
  );
}

@immutable
class VerifiedSessionConfig {
  const VerifiedSessionConfig({
    required this.shadowMode,
    this.minimumVerifiedXpBuild,
  });

  const VerifiedSessionConfig.shadow()
    : shadowMode = true,
      minimumVerifiedXpBuild = null;

  final bool shadowMode;
  final int? minimumVerifiedXpBuild;

  factory VerifiedSessionConfig.fromMap(Map<String, dynamic> map) =>
      VerifiedSessionConfig(
        shadowMode: map['shadow_mode'] as bool? ?? true,
        minimumVerifiedXpBuild: (map['minimum_verified_xp_build'] as num?)
            ?.toInt(),
      );
}

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
    this.liveRunId,
  });

  final String id;
  final String userId;
  final String? subjectId;
  final DateTime start;
  final DateTime end;
  final int durationSeconds;
  final StudySource source;
  final String? liveRunId;

  bool get isVerified => liveRunId != null;

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
      liveRunId: map['live_run_id'] as String?,
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
      'live_run_id': liveRunId,
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
      other.source == source &&
      other.liveRunId == liveRunId;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    subjectId,
    start,
    end,
    durationSeconds,
    source,
    liveRunId,
  );
}
