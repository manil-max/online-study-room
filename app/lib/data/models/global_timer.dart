import 'package:flutter/foundation.dart';

/// WP-342: V2 timer gerçeğinin legacy [LiveStudyRun]'dan ayrı, versioned taşıması.
@immutable
class GlobalTimerSnapshot {
  const GlobalTimerSnapshot({
    this.userId,
    required this.stateVersion,
    required this.serverTime,
    this.run,
    this.resultCode,
  });

  final String? userId;
  final int stateVersion;
  final DateTime serverTime;
  final GlobalTimerRun? run;
  final String? resultCode;

  factory GlobalTimerSnapshot.fromMap(Map<String, dynamic> map) {
    final rawRun = map['run'];
    return GlobalTimerSnapshot(
      userId: map['user_id'] as String?,
      stateVersion: (map['state_version'] as num?)?.toInt() ?? 0,
      serverTime:
          DateTime.tryParse(map['server_time']?.toString() ?? '')?.toUtc() ??
          DateTime.now().toUtc(),
      run: rawRun is Map
          ? GlobalTimerRun.fromMap(Map<String, dynamic>.from(rawRun))
          : null,
      resultCode: map['result_code'] as String?,
    );
  }
}

@immutable
class GlobalTimerRun {
  const GlobalTimerRun({
    required this.id,
    required this.status,
    required this.revision,
    this.effectiveStartedAt,
  });
  final String id;
  final String status;
  final int revision;
  final DateTime? effectiveStartedAt;

  factory GlobalTimerRun.fromMap(Map<String, dynamic> map) => GlobalTimerRun(
    id: map['id'] as String,
    status: map['status'] as String,
    revision: (map['run_revision'] as num?)?.toInt() ?? 1,
    effectiveStartedAt: DateTime.tryParse(
      map['effective_started_at']?.toString() ?? '',
    )?.toLocal(),
  );
}

/// Uzak snapshot'ın yerel sayaç durumuna göre güvenli uygulanabilir sonucu.
/// Sinyal yalnız tetikleyicidir; bu karar her zaman doğrulanmış snapshot'tan gelir.
enum GlobalTimerForegroundDirectiveKind { mirrorStart, mirrorStop, deferred }

class GlobalTimerForegroundDirective {
  const GlobalTimerForegroundDirective({
    required this.kind,
    required this.snapshot,
  });

  final GlobalTimerForegroundDirectiveKind kind;
  final GlobalTimerSnapshot snapshot;
}

GlobalTimerForegroundDirective planGlobalTimerForegroundApply({
  required GlobalTimerSnapshot snapshot,
  required bool localRunning,
  required bool localIsMirror,
  required String? localMirrorRunId,
}) {
  final run = snapshot.run;
  if (run != null &&
      run.status == 'running' &&
      !localRunning &&
      run.effectiveStartedAt != null) {
    return GlobalTimerForegroundDirective(
      kind: GlobalTimerForegroundDirectiveKind.mirrorStart,
      snapshot: snapshot,
    );
  }
  // Eski ya da başka bir koşuya ait stop, kullanıcının yeni yerel koşusuna
  // dokunamaz. Yalnız aynı mirror run güvenle kapatılır.
  if (run == null &&
      localRunning &&
      localIsMirror &&
      localMirrorRunId != null) {
    return GlobalTimerForegroundDirective(
      kind: GlobalTimerForegroundDirectiveKind.mirrorStop,
      snapshot: snapshot,
    );
  }
  return GlobalTimerForegroundDirective(
    kind: GlobalTimerForegroundDirectiveKind.deferred,
    snapshot: snapshot,
  );
}
