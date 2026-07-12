import '../../data/models/daily_stat.dart';
import '../../data/models/study_session.dart';
import 'istanbul_calendar.dart';

/// Çalışma oturumlarından istatistik üreten saf (yan etkisiz) yardımcılar.
/// Tümü `study_sessions` üzerinden hesaplanır (bkz. project.md §3.4/§6); ayrı bir
/// istatistik tablosu yoktur. Gün ayrımı oturumun **başlangıç** gününe göredir.

/// Bir günü (saat sıfırlanmış) verir.
DateTime dayOf(DateTime t) => istanbulDay(t);

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
    final day = dayOf(s.start);
    totals[day] = (totals[day] ?? 0) + s.durationSeconds;
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
  Map<DateTime, int>? totals,
}) {
  final dayMap = totals ?? dailyTotals(sessions);
  final end = dayOf(today ?? DateTime.now());
  return List.generate(count, (i) {
    final day = end.subtract(Duration(days: count - 1 - i));
    return DayTotal(day, dayMap[day] ?? 0);
  });
}

/// [fromDay, toDay] (iki uç dâhil) aralığındaki her takvim günü için seri
/// (eski → yeni), verisi olmayan günler 0. Grafik/özet için.
List<DayTotal> dailyRange(
  Iterable<StudySession> sessions,
  DateTime fromDay,
  DateTime toDay, {
  Map<DateTime, int>? totals,
}) {
  final dayMap = totals ?? dailyTotals(sessions);
  final from = dayOf(fromDay);
  final to = dayOf(toDay);
  final days = to.difference(from).inDays;
  if (days < 0) return const [];
  return List.generate(days + 1, (i) {
    final day = from.add(Duration(days: i));
    return DayTotal(day, dayMap[day] ?? 0);
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
    final wd = istanbulWeekday(s.start);
    if (wd == DateTime.saturday || wd == DateTime.sunday) {
      weekend += s.durationSeconds;
    } else {
      weekday += s.durationSeconds;
    }
  }
  return (weekday: weekday, weekend: weekend);
}

/// Günün saatine göre toplam (0–23 → saniye): her oturum **başlangıç saatine**
/// yazılır. "Günün hangi saatlerinde çalışıyorsun?" görseli için (§3.11).
List<int> hourlyTotals(Iterable<StudySession> sessions) {
  final totals = List<int>.filled(24, 0);
  for (final s in sessions) {
    totals[istanbulHour(s.start)] += s.durationSeconds;
  }
  return totals;
}

/// Haftanın günü × saat toplamı: `[gün][saat]` → saniye. Gün satırları Pazartesi
/// (0) → Pazar (6), saat sütunları 0–23. Oturum **başlangıç** gün/saatine yazılır.
/// "Haftalık ritim" ısı haritası için (§3.11).
List<List<int>> weekdayHourTotals(Iterable<StudySession> sessions) {
  final grid = List.generate(7, (_) => List<int>.filled(24, 0));
  for (final s in sessions) {
    final row = istanbulWeekday(s.start) - 1; // Pzt(1)→0 … Paz(7)→6
    grid[row][istanbulHour(s.start)] += s.durationSeconds;
  }
  return grid;
}

/// Oturumları derse göre toplar: `subjectId` (null → derssiz) → saniye,
/// büyükten küçüğe sıralı (ders bazında dağılım — project.md §3.7).
List<MapEntry<String?, int>> subjectBreakdown(Iterable<StudySession> sessions) {
  final totals = <String?, int>{};
  for (final s in sessions) {
    totals[s.subjectId] = (totals[s.subjectId] ?? 0) + s.durationSeconds;
  }
  final entries = totals.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries;
}

/// Günlük hedefe bağlı güncel seri (üst üste hedefi tutturulan gün sayısı, §3.7).
///
/// Kural: hedefi (≥ [goalSeconds]) tutturduğun her gün +1; tutturamadığın gün
/// sıfırlanır. **Bugün** henüz sürdüğü için, bugün hedefe ulaşılmadıysa seri
/// kırılmaz — dünden geriye sayılır (bugün ulaşıldıysa bugünden geriye sayılır).
/// [today] verilmezse `DateTime.now()` kullanılır (test için enjekte edilebilir).
int currentStreak(
  Iterable<StudySession> sessions,
  int goalSeconds, {
  DateTime? today,
  Map<DateTime, int>? totals,
}) {
  if (goalSeconds <= 0) return 0;
  final dayMap = totals ?? dailyTotals(sessions);
  final start = dayOf(today ?? DateTime.now());
  bool met(DateTime d) => (dayMap[d] ?? 0) >= goalSeconds;

  // Bugün tutturulduysa bugünden, yoksa (gün sürüyor) dünden başla.
  var cursor = met(start) ? start : start.subtract(const Duration(days: 1));
  var streak = 0;
  while (met(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// En uzun (üst üste en az 1 sn çalışılan) gün serisi — "rekor seri" (§3.11).
int longestStudyStreak(
  Iterable<StudySession> sessions, {
  Map<DateTime, int>? totals,
}) {
  final days = (totals ?? dailyTotals(sessions)).keys.toList()..sort();
  if (days.isEmpty) return 0;
  var best = 1;
  var cur = 1;
  for (var i = 1; i < days.length; i++) {
    if (days[i].difference(days[i - 1]).inDays == 1) {
      cur++;
      if (cur > best) best = cur;
    } else {
      cur = 1;
    }
  }
  return best;
}

/// Çalışma serisi: üst üste (en az 1 sn) çalışılan gün sayısı. Grup üyeleri için
/// herkesin günlük hedefi bilinmediğinden "çalıştığın gün" temelli seri (§3.7).
int studyStreak(
  Iterable<StudySession> sessions, {
  DateTime? today,
  Map<DateTime, int>? totals,
}) => currentStreak(sessions, 1, today: today, totals: totals);

// ── Grup geneli agregalar: per-user-per-gün toplamlardan (DailyStat) ─────────

/// Tüm üyelerin günlük toplamlarını gün bazında birleştirir (gün → saniye).
/// Grup serisi/trendi için (`currentStreak`/`lastNDays`'in `totals` paramına verilir).
Map<DateTime, int> groupDayTotals(Iterable<DailyStat> stats) {
  final totals = <DateTime, int>{};
  for (final s in stats) {
    final day = calendarDay(s.day);
    totals[day] = (totals[day] ?? 0) + s.seconds;
  }
  return totals;
}

/// Tek bir kullanıcının gün → saniye haritası (kişi başı seri için).
Map<DateTime, int> userDayTotals(Iterable<DailyStat> stats, String userId) {
  final totals = <DateTime, int>{};
  for (final s in stats) {
    if (s.userId != userId) continue;
    final day = calendarDay(s.day);
    totals[day] = (totals[day] ?? 0) + s.seconds;
  }
  return totals;
}

/// Belirli gündeki (varsayılan: bugün) kullanıcı → saniye haritası.
Map<String, int> todaySecondsByUser(
  Iterable<DailyStat> stats, {
  DateTime? today,
}) {
  final d = dayOf(today ?? DateTime.now());
  final totals = <String, int>{};
  for (final s in stats) {
    if (!isSameDay(s.day, d)) continue;
    totals[s.userId] = (totals[s.userId] ?? 0) + s.seconds;
  }
  return totals;
}

/// [fromDay, toDay] (iki uç dâhil) aralığında kullanıcı → toplam saniye
/// (leaderboard / sınıf istatistiği için).
Map<String, int> userTotalsInRange(
  Iterable<DailyStat> stats,
  DateTime fromDay,
  DateTime toDay,
) {
  final from = dayOf(fromDay);
  final to = dayOf(toDay);
  final totals = <String, int>{};
  for (final s in stats) {
    if (s.day.isBefore(from) || s.day.isAfter(to)) continue;
    totals[s.userId] = (totals[s.userId] ?? 0) + s.seconds;
  }
  return totals;
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

// ── Gün→saniye haritası üzerinden tüm-zamanlar metrikleri (§WP-10) ───────────
// Aşağıdakiler bir `Map<DateTime,int>` (gün → saniye) alır; hem grup
// (`groupDayTotals`) hem kişi (`userDayTotals`/`dailyTotals`) için kullanılır.

/// Haritadaki tüm günlerin toplamı (tüm-zamanlar toplam süre, saniye).
int totalOfDayTotals(Map<DateTime, int> dayTotals) =>
    dayTotals.values.fold<int>(0, (sum, s) => sum + s);

/// Çalışılan (toplamı > 0) farklı gün sayısı.
int activeDayCount(Map<DateTime, int> dayTotals) =>
    dayTotals.values.where((s) => s > 0).length;

/// En yoğun gün (en yüksek toplam süreli gün) ve süresi. Veri yoksa `null`.
/// Eşitlikte en erken gün kazanır (deterministik).
DayTotal? peakDay(Map<DateTime, int> dayTotals) {
  DayTotal? best;
  for (final entry in dayTotals.entries) {
    if (entry.value <= 0) continue;
    if (best == null ||
        entry.value > best.seconds ||
        (entry.value == best.seconds && entry.key.isBefore(best.day))) {
      best = DayTotal(entry.key, entry.value);
    }
  }
  return best;
}
