import '../../models/user_task.dart';
import '../user_task_repository.dart';

/// Bellek içi görev deposu (demo/test).
class InMemoryUserTaskRepository implements UserTaskRepository {
  final Map<String, List<UserTask>> _store = {};

  @override
  Future<List<UserTask>> load({required String userKey}) async {
    final list = _store[userKey];
    if (list == null) return const [];
    return List<UserTask>.from(list);
  }

  @override
  Future<void> saveAll({
    required String userKey,
    required List<UserTask> tasks,
  }) async {
    final clamped = tasks.take(UserTask.maxTasks).toList(growable: false);
    _store[userKey] = clamped;
  }

  void clear() => _store.clear();
}
