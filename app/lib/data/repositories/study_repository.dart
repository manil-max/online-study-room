import '../models/daily_stat.dart';
import '../models/study_session.dart';
import '../models/user_study_summary.dart';

/// Çalışma oturumlarının deposu. Anahtar varsa Supabase, yoksa bellek-içi.
abstract class StudyRepository {
  /// Server saatine bağlı verified run açar. [clientRequestId] aynı ağ
  /// isteğinin tekrarında aynı run'ı döndüren idempotency anahtarıdır.
  Future<LiveStudyRun> startLiveRun({
    required String userId,
    required String clientRequestId,
    String? groupId,
    String? subjectId,
    int clientBuild = 0,
  }) => throw UnsupportedError('verified live runs are not configured');

  Future<LiveStudyRun> pauseLiveRun(String runToken) =>
      throw UnsupportedError('verified live runs are not configured');

  Future<LiveStudyRun> resumeLiveRun(String runToken) =>
      throw UnsupportedError('verified live runs are not configured');

  /// Run'ı tam bir kez session'a dönüştürür. Dönen satırın [StudySession.isVerified]
  /// değeri true'dur; ağ cevabı kaybındaki retry aynı session'ı döndürür.
  Future<StudySession> finalizeLiveRun(String runToken) =>
      throw UnsupportedError('verified live runs are not configured');

  Future<VerifiedSessionConfig> fetchVerifiedSessionConfig() async =>
      const VerifiedSessionConfig.shadow();

  /// Rollout ölçümü güvenlik/XP kanıtı değildir; yalnız 30 günlük sayaca gider.
  Future<void> recordVerifiedSessionRollout({
    required String platform,
    required int clientBuild,
    required bool capability,
    LiveStartOrigin? origin,
    LiveRolloutOutcome? outcome,
  }) async {}

  /// Tamamlanmış bir oturumu kaydeder (canlı sayaç veya manuel giriş).
  Future<void> addSession(StudySession session);

  /// Var olan bir oturumu günceller (manuel düzenleme — yalnızca kendi oturumu).
  Future<void> updateSession(StudySession session);

  /// Bir oturumu siler (yalnızca kendi oturumu).
  Future<void> deleteSession(String sessionId);

  /// Kullanıcının **sıcak pencere** oturumları (yeni → eski).
  /// Varsayılan son 90 gün; eski detay RAM'de tutulmaz.
  Stream<List<StudySession>> watchUserSessions(String userId);

  /// Ömür boyu / bu yıl / sıcak pencere toplam saniyeleri (tek hafif sorgu).
  Future<UserStudySummary> fetchUserStudySummary(String userId);

  /// Bir sınıfın tüm oturumlarını canlı izler (istatistik/sıralama için).
  Stream<List<StudySession>> watchGroupSessions(String groupId);

  /// Bir sınıfın **per-user-per-gün** toplamlarını canlı izler. Ham oturumları
  /// akıtmak yerine sunucuda toplanmış veriyi verir (sınırlı boyut — F1).
  /// Grup geneli leaderboard/seri/trend bundan hesaplanır.
  Stream<List<DailyStat>> watchGroupDailyStats(String groupId);
}
