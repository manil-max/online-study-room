import '../../models/user_task.dart';
import '../../../core/stats/istanbul_calendar.dart';
import '../../../core/tasks/task_recurrence.dart';
import '../user_task_repository.dart';

/// Bellek içi görev deposu (demo/test).
class InMemoryUserTaskRepository implements UserTaskRepository {
  InMemoryUserTaskRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Map<String, List<UserTask>> _store = {};
  final Map<String, Map<String, _CompletionMutation>> _completionOperations =
      {};
  final DateTime Function() _now;

  @override
  Future<List<UserTask>> load({required String userKey}) async {
    final list = _store[userKey];
    if (list == null) return const [];
    final today = istanbulDay(_now());
    return [
      for (final task in list)
        if (task.isRecurring &&
            task.completionDay != null &&
            istanbulDay(task.completionDay!) != today)
          task.copyWith(completed: false, clearCompletedAt: true)
        else
          task,
    ];
  }

  @override
  Future<void> saveAll({
    required String userKey,
    required List<UserTask> tasks,
  }) async {
    final clamped = tasks.take(UserTask.maxTasks).toList(growable: false);
    _store[userKey] = clamped;
  }

  @override
  Future<UserTask> upsert({
    required String userKey,
    required UserTask task,
    required String operationId,
    bool archived = false,
  }) async {
    final current = await load(userKey: userKey);
    final now = _now().toUtc();
    final next = task.copyWith(
      archivedAt: archived ? now : null,
      updatedAt: now,
    );
    final found = current.indexWhere((item) => item.id == task.id);
    if (found < 0) {
      if (current.where((item) => !item.isArchived).length >=
          UserTask.maxTasks) {
        throw StateError('task_limit_reached');
      }
      await saveAll(userKey: userKey, tasks: [...current, next]);
    } else {
      current[found] = next;
      await saveAll(userKey: userKey, tasks: current);
    }
    return next;
  }

  @override
  Future<void> setCompleted({
    required String userKey,
    required String taskId,
    required bool completed,
    required DateTime occurredAt,
    required DateTime occurrenceDay,
    required String operationId,
  }) async {
    final normalizedOccurrence = DateTime(
      occurrenceDay.year,
      occurrenceDay.month,
      occurrenceDay.day,
    );
    final mutation = _CompletionMutation(
      taskId: taskId,
      completed: completed,
      occurredAt: occurredAt.toUtc(),
      occurrenceDay: normalizedOccurrence,
    );
    final operations = _completionOperations.putIfAbsent(userKey, () => {});
    final previous = operations[operationId];
    if (previous != null) {
      if (previous != mutation) {
        throw StateError('task_operation_conflict');
      }
      return;
    }

    final current = await load(userKey: userKey);
    final index = current.indexWhere(
      (item) => item.id == taskId && !item.isArchived,
    );
    if (index < 0) throw StateError('task_not_found');
    final task = current[index];
    final eventDay = istanbulDay(occurredAt);
    if (eventDay != normalizedOccurrence) {
      throw StateError('task_occurrence_day_mismatch');
    }
    if (task.isRecurring &&
        !isTaskCalendarOccurrenceDay(task, normalizedOccurrence)) {
      throw StateError('task_occurrence_not_scheduled');
    }

    current[index] = task.copyWith(
      completed: completed,
      completedAt: completed ? occurredAt.toUtc() : null,
      clearCompletedAt: !completed,
      completionDay: _completionDayInstant(normalizedOccurrence),
      updatedAt: _now().toUtc(),
    );
    await saveAll(userKey: userKey, tasks: current);
    operations[operationId] = mutation;
  }

  @override
  Future<void> migrateLegacy({
    required String userKey,
    required List<UserTask> tasks,
    required String migrationId,
  }) => saveAll(userKey: userKey, tasks: tasks);

  void clear() {
    _store.clear();
    _completionOperations.clear();
  }
}

DateTime _completionDayInstant(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day, 12);

class _CompletionMutation {
  const _CompletionMutation({
    required this.taskId,
    required this.completed,
    required this.occurredAt,
    required this.occurrenceDay,
  });

  final String taskId;
  final bool completed;
  final DateTime occurredAt;
  final DateTime occurrenceDay;

  @override
  bool operator ==(Object other) =>
      other is _CompletionMutation &&
      other.taskId == taskId &&
      other.completed == completed &&
      other.occurredAt == occurredAt &&
      other.occurrenceDay == occurrenceDay;

  @override
  int get hashCode => Object.hash(taskId, completed, occurredAt, occurrenceDay);
}
