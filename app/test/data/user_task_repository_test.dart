import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/user_task.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_user_task_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_user_task_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('UserTask model v2', () {
    test('roundtrip map without scope', () {
      final t = UserTask(
        id: 'a',
        title: 'Market',
        dueAt: DateTime.utc(2026, 8, 28, 20, 59),
        completed: false,
        createdAt: DateTime.utc(2026, 7, 18),
        sortOrder: 1,
      );
      final back = UserTask.fromMap(t.toMap());
      expect(back.id, 'a');
      expect(back.title, 'Market');
      expect(back.dueAt, isNotNull);
      expect(back.completed, isFalse);
      expect(back.toMap().containsKey('scope'), isFalse);
    });

    test('normalizeTitle', () {
      expect(UserTask.normalizeTitle('  '), isNull);
      expect(UserTask.normalizeTitle(' hi '), 'hi');
      expect(UserTask.normalizeTitle('x' * 100)!.length, UserTask.maxTitleLength);
    });

    test('prefs key v2', () {
      expect(userTasksPrefsKey('u1'), 'user_tasks_v2.u1');
      expect(userTasksPrefsKey('local'), 'user_tasks_v2.local');
    });
  });

  group('InMemoryUserTaskRepository', () {
    test('single list per user (no period keys)', () async {
      final repo = InMemoryUserTaskRepository();
      final t = UserTask(
        id: 'a',
        title: 'Alışveriş',
        dueAt: DateTime.utc(2026, 8, 1),
        completed: false,
        createdAt: DateTime.utc(2026, 7, 18),
        sortOrder: 0,
      );
      await repo.saveAll(userKey: 'u1', tasks: [t]);
      final loaded = await repo.load(userKey: 'u1');
      expect(loaded.single.title, 'Alışveriş');
      expect(await repo.load(userKey: 'u2'), isEmpty);
    });

    test('clamps to maxTasks', () async {
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
      await repo.saveAll(userKey: 'u', tasks: tasks);
      final loaded = await repo.load(userKey: 'u');
      expect(loaded.length, UserTask.maxTasks);
    });
  });

  group('SupabaseUserTaskRepository prefs v2', () {
    test('persists across instances; ignores v1 keys', () async {
      SharedPreferences.setMockInitialValues({
        'user_tasks_v1.local.daily.d:2026-07-18': ['legacy'],
      });
      final prefs = await SharedPreferences.getInstance();
      final a = SupabaseUserTaskRepository(prefs);
      await a.saveAll(
        userKey: 'local',
        tasks: [
          UserTask(
            id: 'x',
            title: 'Math',
            completed: false,
            createdAt: DateTime.utc(2026, 7, 18),
            sortOrder: 0,
          ),
        ],
      );
      expect(prefs.getStringList('user_tasks_v2.local'), isNotNull);
      final b = SupabaseUserTaskRepository(prefs);
      final loaded = await b.load(userKey: 'local');
      expect(loaded.single.title, 'Math');
      // v1 hâlâ duruyor ama okunmuyor
      expect(prefs.getStringList('user_tasks_v1.local.daily.d:2026-07-18'),
          isNotNull);
    });
  });
}
