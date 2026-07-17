import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/stats/study_stats.dart';
import '../../models/analytics_query_models.dart';
import '../../models/study_session.dart';
import '../analytics_query_repository.dart';

class SupabaseAnalyticsQueryRepository implements AnalyticsQueryRepository {
  SupabaseAnalyticsQueryRepository(this._client);

  final SupabaseClient _client;

  String _dateParam(DateTime d) {
    final day = dayOf(d);
    final m = day.month.toString().padLeft(2, '0');
    final dd = day.day.toString().padLeft(2, '0');
    return '${day.year}-$m-$dd';
  }

  @override
  Future<List<UserDayTotal>> getUserDayTotals({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client.rpc(
      'get_user_day_totals',
      params: {
        'p_from': _dateParam(from),
        'p_to': _dateParam(to),
      },
    );
    return [
      for (final r in (rows as List<dynamic>))
        UserDayTotal.fromMap(Map<String, dynamic>.from(r as Map)),
    ];
  }

  @override
  Future<List<StudySession>> getUserSessionsInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    // Inclusive Istanbul day range → UTC bounds (generous).
    final fromDay = dayOf(from);
    final toDay = dayOf(to).add(const Duration(days: 1));
    final rows = await _client
        .from('study_sessions')
        .select()
        .eq('user_id', userId)
        .gte('start_time', fromDay.toUtc().toIso8601String())
        .lt('start_time', toDay.toUtc().toIso8601String())
        .order('start_time', ascending: true);
    final sessions = (rows as List<dynamic>)
        .map((r) => StudySession.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
    // Client-side Istanbul filter for edge TZ days.
    return inRange(sessions, from, to).toList();
  }

  @override
  Future<List<GroupContributionRow>> getGroupContribution({
    required String groupId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client.rpc(
      'group_contribution_breakdown',
      params: {
        'p_group_id': groupId,
        'p_from': _dateParam(from),
        'p_to': _dateParam(to),
      },
    );
    return [
      for (final r in (rows as List<dynamic>))
        GroupContributionRow.fromMap(Map<String, dynamic>.from(r as Map)),
    ];
  }

  @override
  Future<List<GroupLeaderboardPoint>> getGroupLeaderboardSeries({
    required String groupId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client.rpc(
      'group_leaderboard_series',
      params: {
        'p_group_id': groupId,
        'p_from': _dateParam(from),
        'p_to': _dateParam(to),
      },
    );
    return [
      for (final r in (rows as List<dynamic>))
        GroupLeaderboardPoint.fromMap(Map<String, dynamic>.from(r as Map)),
    ];
  }
}
