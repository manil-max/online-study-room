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
  }) async {
    if (name.trim().isEmpty) {
      throw const GroupException('Sınıf adı boş olamaz.');
    }
    // Benzersiz davet kodu bulana kadar dene (çakışma çok olası değil).
    for (var attempt = 0; attempt < 5; attempt++) {
      try {
        final row = await _client
            .from('groups')
            .insert({
              'name': name.trim(),
              'invite_code': _newCode(),
              'created_by': creator.id,
            })
            .select()
            .single();
        final group = StudyGroup.fromMap(row);
        await _client.from('group_members').insert({
          'group_id': group.id,
          'user_id': creator.id,
          'role': 'admin',
        });
        return group;
      } on PostgrestException catch (e) {
        // 23505 = unique violation (davet kodu çakıştı) → tekrar dene.
        if (e.code == '23505' && attempt < 4) continue;
        throw GroupException('Sınıf oluşturulamadı: ${e.message}');
      }
    }
    throw const GroupException('Sınıf oluşturulamadı, tekrar deneyin.');
  }

  @override
  Future<StudyGroup> joinGroup({
    required String inviteCode,
    required Profile member,
  }) async {
    final code = inviteCode.trim().toUpperCase();
    final row = await _client
        .from('groups')
        .select()
        .eq('invite_code', code)
        .maybeSingle();
    if (row == null) {
      throw const GroupException('Bu koda ait sınıf bulunamadı.');
    }
    final group = StudyGroup.fromMap(row);
    try {
      await _client.from('group_members').insert({
        'group_id': group.id,
        'user_id': member.id,
        'role': 'member',
      });
    } on PostgrestException catch (e) {
      // Zaten üyeyse (unique violation) sorun değil; sınıfı döndür.
      if (e.code != '23505') {
        throw GroupException('Sınıfa katılınamadı: ${e.message}');
      }
    }
    return group;
  }

  @override
  Stream<List<StudyGroup>> watchUserGroups(String userId) {
    return _client
        .from('group_members')
        .stream(primaryKey: ['group_id', 'user_id'])
        .eq('user_id', userId)
        .asyncMap((rows) async {
          if (rows.isEmpty) return <StudyGroup>[];
          final ids = rows.map((r) => r['group_id'] as String).toList();
          final gs =
              await _client.from('groups').select().inFilter('id', ids);
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
          final profs =
              await _client.from('profiles').select().inFilter('id', ids);
          return profs.map<Profile>(Profile.fromMap).toList();
        });
  }

  @override
  Future<void> updateGroupName(String groupId, String name) async {
    if (name.trim().isEmpty) {
      throw const GroupException('Sınıf adı boş olamaz.');
    }
    try {
      await _client
          .from('groups')
          .update({'name': name.trim()}).eq('id', groupId);
    } on PostgrestException catch (e) {
      throw GroupException('Sınıf adı değiştirilemedi: ${e.message}');
    }
  }

  @override
  Future<String> regenerateInviteCode(String groupId) async {
    for (var attempt = 0; attempt < 5; attempt++) {
      final code = _newCode();
      try {
        await _client
            .from('groups')
            .update({'invite_code': code}).eq('id', groupId);
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
          .delete()
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
      throw GroupException('Sınıf silinemedi: ${e.message}');
    }
  }
}
