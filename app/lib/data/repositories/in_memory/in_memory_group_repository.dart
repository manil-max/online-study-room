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
  // Çoklu sınıf: bir kullanıcı birden çok sınıfa üye olabilir (katılım sırasıyla).
  final Map<String, List<String>> _userGroups = {}; // userId -> [groupId...]
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

  List<StudyGroup> _groupsForUser(String userId) {
    final ids = _userGroups[userId] ?? const [];
    final list = ids.map((id) => _groups[id]).whereType<StudyGroup>().toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List.unmodifiable(list);
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
    _userGroups.putIfAbsent(creator.id, () => []).add(group.id);
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
    final mine = _userGroups.putIfAbsent(member.id, () => []);
    if (!mine.contains(group.id)) mine.add(group.id);
    _changes.add(null);
    return group;
  }

  @override
  Stream<List<StudyGroup>> watchUserGroups(String userId) async* {
    yield _groupsForUser(userId);
    await for (final _ in _changes.stream) {
      yield _groupsForUser(userId);
    }
  }

  @override
  Stream<List<Profile>> watchMembers(String groupId) async* {
    yield List.unmodifiable(_members[groupId] ?? const []);
    await for (final _ in _changes.stream) {
      yield List.unmodifiable(_members[groupId] ?? const []);
    }
  }

  @override
  Future<void> updateGroupName(String groupId, String name) async {
    final g = _groups[groupId];
    if (g == null) return;
    if (name.trim().isEmpty) {
      throw const GroupException('Sınıf adı boş olamaz.');
    }
    _groups[groupId] = g.copyWith(name: name.trim());
    _changes.add(null);
  }

  @override
  Future<String> regenerateInviteCode(String groupId) async {
    final g = _groups[groupId];
    if (g == null) throw const GroupException('Sınıf bulunamadı.');
    final code = _generateInviteCode();
    _groups[groupId] = g.copyWith(inviteCode: code);
    _changes.add(null);
    return code;
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    _members[groupId]?.removeWhere((m) => m.id == userId);
    _userGroups[userId]?.remove(groupId);
    _changes.add(null);
  }

  @override
  Future<void> leaveGroup(String groupId, String userId) =>
      removeMember(groupId, userId);

  @override
  Future<void> deleteGroup(String groupId) async {
    _groups.remove(groupId);
    _members.remove(groupId);
    for (final ids in _userGroups.values) {
      ids.remove(groupId);
    }
    _changes.add(null);
  }

  void dispose() => _changes.close();
}
