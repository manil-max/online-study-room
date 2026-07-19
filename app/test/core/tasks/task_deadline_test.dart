import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';
import 'package:online_study_room/core/tasks/task_deadline.dart';
import 'package:online_study_room/data/models/user_task.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  group('dueAtFromCalendarDate', () {
    test('Istanbul day end 23:59 local', () {
      // 2026-08-28 calendar → 28 Ağustos 23:59 Istanbul
      final due = dueAtFromCalendarDate(DateTime(2026, 8, 28));
      final loc = tz.getLocation('Europe/Istanbul');
      final local = tz.TZDateTime.from(due, loc);
      expect(local.year, 2026);
      expect(local.month, 8);
      expect(local.day, 28);
      expect(local.hour, 23);
      expect(local.minute, 59);
    });

    test('UTC evening still maps to Istanbul calendar day end', () {
      // 2026-07-17 22:30 UTC = 2026-07-18 Istanbul
      final instant = DateTime.utc(2026, 7, 17, 22, 30);
      final day = istanbulDay(instant);
      expect(day, DateTime(2026, 7, 18));
      final due = dueAtFromCalendarDate(instant);
      final local = tz.TZDateTime.from(due, tz.getLocation('Europe/Istanbul'));
      expect(local.day, 18);
      expect(local.hour, 23);
    });
  });

  group('dueAtFromRemaining', () {
    test('adds duration to now', () {
      final now = DateTime.utc(2026, 7, 18, 12);
      final due = dueAtFromRemaining(const Duration(hours: 3), now: now);
      expect(due, DateTime.utc(2026, 7, 18, 15));
    });
  });

  group('sortUserTasksByDue', () {
    UserTask t({
      required String id,
      DateTime? due,
      bool done = false,
      int order = 0,
      bool daily = false,
    }) =>
        UserTask(
          id: id,
          title: id,
          dueAt: due,
          completed: done,
          createdAt: DateTime.utc(2026, 7, 1),
          sortOrder: order,
          recurrence:
              daily ? UserTaskRecurrence.daily : UserTaskRecurrence.once,
        );

    test('nearest due first; null last; completed after active', () {
      final a = t(id: 'soon', due: DateTime.utc(2026, 7, 19));
      final b = t(id: 'later', due: DateTime.utc(2026, 7, 25));
      final c = t(id: 'none', due: null);
      final d = t(id: 'done', due: DateTime.utc(2026, 7, 18), done: true);
      final sorted = sortUserTasksByDue([c, b, d, a]);
      expect(sorted.map((e) => e.id).toList(), ['soon', 'later', 'none', 'done']);
    });

    test('daily görevler süreli/tek-sefer görevlerin üstünde (WP-J)', () {
      final timedSoon = t(id: 'timed', due: DateTime.utc(2026, 7, 19));
      final once = t(id: 'once', due: null);
      final dailyA = t(id: 'dailyA', daily: true, order: 1);
      final dailyDone = t(id: 'dailyDone', daily: true, done: true, order: 0);
      final sorted =
          sortUserTasksByDue([timedSoon, once, dailyDone, dailyA]);
      // Önce günlükler (aktif → tamamlanmış), sonra süreli, en sonda süresiz.
      expect(
        sorted.map((e) => e.id).toList(),
        ['dailyA', 'dailyDone', 'timed', 'once'],
      );
    });
  });

  group('taskUrgencyColor / kind', () {
    final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);
    final now = DateTime.utc(2026, 7, 18, 12);

    test('null due is neutral kind', () {
      expect(taskUrgencyKind(now, null), TaskUrgencyKind.none);
    });

    test('overdue is overdue kind and red-ish', () {
      final past = DateTime.utc(2026, 7, 18, 10);
      expect(taskUrgencyKind(now, past), TaskUrgencyKind.overdue);
      expect(isTaskOverdue(now, past), isTrue);
      final c = taskUrgencyColor(now, past, scheme);
      expect(c.r, greaterThan(0.5));
    });

    test('far future calm', () {
      final far = now.add(const Duration(days: 14));
      expect(taskUrgencyKind(now, far), TaskUrgencyKind.calm);
    });

    test('under 6h urgent', () {
      final near = now.add(const Duration(hours: 2));
      expect(taskUrgencyKind(now, near), TaskUrgencyKind.urgent);
    });
  });
}
