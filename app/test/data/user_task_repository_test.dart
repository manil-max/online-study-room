import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/tasks/task_recurrence.dart';
import 'package:online_study_room/data/models/user_task.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_user_task_repository.dart';

void main() {
  group('UserTask cloud model', () {
    test('legacy map roundtrip remains compatible', () {
      final task = UserTask(
        id: 'a',
        title: 'Market',
        dueAt: DateTime.utc(2026, 8, 28, 20, 59),
        completed: false,
        createdAt: DateTime.utc(2026, 7, 18),
        sortOrder: 1,
        recurrence: UserTaskRecurrence.daily,
        intervalDays: 3,
        anchorDate: DateTime(2026, 7, 28),
      );
      final back = UserTask.fromMap(task.toMap());
      expect(back.id, 'a');
      expect(back.dueAt, isNotNull);
      expect(back.isRecurring, isTrue);
      expect(back.isDaily, isFalse);
      expect(back.intervalDays, 3);
      expect(back.anchorDate, DateTime(2026, 7, 28));
      expect(back.toCloudMap()['anchor_date'], '2026-07-28');
      expect(back.toMap().containsKey('scope'), isFalse);
    });

    test('legacy daily maps remain one-day compatible', () {
      final task = UserTask.fromMap({
        'id': 'legacy',
        'title': 'Günlük',
        'completed': false,
        'createdAt': '2026-07-29T21:30:00.000Z',
        'sortOrder': 0,
        'recurrence': 'daily',
      });

      expect(task.isDaily, isTrue);
      expect(task.intervalDays, 1);
      expect(task.anchorDate, isNull);
      expect(taskRecurrenceAnchorDay(task), DateTime(2026, 7, 30));
    });

    test('invalid interval data fails closed', () {
      expect(
        () => UserTask.fromMap({
          'id': 'broken',
          'title': 'Bozuk',
          'completed': false,
          'createdAt': '2026-07-30T00:00:00.000Z',
          'sortOrder': 0,
          'recurrence': 'daily',
          'interval_days': 0,
        }),
        throwsFormatException,
      );
    });

    test('title and local key contracts stay bounded', () {
      expect(UserTask.normalizeTitle('  '), isNull);
      expect(UserTask.normalizeTitle(' hi '), 'hi');
      expect(
        UserTask.normalizeTitle('x' * 100)!.length,
        UserTask.maxTitleLength,
      );
      expect(userTasksPrefsKey('u1'), 'user_tasks_v2.u1');
    });
  });

  group('InMemoryUserTaskRepository', () {
    test('users are isolated and max task count remains bounded', () async {
      final repo = InMemoryUserTaskRepository();
      final tasks = [
        for (var i = 0; i < UserTask.maxTasks + 10; i++)
          UserTask(
            id: 't$i',
            title: 'T$i',
            completed: false,
            createdAt: DateTime.utc(2026, 7, 18),
            sortOrder: i,
          ),
      ];
      await repo.saveAll(userKey: 'u1', tasks: tasks);
      expect((await repo.load(userKey: 'u1')).length, UserTask.maxTasks);
      expect(await repo.load(userKey: 'u2'), isEmpty);
    });

    test(
      'toggle/undo completion projection is the single task state',
      () async {
        final now = DateTime.utc(2026, 7, 30, 12);
        final occurrenceDay = DateTime(2026, 7, 30);
        final repo = InMemoryUserTaskRepository(now: () => now);
        const id = '00000000-0000-4000-8000-000000000001';
        final task = UserTask(
          id: id,
          title: 'Matematik',
          completed: false,
          createdAt: DateTime.utc(2026, 7, 18),
          sortOrder: 0,
          recurrence: UserTaskRecurrence.daily,
          intervalDays: 3,
          anchorDate: occurrenceDay,
        );
        await repo.upsert(userKey: 'u1', task: task, operationId: id);
        await repo.setCompleted(
          userKey: 'u1',
          taskId: id,
          completed: true,
          occurredAt: now,
          occurrenceDay: occurrenceDay,
          operationId: '00000000-0000-4000-8000-000000000002',
        );
        expect((await repo.load(userKey: 'u1')).single.completed, isTrue);
        await repo.setCompleted(
          userKey: 'u1',
          taskId: id,
          completed: false,
          occurredAt: now.add(const Duration(minutes: 1)),
          occurrenceDay: occurrenceDay,
          operationId: '00000000-0000-4000-8000-000000000003',
        );
        expect((await repo.load(userKey: 'u1')).single.completed, isFalse);
      },
    );

    test('same operation is idempotent, conflicting reuse fails', () async {
      final now = DateTime.utc(2026, 7, 30, 12);
      final day = DateTime(2026, 7, 30);
      final repo = InMemoryUserTaskRepository(now: () => now);
      final task = UserTask(
        id: 'task',
        title: 'Fizik',
        completed: false,
        createdAt: now,
        sortOrder: 0,
        recurrence: UserTaskRecurrence.daily,
        intervalDays: 3,
        anchorDate: day,
      );
      await repo.upsert(userKey: 'u1', task: task, operationId: 'create');

      Future<void> complete(bool completed) => repo.setCompleted(
        userKey: 'u1',
        taskId: task.id,
        completed: completed,
        occurredAt: now,
        occurrenceDay: day,
        operationId: 'same-operation',
      );

      await complete(true);
      await complete(true);
      expect((await repo.load(userKey: 'u1')).single.completed, isTrue);
      await expectLater(
        complete(false),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'task_operation_conflict',
          ),
        ),
      );
    });

    test('off-cycle completion is rejected and next day reopens', () async {
      var now = DateTime.utc(2026, 7, 30, 12);
      final repo = InMemoryUserTaskRepository(now: () => now);
      final task = UserTask(
        id: 'task',
        title: 'Fizik',
        completed: false,
        createdAt: now,
        sortOrder: 0,
        recurrence: UserTaskRecurrence.daily,
        intervalDays: 3,
        anchorDate: DateTime(2026, 7, 30),
      );
      await repo.upsert(userKey: 'u1', task: task, operationId: 'create');
      await repo.setCompleted(
        userKey: 'u1',
        taskId: task.id,
        completed: true,
        occurredAt: now,
        occurrenceDay: DateTime(2026, 7, 30),
        operationId: 'complete-july-30',
      );
      expect((await repo.load(userKey: 'u1')).single.completed, isTrue);

      now = DateTime.utc(2026, 7, 31, 12);
      expect((await repo.load(userKey: 'u1')).single.completed, isFalse);
      await expectLater(
        repo.setCompleted(
          userKey: 'u1',
          taskId: task.id,
          completed: true,
          occurredAt: now,
          occurrenceDay: DateTime(2026, 7, 31),
          operationId: 'off-cycle',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'task_occurrence_not_scheduled',
          ),
        ),
      );
    });
  });
}
