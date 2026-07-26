import 'package:flutter/foundation.dart';

/// WP-342: V2 timer gerçeğinin legacy [LiveStudyRun]'dan ayrı, versioned taşıması.
@immutable
class GlobalTimerSnapshot {
  const GlobalTimerSnapshot({
    required this.stateVersion,
    required this.serverTime,
    this.run,
    this.resultCode,
  });

  final int stateVersion;
  final DateTime serverTime;
  final GlobalTimerRun? run;
  final String? resultCode;

  factory GlobalTimerSnapshot.fromMap(Map<String, dynamic> map) {
    final rawRun = map['run'];
    return GlobalTimerSnapshot(
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
  });
  final String id;
  final String status;
  final int revision;

  factory GlobalTimerRun.fromMap(Map<String, dynamic> map) => GlobalTimerRun(
    id: map['id'] as String,
    status: map['status'] as String,
    revision: (map['run_revision'] as num?)?.toInt() ?? 1,
  );
}
