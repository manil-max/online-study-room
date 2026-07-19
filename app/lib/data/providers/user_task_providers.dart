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

/// Bir görev mutasyonu (ekle/tamamla/sil) arka planda yazılırken hata verdiğinde
/// artan sayaç. UI bunu dinleyip kullanıcıya "senkron başarısız" uyarısı gösterir;
/// optimistic state zaten geri alınmış olur (WP-J).
final userTaskMutationErrorProvider =
    NotifierProvider<UserTaskMutationError, int>(UserTaskMutationError.new);

class UserTaskMutationError extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

/// Tüm görevler — daily üstte, sonra süreli/tek-sefer (WP-J).
///
/// AsyncNotifier: ekle/tamamla/sil/güncelle **optimistic** — state anında güncellenir,
/// yazma arka planda gider; hata olursa geri alınır + [userTaskMutationErrorProvider]
/// tetiklenir (item 5: ~1.5 sn algılanan gecikme kalkar).
final userTasksProvider =
    AsyncNotifierProvider<UserTasksNotifier, List<UserTask>>(
      UserTasksNotifier.new,
    );

class UserTasksNotifier extends AsyncNotifier<List<UserTask>> {
  static const _uuid = Uuid();

  @override
  Future<List<UserTask>> build() async {
    ref.watch(authStateProvider);
    final repo = ref.watch(userTaskRepositoryProvider);
    final list = await repo.load(userKey: userTaskUserKey(ref));
    return sortUserTasksByDue(list);
  }

  UserTaskRepository get _repo => ref.read(userTaskRepositoryProvider);

  String get _userKey {
    final id = ref.read(authStateProvider).value?.id;
    return (id == null || id.isEmpty) ? 'local' : id;
  }

  List<UserTask> get _current => state.value ?? const [];

  void _apply(List<UserTask> list) {
    state = AsyncData(sortUserTasksByDue(list));
  }

  void _signalError() {
    ref.read(userTaskMutationErrorProvider.notifier).bump();
  }

  /// Sunucudan taze yükle (gün sınırı / resume reconcile).
  Future<void> reload() async {
    state = await AsyncValue.guard(() async {
      final list = await _repo.load(userKey: _userKey);
      return sortUserTasksByDue(list);
    });
  }

  Future<UserTask?> add({
    required String rawTitle,
    DateTime? dueAt,
    UserTaskRecurrence recurrence = UserTaskRecurrence.once,
  }) async {
    final title = UserTask.normalizeTitle(rawTitle);
    if (title == null) return null;
    final current = _current;
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
    _apply([...current, task]); // optimistic
    try {
      final saved = await _repo.upsert(
        userKey: _userKey,
        task: task,
        operationId: _uuid.v4(),
      );
      _apply([
        for (final t in _current)
          if (t.id == task.id) saved else t,
      ]);
      return saved;
    } catch (_) {
      _apply([
        for (final t in _current)
          if (t.id != task.id) t,
      ]);
      _signalError();
      return null;
    }
  }

  Future<void> updateTask(UserTask task) async {
    final previous = _current;
    _apply([
      for (final t in previous)
        if (t.id == task.id) task else t,
    ]); // optimistic
    try {
      await _repo.upsert(
        userKey: _userKey,
        task: task,
        operationId: _uuid.v4(),
      );
    } catch (_) {
      _apply(previous);
      _signalError();
    }
  }

  Future<void> toggle(String id) async {
    final current = _current;
    final task = current.where((item) => item.id == id).firstOrNull;
    if (task == null) return;
    final now = DateTime.now().toUtc();
    final target = !task.completed;
    final optimistic = task.copyWith(
      completed: target,
      completedAt: target ? now : null,
      clearCompletedAt: !target,
    );
    _apply([
      for (final t in current)
        if (t.id == id) optimistic else t,
    ]); // optimistic
    try {
      await _repo.setCompleted(
        userKey: _userKey,
        taskId: id,
        completed: target,
        occurredAt: now,
        operationId: _uuid.v4(),
      );
    } catch (_) {
      _apply([
        for (final t in _current)
          if (t.id == id) task else t,
      ]);
      _signalError();
    }
  }

  Future<void> remove(String id) async {
    final current = _current;
    final task = current.where((item) => item.id == id).firstOrNull;
    if (task == null) return;
    _apply([
      for (final t in current)
        if (t.id != id) t,
    ]); // optimistic
    try {
      await _repo.upsert(
        userKey: _userKey,
        task: task,
        operationId: _uuid.v4(),
        archived: true,
      );
    } catch (_) {
      _apply(current);
      _signalError();
    }
  }
}

/// Geriye-uyumlu ince cephe: mevcut çağrı yerleri (kart/ekran/testler) bu API'yi
/// kullanmaya devam eder; gerçek iş [UserTasksNotifier]'da (optimistic) yürür.
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

  UserTasksNotifier get _notifier => _ref.read(userTasksProvider.notifier);

  Future<UserTask?> add({
    required String rawTitle,
    DateTime? dueAt,
    UserTaskRecurrence recurrence = UserTaskRecurrence.once,
  }) => _notifier.add(rawTitle: rawTitle, dueAt: dueAt, recurrence: recurrence);

  Future<void> update(UserTask task) => _notifier.updateTask(task);

  Future<void> toggle(String id) => _notifier.toggle(id);

  Future<void> remove(String id) => _notifier.remove(id);
}
