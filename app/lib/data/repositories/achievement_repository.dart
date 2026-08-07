import '../models/achievement_ledger.dart';
import '../models/achievement_metric_progress.dart';
import '../models/study_session.dart';

/// Server-authoritative başarım API'si (WP-56).
/// İstemci XP yazmaz; yalnız olay fırlatır / sözlük okur.
abstract class AchievementRepository {
  /// `achievements_dict` sözlüğü (statik seed).
  Future<List<AchievementDictEntry>> fetchDictionary();

  /// Private real-metric projection. Supabase RLS still enforces auth.uid().
  Future<List<AchievementMetricProgress>> fetchMetricProgress(String userId);

  Stream<List<AchievementMetricProgress>> watchMetricProgress(String userId);

  /// WP-501: grup başarımlarının **seçili gruba** ait değeri.
  ///
  /// 🔴 `achievement_metric_progress` birincil anahtarı `(user_id,
  /// achievement_id)` olduğu için grup boyutu yoktu ve üç projeksiyon da
  /// `group by user_id` ile TÜM grupları topluyordu: iki grupta aynı hafta
  /// birinci olan kullanıcı 2 alıyordu. `0121` kırılımı ayrı tabloya taşıdı.
  ///
  /// Sunucu hangi grubun seçili olduğunu **bilemez** (`activeGroupIdProvider`
  /// yalnız cihazdaki `SharedPreferences`'a yazar), bu yüzden seçimi istemci
  /// uygular; sunucudaki düz tablo ödül/XP için gruplar arası `max` tutar.
  Stream<List<AchievementMetricProgress>> watchGroupScopedMetricProgress(
    String userId,
    String groupId,
  );

  /// Sunucu RPC `process_achievement_event` (veya in_memory eşdeğeri).
  /// [sessions] yalnız in_memory yolu için gerekli; Supabase sunucuda hesaplar.
  Future<AchievementEventResult> processEvent({
    required String eventType,
    Map<String, dynamic> payload,
    List<StudySession> sessions,
    int dailyGoalMinutes,
    String? userId,
    DateTime? evaluationTime,
  });
}
