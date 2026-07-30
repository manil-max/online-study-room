import '../../data/models/goal_streak.dart';

const goalStreakProjectionSourceVersion = 'goal_completion_v1';

/// Server'ın ürettiği kanonik hedef olaylarından kişisel veya grup serisini
/// hesaplar. Uygulama açılışı, sayaç başlangıcı ve kısmi ilerleme olayları
/// bilinçli olarak seriye dahil edilmez.
GoalStreakProjection projectGoalStreak({
  required GoalStreakScope scope,
  required Iterable<GoalProgressEvent> events,
  required DateTime asOfDay,
}) {
  final normalizedAsOf = _day(asOfDay);
  final canonicalEvents = <String, GoalProgressEvent>{};

  for (final event in events) {
    final existing = canonicalEvents[event.eventKey];
    if (existing != null) {
      if (!_sameEvent(existing, event)) {
        throw StateError('Goal event key collision for ${event.eventKey}');
      }
      continue;
    }
    canonicalEvents[event.eventKey] = event;
  }

  final completedDays =
      canonicalEvents.values
          .where(
            (event) =>
                event.scope == scope &&
                event.kind == GoalProgressEventKind.goalCompleted &&
                !_day(event.goalDay).isAfter(normalizedAsOf),
          )
          .map((event) => _day(event.goalDay))
          .toSet()
          .toList(growable: false)
        ..sort();

  if (completedDays.isEmpty) {
    return GoalStreakProjection(
      scope: scope,
      asOfDay: normalizedAsOf,
      currentStreak: 0,
      completionCount: 0,
      state: GoalStreakState.empty,
      sourceVersion: goalStreakProjectionSourceVersion,
    );
  }

  var streak = 0;
  DateTime? previous;
  for (final day in completedDays) {
    if (previous == null || day.difference(previous).inDays > 2) {
      streak = 1;
    } else {
      streak += 1;
    }
    previous = day;
  }

  final lastCompletedDay = previous!;
  final distance = normalizedAsOf.difference(lastCompletedDay).inDays;
  final state = switch (distance) {
    0 => GoalStreakState.completedToday,
    1 => GoalStreakState.pendingToday,
    2 => GoalStreakState.atRisk,
    _ => GoalStreakState.expired,
  };

  return GoalStreakProjection(
    scope: scope,
    asOfDay: normalizedAsOf,
    currentStreak: distance <= 2 ? streak : 0,
    completionCount: completedDays.length,
    lastCompletedDay: lastCompletedDay,
    state: state,
    sourceVersion: goalStreakProjectionSourceVersion,
  );
}

DateTime _day(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

bool _sameEvent(GoalProgressEvent left, GoalProgressEvent right) =>
    left.scope == right.scope &&
    left.kind == right.kind &&
    _day(left.goalDay) == _day(right.goalDay) &&
    left.occurredAt.toUtc() == right.occurredAt.toUtc();
