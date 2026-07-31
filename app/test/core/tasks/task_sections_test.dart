import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/tasks/task_sections.dart';
import 'package:online_study_room/data/models/user_task.dart';

UserTask _task({
  required String id,
  UserTaskRecurrence recurrence = UserTaskRecurrence.once,
  int intervalDays = 1,
  DateTime? anchorDate,
  DateTime? dueAt,
  bool completed = false,
  DateTime? completionDay,
  int sortOrder = 0,
}) => UserTask(
  id: id,
  title: id,
  dueAt: dueAt,
  completed: completed,
  createdAt: DateTime.utc(2026, 7, 1),
  sortOrder: sortOrder,
  recurrence: recurrence,
  intervalDays: intervalDays,
  anchorDate: anchorDate,
  completionDay: completionDay,
);

void main() {
  final now = DateTime.utc(2026, 7, 30, 9);

  test('bugünün occurrence\'ı Bugün bölümündedir', () {
    final entries = groupTasksBySection([
      _task(
        id: 'fizik',
        recurrence: UserTaskRecurrence.daily,
        intervalDays: 3,
        anchorDate: DateTime(2026, 7, 27),
      ),
    ], now);

    expect(entries.single.section, TaskSection.today);
    expect(entries.single.nextOccurrenceDay, isNull);
  });

  test('sırası gelmemiş tekrarlanan görev sıradaki günüyle ayrı bölümdedir', () {
    final entries = groupTasksBySection([
      _task(
        id: 'kimya',
        recurrence: UserTaskRecurrence.daily,
        intervalDays: 3,
        anchorDate: DateTime(2026, 7, 29),
      ),
    ], now);

    expect(entries.single.section, TaskSection.recurring);
    expect(entries.single.nextOccurrenceDay, DateTime(2026, 8, 1));
  });

  test('gecikmiş ve bugün biten tek seferlikler Bugün, ileri tarihli Diğer', () {
    final entries = groupTasksBySection([
      _task(id: 'gecikmis', dueAt: DateTime.utc(2026, 7, 28, 10)),
      _task(id: 'bugun', dueAt: DateTime.utc(2026, 7, 30, 20)),
      _task(id: 'ileri', dueAt: DateTime.utc(2026, 8, 5, 10)),
      _task(id: 'suresiz'),
    ], now);

    Set<String> idsIn(TaskSection section) => {
      for (final entry in entries)
        if (entry.section == section) entry.task.id,
    };

    expect(idsIn(TaskSection.today), {'gecikmis', 'bugun'});
    expect(idsIn(TaskSection.other), {'ileri', 'suresiz'});
    expect(idsIn(TaskSection.recurring), isEmpty);
  });

  test('bugün tamamlanan satır bölümde kalır ve sona iner', () {
    final entries = groupTasksBySection([
      _task(
        id: 'tamamlanan',
        recurrence: UserTaskRecurrence.daily,
        intervalDays: 3,
        anchorDate: DateTime(2026, 7, 30),
        completed: true,
        completionDay: DateTime.utc(2026, 7, 30, 12),
      ),
      _task(
        id: 'bekleyen',
        recurrence: UserTaskRecurrence.daily,
        intervalDays: 1,
        anchorDate: DateTime(2026, 7, 1),
      ),
    ], now);

    final today = tasksInSection(entries, TaskSection.today);
    // Undo yalnız satır listede kaldığı sürece mümkündür.
    expect(today.map((entry) => entry.task.id), ['bekleyen', 'tamamlanan']);
  });

  test('tekrarlanan bölümü en yakın occurrence gününe göre sıralanır', () {
    final entries = groupTasksBySection([
      _task(
        id: 'uzak',
        recurrence: UserTaskRecurrence.daily,
        intervalDays: 7,
        anchorDate: DateTime(2026, 7, 29),
      ),
      _task(
        id: 'yakin',
        recurrence: UserTaskRecurrence.daily,
        intervalDays: 2,
        anchorDate: DateTime(2026, 7, 29),
      ),
    ], now);

    final recurring = tasksInSection(entries, TaskSection.recurring);
    expect(recurring.map((entry) => entry.task.id), ['yakin', 'uzak']);
    expect(recurring.first.nextOccurrenceDay, DateTime(2026, 7, 31));
    expect(recurring.last.nextOccurrenceDay, DateTime(2026, 8, 5));
  });

  test('arşivlenmiş görev hiçbir bölümde görünmez', () {
    final archived = UserTask(
      id: 'silinmis',
      title: 'silinmis',
      completed: false,
      createdAt: DateTime.utc(2026, 7, 1),
      sortOrder: 0,
      archivedAt: DateTime.utc(2026, 7, 20),
    );
    expect(groupTasksBySection([archived], now), isEmpty);
  });
}
