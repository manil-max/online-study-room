import '../models/profile.dart';
import '../models/study_group.dart';

/// Sınıf (grup) işlemlerinde kullanıcıya gösterilebilir hata.
class GroupException implements Exception {
  const GroupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Sınıf/grup soyutlaması. Şimdilik bellek-içi; ileride Supabase ile değiştirilecek.
abstract class GroupRepository {
  /// Yeni sınıf oluşturur; oluşturan otomatik üye olur.
  Future<StudyGroup> createGroup({
    required String name,
    required Profile creator,
  });

  /// Davet koduyla sınıfa katılır.
  Future<StudyGroup> joinGroup({
    required String inviteCode,
    required Profile member,
  });

  /// Kullanıcının üyesi olduğu TÜM sınıfları (eski → yeni) canlı izler.
  /// Çoklu sınıf desteği (project.md §3.8); boşsa boş liste.
  Stream<List<StudyGroup>> watchUserGroups(String userId);

  /// Bir sınıfın üyelerini canlı izler.
  Stream<List<Profile>> watchMembers(String groupId);
}
