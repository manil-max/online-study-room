import '../models/subject.dart';

/// Kullanıcının derslerinin (kategorilerinin) deposu. Anahtar varsa Supabase,
/// yoksa bellek-içi. Dersler kişiye özeldir (bkz. project.md §3.7).
abstract class SubjectRepository {
  /// Yeni bir ders ekler.
  Future<void> addSubject(Subject subject);

  /// Var olan bir dersi günceller (ad/renk — yalnızca kendi dersi).
  Future<void> updateSubject(Subject subject);

  /// Bir dersi siler. Bu derse ait geçmiş oturumlar SİLİNMEZ, "derssize" düşer
  /// (`study_sessions.subject_id` → null; DB'de `on delete set null`).
  Future<void> deleteSubject(String subjectId);

  /// Bir kullanıcının derslerini (ada göre sıralı) canlı izler.
  Stream<List<Subject>> watchUserSubjects(String userId);
}
