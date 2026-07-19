import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/supabase_config.dart';
import '../../core/prefs/app_prefs.dart';
import '../../core/tasks/task_deadline.dart';
import '../models/user_task.dart';
import '../repositories/supabase/supabase_user_task_repository.dart';
import '../repositories/in_memory/in_memory_user_task_repository.dart';
import '../repositories/user_task_repository.dart';
import 'auth_providers.dart';

final userTaskRepositoryProvider = Provider<UserTaskRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  if (SupabaseConfig.isConfigured) {
    return SupabaseUserTaskRepository(Supabase.instance.client, prefs);
  }
  return InMemoryUserTaskRepository();
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

  Future<UserTask?> add({required String rawTitle, DateTime? dueAt}) async {
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
    final saved = await _repo.upsert(
      userKey: _userKey,
      task: task,
      operationId: _uuid.v4(),
    );
    _ref.invalidate(userTasksProvider);
    return saved;
  }

  Future<void> update(UserTask task) async {
    await _repo.upsert(userKey: _userKey, task: task, operationId: _uuid.v4());
    _ref.invalidate(userTasksProvider);
  }

  Future<void> toggle(String id) async {
    final current = await _load();
    final task = current.where((item) => item.id == id).firstOrNull;
    if (task == null) return;
    final now = DateTime.now().toUtc();
    await _repo.setCompleted(
      userKey: _userKey,
      taskId: id,
      completed: !task.completed,
      occurredAt: now,
      operationId: _uuid.v4(),
    );
    _ref.invalidate(userTasksProvider);
  }

  Future<void> remove(String id) async {
    final current = await _load();
    final task = current.where((item) => item.id == id).firstOrNull;
    if (task == null) return;
    await _repo.upsert(
      userKey: _userKey,
      task: task,
      operationId: _uuid.v4(),
      archived: true,
    );
    _ref.invalidate(userTasksProvider);
  }
}
