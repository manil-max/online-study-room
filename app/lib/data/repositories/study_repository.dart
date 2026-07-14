import '../models/daily_stat.dart';
import '../models/study_session.dart';
import '../models/user_study_summary.dart';

/// Çalışma oturumlarının deposu. Anahtar varsa Supabase, yoksa bellek-içi.
abstract class StudyRepository {
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
