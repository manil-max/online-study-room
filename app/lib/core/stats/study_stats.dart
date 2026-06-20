import '../../data/models/study_session.dart';

/// Çalışma oturumlarından istatistik üreten saf (yan etkisiz) yardımcılar.
/// Tümü `study_sessions` üzerinden hesaplanır (bkz. project.md §3.4/§6); ayrı bir
/// istatistik tablosu yoktur. Gün ayrımı oturumun **başlangıç** gününe göredir.

/// Bir günü (saat sıfırlanmış) verir.
DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// Aynı gün mü?
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Haftanın başlangıcı (Pazartesi 00:00) — Türkiye'de hafta Pazartesi başlar.
DateTime startOfWeek(DateTime t) {
  final d = dayOf(t);
  return d.subtract(Duration(days: d.weekday - DateTime.monday));
}

/// Ayın başlangıcı (ayın 1'i 00:00).
DateTime startOfMonth(DateTime t) => DateTime(t.year, t.month, 1);

/// Yılın başlangıcı (1 Ocak 00:00).
DateTime startOfYear(DateTime t) => DateTime(t.year, 1, 1);

/// Toplam çalışma süresi (saniye).
int totalSeconds(Iterable<StudySession> sessions) =>
    sessions.fold<int>(0, (sum, s) => sum + s.durationSeconds);

/// [fromDay, toDay] (gün bazlı, iki uç dâhil) aralığındaki oturumlar.
Iterable<StudySession> inRange(
  Iterable<StudySession> sessions,
  DateTime fromDay,
  DateTime toDay,
) {
  final from = dayOf(fromDay);
  final to = dayOf(toDay);
  return sessions.where((s) {
    final d = s.day;
    return !d.isBefore(from) && !d.isAfter(to);
  });
}

/// Belirli bir gündeki toplam süre (saniye).
int secondsOnDay(Iterable<StudySession> sessions, DateTime day) => sessions
    .where((s) => isSameDay(s.day, day))
    .fold<int>(0, (sum, s) => sum + s.durationSeconds);

/// Gün → toplam saniye haritası (yalnızca verisi olan günler).
Map<DateTime, int> dailyTotals(Iterable<StudySession> sessions) {
  final totals = <DateTime, int>{};
  for (final s in sessions) {
    totals[s.day] = (totals[s.day] ?? 0) + s.durationSeconds;
  }
  return totals;
}

/// Bir gün ve o günün toplam süresi (grafik/seri için).
class DayTotal {
  const DayTotal(this.day, this.seconds);
  final DateTime day;
  final int seconds;
}

/// Bugünden geriye [count] günlük seri (eski → yeni), verisi olmayan günler 0.
/// [today] verilmezse `DateTime.now()` kullanılır (test için enjekte edilebilir).
List<DayTotal> lastNDays(
  Iterable<StudySession> sessions,
  int count, {
  DateTime? today,
}) {
  final totals = dailyTotals(sessions);
  final end = dayOf(today ?? DateTime.now());
  return List.generate(count, (i) {
    final day = end.subtract(Duration(days: count - 1 - i));
    return DayTotal(day, totals[day] ?? 0);
  });
}

/// [fromDay, toDay] (iki uç dâhil) aralığındaki her takvim günü için seri
/// (eski → yeni), verisi olmayan günler 0. Grafik/özet için.
List<DayTotal> dailyRange(
  Iterable<StudySession> sessions,
  DateTime fromDay,
  DateTime toDay,
) {
  final totals = dailyTotals(sessions);
  final from = dayOf(fromDay);
  final to = dayOf(toDay);
  final days = to.difference(from).inDays;
  if (days < 0) return const [];
  return List.generate(days + 1, (i) {
    final day = from.add(Duration(days: i));
    return DayTotal(day, totals[day] ?? 0);
  });
}

/// [fromDay, toDay] aralığındaki günlük ortalama (saniye).
/// Payda, aralıktaki **takvim günü** sayısıdır (çalışılmayan günler de sayılır).
double dailyAverageSeconds(
  Iterable<StudySession> sessions,
  DateTime fromDay,
  DateTime toDay,
) {
  final from = dayOf(fromDay);
  final to = dayOf(toDay);
  final days = to.difference(from).inDays + 1;
  if (days <= 0) return 0;
  return totalSeconds(inRange(sessions, from, to)) / days;
}

/// Hafta içi (Pzt–Cum) ve hafta sonu (Cmt–Paz) toplam süreleri.
({int weekday, int weekend}) weekdayWeekendSplit(
  Iterable<StudySession> sessions,
) {
  var weekday = 0;
  var weekend = 0;
  for (final s in sessions) {
    final wd = s.day.weekday;
    if (wd == DateTime.saturday || wd == DateTime.sunday) {
      weekend += s.durationSeconds;
    } else {
      weekday += s.durationSeconds;
    }
  }
  return (weekday: weekday, weekend: weekend);
}

/// Bir sınıfın oturumlarından kullanıcı başına toplam (userId → saniye),
/// büyükten küçüğe sıralı (leaderboard).
List<MapEntry<String, int>> leaderboard(Iterable<StudySession> sessions) {
  final totals = <String, int>{};
  for (final s in sessions) {
    totals[s.userId] = (totals[s.userId] ?? 0) + s.durationSeconds;
  }
  final entries = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries;
}
