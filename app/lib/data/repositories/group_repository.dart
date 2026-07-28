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

/// Hesap-geneli birincil grup tercihi. `selectionRevision` yalnız sunucunun
/// sıraladığı değişimlerde artar; cihazdaki gezinti seçimi değildir.
class PrimaryGroupPreference {
  const PrimaryGroupPreference({
    required this.primaryGroupId,
    required this.selectionRevision,
    this.nextChangeAllowedAt,
  });

  final String? primaryGroupId;
  final int selectionRevision;

  /// Server time derived cooldown. A null value means that no explicit change
  /// has started a cooldown yet; clients must never derive this from device time.
  final DateTime? nextChangeAllowedAt;

  factory PrimaryGroupPreference.fromMap(Map<String, dynamic> map) =>
      PrimaryGroupPreference(
        primaryGroupId: map['primary_group_id'] as String?,
        selectionRevision: (map['selection_revision'] as num?)?.toInt() ?? 0,
        nextChangeAllowedAt: map['next_change_allowed_at'] == null
            ? null
            : DateTime.tryParse(map['next_change_allowed_at'] as String),
      );
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
    String timeZone = kDefaultGroupTimeZone,
  });

  /// Davet koduyla sınıfa katılır.
  Future<StudyGroup> joinGroup({
    required String inviteCode,
    required Profile member,
  });

  /// Açık grupların güvenli, davet kodu içermeyen keşif özeti.
  Future<List<PublicGroupSummary>> discoverPublicGroups({
    String query = '',
    String? timeZone,
    String userTimeZone = kDefaultGroupTimeZone,
    bool onlyWithCapacity = false,
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

  /// Hesap-geneli primary tercihini izler. Bu akış hiçbir zaman aktif/gezilen
  /// grup provider'ını veya timer durumunu değiştirmez.
  Stream<PrimaryGroupPreference> watchPrimaryGroupPreference(String userId);

  /// Kullanıcının aktif üyesi olduğu grubu CAS revision ile birincil yapar.
  Future<PrimaryGroupPreference> setPrimaryGroup({
    required String userId,
    required String groupId,
    required int expectedRevision,
  });

  /// Bir sınıfın üyelerini canlı izler.
  Stream<List<Profile>> watchMembers(String groupId);

  // --- Yönetim (admin = sınıfı oluşturan; yetki kontrolü çağıran tarafta + RLS) ---

  /// Sınıf adını değiştirir (admin).
  Future<void> updateGroupName(String groupId, String name);

  /// Grubun günlük hedefini (dakika) değiştirir (admin). 1..24*60 aralığına
  /// sıkıştırılır.
  Future<void> updateGroupGoal(String groupId, int minutes);

  /// Grubun IANA saat dilimini değiştirir (admin). Bu sadece gelecekteki grup
  /// gün sınırlarını etkiler; damgalanmış geçmiş oturumları yeniden yazmaz.
  Future<void> updateGroupTimeZone(String groupId, String timeZone);

  /// Adminin grubun katılım görünürlüğünü ve üye sınırını değiştirmesi.
  Future<void> updateGroupAccess(
    String groupId, {
    required GroupVisibility visibility,
    required int memberLimit,
  });

  /// Yeni davet kodu üretir ve döndürür (admin).
  Future<String> regenerateInviteCode(String groupId);

  /// Üyeyi gruptan çıkarır ve yeniden katılmasını sunucuda engeller (admin).
  Future<void> banMember(String groupId, String userId);

  /// Grup yasağını kaldırır; kullanıcı ancak tekrar katılırsa üye olur (admin).
  Future<void> unbanMember(String groupId, String userId);

  /// Yalnız yöneticinin görebildiği grup yasak listesini döndürür.
  Future<List<Profile>> listBannedMembers(String groupId);

  /// Bir üyeyi sınıftan çıkarır (admin başkasını; kişi kendini → çık).
  Future<void> removeMember(String groupId, String userId);

  /// Kullanıcı sınıftan ayrılır (kendi üyeliğini siler).
  Future<void> leaveGroup(String groupId, String userId);

  /// Sınıfı tamamen siler (admin). İlişkili veriler DB'de cascade ile gider.
  Future<void> deleteGroup(String groupId);
}
