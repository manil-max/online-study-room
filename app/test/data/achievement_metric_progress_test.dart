import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/achievement_metric_progress.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_achievement_repository.dart';

StudySession _goalSession(String id, DateTime start) => StudySession(
  id: id,
  userId: 'u1',
  start: start,
  end: start.add(const Duration(hours: 1)),
  durationSeconds: 3600,
  source: StudySource.live,
);

void main() {
  test('AchievementMetricProgress map roundtrip', () {
    final progress = AchievementMetricProgress(
      userId: 'u1',
      achievementId: 'fire_streak',
      metricValue: 7,
      sourceVersion: 'metric_v2',
      updatedAt: DateTime.utc(2026, 7, 19, 12),
    );
    expect(AchievementMetricProgress.fromMap(progress.toMap()), progress);
  });

  test('current streak decreases, cumulative metric does not', () async {
    final repository = InMemoryAchievementRepository();
    final evaluationTime = DateTime.utc(2026, 7, 10, 12);
    final threeDays = [
      _goalSession('d8', DateTime.utc(2026, 7, 8, 12)),
      _goalSession('d9', DateTime.utc(2026, 7, 9, 12)),
      _goalSession('d10', DateTime.utc(2026, 7, 10, 12)),
    ];

    await repository.processEvent(
      eventType: 'manual_refresh',
      sessions: threeDays,
      dailyGoalMinutes: 60,
      userId: 'u1',
      evaluationTime: evaluationTime,
    );
    final first = await repository.fetchMetricProgress('u1');
    expect(
      first
          .singleWhere((row) => row.achievementId == 'fire_streak')
          .metricValue,
      3,
    );
    expect(
      first
          .singleWhere((row) => row.achievementId == 'marathon_total')
          .metricValue,
      3,
    );

    await repository.processEvent(
      eventType: 'manual_refresh',
      sessions: [threeDays.last],
      dailyGoalMinutes: 60,
      userId: 'u1',
      evaluationTime: evaluationTime,
    );
    final second = await repository.fetchMetricProgress('u1');
    expect(
      second
          .singleWhere((row) => row.achievementId == 'fire_streak')
          .metricValue,
      1,
    );
    expect(
      second
          .singleWhere((row) => row.achievementId == 'marathon_total')
          .metricValue,
      3,
    );
    repository.dispose();
  });

  test('unchanged projection keeps updatedAt stable', () async {
    final repository = InMemoryAchievementRepository();
    final evaluationTime = DateTime.utc(2026, 7, 10, 12);
    final sessions = [_goalSession('d10', DateTime.utc(2026, 7, 10, 12))];

    await repository.processEvent(
      eventType: 'manual_refresh',
      sessions: sessions,
      dailyGoalMinutes: 60,
      userId: 'u1',
      evaluationTime: evaluationTime,
    );
    final first = await repository.fetchMetricProgress('u1');
    await repository.processEvent(
      eventType: 'manual_refresh',
      sessions: sessions,
      dailyGoalMinutes: 60,
      userId: 'u1',
      evaluationTime: evaluationTime,
    );
    final second = await repository.fetchMetricProgress('u1');

    expect(second, first);
    repository.dispose();
  });
}
