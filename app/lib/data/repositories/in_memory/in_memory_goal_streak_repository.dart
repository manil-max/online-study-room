import 'dart:async';

import '../../../core/stats/goal_streak_projection.dart';
import '../../models/goal_streak.dart';
import '../goal_streak_repository.dart';

class InMemoryGoalStreakRepository implements GoalStreakRepository {
  InMemoryGoalStreakRepository({
    Iterable<GoalProgressEvent> initialEvents = const [],
    DateTime Function()? now,
  }) : _events = {for (final event in initialEvents) event.eventKey: event},
       _now = now ?? DateTime.now;

  final Map<String, GoalProgressEvent> _events;
  final DateTime Function() _now;
  final StreamController<GoalStreakScope> _changes =
      StreamController<GoalStreakScope>.broadcast();

  /// Mirrors the server-owned ledger for offline/demo parity.
  ///
  /// This method intentionally is not part of [GoalStreakRepository], so
  /// feature code cannot mutate streak state through the shared abstraction.
  void ingestCanonicalEvent(GoalProgressEvent event) {
    final existing = _events[event.eventKey];
    if (existing != null) {
      projectGoalStreak(
        scope: event.scope,
        events: [existing, event],
        asOfDay: event.goalDay,
      );
      return;
    }
    _events[event.eventKey] = event;
    _changes.add(event.scope);
  }

  @override
  Future<GoalStreakProjection> readProjection(
    GoalStreakScope scope, {
    DateTime? asOfDay,
  }) async => _projection(scope, asOfDay: asOfDay);

  @override
  Stream<GoalStreakProjection> watchProjection(
    GoalStreakScope scope, {
    DateTime? asOfDay,
  }) async* {
    yield _projection(scope, asOfDay: asOfDay);
    await for (final changedScope in _changes.stream) {
      if (changedScope == scope) {
        yield _projection(scope, asOfDay: asOfDay);
      }
    }
  }

  GoalStreakProjection _projection(
    GoalStreakScope scope, {
    DateTime? asOfDay,
  }) => projectGoalStreak(
    scope: scope,
    events: _events.values,
    asOfDay: asOfDay ?? _now(),
  );

  Future<void> dispose() => _changes.close();
}
