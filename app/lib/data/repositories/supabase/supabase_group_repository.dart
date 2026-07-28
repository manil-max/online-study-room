import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../models/profile.dart';
import '../../models/study_group.dart';
import '../group_repository.dart';

/// Supabase tabanlı sınıf (grup) deposu. UI hiç değişmeden bellek-içi yerine geçer.
class SupabaseGroupRepository implements GroupRepository {
  SupabaseGroupRepository(this._client);

  final SupabaseClient _client;
  static const _avatarBucket = 'group-avatars';
  static const _avatarMaxBytes = 2 * 1024 * 1024;
  static const _uuid = Uuid();

  @override
  Future<StudyGroup> uploadGroupAvatar({
    required String groupId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final normalizedExtension = extension.toLowerCase().replaceAll('.', '');
    if (bytes.isEmpty ||
        bytes.lengthInBytes > _avatarMaxBytes ||
        !const {'jpg', 'jpeg', 'png', 'webp'}.contains(normalizedExtension)) {
      throw const GroupException(
        'Fotoğraf JPEG, PNG veya WebP ve en fazla 2 MB olmalı.',
      );
    }
    final contentType = switch (normalizedExtension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    final path = '$groupId/${_uuid.v4()}.$normalizedExtension';
    // Eski nesneyi başarılı değişimden sonra Storage API ile temizleyeceğiz;
    // DB trigger'ı artık storage.objects'ten doğrudan silmiyor (0054). Eski path'i
    // güncellemeden önce oku (UPDATE yalnız yeni satırı döndürür).
    String? previousPath;
    try {
      final current = await _client
          .from('groups')
          .select('avatar_path')
          .eq('id', groupId)
          .maybeSingle();
      previousPath = current?['avatar_path'] as String?;
    } on PostgrestException {
      previousPath =
          null; // Okuma başarısızsa temizliği atla; yükleme engellenmez.
    }
    try {
      await _client.storage
          .from(_avatarBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              cacheControl: '3600',
              contentType: contentType,
              upsert: false,
            ),
          );
      final rows = await _client
          .from('groups')
          .update({
            'avatar_path': path,
            'avatar_updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', groupId)
          .select();
      if (rows.isEmpty) {
        await _removeUploadedObject(path);
        throw const GroupException('Grup fotoğrafı güncellenemedi: yetki yok.');
      }
      // Değişim başarılı: artık yetim kalan eski nesneyi best-effort sil.
      if (previousPath != null &&
          previousPath.isNotEmpty &&
          previousPath != path) {
        await _removeUploadedObject(previousPath);
      }
      final group = StudyGroup.fromMap(
        Map<String, dynamic>.from(rows.first as Map),
      );
      return group;
    } on StorageException catch (e) {
      throw GroupException('Fotoğraf yüklenemedi: ${e.message}');
    } on PostgrestException catch (e) {
      await _removeUploadedObject(path);
      throw GroupException('Grup fotoğrafı güncellenemedi: ${e.message}');
    }
  }

  Future<void> _removeUploadedObject(String path) async {
    try {
      await _client.storage.from(_avatarBucket).remove([path]);
    } on StorageException {
      // Best effort: the database update remains authoritative. A failed cleanup
      // is visible as an orphan object and can be removed by the storage audit.
    }
  }

  @override
  Future<String?> createGroupAvatarSignedUrl(String? avatarPath) async {
    if (avatarPath == null || avatarPath.isEmpty) return null;
    try {
      return await _client.storage
          .from(_avatarBucket)
          .createSignedUrl(avatarPath, 3600);
    } on StorageException {
      return null;
    }
  }

  @override
  Future<StudyGroup> createGroup({
    required String name,
    required Profile creator,
    GroupVisibility visibility = GroupVisibility.private,
    int memberLimit = kDefaultGroupMemberLimit,
    String timeZone = kDefaultGroupTimeZone,
  }) async {
    if (name.trim().isEmpty) {
      throw const GroupException('Grup adı boş olamaz.');
    }
    // Grup + admin üyeliği tek transaction'da sunucuda kurulur (RPC).
    // Davet kodu sunucuda üretilir; istemci groups'a doğrudan insert atmaz.
    try {
      final row = await _client.rpc(
        'create_group_with_access',
        params: {
          'p_name': name.trim(),
          'p_visibility': visibility.dbValue,
          'p_member_limit': memberLimit,
          'p_time_zone': timeZone,
        },
      );
      if (row == null) {
        throw const GroupException('Grup oluşturulamadı, tekrar deneyin.');
      }
      return StudyGroup.fromMap(Map<String, dynamic>.from(row as Map));
    } on PostgrestException catch (e) {
      throw GroupException('Grup oluşturulamadı: ${e.message}');
    }
  }

  @override
  Future<StudyGroup> joinGroup({
    required String inviteCode,
    required Profile member,
  }) async {
    // Davet kodu SUNUCUDA doğrulanır (RPC). İstemci artık groups tablosunu
    // kodla sorgulamaz ve group_members'a doğrudan insert atmaz — böylece
    // kod bilinmeden gruba katılma / kod ifşası mümkün değildir.
    final code = inviteCode.trim().toUpperCase();
    try {
      final row = await _client.rpc('join_group', params: {'p_code': code});
      if (row == null) {
        throw const GroupException('Bu koda ait grup bulunamadı.');
      }
      return StudyGroup.fromMap(Map<String, dynamic>.from(row as Map));
    } on PostgrestException catch (e) {
      throw GroupException('Gruba katılınamadı: ${e.message}');
    }
  }

  @override
  Future<List<PublicGroupSummary>> discoverPublicGroups({
    String query = '',
    String? timeZone,
    String userTimeZone = kDefaultGroupTimeZone,
    bool onlyWithCapacity = false,
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      final rows =
          await _client.rpc(
                'discover_public_groups',
                params: {
                  'p_query': query.trim(),
                  'p_time_zone': timeZone?.trim(),
                  'p_user_time_zone': userTimeZone.trim(),
                  'p_only_with_capacity': onlyWithCapacity,
                  'p_offset': offset < 0 ? 0 : offset,
                  'p_limit': limit.clamp(1, 50).toInt(),
                },
              )
              as List<dynamic>;
      return rows
          .map(
            (row) => PublicGroupSummary.fromMap(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw GroupException('Açık gruplar yüklenemedi: ${e.message}');
    }
  }

  @override
  Future<StudyGroup> joinPublicGroup({
    required String groupId,
    required Profile member,
  }) async {
    try {
      final row = await _client.rpc(
        'join_public_group',
        params: {'p_group_id': groupId},
      );
      if (row == null) {
        throw const GroupException('Gruba katılınamadı.');
      }
      return StudyGroup.fromMap(Map<String, dynamic>.from(row as Map));
    } on PostgrestException catch (e) {
      throw GroupException('Gruba katılınamadı: ${e.message}');
    }
  }

  @override
  Stream<List<StudyGroup>> watchUserGroups(String userId) {
    return _client
        .from('group_members')
        .stream(primaryKey: ['group_id', 'user_id'])
        .eq('user_id', userId)
        .asyncMap((rows) async {
          final activeRows = rows.where((row) => row['left_at'] == null);
          if (activeRows.isEmpty) return <StudyGroup>[];
          final ids = activeRows.map((r) => r['group_id'] as String).toList();
          final gs = await _client.from('groups').select().inFilter('id', ids);
          final list = gs.map<StudyGroup>(StudyGroup.fromMap).toList()
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return list;
        });
  }

  @override
  Stream<PrimaryGroupPreference> watchPrimaryGroupPreference(String userId) {
    return _client
        .from('user_group_preferences')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId)
        .map((rows) {
          if (rows.isEmpty) {
            return const PrimaryGroupPreference(
              primaryGroupId: null,
              selectionRevision: 0,
            );
          }
          return PrimaryGroupPreference.fromMap(
            Map<String, dynamic>.from(rows.single),
          );
        });
  }

  @override
  Future<PrimaryGroupPreference> setPrimaryGroup({
    required String userId,
    required String groupId,
    required int expectedRevision,
  }) async {
    try {
      final row = await _client.rpc(
        'set_primary_group',
        params: {
          'p_group_id': groupId,
          'p_expected_revision': expectedRevision,
        },
      );
      if (row == null) {
        throw const GroupException('Birincil grup güncellenemedi.');
      }
      final result = row is List ? row.single : row;
      return PrimaryGroupPreference.fromMap(
        Map<String, dynamic>.from(result as Map),
      );
    } on GroupException {
      rethrow;
    } on PostgrestException catch (e) {
      throw GroupException('Birincil grup güncellenemedi: ${e.message}');
    }
  }

  @override
  Stream<List<Profile>> watchMembers(String groupId) {
    return _client
        .from('group_members')
        .stream(primaryKey: ['group_id', 'user_id'])
        .eq('group_id', groupId)
        .asyncMap((rows) async {
          if (rows.isEmpty) return <Profile>[];
          // WP-413: profil satırları artık `profiles`ten okunmaz. `profiles`
          // RLS'i engellenen çifti reddettiği için doğrudan okuma engellenen
          // üyeyi listeden **düşürür** ve kamp ateşinde katılımcı sayısını
          // bozardı. `group_member_directory` satırı korur, yalnız kimliği
          // (ad/avatar/hayvan) sunucuda boşaltır → üye anonimleşir, kaybolmaz.
          final directory = await _client.rpc(
            'group_member_directory',
            params: {'p_group_id': groupId},
          );
          return [
            for (final raw in directory as List)
              Profile.fromMap(Map<String, dynamic>.from(raw as Map)),
          ];
        });
  }

  @override
  Future<void> updateGroupName(String groupId, String name) async {
    if (name.trim().isEmpty) {
      throw const GroupException('Grup adı boş olamaz.');
    }
    try {
      final rows = await _client
          .from('groups')
          .update({'name': name.trim()})
          .eq('id', groupId)
          .select('id');
      if (rows.isEmpty) {
        throw const GroupException(
          'Grup adı değiştirilemedi: yetki yok veya grup bulunamadı.',
        );
      }
    } on GroupException {
      rethrow;
    } on PostgrestException catch (e) {
      if (e.message.contains('public_name_not_allowed')) {
        throw const GroupException('public_name_not_allowed');
      }
      throw GroupException('Grup adı değiştirilemedi: ${e.message}');
    }
  }

  @override
  Future<void> updateGroupGoal(String groupId, int minutes) async {
    try {
      final rows = await _client
          .from('groups')
          .update({'daily_goal_minutes': minutes.clamp(1, 24 * 60)})
          .eq('id', groupId)
          .select('id');
      if (rows.isEmpty) {
        throw const GroupException(
          'Grup hedefi değiştirilemedi: yetki yok veya grup bulunamadı.',
        );
      }
    } on GroupException {
      rethrow;
    } on PostgrestException catch (e) {
      throw GroupException('Grup hedefi değiştirilemedi: ${e.message}');
    }
  }

  @override
  Future<void> updateGroupTimeZone(String groupId, String timeZone) async {
    try {
      await _client.rpc(
        'update_group_time_zone',
        params: {'p_group_id': groupId, 'p_time_zone': timeZone.trim()},
      );
    } on PostgrestException catch (e) {
      throw GroupException('Grup zaman dilimi değiştirilemedi: ${e.message}');
    }
  }

  @override
  Future<void> updateGroupAccess(
    String groupId, {
    required GroupVisibility visibility,
    required int memberLimit,
  }) async {
    try {
      await _client.rpc(
        'update_group_access',
        params: {
          'p_group_id': groupId,
          'p_visibility': visibility.dbValue,
          'p_member_limit': memberLimit,
        },
      );
    } on PostgrestException catch (e) {
      throw GroupException('Grup erişimi değiştirilemedi: ${e.message}');
    }
  }

  @override
  Future<String> regenerateInviteCode(String groupId) async {
    try {
      return await _client.rpc(
            'regenerate_group_invite_code',
            params: {'p_group_id': groupId},
          )
          as String;
    } on PostgrestException catch (e) {
      throw GroupException('Kod yenilenemedi: ${e.message}');
    }
  }

  @override
  Future<void> banMember(String groupId, String userId) async {
    try {
      await _client.rpc(
        'ban_group_member',
        params: {'p_group_id': groupId, 'p_user_id': userId},
      );
    } on PostgrestException catch (e) {
      throw GroupException('Üye engellenemedi: ${e.message}');
    }
  }

  @override
  Future<void> unbanMember(String groupId, String userId) async {
    try {
      await _client.rpc(
        'unban_group_member',
        params: {'p_group_id': groupId, 'p_user_id': userId},
      );
    } on PostgrestException catch (e) {
      throw GroupException('Üye yasağı kaldırılamadı: ${e.message}');
    }
  }

  @override
  Future<List<Profile>> listBannedMembers(String groupId) async {
    try {
      final rows =
          await _client.rpc('list_group_bans', params: {'p_group_id': groupId})
              as List<dynamic>;
      return rows
          .map((row) => Profile.fromMap(Map<String, dynamic>.from(row as Map)))
          .toList(growable: false);
    } on PostgrestException catch (e) {
      throw GroupException('Yasaklı üyeler yüklenemedi: ${e.message}');
    }
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    try {
      final rows = await _client
          .from('group_members')
          .update({'left_at': DateTime.now().toUtc().toIso8601String()})
          .eq('group_id', groupId)
          .eq('user_id', userId)
          .select('user_id');
      if (rows.isEmpty) {
        throw const GroupException(
          'Üye çıkarılamadı: yetki yok veya üye bulunamadı.',
        );
      }
    } on GroupException {
      rethrow;
    } on PostgrestException catch (e) {
      throw GroupException('Üye çıkarılamadı: ${e.message}');
    }
  }

  @override
  Future<void> leaveGroup(String groupId, String userId) =>
      removeMember(groupId, userId);

  @override
  Future<void> deleteGroup(String groupId) async {
    try {
      final rows = await _client
          .from('groups')
          .delete()
          .eq('id', groupId)
          .select('id');
      if (rows.isEmpty) {
        throw const GroupException(
          'Grup silinemedi: yetki yok veya grup bulunamadı.',
        );
      }
    } on GroupException {
      rethrow;
    } on PostgrestException catch (e) {
      throw GroupException('Grup silinemedi: ${e.message}');
    }
  }
}
