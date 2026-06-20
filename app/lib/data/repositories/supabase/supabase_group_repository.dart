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
  Stream<StudyGroup?> watchUserGroup(String userId) {
    return _client
        .from('group_members')
        .stream(primaryKey: ['group_id', 'user_id'])
        .eq('user_id', userId)
        .asyncMap((rows) async {
          if (rows.isEmpty) return null;
          final groupId = rows.first['group_id'] as String;
          final g = await _client
              .from('groups')
              .select()
              .eq('id', groupId)
              .maybeSingle();
          return g == null ? null : StudyGroup.fromMap(g);
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
}
