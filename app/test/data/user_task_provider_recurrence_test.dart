import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/tasks/task_recurrence.dart';
import 'package:online_study_room/data/models/user_task.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/user_task_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_user_task_repository.dart';
import 'package:online_study_room/data/repositories/user_task_repository.dart';

void main() {
  test(
    'provider sabit occurrence gününde tamamlar, ara günde reddeder',
    () async {
      var now = DateTime.utc(2026, 7, 30, 12);
      final repo = InMemoryUserTaskRepository(now: () => now);
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          userTaskRepositoryProvider.overrideWithValue(repo),
          userTaskClockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(container.dispose);

      await container.read(userTasksProvider.future);
      final task = await container
          .read(userTaskActionsProvider)
          .add(
            rawTitle: 'Fizik',
            recurrence: UserTaskRecurrence.daily,
            intervalDays: 3,
            anchorDate: DateTime(2026, 7, 30),
          );

      expect(task, isNotNull);
      expect(task!.intervalDays, 3);
      expect(task.anchorDate, DateTime(2026, 7, 30));

      await container.read(userTaskActionsProvider).toggle(task.id);
      expect(container.read(userTasksProvider).value!.single.completed, isTrue);

      now = DateTime.utc(2026, 7, 31, 12);
      await container.read(userTasksProvider.notifier).reload();
      expect(
        container.read(userTasksProvider).value!.single.completed,
        isFalse,
      );
      final errorsBefore = container.read(userTaskMutationErrorProvider);

      await container.read(userTaskActionsProvider).toggle(task.id);
      expect(
        container.read(userTasksProvider).value!.single.completed,
        isFalse,
      );
      expect(container.read(userTaskMutationErrorProvider), errorsBefore + 1);

      now = DateTime.utc(2026, 8, 2, 12);
      await container.read(userTasksProvider.notifier).reload();
      await container.read(userTaskActionsProvider).toggle(task.id);
      expect(container.read(userTasksProvider).value!.single.completed, isTrue);
    },
  );

  test("undo aynı occurrence'ı geri açar ve fazı kaydırmaz", () async {
    var now = DateTime.utc(2026, 7, 30, 12);
    final repo = InMemoryUserTaskRepository(now: () => now);
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        userTaskRepositoryProvider.overrideWithValue(repo),
        userTaskClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);

    await container.read(userTasksProvider.future);
    final task = await container
        .read(userTaskActionsProvider)
        .add(
          rawTitle: 'Kimya',
          recurrence: UserTaskRecurrence.daily,
          intervalDays: 3,
          anchorDate: DateTime(2026, 7, 30),
        );

    await container.read(userTaskActionsProvider).toggle(task!.id);
    expect(container.read(userTasksProvider).value!.single.completed, isTrue);

    await container.read(userTaskActionsProvider).toggle(task.id);
    final undone = container.read(userTasksProvider).value!.single;
    expect(undone.completed, isFalse);
    expect(undone.completedAt, isNull);
    // Geri alma yalnız o occurrence'ı açar; sabit faz aynı kalır.
    expect(undone.anchorDate, DateTime(2026, 7, 30));
    expect(
      nextTaskOccurrenceDay(undone, DateTime.utc(2026, 7, 31, 12)),
      DateTime(2026, 8, 2),
    );

    // Aynı gün yeniden tamamlama çift occurrence üretmez.
    await container.read(userTaskActionsProvider).toggle(task.id);
    final reloaded = await repo.load(userKey: 'local');
    expect(reloaded.single.completed, isTrue);
    expect(reloaded.length, 1);
  });

  test('cihaz saati geri alınsa da geçmiş occurrence açılmaz', () async {
    var now = DateTime.utc(2026, 8, 2, 12);
    final repo = InMemoryUserTaskRepository(now: () => now);
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        userTaskRepositoryProvider.overrideWithValue(repo),
        userTaskClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);

    await container.read(userTasksProvider.future);
    final task = await container
        .read(userTaskActionsProvider)
        .add(
          rawTitle: 'Biyoloji',
          recurrence: UserTaskRecurrence.daily,
          intervalDays: 3,
          anchorDate: DateTime(2026, 7, 30),
        );
    await container.read(userTaskActionsProvider).toggle(task!.id);
    expect(container.read(userTasksProvider).value!.single.completed, isTrue);

    // Kullanıcı cihaz saatini döngü dışı bir güne çeker.
    now = DateTime.utc(2026, 8, 1, 12);
    await container.read(userTasksProvider.notifier).reload();
    final errorsBefore = container.read(userTaskMutationErrorProvider);
    await container.read(userTaskActionsProvider).toggle(task.id);
    expect(container.read(userTasksProvider).value!.single.completed, isFalse);
    expect(container.read(userTaskMutationErrorProvider), errorsBefore + 1);

    // Saat geri geldiğinde sabit faz hâlâ 2 Ağustos'tur.
    now = DateTime.utc(2026, 8, 2, 12);
    await container.read(userTasksProvider.notifier).reload();
    final current = container.read(userTasksProvider).value!.single;
    expect(isTaskOccurrenceDay(current, now), isTrue);
  });

  test('çevrimdışı yazma hatası optimistic tamamlamayı geri alır', () async {
    final now = DateTime.utc(2026, 7, 30, 12);
    final inner = InMemoryUserTaskRepository(now: () => now);
    final repo = _OfflineOnCompletionRepository(inner);
    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(null)),
        userTaskRepositoryProvider.overrideWithValue(repo),
        userTaskClockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);

    await container.read(userTasksProvider.future);
    final task = await container
        .read(userTaskActionsProvider)
        .add(
          rawTitle: 'Matematik',
          recurrence: UserTaskRecurrence.daily,
          intervalDays: 3,
          anchorDate: DateTime(2026, 7, 30),
        );

    repo.offline = true;
    final errorsBefore = container.read(userTaskMutationErrorProvider);
    await container.read(userTaskActionsProvider).toggle(task!.id);
    expect(container.read(userTasksProvider).value!.single.completed, isFalse);
    expect(container.read(userTaskMutationErrorProvider), errorsBefore + 1);

    repo.offline = false;
    await container.read(userTaskActionsProvider).toggle(task.id);
    expect(container.read(userTasksProvider).value!.single.completed, isTrue);
    expect((await inner.load(userKey: 'local')).single.completed, isTrue);
  });
}

/// Tamamlama yazımında çevrimdışı olan repository; okuma ve upsert çalışır.
class _OfflineOnCompletionRepository implements UserTaskRepository {
  _OfflineOnCompletionRepository(this._inner);

  final InMemoryUserTaskRepository _inner;
  var offline = false;

  @override
  Future<List<UserTask>> load({required String userKey}) =>
      _inner.load(userKey: userKey);

  @override
  Future<void> saveAll({
    required String userKey,
    required List<UserTask> tasks,
  }) => _inner.saveAll(userKey: userKey, tasks: tasks);

  @override
  Future<UserTask> upsert({
    required String userKey,
    required UserTask task,
    required String operationId,
    bool archived = false,
  }) => _inner.upsert(
    userKey: userKey,
    task: task,
    operationId: operationId,
    archived: archived,
  );

  @override
  Future<void> setCompleted({
    required String userKey,
    required String taskId,
    required bool completed,
    required DateTime occurredAt,
    required DateTime occurrenceDay,
    required String operationId,
  }) async {
    if (offline) throw StateError('offline');
    await _inner.setCompleted(
      userKey: userKey,
      taskId: taskId,
      completed: completed,
      occurredAt: occurredAt,
      occurrenceDay: occurrenceDay,
      operationId: operationId,
    );
  }

  @override
  Future<void> migrateLegacy({
    required String userKey,
    required List<UserTask> tasks,
    required String migrationId,
  }) => _inner.migrateLegacy(
    userKey: userKey,
    tasks: tasks,
    migrationId: migrationId,
  );
}
