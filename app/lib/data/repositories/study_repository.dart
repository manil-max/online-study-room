import '../models/study_session.dart';

/// Çalışma oturumlarının deposu. Şimdilik bellek-içi; ileride Supabase ile değiştirilecek.
abstract class StudyRepository {
  /// Tamamlanmış bir oturumu kaydeder.
  Future<void> addSession(StudySession session);

  /// Bir kullanıcının oturumlarını (yeni → eski) canlı izler.
  Stream<List<StudySession>> watchUserSessions(String userId);

  /// Bir sınıfın tüm oturumlarını canlı izler (istatistik/sıralama için).
  Stream<List<StudySession>> watchGroupSessions(String groupId);
}
