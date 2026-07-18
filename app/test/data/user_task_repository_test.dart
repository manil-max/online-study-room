import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/user_task.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_user_task_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_user_task_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('taskPeriodKey', () {
    test('daily uses Istanbul calendar day', () {
      // 2026-07-17 22:30 UTC = 2026-07-18 01:30 Istanbul (UTC+3)
      final instant = DateTime.utc(2026, 7, 17, 22, 30);
      final day = istanbulDay(instant);
      expect(day, DateTime(2026, 7, 18));
      expect(taskPeriodKey(TaskScope.daily, now: instant), 'd:2026-07-18');
    });

    test('weekly uses Monday startOfWeek', () {
      // 2026-07-18 is Saturday → week starts 2026-07-13
      final day = DateTime(2026, 7, 18);
      expect(startOfWeek(day), DateTime(2026, 7, 13));
      expect(taskPeriodKey(TaskScope.weekly, now: day), 'w:2026-07-13');
    });
  });

  group('InMemoryUserTaskRepository', () {
    test('add toggle remove + period isolation', () async {
      final repo = InMemoryUserTaskRepository();
      const user = 'u1';
      final dailyKey = taskPeriodKey(TaskScope.daily, now: DateTime(2026, 7, 18));
      final otherKey = 'd:2026-07-17';

      final t = UserTask(
        id: 'a',
        title: 'Pomodoro',
        scope: TaskScope.daily,
        completed: false,
        createdAt: DateTime.utc(2026, 7, 18),
        sortOrder: 0,
      );
      await repo.saveAll(
        userKey: user,
        scope: TaskScope.daily,
        periodKey: dailyKey,
        tasks: [t],
      );

      final loaded = await repo.load(
        userKey: user,
        scope: TaskScope.daily,
        periodKey: dailyKey,
      );
      expect(loaded.single.title, 'Pomodoro');

      final other = await repo.load(
        userKey: user,
        scope: TaskScope.daily,
        periodKey: otherKey,
      );
      expect(other, isEmpty);

      await repo.saveAll(
        userKey: user,
        scope: TaskScope.daily,
        periodKey: dailyKey,
        tasks: [
          t.copyWith(completed: true, completedAt: DateTime.utc(2026, 7, 18, 12)),
        ],
      );
      final done = await repo.load(
        userKey: user,
        scope: TaskScope.daily,
        periodKey: dailyKey,
      );
      expect(done.single.completed, isTrue);
    });

    test('clamps to max 20', () async {
      final repo = InMemoryUserTaskRepository();
      final tasks = [
        for (var i = 0; i < 25; i++)
          UserTask(
            id: 't$i',
            title: 'T$i',
            scope: TaskScope.weekly,
            completed: false,
            createdAt: DateTime.utc(2026, 7, 18),
            sortOrder: i,
          ),
      ];
      await repo.saveAll(
        userKey: 'u',
        scope: TaskScope.weekly,
        periodKey: 'w:2026-07-13',
        tasks: tasks,
      );
      final loaded = await repo.load(
        userKey: 'u',
        scope: TaskScope.weekly,
        periodKey: 'w:2026-07-13',
      );
      expect(loaded.length, UserTask.maxTasksPerPeriod);
    });
  });

  group('SupabaseUserTaskRepository prefs', () {
    test('persists across instances', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final a = SupabaseUserTaskRepository(prefs);
      final key = taskPeriodKey(TaskScope.daily, now: DateTime(2026, 7, 18));
      await a.saveAll(
        userKey: 'local',
        scope: TaskScope.daily,
        periodKey: key,
        tasks: [
          UserTask(
            id: 'x',
            title: 'Math',
            scope: TaskScope.daily,
            completed: false,
            createdAt: DateTime.utc(2026, 7, 18),
            sortOrder: 0,
          ),
        ],
      );
      final b = SupabaseUserTaskRepository(prefs);
      final loaded = await b.load(
        userKey: 'local',
        scope: TaskScope.daily,
        periodKey: key,
      );
      expect(loaded.single.title, 'Math');
    });
  });

  test('sortUserTasks open first then completed', () {
    final open = UserTask(
      id: '1',
      title: 'A',
      scope: TaskScope.daily,
      completed: false,
      createdAt: DateTime.utc(2026, 7, 18),
      sortOrder: 1,
    );
    final done = UserTask(
      id: '2',
      title: 'B',
      scope: TaskScope.daily,
      completed: true,
      createdAt: DateTime.utc(2026, 7, 18),
      sortOrder: 0,
    );
    final sorted = sortUserTasks([done, open]);
    expect(sorted.first.id, '1');
    expect(sorted.last.id, '2');
  });

  test('normalizeTitle', () {
    expect(UserTask.normalizeTitle('  '), isNull);
    expect(UserTask.normalizeTitle(' hi '), 'hi');
    expect(
      UserTask.normalizeTitle('x' * 100)!.length,
      UserTask.maxTitleLength,
    );
  });
}
