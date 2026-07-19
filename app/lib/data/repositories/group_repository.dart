import 'dart:typed_data';

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
  /// Admin-only private avatar upload. DB'ye yalnız versioned object path yazılır.
  Future<StudyGroup> uploadGroupAvatar({
    required String groupId,
    required Uint8List bytes,
    required String extension,
  });

  Future<String?> createGroupAvatarSignedUrl(String? avatarPath);

  /// Yeni sınıf oluşturur; oluşturan otomatik üye olur.
  Future<StudyGroup> createGroup({
    required String name,
    required Profile creator,
    GroupVisibility visibility = GroupVisibility.private,
    int memberLimit = kDefaultGroupMemberLimit,
  });

  /// Davet koduyla sınıfa katılır.
  Future<StudyGroup> joinGroup({
    required String inviteCode,
    required Profile member,
  });

  /// Açık grupların güvenli, davet kodu içermeyen keşif özeti.
  Future<List<PublicGroupSummary>> discoverPublicGroups({
    String query = '',
    int offset = 0,
    int limit = 20,
  });

  /// Açık bir gruba sunucu tarafında görünürlük ve kapasite kontrolüyle katılır.
  Future<StudyGroup> joinPublicGroup({
    required String groupId,
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

  /// Grubun günlük hedefini (dakika) değiştirir (admin). 1..24*60 aralığına
  /// sıkıştırılır.
  Future<void> updateGroupGoal(String groupId, int minutes);

  /// Adminin grubun katılım görünürlüğünü ve üye sınırını değiştirmesi.
  Future<void> updateGroupAccess(
    String groupId, {
    required GroupVisibility visibility,
    required int memberLimit,
  });

  /// Yeni davet kodu üretir ve döndürür (admin).
  Future<String> regenerateInviteCode(String groupId);

  /// Bir üyeyi sınıftan çıkarır (admin başkasını; kişi kendini → çık).
  Future<void> removeMember(String groupId, String userId);

  /// Kullanıcı sınıftan ayrılır (kendi üyeliğini siler).
  Future<void> leaveGroup(String groupId, String userId);

  /// Sınıfı tamamen siler (admin). İlişkili veriler DB'de cascade ile gider.
  Future<void> deleteGroup(String groupId);
}
