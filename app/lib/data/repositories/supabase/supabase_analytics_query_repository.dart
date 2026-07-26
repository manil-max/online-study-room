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
      params: {'p_from': _dateParam(from), 'p_to': _dateParam(to)},
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
    // WP-325: gün aralığı, start_time yeniden yorumlanarak değil sunucunun
    // kayda damgaladığı day sütunuyla seçilir.
    final rows = await _client
        .from('study_sessions')
        .select()
        .eq('user_id', userId)
        .gte('day', _dateParam(from))
        .lte('day', _dateParam(to))
        .order('start_time', ascending: true);
    final sessions = (rows as List<dynamic>)
        .map((r) => StudySession.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
    // Recorded day filteriyle aynı sözleşmeyi koruyan son savunma katmanı.
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

  @override
  Future<List<GroupAlphaScore>> getGroupAlphaScores({
    required String groupId,
  }) async {
    final rows = await _client.rpc(
      'group_alpha_scores',
      params: {'p_group_id': groupId},
    );
    return [
      for (final row in (rows as List<dynamic>))
        GroupAlphaScore.fromMap(Map<String, dynamic>.from(row as Map)),
    ];
  }
}
