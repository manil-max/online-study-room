import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/canonical_stats_projection.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/study_session.dart';

StudySession _session(String id, DateTime start, int seconds) => StudySession(
  id: id,
  userId: 'u1',
  start: start,
  end: start.add(Duration(seconds: seconds)),
  durationSeconds: seconds,
  source: StudySource.live,
);

void main() {
  test('Istanbul gün sınırı UTC 21:00 sonrası yeni güne geçer', () {
    final sessions = [
      _session('before', DateTime.utc(2026, 7, 11, 20, 59), 60),
      _session('after', DateTime.utc(2026, 7, 11, 21, 1), 120),
    ];

    final totals = dailyTotals(sessions);

    expect(totals[DateTime(2026, 7, 11)], 60);
    expect(totals[DateTime(2026, 7, 12)], 120);
  });

  test('canonical projection aynı session id değerini bir kez sayar', () {
    final original = _session('same', DateTime.utc(2026, 7, 11, 10), 600);
    final updated = _session('same', DateTime.utc(2026, 7, 11, 10), 900);

    final projection = CanonicalStatsProjection.fromSessions([
      original,
      updated,
    ], now: DateTime.utc(2026, 7, 11, 12));

    expect(projection.sessions, hasLength(1));
    expect(projection.todaySeconds, 900);
  });
}
