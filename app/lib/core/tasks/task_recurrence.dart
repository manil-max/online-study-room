import '../../data/models/user_task.dart';
import '../stats/istanbul_calendar.dart';

/// Sabit-fazlı görev recurrence sözleşmesi (WP-449).
///
/// Tekrarlanan bir görevin occurrence günleri:
///
/// `anchorDate + k * intervalDays`, `k >= 0`
///
/// Completion zamanı bu hesabın girdisi değildir. Böylece geç tamamlama,
/// çevrimdışı retry veya cihaz saatindeki ileri/geri değişim gelecekteki
/// occurrence'ları kaydırmaz.
DateTime taskRecurrenceAnchorDay(UserTask task) {
  final explicit = task.anchorDate;
  if (explicit != null) return _calendarDate(explicit);
  return istanbulDay(task.dueAt ?? task.createdAt);
}

/// [instant] anının Europe/Istanbul gününde bu görev occurrence üretir mi?
bool isTaskOccurrenceDay(UserTask task, DateTime instant) {
  return isTaskCalendarOccurrenceDay(task, istanbulDay(instant));
}

/// Tarih-only bir Europe/Istanbul gününü recurrence fazına karşı doğrular.
bool isTaskCalendarOccurrenceDay(UserTask task, DateTime day) {
  if (!task.isRecurring) return false;
  final delta = _dayOrdinal(day) - _dayOrdinal(taskRecurrenceAnchorDay(task));
  return delta >= 0 && delta % task.intervalDays == 0;
}

/// Tamamlama komutunun hedeflediği occurrence günü.
///
/// Tek seferlik görevler olayın İstanbul gününü hedefler. Tekrarlanan görevler
/// yalnız kendi sabit döngü günlerinde tamamlanabilir; döngü dışı günlerde null
/// dönerek istemci ve InMemory repository'nin yanlış occurrence kapatmasını
/// engeller.
DateTime? taskOccurrenceDayForCompletion(UserTask task, DateTime occurredAt) {
  final day = istanbulDay(occurredAt);
  if (!task.isRecurring) return day;
  return isTaskOccurrenceDay(task, occurredAt) ? day : null;
}

/// [instant] gününde veya sonrasında sıradaki sabit occurrence tarihi.
///
/// Eski occurrence'lar birikmez. Bugün döngü günüyse bugün; değilse doğrudan
/// bir sonraki `anchor + k*N` günü döner.
DateTime nextTaskOccurrenceDay(
  UserTask task,
  DateTime instant, {
  bool includeCurrentDay = true,
}) {
  if (!task.isRecurring) {
    throw ArgumentError.value(task.id, 'task', 'task_is_not_recurring');
  }

  final anchorOrdinal = _dayOrdinal(taskRecurrenceAnchorDay(task));
  var candidateOrdinal = _dayOrdinal(istanbulDay(instant));
  if (!includeCurrentDay) candidateOrdinal += 1;

  if (candidateOrdinal <= anchorOrdinal) {
    return _calendarDateFromOrdinal(anchorOrdinal);
  }

  final delta = candidateOrdinal - anchorOrdinal;
  final steps = (delta + task.intervalDays - 1) ~/ task.intervalDays;
  return _calendarDateFromOrdinal(anchorOrdinal + (steps * task.intervalDays));
}

/// Projection'daki completion yalnız sorulan occurrence'a mı ait?
bool isTaskOccurrenceCompleted(UserTask task, DateTime occurrenceDay) {
  if (!task.completed || task.completionDay == null) return false;
  final expected = _calendarDate(occurrenceDay);
  final actual = istanbulDay(task.completionDay!);
  return _dayOrdinal(actual) == _dayOrdinal(expected);
}

DateTime _calendarDate(DateTime value) =>
    DateTime(value.year, value.month, value.day);

int _dayOrdinal(DateTime value) => DateTime.utc(
  value.year,
  value.month,
  value.day,
).difference(DateTime.utc(1970)).inDays;

DateTime _calendarDateFromOrdinal(int ordinal) {
  final utc = DateTime.utc(1970).add(Duration(days: ordinal));
  return DateTime(utc.year, utc.month, utc.day);
}
