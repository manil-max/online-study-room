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

  // --- Yönetim (admin = sınıfı oluşturan; yetki kontrolü çağıran tarafta + RLS) ---

  /// Sınıf adını değiştirir (admin).
  Future<void> updateGroupName(String groupId, String name);

  /// Yeni davet kodu üretir ve döndürür (admin).
  Future<String> regenerateInviteCode(String groupId);

  /// Bir üyeyi sınıftan çıkarır (admin başkasını; kişi kendini → çık).
  Future<void> removeMember(String groupId, String userId);

  /// Kullanıcı sınıftan ayrılır (kendi üyeliğini siler).
  Future<void> leaveGroup(String groupId, String userId);

  /// Sınıfı tamamen siler (admin). İlişkili veriler DB'de cascade ile gider.
  Future<void> deleteGroup(String groupId);
}
