import '../models/goal_streak.dart';

/// Goal streak state is read-only for app clients.
///
/// Canonical completion events are created by the server projection. Keeping a
/// mutation method out of this interface prevents app-open, timer-start or
/// partial-duration code from incrementing a streak directly.
abstract class GoalStreakRepository {
  Stream<GoalStreakProjection> watchProjection(
    GoalStreakScope scope, {
    DateTime? asOfDay,
  });

  Future<GoalStreakProjection> readProjection(
    GoalStreakScope scope, {
    DateTime? asOfDay,
  });
}
