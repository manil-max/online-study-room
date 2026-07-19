import 'dart:async';

import '../../../core/stats/achievement_ledger_engine.dart';
import '../../models/achievement_ledger.dart';
import '../../models/achievement_metric_progress.dart';
import '../../models/study_session.dart';
import '../achievement_repository.dart';

/// Demo/offline: sunucu RPC kurallarının Dart aynası (XP yalnız engine ledger).
class InMemoryAchievementRepository implements AchievementRepository {
  InMemoryAchievementRepository({AchievementLedgerEngine? engine})
    : _engine = engine ?? AchievementLedgerEngine();

  final AchievementLedgerEngine _engine;
  final Map<String, Map<String, AchievementMetricProgress>> _progress = {};
  final StreamController<String> _progressChanges =
      StreamController<String>.broadcast();

  @override
  Future<List<AchievementDictEntry>> fetchDictionary() async {
    return List.unmodifiable(_engine.dictionary);
  }

  List<AchievementMetricProgress> _snapshot(String userId) {
    final rows = _progress[userId]?.values.toList() ?? [];
    rows.sort((a, b) => a.achievementId.compareTo(b.achievementId));
    return List.unmodifiable(rows);
  }

  @override
  Future<List<AchievementMetricProgress>> fetchMetricProgress(
    String userId,
  ) async => _snapshot(userId);

  @override
  Stream<List<AchievementMetricProgress>> watchMetricProgress(
    String userId,
  ) async* {
    yield _snapshot(userId);
    yield* _progressChanges.stream
        .where((changedUserId) => changedUserId == userId)
        .map((_) => _snapshot(userId));
  }

  @override
  Future<AchievementEventResult> processEvent({
    required String eventType,
    Map<String, dynamic> payload = const {},
    List<StudySession> sessions = const [],
    int dailyGoalMinutes = 360,
    String? userId,
    DateTime? evaluationTime,
  }) async {
    final uid = userId ?? 'local-user';
    final result = _engine.processEvent(
      userId: uid,
      eventType: eventType,
      sessions: sessions,
      dailyGoalMinutes: dailyGoalMinutes,
      now: evaluationTime,
    );
    _project(uid, result.metrics);
    return result;
  }

  void _project(String userId, Map<String, dynamic> metrics) {
    final userProgress = _progress.putIfAbsent(userId, () => {});
    final now = DateTime.now().toUtc();
    var changed = false;
    for (final entry in kAchievementMetricSourceVersions.entries) {
      final currentValue = _engine.progressForAchievement(entry.key, metrics);
      final previous = userProgress[entry.key];
      final nextValue = kCurrentAchievementMetrics.contains(entry.key)
          ? currentValue
          : previous == null
          ? currentValue
          : currentValue > previous.metricValue
          ? currentValue
          : previous.metricValue;
      if (previous != null &&
          previous.metricValue == nextValue &&
          previous.sourceVersion == entry.value) {
        continue;
      }
      userProgress[entry.key] = AchievementMetricProgress(
        userId: userId,
        achievementId: entry.key,
        metricValue: nextValue,
        sourceVersion: entry.value,
        updatedAt: now,
      );
      changed = true;
    }
    if (changed && !_progressChanges.isClosed) {
      _progressChanges.add(userId);
    }
  }

  /// Test yardımcısı: mevcut defter XP'si.
  int get totalXp => _engine.totalXp;

  void dispose() => _progressChanges.close();
}
