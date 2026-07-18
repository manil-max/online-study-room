import '../../models/user_task.dart';
import '../user_task_repository.dart';

/// Bellek içi görev deposu (demo/test).
class InMemoryUserTaskRepository implements UserTaskRepository {
  final Map<String, List<UserTask>> _store = {};

  String _key(String userKey, TaskScope scope, String periodKey) =>
      '$userKey|${scope.name}|$periodKey';

  @override
  Future<List<UserTask>> load({
    required String userKey,
    required TaskScope scope,
    required String periodKey,
  }) async {
    final list = _store[_key(userKey, scope, periodKey)];
    if (list == null) return const [];
    return sortUserTasks(List<UserTask>.from(list));
  }

  @override
  Future<void> saveAll({
    required String userKey,
    required TaskScope scope,
    required String periodKey,
    required List<UserTask> tasks,
  }) async {
    final clamped = sortUserTasks(tasks)
        .take(UserTask.maxTasksPerPeriod)
        .toList(growable: false);
    _store[_key(userKey, scope, periodKey)] = clamped;
  }

  void clear() => _store.clear();
}
