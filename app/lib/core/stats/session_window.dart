import 'istanbul_calendar.dart';

/// Canlı UI / grafik / kayıt listesi için sıcak pencere (detay satırları).
/// Eski kayıtlar RAM'de tutulmaz; özet sayılar [UserStudySummary] ile gelir.
const int kUserSessionsHotWindowDays = 90;

/// Sıcak pencerenin başlangıç anı (Europe/Istanbul gün sınırına hizalı).
DateTime sessionHotWindowStart({DateTime? now}) {
  final today = istanbulDay(now ?? DateTime.now());
  return today.subtract(const Duration(days: kUserSessionsHotWindowDays - 1));
}

/// Oturum sıcak pencerede mi?
bool isSessionInHotWindow(DateTime start, {DateTime? now}) {
  final cutoff = sessionHotWindowStart(now: now);
  final day = istanbulDay(start);
  return !day.isBefore(cutoff);
}

/// Listeyi sıcak pencerede tut (yeni → eski sıralı kopya).
List<T> filterHotWindowSessions<T>(
  Iterable<T> sessions, {
  required DateTime Function(T) startOf,
  DateTime? now,
}) {
  final cutoff = sessionHotWindowStart(now: now);
  return [
    for (final s in sessions)
      if (!istanbulDay(startOf(s)).isBefore(cutoff)) s,
  ];
}
