import 'dart:math';
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
  final _random = Random.secure();

  static const _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
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

  String _newCode() => List.generate(
    6,
    (_) => _codeAlphabet[_random.nextInt(_codeAlphabet.length)],
  ).join();

  @override
  Future<StudyGroup> createGroup({
    required String name,
    required Profile creator,
    GroupVisibility visibility = GroupVisibility.private,
    int memberLimit = kDefaultGroupMemberLimit,
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
    int offset = 0,
    int limit = 20,
  }) async {
    try {
      final rows =
          await _client.rpc(
                'discover_public_groups',
                params: {
                  'p_query': query.trim(),
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
  Stream<List<Profile>> watchMembers(String groupId) {
    return _client
        .from('group_members')
        .stream(primaryKey: ['group_id', 'user_id'])
        .eq('group_id', groupId)
        .asyncMap((rows) async {
          final ids = rows.map((r) => r['user_id'] as String).toList();
          if (ids.isEmpty) return <Profile>[];
          final profs = await _client
              .from('profiles')
              .select()
              .inFilter('id', ids);
          // WP-106: O(n) map; firstWhere StateError riski yok.
          final byUser = {for (final r in rows) r['user_id'] as String: r};
          return profs.map<Profile>((pMap) {
            final profile = Profile.fromMap(pMap);
            final memberRow = byUser[profile.id];
            return profile.copyWith(
              isActive: memberRow == null
                  ? false
                  : memberRow['left_at'] == null,
            );
          }).toList();
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
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _newCode();
      try {
        // WP-109 B7: 0 satır (RLS) sessiz başarı sayılmasın — select ile doğrula.
        final rows = await _client
            .from('groups')
            .update({'invite_code': code})
            .eq('id', groupId)
            .select('invite_code');
        if (rows.isEmpty) {
          throw const GroupException(
            'Kod yenilenemedi: yetki yok veya grup bulunamadı.',
          );
        }
        return (rows.first as Map)['invite_code'] as String;
      } on GroupException {
        rethrow;
      } on PostgrestException catch (e) {
        if (e.code == '23505' && attempt < 4) continue; // kod çakıştı
        throw GroupException('Kod yenilenemedi: ${e.message}');
      }
    }
    throw const GroupException('Kod yenilenemedi, tekrar deneyin.');
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
