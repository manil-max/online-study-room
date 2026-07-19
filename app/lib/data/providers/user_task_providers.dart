import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

import '../../core/config/supabase_config.dart';
import '../../core/prefs/app_prefs.dart';
import '../../core/stats/istanbul_calendar.dart';
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

/// Tek container-ömürlü İstanbul gün sınırı/app-resume invalidation kaynağı.
/// Home kartı ve Araçlar ekranı aynı instance'ı izlediği için çift timer yoktur.
final userTaskDayRefreshLifecycleProvider =
    Provider<UserTaskDayRefreshLifecycle>((ref) {
      final lifecycle = UserTaskDayRefreshLifecycle(ref)..start();
      ref.onDispose(lifecycle.dispose);
      return lifecycle;
    });

class UserTaskDayRefreshLifecycle with WidgetsBindingObserver {
  UserTaskDayRefreshLifecycle(this._ref);

  final Ref _ref;
  Timer? _timer;
  var _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _ref.invalidate(userTasksProvider);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final localNow = istanbulNow();
    final location = tz.getLocation('Europe/Istanbul');
    final nextDay = tz.TZDateTime(
      location,
      localNow.year,
      localNow.month,
      localNow.day + 1,
    );
    final delay = nextDay.toUtc().difference(DateTime.now().toUtc());
    _timer = Timer(delay + const Duration(milliseconds: 100), () {
      _ref.invalidate(userTasksProvider);
      _schedule();
    });
  }

  void dispose() {
    if (!_started) return;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    _started = false;
  }
}

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

  Future<UserTask?> add({
    required String rawTitle,
    DateTime? dueAt,
    UserTaskRecurrence recurrence = UserTaskRecurrence.once,
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
      recurrence: recurrence,
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
