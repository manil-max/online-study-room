import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/goal_streak_projection.dart';
import 'package:online_study_room/data/models/goal_streak.dart';

void main() {
  group('projectGoalStreak', () {
    final fixture =
        jsonDecode(
              File(
                'test/fixtures/goal_streak_parity_v1.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;

    for (final rawCase in fixture['cases'] as List<dynamic>) {
      final testCase = rawCase as Map<String, dynamic>;
      test(testCase['name'] as String, () {
        final scope = _scopeFrom(testCase);
        final events = (testCase['events'] as List<dynamic>)
            .map(
              (raw) =>
                  _eventFrom(raw as Map<String, dynamic>, fallbackScope: scope),
            )
            .toList();
        final expected = testCase['expected'] as Map<String, dynamic>;

        final result = projectGoalStreak(
          scope: scope,
          events: events,
          asOfDay: DateTime.parse(testCase['asOfDay'] as String),
        );

        expect(result.sourceVersion, fixture['version']);
        expect(result.currentStreak, expected['streak']);
        expect(result.completionCount, expected['count']);
        expect(result.state.wireValue, expected['state']);
      });
    }

    test('aynı completion event retry ile yalnız bir kez sayılır', () {
      const scope = GoalStreakScope.personal('user-a');
      final event = _completed(scope, 'same-key', '2026-07-01');

      final result = projectGoalStreak(
        scope: scope,
        events: [event, event],
        asOfDay: DateTime.utc(2026, 7, 1),
      );

      expect(result.currentStreak, 1);
      expect(result.completionCount, 1);
    });

    test('farklı key ile aynı gün gelen completion yalnız bir gündür', () {
      const scope = GoalStreakScope.personal('user-a');

      final result = projectGoalStreak(
        scope: scope,
        events: [
          _completed(scope, 'key-a', '2026-07-01'),
          _completed(scope, 'key-b', '2026-07-01'),
        ],
        asOfDay: DateTime.utc(2026, 7, 1),
      );

      expect(result.currentStreak, 1);
      expect(result.completionCount, 1);
    });

    test('aynı event key farklı payload ile yeniden kullanılamaz', () {
      const scope = GoalStreakScope.personal('user-a');

      expect(
        () => projectGoalStreak(
          scope: scope,
          events: [
            _completed(scope, 'collision', '2026-07-01'),
            _completed(scope, 'collision', '2026-07-02'),
          ],
          asOfDay: DateTime.utc(2026, 7, 2),
        ),
        throwsStateError,
      );
    });

    test('tek kaçırma her defasında tekrar grace sağlar', () {
      const scope = GoalStreakScope.personal('user-a');
      final result = projectGoalStreak(
        scope: scope,
        events: [
          _completed(scope, 'd1', '2026-07-01'),
          _completed(scope, 'd3', '2026-07-03'),
          _completed(scope, 'd5', '2026-07-05'),
          _completed(scope, 'd7', '2026-07-07'),
        ],
        asOfDay: DateTime.utc(2026, 7, 7),
      );

      expect(result.currentStreak, 4);
      expect(result.state, GoalStreakState.completedToday);
    });

    test('dünkü tamamlama pending, önceki günkü tamamlama at-risk olur', () {
      const scope = GoalStreakScope.personal('user-a');
      final event = _completed(scope, 'd1', '2026-07-01');

      final pending = projectGoalStreak(
        scope: scope,
        events: [event],
        asOfDay: DateTime.utc(2026, 7, 2),
      );
      final atRisk = projectGoalStreak(
        scope: scope,
        events: [event],
        asOfDay: DateTime.utc(2026, 7, 3),
      );

      expect(pending.state, GoalStreakState.pendingToday);
      expect(pending.currentStreak, 1);
      expect(atRisk.state, GoalStreakState.atRisk);
      expect(atRisk.currentStreak, 1);
      expect(atRisk.isProtectedByAutomaticGrace, isTrue);
    });
  });
}

GoalStreakScope _scopeFrom(Map<String, dynamic> map) => GoalStreakScope(
  type: GoalStreakScopeType.fromWire(map['scopeType'] as String),
  id: map['scopeId'] as String,
  timeZone: map['timeZone'] as String,
);

GoalProgressEvent _eventFrom(
  Map<String, dynamic> map, {
  required GoalStreakScope fallbackScope,
}) {
  final scope = map.containsKey('scopeType')
      ? GoalStreakScope(
          type: GoalStreakScopeType.fromWire(map['scopeType'] as String),
          id: map['scopeId'] as String,
          timeZone: map['timeZone'] as String,
        )
      : fallbackScope;
  final day = map['day'] as String;
  return GoalProgressEvent(
    eventKey: map['key'] as String,
    scope: scope,
    kind: GoalProgressEventKind.fromWire(map['kind'] as String),
    goalDay: DateTime.parse(day),
    occurredAt: DateTime.parse('${day}T12:00:00Z'),
  );
}

GoalProgressEvent _completed(
  GoalStreakScope scope,
  String eventKey,
  String day,
) => GoalProgressEvent(
  eventKey: eventKey,
  scope: scope,
  kind: GoalProgressEventKind.goalCompleted,
  goalDay: DateTime.parse(day),
  occurredAt: DateTime.parse('${day}T12:00:00Z'),
);
