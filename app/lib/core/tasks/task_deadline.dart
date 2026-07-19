import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:online_study_room/l10n/app_localizations.dart';

import '../stats/istanbul_calendar.dart';
import '../../data/models/user_task.dart';

/// Europe/Istanbul gününün sonu (23:59:59.999 local → UTC).
DateTime dueAtFromCalendarDate(DateTime calendarDay, {DateTime? now}) {
  final day = istanbulDay(calendarDay);
  final loc = tz.getLocation('Europe/Istanbul');
  final endLocal = tz.TZDateTime(
    loc,
    day.year,
    day.month,
    day.day,
    23,
    59,
    59,
    999,
  );
  return endLocal.toUtc();
}

/// Şimdi + süre (UTC).
DateTime dueAtFromRemaining(Duration remaining, {DateTime? now}) {
  final n = now ?? DateTime.now();
  return n.toUtc().add(remaining);
}

/// Aktif liste sırası (WP-J):
/// 1. Günlük (daily) görevler her zaman üstte, süreli/tek-sefer altta.
/// 2. Her grup içinde tamamlananlar sona.
/// 3. dueAt artan; null en sona; eşitlikte sortOrder/createdAt.
List<UserTask> sortUserTasksByDue(List<UserTask> tasks) {
  final copy = [...tasks];
  copy.sort((a, b) {
    if (a.isDaily != b.isDaily) return a.isDaily ? -1 : 1;
    if (a.completed != b.completed) return a.completed ? 1 : -1;
    final ad = a.dueAt;
    final bd = b.dueAt;
    if (ad == null && bd == null) {
      final o = a.sortOrder.compareTo(b.sortOrder);
      if (o != 0) return o;
      return a.createdAt.compareTo(b.createdAt);
    }
    if (ad == null) return 1;
    if (bd == null) return -1;
    final c = ad.compareTo(bd);
    if (c != 0) return c;
    final o = a.sortOrder.compareTo(b.sortOrder);
    if (o != 0) return o;
    return a.createdAt.compareTo(b.createdAt);
  });
  return copy;
}

/// Gecikmiş mi? (dueAt < now, tamamlanmamış varsayımı çağıranda).
bool isTaskOverdue(DateTime now, DateTime? dueAt) {
  if (dueAt == null) return false;
  return dueAt.toUtc().isBefore(now.toUtc());
}

/// Kalan süre spektrumu (WP-197).
///
/// - süresiz: nötr outline
/// - gecikti: güçlü kırmızı
/// - >7g: sakin primary
/// - ~1–7g: sarı→turuncu lerp
/// - <24s: turuncu→kırmızı
Color taskUrgencyColor(
  DateTime now,
  DateTime? dueAt,
  ColorScheme scheme,
) {
  if (dueAt == null) {
    return scheme.onSurfaceVariant;
  }
  final n = now.toUtc();
  final d = dueAt.toUtc();
  if (d.isBefore(n)) {
    return const Color(0xFFB91C1C); // koyu kırmızı
  }
  final hours = d.difference(n).inMinutes / 60.0;
  if (hours >= 7 * 24) {
    return scheme.primary;
  }
  if (hours >= 24) {
    // 7g → 1g: sakin → turuncu
    final t = 1.0 - ((hours - 24) / (6 * 24)).clamp(0.0, 1.0);
    return Color.lerp(
      scheme.primary,
      const Color(0xFFF59E0B),
      t,
    )!;
  }
  if (hours >= 6) {
    // 24s → 6s: turuncu
    final t = 1.0 - ((hours - 6) / 18).clamp(0.0, 1.0);
    return Color.lerp(
      const Color(0xFFF59E0B),
      const Color(0xFFEA580C),
      t,
    )!;
  }
  // <6s: turuncu → kırmızı
  final t = 1.0 - (hours / 6).clamp(0.0, 1.0);
  return Color.lerp(
    const Color(0xFFEA580C),
    const Color(0xFFDC2626),
    t,
  )!;
}

/// a11y: yalnız renge güvenme — etiket anahtarı.
enum TaskUrgencyKind { none, calm, soon, urgent, overdue }

TaskUrgencyKind taskUrgencyKind(DateTime now, DateTime? dueAt) {
  if (dueAt == null) return TaskUrgencyKind.none;
  final n = now.toUtc();
  final d = dueAt.toUtc();
  if (d.isBefore(n)) return TaskUrgencyKind.overdue;
  final hours = d.difference(n).inMinutes / 60.0;
  if (hours >= 24) return TaskUrgencyKind.calm;
  if (hours >= 6) return TaskUrgencyKind.soon;
  return TaskUrgencyKind.urgent;
}

/// Kısa kalan-süre etiketi (chip için): `Süresiz` / `Gecikti` / `3g` / `5s`
/// / `12dk`. Gün→saat→dakika en kaba birime yuvarlar (min 1dk).
String taskRemainingShort(
  AppLocalizations l10n,
  DateTime now,
  DateTime? dueAt,
) {
  if (dueAt == null) return l10n.taskListNoDue;
  final diff = dueAt.toUtc().difference(now.toUtc());
  if (diff.isNegative) return l10n.taskListOverdue;
  final days = diff.inDays;
  if (days >= 1) return l10n.taskListDaysShort(days);
  final hours = diff.inHours;
  if (hours >= 1) return l10n.taskListHoursShort(hours);
  final mins = diff.inMinutes;
  return l10n.taskListMinutesShort(mins < 1 ? 1 : mins);
}

/// İnsan-okur bitiş tarihi (yalnız gün): `28 Ağu`, yıl farklıysa `28 Ağu 2027`.
String taskDueDateLabel(DateTime now, DateTime dueAt) {
  final d = dueAt.toLocal();
  const months = [
    'Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz',
    'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara',
  ];
  final base = '${d.day} ${months[d.month - 1]}';
  return d.year == now.year ? base : '$base ${d.year}';
}
