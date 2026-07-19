import 'package:flutter_test/flutter_test.dart';
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
      );
      final back = UserTask.fromMap(task.toMap());
      expect(back.id, 'a');
      expect(back.dueAt, isNotNull);
      expect(back.isDaily, isTrue);
      expect(back.toMap().containsKey('scope'), isFalse);
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
        final repo = InMemoryUserTaskRepository();
        const id = '00000000-0000-4000-8000-000000000001';
        final task = UserTask(
          id: id,
          title: 'Matematik',
          completed: false,
          createdAt: DateTime.utc(2026, 7, 18),
          sortOrder: 0,
          recurrence: UserTaskRecurrence.daily,
        );
        await repo.upsert(userKey: 'u1', task: task, operationId: id);
        await repo.setCompleted(
          userKey: 'u1',
          taskId: id,
          completed: true,
          occurredAt: DateTime.utc(2026, 7, 19, 12),
          operationId: '00000000-0000-4000-8000-000000000002',
        );
        expect((await repo.load(userKey: 'u1')).single.completed, isTrue);
        await repo.setCompleted(
          userKey: 'u1',
          taskId: id,
          completed: false,
          occurredAt: DateTime.utc(2026, 7, 19, 12, 1),
          operationId: '00000000-0000-4000-8000-000000000003',
        );
        expect((await repo.load(userKey: 'u1')).single.completed, isFalse);
      },
    );
  });
}
