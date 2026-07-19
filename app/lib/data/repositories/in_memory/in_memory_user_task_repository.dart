import '../../models/user_task.dart';
import '../../../core/stats/istanbul_calendar.dart';
import '../user_task_repository.dart';

/// Bellek içi görev deposu (demo/test).
class InMemoryUserTaskRepository implements UserTaskRepository {
  final Map<String, List<UserTask>> _store = {};

  @override
  Future<List<UserTask>> load({required String userKey}) async {
    final list = _store[userKey];
    if (list == null) return const [];
    final today = istanbulDay(DateTime.now());
    return [
      for (final task in list)
        if (task.isDaily &&
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
    final next = task.copyWith(
      archivedAt: archived ? DateTime.now().toUtc() : null,
      updatedAt: DateTime.now().toUtc(),
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
    required String operationId,
  }) async {
    final current = await load(userKey: userKey);
    final index = current.indexWhere(
      (item) => item.id == taskId && !item.isArchived,
    );
    if (index < 0) throw StateError('task_not_found');
    final task = current[index];
    current[index] = task.copyWith(
      completed: completed,
      completedAt: completed ? occurredAt.toUtc() : null,
      clearCompletedAt: !completed,
      completionDay: occurredAt.toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    await saveAll(userKey: userKey, tasks: current);
  }

  @override
  Future<void> migrateLegacy({
    required String userKey,
    required List<UserTask> tasks,
    required String migrationId,
  }) => saveAll(userKey: userKey, tasks: tasks);

  void clear() => _store.clear();
}
