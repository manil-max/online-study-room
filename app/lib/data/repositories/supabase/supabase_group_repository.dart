import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/profile.dart';
import '../../models/study_group.dart';
import '../group_repository.dart';

/// Supabase tabanlı sınıf (grup) deposu. UI hiç değişmeden bellek-içi yerine geçer.
class SupabaseGroupRepository implements GroupRepository {
  SupabaseGroupRepository(this._client);

  final SupabaseClient _client;
  final _random = Random.secure();

  static const _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

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
          return profs.map<Profile>((pMap) {
            final profile = Profile.fromMap(pMap);
            final memberRow = rows.firstWhere(
              (r) => r['user_id'] == profile.id,
            );
            return profile.copyWith(isActive: memberRow['left_at'] == null);
          }).toList();
        });
  }

  @override
  Future<void> updateGroupName(String groupId, String name) async {
    if (name.trim().isEmpty) {
      throw const GroupException('Grup adı boş olamaz.');
    }
    try {
      await _client
          .from('groups')
          .update({'name': name.trim()})
          .eq('id', groupId);
    } on PostgrestException catch (e) {
      throw GroupException('Grup adı değiştirilemedi: ${e.message}');
    }
  }

  @override
  Future<void> updateGroupGoal(String groupId, int minutes) async {
    try {
      await _client
          .from('groups')
          .update({'daily_goal_minutes': minutes.clamp(1, 24 * 60)})
          .eq('id', groupId);
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
        await _client
            .from('groups')
            .update({'invite_code': code})
            .eq('id', groupId);
        return code;
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
      await _client
          .from('group_members')
          .update({'left_at': DateTime.now().toUtc().toIso8601String()})
          .eq('group_id', groupId)
          .eq('user_id', userId);
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
      await _client.from('groups').delete().eq('id', groupId);
    } on PostgrestException catch (e) {
      throw GroupException('Grup silinemedi: ${e.message}');
    }
  }
}
