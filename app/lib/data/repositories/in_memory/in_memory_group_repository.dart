import 'dart:async';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../../models/profile.dart';
import '../../models/study_group.dart';
import '../group_repository.dart';

/// Bellek-içi (kalıcı olmayan) sınıf deposu. Supabase entegrasyonuna kadar geçicidir.
class InMemoryGroupRepository implements GroupRepository {
  InMemoryGroupRepository();

  final _uuid = const Uuid();
  final _random = Random();

  final Map<String, StudyGroup> _groups = {};
  final Map<String, String> _userGroup = {}; // userId -> groupId
  final Map<String, List<Profile>> _members = {}; // groupId -> üyeler
  final StreamController<void> _changes = StreamController<void>.broadcast();

  static const _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  String _generateInviteCode() {
    String code;
    do {
      code = List.generate(
        6,
        (_) => _codeAlphabet[_random.nextInt(_codeAlphabet.length)],
      ).join();
    } while (_groups.values.any((g) => g.inviteCode == code));
    return code;
  }

  StudyGroup? _groupForUser(String userId) {
    final groupId = _userGroup[userId];
    if (groupId == null) return null;
    return _groups[groupId];
  }

  @override
  Future<StudyGroup> createGroup({
    required String name,
    required Profile creator,
  }) async {
    if (name.trim().isEmpty) {
      throw const GroupException('Sınıf adı boş olamaz.');
    }
    final group = StudyGroup(
      id: _uuid.v4(),
      name: name.trim(),
      inviteCode: _generateInviteCode(),
      createdBy: creator.id,
      createdAt: DateTime.now(),
    );
    _groups[group.id] = group;
    _members[group.id] = [creator];
    _userGroup[creator.id] = group.id;
    _changes.add(null);
    return group;
  }

  @override
  Future<StudyGroup> joinGroup({
    required String inviteCode,
    required Profile member,
  }) async {
    final code = inviteCode.trim().toUpperCase();
    final group = _groups.values.firstWhere(
      (g) => g.inviteCode == code,
      orElse: () => throw const GroupException('Bu koda ait sınıf bulunamadı.'),
    );

    final members = _members.putIfAbsent(group.id, () => []);
    if (!members.any((m) => m.id == member.id)) {
      members.add(member);
    }
    _userGroup[member.id] = group.id;
    _changes.add(null);
    return group;
  }

  @override
  Stream<StudyGroup?> watchUserGroup(String userId) async* {
    yield _groupForUser(userId);
    await for (final _ in _changes.stream) {
      yield _groupForUser(userId);
    }
  }

  @override
  Stream<List<Profile>> watchMembers(String groupId) async* {
    yield List.unmodifiable(_members[groupId] ?? const []);
    await for (final _ in _changes.stream) {
      yield List.unmodifiable(_members[groupId] ?? const []);
    }
  }

  void dispose() => _changes.close();
}
