import '../../data/models/daily_stat.dart';
import '../../data/models/study_session.dart';
import 'istanbul_calendar.dart';
import 'study_stats.dart';

/// Uygulama, profil ve widget yüzeylerinin ortak kişisel istatistik özeti.
/// Aynı oturum kimliği birden fazla kez gelirse yalnız son görünüm sayılır.
class CanonicalStatsProjection {
  CanonicalStatsProjection._({
    required this.sessions,
    required this.dayTotals,
    required this.todaySeconds,
    required this.weekSeconds,
    required this.freshAt,
    required this.version,
  });

  factory CanonicalStatsProjection.fromSessions(
    Iterable<StudySession> input, {
    DateTime? now,
  }) {
    final byId = <String, StudySession>{};
    for (final session in input) {
      byId[session.id] = session;
    }
    final sessions = byId.values.toList(growable: false);
    final totals = dailyTotals(sessions);
    final today = dayOf(now ?? istanbulNow());
    final week = startOfWeek(today);
    return CanonicalStatsProjection._(
      sessions: sessions,
      dayTotals: totals,
      todaySeconds: totals[today] ?? 0,
      weekSeconds: totalSeconds(inRange(sessions, week, today)),
      freshAt: istanbulNow(),
      version: Object.hashAll(
        sessions.map(
          (s) =>
              Object.hash(s.id, s.start, s.end, s.durationSeconds, s.subjectId),
        ),
      ),
    );
  }

  final List<StudySession> sessions;
  final Map<DateTime, int> dayTotals;
  final int todaySeconds;
  final int weekSeconds;
  final DateTime freshAt;
  final int version;

  int streakForGoal(int goalSeconds) =>
      currentStreak(sessions, goalSeconds, totals: dayTotals, today: freshAt);
}

/// Grup günlük aggregate verisinden üretilen canonical leaderboard girdisi.
class CanonicalGroupStatsProjection {
  CanonicalGroupStatsProjection._(this.secondsByUser);

  factory CanonicalGroupStatsProjection.fromDailyStats(
    Iterable<DailyStat> stats, {
    DateTime? now,
  }) {
    final today = calendarDay(now ?? istanbulNow());
    final totals = <String, int>{};
    for (final stat in stats) {
      if (calendarDay(stat.day) != today) continue;
      totals[stat.userId] = (totals[stat.userId] ?? 0) + stat.seconds;
    }
    return CanonicalGroupStatsProjection._(totals);
  }

  final Map<String, int> secondsByUser;
}
