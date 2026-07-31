import '../stats/istanbul_calendar.dart';
import '../../data/models/user_task.dart';
import 'task_recurrence.dart';

/// Görev listesinin anlaşılır bilgi mimarisi (WP-450).
///
/// Kullanıcı listeye baktığında ilk cevaplamak istediği soru "bugün ne
/// yapmalıyım?"dır. Tek düz liste bunu tekrarlanan ve ileri tarihli görevlerle
/// gizler; bu yüzden aktif görevler üç ayrık bölüme indirgenir.
enum TaskSection {
  /// Bugün İstanbul gününde işlem bekleyen görevler: bugünün occurrence'ı olan
  /// tekrarlananlar, bugün biten veya gecikmiş tek seferlikler.
  today,

  /// Tekrarlanan ama bugün sırası olmayan görevler; sıradaki occurrence günü
  /// gösterilir.
  recurring,

  /// Süresiz veya ileri tarihli tek seferlik görevler.
  other,
}

/// Bir görevin bölümü ve bölüme özgü türetilmiş günü.
class TaskSectionEntry {
  const TaskSectionEntry({
    required this.task,
    required this.section,
    this.nextOccurrenceDay,
  });

  final UserTask task;
  final TaskSection section;

  /// Yalnız [TaskSection.recurring] için doludur: sıradaki sabit occurrence.
  final DateTime? nextOccurrenceDay;
}

/// Aktif görevleri bölümlere ayırır.
///
/// Bugün tamamlanmış görev listeden düşmez; aynı satırdan geri alınabilmesi
/// için kendi bölümünde kalır (WP-450 undo sözleşmesi).
List<TaskSectionEntry> groupTasksBySection(
  List<UserTask> tasks,
  DateTime now,
) {
  final today = istanbulDay(now);
  final entries = <TaskSectionEntry>[];

  for (final task in tasks) {
    if (task.isArchived) continue;
    if (task.isRecurring) {
      if (isTaskCalendarOccurrenceDay(task, today)) {
        entries.add(
          TaskSectionEntry(task: task, section: TaskSection.today),
        );
      } else {
        entries.add(
          TaskSectionEntry(
            task: task,
            section: TaskSection.recurring,
            nextOccurrenceDay: nextTaskOccurrenceDay(task, now),
          ),
        );
      }
      continue;
    }

    final dueAt = task.dueAt;
    final dueDay = dueAt == null ? null : istanbulDay(dueAt);
    final dueToday = dueDay != null && !dueDay.isAfter(today);
    entries.add(
      TaskSectionEntry(
        task: task,
        section: dueToday ? TaskSection.today : TaskSection.other,
      ),
    );
  }

  return entries;
}

/// Tek bir bölümün görevlerini görüntüleme sırasına dizer.
///
/// Bugün: yakın bitiş önce, süresiz sonra. Tekrarlanan: en yakın occurrence
/// önce. Diğer: mevcut süre sıralaması. Tamamlanan satır bölümün sonuna iner ki
/// bekleyen iş üstte kalsın, ama satır kaybolmadığı için undo erişilebilir olur.
List<TaskSectionEntry> sortTaskSection(List<TaskSectionEntry> entries) {
  final sorted = [...entries];
  sorted.sort((a, b) {
    if (a.task.completed != b.task.completed) {
      return a.task.completed ? 1 : -1;
    }
    final aNext = a.nextOccurrenceDay;
    final bNext = b.nextOccurrenceDay;
    if (aNext != null && bNext != null && aNext != bNext) {
      return aNext.compareTo(bNext);
    }
    final aDue = a.task.dueAt;
    final bDue = b.task.dueAt;
    if (aDue != null && bDue != null && aDue != bDue) {
      return aDue.compareTo(bDue);
    }
    if (aDue == null && bDue != null) return 1;
    if (aDue != null && bDue == null) return -1;
    final order = a.task.sortOrder.compareTo(b.task.sortOrder);
    if (order != 0) return order;
    return a.task.createdAt.compareTo(b.task.createdAt);
  });
  return sorted;
}

/// [section] için hazır, sıralanmış görev listesi.
List<TaskSectionEntry> tasksInSection(
  List<TaskSectionEntry> entries,
  TaskSection section,
) => sortTaskSection([
  for (final entry in entries)
    if (entry.section == section) entry,
]);
