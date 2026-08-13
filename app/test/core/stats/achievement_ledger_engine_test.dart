import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/achievement_ledger_engine.dart';
import 'package:online_study_room/data/models/study_session.dart';

StudySession _goalDay(DateTime day) {
  final start = DateTime.utc(day.year, day.month, day.day, 7);
  return StudySession(
    id: day.toIso8601String(),
    userId: 'u1',
    start: start,
    end: start.add(const Duration(hours: 1)),
    durationSeconds: 3600,
    source: StudySource.live,
  );
}

void main() {
  group('WP-732 live fire streak', () {
    test('four uninterrupted Istanbul goal days report 4/7 progress', () {
      final sessions = [
        for (var day = 10; day <= 13; day++) _goalDay(DateTime(2026, 8, day)),
      ];
      final engine = AchievementLedgerEngine();
      final metrics = engine.computeMetrics(
        sessions: sessions,
        dailyGoalMinutes: 60,
        now: DateTime.utc(2026, 8, 13, 12),
      );

      expect(metrics['streak_days'], 4);
      expect(engine.progressForAchievement('fire_streak', metrics), 4);
    });

    test(
      'broken current streak retracts but an earned ledger tier remains',
      () {
        final key = ledgerEventKey('u1', 'fire_streak', 1);
        final engine = AchievementLedgerEngine(initialLedgerXp: {key: 1000});
        final result = engine.processEvent(
          userId: 'u1',
          eventType: 'profile_opened',
          sessions: const [],
          dailyGoalMinutes: 60,
          now: DateTime.utc(2026, 8, 13, 12),
        );

        expect(result.metrics['streak_days'], 0);
        expect(engine.eventKeys, contains(key));
        expect(engine.totalXp, 1000);
        expect(
          result.awarded.where((a) => a.achievementId == 'fire_streak'),
          isEmpty,
        );
      },
    );
  });
}
