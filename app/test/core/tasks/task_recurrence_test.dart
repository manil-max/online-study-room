import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/tasks/task_recurrence.dart';
import 'package:online_study_room/data/models/user_task.dart';

void main() {
  UserTask recurring({
    required String id,
    required DateTime anchor,
    int intervalDays = 3,
    DateTime? completedAt,
    DateTime? completionDay,
  }) {
    return UserTask(
      id: id,
      title: id,
      completed: completedAt != null,
      createdAt: DateTime.utc(2026, 7, 27, 9),
      completedAt: completedAt,
      completionDay: completionDay,
      sortOrder: 0,
      recurrence: UserTaskRecurrence.daily,
      intervalDays: intervalDays,
      anchorDate: anchor,
    );
  }

  group('sabit fazlı recurrence', () {
    test('üç ayrı anchor Fizik-Kimya-Biyoloji fazını korur', () {
      final physics = recurring(id: 'Fizik', anchor: DateTime(2026, 7, 27));
      final chemistry = recurring(id: 'Kimya', anchor: DateTime(2026, 7, 28));
      final biology = recurring(id: 'Biyoloji', anchor: DateTime(2026, 7, 29));

      expect(
        nextTaskOccurrenceDay(physics, DateTime.utc(2026, 7, 29, 12)),
        DateTime(2026, 7, 30),
      );
      expect(
        nextTaskOccurrenceDay(chemistry, DateTime.utc(2026, 7, 29, 12)),
        DateTime(2026, 7, 31),
      );
      expect(
        nextTaskOccurrenceDay(biology, DateTime.utc(2026, 7, 29, 12)),
        DateTime(2026, 7, 29),
      );
    });

    test('completion zamanı gelecekteki fazı kaydırmaz', () {
      final task = recurring(
        id: 'Fizik',
        anchor: DateTime(2026, 7, 30),
        completedAt: DateTime.utc(2026, 7, 30, 20, 55),
        completionDay: DateTime.utc(2026, 7, 30, 12),
      );

      expect(
        nextTaskOccurrenceDay(task, DateTime.utc(2026, 7, 31, 12)),
        DateTime(2026, 8, 2),
      );
      expect(
        nextTaskOccurrenceDay(task, DateTime.utc(2026, 8, 20, 12)),
        DateTime(2026, 8, 20),
      );
    });

    test('kaçırılan occurrence birikmez, bugün veya sıradaki gün seçilir', () {
      final task = recurring(
        id: 'Fizik',
        anchor: DateTime(2026, 7, 1),
        intervalDays: 7,
      );

      expect(
        nextTaskOccurrenceDay(task, DateTime.utc(2026, 7, 20, 12)),
        DateTime(2026, 7, 22),
      );
      expect(
        nextTaskOccurrenceDay(task, DateTime.utc(2026, 7, 22, 12)),
        DateTime(2026, 7, 22),
      );
      expect(
        nextTaskOccurrenceDay(
          task,
          DateTime.utc(2026, 7, 22, 12),
          includeCurrentDay: false,
        ),
        DateTime(2026, 7, 29),
      );
    });

    test('1-gün recurrence mevcut günlük davranışı korur', () {
      final task = recurring(
        id: 'Günlük',
        anchor: DateTime(2026, 7, 1),
        intervalDays: 1,
      );

      expect(isTaskOccurrenceDay(task, DateTime.utc(2026, 7, 30, 12)), isTrue);
      expect(
        nextTaskOccurrenceDay(task, DateTime.utc(2026, 8, 1, 12)),
        DateTime(2026, 8, 1),
      );
    });
  });

  group('Europe/Istanbul gün sınırı', () {
    test('23:59 occurrence, 00:01 ertesi gündür', () {
      final task = recurring(id: 'Fizik', anchor: DateTime(2026, 7, 30));
      final beforeMidnight = DateTime.utc(2026, 7, 30, 20, 59);
      final afterMidnight = DateTime.utc(2026, 7, 30, 21, 1);

      expect(isTaskOccurrenceDay(task, beforeMidnight), isTrue);
      expect(
        taskOccurrenceDayForCompletion(task, beforeMidnight),
        DateTime(2026, 7, 30),
      );
      expect(isTaskOccurrenceDay(task, afterMidnight), isFalse);
      expect(taskOccurrenceDayForCompletion(task, afterMidnight), isNull);
      expect(nextTaskOccurrenceDay(task, afterMidnight), DateTime(2026, 8, 2));
    });

    test('completion projection yalnız aynı occurrence gününü kapatır', () {
      final task = recurring(
        id: 'Fizik',
        anchor: DateTime(2026, 7, 30),
        completedAt: DateTime.utc(2026, 7, 30, 18),
        completionDay: DateTime.utc(2026, 7, 30, 12),
      );

      expect(isTaskOccurrenceCompleted(task, DateTime(2026, 7, 30)), isTrue);
      expect(isTaskOccurrenceCompleted(task, DateTime(2026, 8, 2)), isFalse);
    });
  });
}
