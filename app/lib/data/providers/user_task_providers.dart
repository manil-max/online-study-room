import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/supabase_config.dart';
import '../../core/prefs/app_prefs.dart';
import '../../core/tasks/task_deadline.dart';
import '../models/user_task.dart';
import '../repositories/supabase/supabase_user_task_repository.dart';
import '../repositories/user_task_repository.dart';
import 'auth_providers.dart';

final userTaskRepositoryProvider = Provider<UserTaskRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  if (SupabaseConfig.isConfigured) {
    return SupabaseUserTaskRepository(prefs);
  }
  return SupabaseUserTaskRepository(prefs);
});

String userTaskUserKey(Ref ref) {
  final id = ref.watch(authStateProvider).value?.id;
  return (id == null || id.isEmpty) ? 'local' : id;
}

/// Tüm görevler — dueAt sıralı (WP-197).
final userTasksProvider = FutureProvider<List<UserTask>>((ref) async {
  ref.watch(authStateProvider);
  final repo = ref.watch(userTaskRepositoryProvider);
  final list = await repo.load(userKey: userTaskUserKey(ref));
  return sortUserTasksByDue(list);
});

final userTaskActionsProvider = Provider<UserTaskActions>((ref) {
  return UserTaskActions(ref);
});

class UserTaskActions {
  UserTaskActions(this._ref);

  final Ref _ref;
  static const _uuid = Uuid();

  UserTaskRepository get _repo => _ref.read(userTaskRepositoryProvider);

  String get _userKey {
    final id = _ref.read(authStateProvider).value?.id;
    return (id == null || id.isEmpty) ? 'local' : id;
  }

  Future<List<UserTask>> _load() => _repo.load(userKey: _userKey);

  Future<void> _save(List<UserTask> tasks) async {
    await _repo.saveAll(userKey: _userKey, tasks: tasks);
    _ref.invalidate(userTasksProvider);
  }

  Future<UserTask?> add({
    required String rawTitle,
    DateTime? dueAt,
  }) async {
    final title = UserTask.normalizeTitle(rawTitle);
    if (title == null) return null;
    final current = await _load();
    if (current.length >= UserTask.maxTasks) return null;
    final now = DateTime.now().toUtc();
    final task = UserTask(
      id: _uuid.v4(),
      title: title,
      dueAt: dueAt?.toUtc(),
      completed: false,
      createdAt: now,
      sortOrder: current.length,
    );
    await _save([...current, task]);
    return task;
  }

  Future<void> update(UserTask task) async {
    final current = await _load();
    final next = [
      for (final t in current)
        if (t.id == task.id) task else t,
    ];
    await _save(next);
  }

  Future<void> toggle(String id) async {
    final current = await _load();
    final now = DateTime.now().toUtc();
    final next = [
      for (final t in current)
        if (t.id == id)
          t.copyWith(
            completed: !t.completed,
            completedAt: !t.completed ? now : null,
            clearCompletedAt: t.completed,
          )
        else
          t,
    ];
    await _save(next);
  }

  Future<void> remove(String id) async {
    final current = await _load();
    await _save([for (final t in current) if (t.id != id) t]);
  }
}
