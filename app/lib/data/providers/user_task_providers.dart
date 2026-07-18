import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/supabase_config.dart';
import '../../core/prefs/app_prefs.dart';
import '../models/user_task.dart';
import '../repositories/supabase/supabase_user_task_repository.dart';
import '../repositories/user_task_repository.dart';
import 'auth_providers.dart';

final userTaskRepositoryProvider = Provider<UserTaskRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  // v1: prefs mirror (InMemory unit testlerde override).
  // SupabaseConfig ileride gerçek PostgREST dalı için (şimdilik aynı store).
  if (SupabaseConfig.isConfigured) {
    return SupabaseUserTaskRepository(prefs);
  }
  return SupabaseUserTaskRepository(prefs);
});

/// Prefs / bellek izolasyonu anahtarı (hesap değişince ayrı liste).
String userTaskUserKey(Ref ref) {
  final id = ref.watch(authStateProvider).value?.id;
  return (id == null || id.isEmpty) ? 'local' : id;
}

/// Dönem listesi — okuma; mutasyonlar [userTaskActionsProvider] ile.
final userTasksProvider =
    FutureProvider.family<List<UserTask>, TaskScope>((ref, scope) async {
  ref.watch(authStateProvider);
  final repo = ref.watch(userTaskRepositoryProvider);
  final list = await repo.load(
    userKey: userTaskUserKey(ref),
    scope: scope,
    periodKey: taskPeriodKey(scope),
  );
  return sortUserTasks(list);
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

  Future<List<UserTask>> _load(TaskScope scope) {
    return _repo.load(
      userKey: _userKey,
      scope: scope,
      periodKey: taskPeriodKey(scope),
    );
  }

  Future<void> _save(TaskScope scope, List<UserTask> tasks) async {
    await _repo.saveAll(
      userKey: _userKey,
      scope: scope,
      periodKey: taskPeriodKey(scope),
      tasks: sortUserTasks(tasks),
    );
    _ref.invalidate(userTasksProvider(scope));
  }

  Future<UserTask?> add(TaskScope scope, String rawTitle) async {
    final title = UserTask.normalizeTitle(rawTitle);
    if (title == null) return null;
    final current = await _load(scope);
    if (current.length >= UserTask.maxTasksPerPeriod) return null;
    final now = DateTime.now().toUtc();
    final task = UserTask(
      id: _uuid.v4(),
      title: title,
      scope: scope,
      completed: false,
      createdAt: now,
      sortOrder: current.length,
    );
    await _save(scope, [...current, task]);
    return task;
  }

  Future<void> toggle(TaskScope scope, String id) async {
    final current = await _load(scope);
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
    await _save(scope, next);
  }

  Future<void> remove(TaskScope scope, String id) async {
    final current = await _load(scope);
    await _save(scope, [for (final t in current) if (t.id != id) t]);
  }
}
