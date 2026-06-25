import '../models/daily_stat.dart';
import '../models/study_session.dart';

/// Çalışma oturumlarının deposu. Anahtar varsa Supabase, yoksa bellek-içi.
abstract class StudyRepository {
  /// Tamamlanmış bir oturumu kaydeder (canlı sayaç veya manuel giriş).
  Future<void> addSession(StudySession session);

  /// Var olan bir oturumu günceller (manuel düzenleme — yalnızca kendi oturumu).
  Future<void> updateSession(StudySession session);

  /// Bir oturumu siler (yalnızca kendi oturumu).
  Future<void> deleteSession(String sessionId);

  /// Bir kullanıcının oturumlarını (yeni → eski) canlı izler.
  Stream<List<StudySession>> watchUserSessions(String userId);

  /// Bir sınıfın tüm oturumlarını canlı izler (istatistik/sıralama için).
  Stream<List<StudySession>> watchGroupSessions(String groupId);

  /// Bir sınıfın **per-user-per-gün** toplamlarını canlı izler. Ham oturumları
  /// akıtmak yerine sunucuda toplanmış veriyi verir (sınırlı boyut — F1).
  /// Grup geneli leaderboard/seri/trend bundan hesaplanır.
  Stream<List<DailyStat>> watchGroupDailyStats(String groupId);
}
