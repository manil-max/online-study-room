import '../../../core/stats/study_stats.dart';
import '../../models/analytics_query_models.dart';
import '../../models/daily_stat.dart';
import '../../models/study_session.dart';
import '../analytics_query_repository.dart';

/// Bellek-içi analitik sorgu. Testlerde [seedSessions]/[seedGroupStats] ile
/// doldurulur; uygulama demo modunda [sessionSource]/[groupStatsSource] bağlanır.
class InMemoryAnalyticsQueryRepository implements AnalyticsQueryRepository {
  InMemoryAnalyticsQueryRepository({
    this.sessionSource,
    this.groupStatsSource,
  });

  /// Canlı demo: tüm (hot window dışı dâhil) oturumları sağlar.
  final Future<List<StudySession>> Function(String userId)? sessionSource;

  /// Canlı demo: grup günlük toplamları (DailyStat).
  final Future<List<DailyStat>> Function(String groupId)? groupStatsSource;

  final Map<String, List<StudySession>> _sessionsByUser = {};
  final Map<String, List<DailyStat>> _groupStats = {};

  void seedSessions(String userId, List<StudySession> sessions) {
    _sessionsByUser[userId] = List.of(sessions);
  }

  void seedGroupStats(String groupId, List<DailyStat> stats) {
    _groupStats[groupId] = List.of(stats);
  }

  Future<List<StudySession>> _sessions(String userId) async {
    if (sessionSource != null) {
      return sessionSource!(userId);
    }
    return _sessionsByUser[userId] ?? const [];
  }

  Future<List<DailyStat>> _stats(String groupId) async {
    if (groupStatsSource != null) {
      return groupStatsSource!(groupId);
    }
    return _groupStats[groupId] ?? const [];
  }

  @override
  Future<List<UserDayTotal>> getUserDayTotals({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final sessions = await _sessions(userId);
    final map = dailyTotals(inRange(sessions, from, to));
    final days = dailyRange(const [], from, to, totals: map);
    return [
      for (final d in days)
        if (d.seconds > 0) UserDayTotal(day: d.day, seconds: d.seconds),
    ];
  }

  @override
  Future<List<StudySession>> getUserSessionsInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final sessions = await _sessions(userId);
    return inRange(sessions, from, to).toList();
  }

  @override
  Future<List<GroupContributionRow>> getGroupContribution({
    required String groupId,
    required DateTime from,
    required DateTime to,
  }) async {
    final stats = await _stats(groupId);
    final totals = <String, int>{};
    final fromD = dayOf(from);
    final toD = dayOf(to);
    for (final s in stats) {
      final d = dayOf(s.day);
      if (d.isBefore(fromD) || d.isAfter(toD)) continue;
      totals[s.userId] = (totals[s.userId] ?? 0) + s.seconds;
    }
    final rows = [
      for (final e in totals.entries)
        GroupContributionRow(userId: e.key, seconds: e.value),
    ]..sort((a, b) => b.seconds.compareTo(a.seconds));
    return rows;
  }

  @override
  Future<List<GroupLeaderboardPoint>> getGroupLeaderboardSeries({
    required String groupId,
    required DateTime from,
    required DateTime to,
  }) async {
    final stats = await _stats(groupId);
    final fromD = dayOf(from);
    final toD = dayOf(to);
    final points = <GroupLeaderboardPoint>[];
    for (final s in stats) {
      final d = dayOf(s.day);
      if (d.isBefore(fromD) || d.isAfter(toD)) continue;
      points.add(
        GroupLeaderboardPoint(
          day: d,
          userId: s.userId,
          seconds: s.seconds,
        ),
      );
    }
    points.sort((a, b) {
      final byDay = a.day.compareTo(b.day);
      if (byDay != 0) return byDay;
      return b.seconds.compareTo(a.seconds);
    });
    return points;
  }
}
