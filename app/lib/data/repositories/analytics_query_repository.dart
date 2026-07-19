import '../models/analytics_query_models.dart';
import '../models/study_session.dart';

/// WP-164: analitik sorgu katmanı (Supabase RPC + InMemory aggregate).
/// Ham başka-kullanıcı session satırı dönmez; aggregate veya self-session.
abstract class AnalyticsQueryRepository {
  /// Kişisel gün toplamları — `get_user_day_totals` (Istanbul gün).
  Future<List<UserDayTotal>> getUserDayTotals({
    required String userId,
    required DateTime from,
    required DateTime to,
  });

  /// Self oturumlar (konu×gün vb. için). RLS: yalnız kendi satırları.
  Future<List<StudySession>> getUserSessionsInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  });

  /// Üye katkı payı — `group_contribution_breakdown`.
  Future<List<GroupContributionRow>> getGroupContribution({
    required String groupId,
    required DateTime from,
    required DateTime to,
  });

  /// Liderlik zaman serisi — `group_leaderboard_series`.
  Future<List<GroupLeaderboardPoint>> getGroupLeaderboardSeries({
    required String groupId,
    required DateTime from,
    required DateTime to,
  });

  /// Aktif grup üyelerinin yalnız o gruptaki finalized verified alfa toplamı.
  /// İstemci, ham oturumdan alpha hesaplamaz.
  Future<List<GroupAlphaScore>> getGroupAlphaScores({required String groupId});
}
