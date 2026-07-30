import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/goal_streak.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_goal_streak_repository.dart';

void main() {
  const personal = GoalStreakScope.personal('user-a');
  const group = GoalStreakScope.group(
    groupId: 'group-a',
    timeZone: 'America/New_York',
  );

  test(
    'watch yalnız ilgili scope canonical eventleriyle güncellenir',
    () async {
      final repository = InMemoryGoalStreakRepository(
        now: () => DateTime.utc(2026, 7, 3),
      );
      addTearDown(repository.dispose);
      final valuesFuture = repository
          .watchProjection(personal)
          .take(2)
          .toList();
      await Future<void>.delayed(Duration.zero);

      repository.ingestCanonicalEvent(
        _completed(group, 'group-1', '2026-07-03'),
      );
      repository.ingestCanonicalEvent(
        _completed(personal, 'personal-1', '2026-07-03'),
      );
      final values = await valuesFuture;

      expect(values.first.currentStreak, 0);
      expect(values.last.currentStreak, 1);
      expect(values.last.scope, personal);
    },
  );

  test('canonical retry yayın ve seri sayısını çoğaltmaz', () async {
    final event = _completed(personal, 'personal-1', '2026-07-03');
    final repository = InMemoryGoalStreakRepository(
      initialEvents: [event],
      now: () => DateTime.utc(2026, 7, 3),
    );
    addTearDown(repository.dispose);

    repository.ingestCanonicalEvent(event);
    final result = await repository.readProjection(personal);

    expect(result.currentStreak, 1);
    expect(result.completionCount, 1);
  });
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
