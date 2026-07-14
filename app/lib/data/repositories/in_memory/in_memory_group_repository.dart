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
    GroupVisibility visibility = GroupVisibility.private,
    int memberLimit = kDefaultGroupMemberLimit,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || normalizedName.length > 64) {
      throw const GroupException('Grup adı 1 ile 64 karakter arasında olmalı.');
    }
    if (memberLimit < 2 || memberLimit > 100) {
      throw const GroupException('Üye sınırı 2 ile 100 arasında olmalı.');
    }
    final group = StudyGroup(
      id: _uuid.v4(),
      name: normalizedName,
      inviteCode: _generateInviteCode(),
      createdBy: creator.id,
      createdAt: DateTime.now(),
      visibility: visibility,
      memberLimit: memberLimit,
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
      orElse: () => throw const GroupException('Bu koda ait grup bulunamadı.'),
    );

    return _join(group, member);
  }

  @override
  Future<List<PublicGroupSummary>> discoverPublicGroups({
    String query = '',
    int offset = 0,
    int limit = 20,
  }) async {
    final normalized = query.trim().toLowerCase();
    final safeOffset = offset < 0 ? 0 : offset;
    final safeLimit = limit.clamp(1, 50).toInt();
    final visible =
        _groups.values
            .where((group) => group.visibility == GroupVisibility.public)
            .where(
              (group) =>
                  normalized.isEmpty ||
                  group.name.toLowerCase().contains(normalized),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return visible
        .skip(safeOffset)
        .take(safeLimit)
        .map(
          (group) => PublicGroupSummary(
            id: group.id,
            name: group.name,
            dailyGoalMinutes: group.dailyGoalMinutes,
            memberCount: _members[group.id]?.length ?? 0,
            memberLimit: group.memberLimit,
            createdAt: group.createdAt,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<StudyGroup> joinPublicGroup({
    required String groupId,
    required Profile member,
  }) async {
    final group = _groups[groupId];
    if (group == null || group.visibility != GroupVisibility.public) {
      throw const GroupException('Bu grup açık değil.');
    }
    return _join(group, member);
  }

  Future<StudyGroup> _join(StudyGroup group, Profile member) async {
    final members = _members.putIfAbsent(group.id, () => []);
    final isAlreadyMember = members.any((profile) => profile.id == member.id);
    if (!isAlreadyMember && members.length >= group.memberLimit) {
      throw const GroupException('Grup dolu.');
    }
    if (!isAlreadyMember) members.add(member);
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
      throw const GroupException('Grup adı boş olamaz.');
    }
    _groups[groupId] = g.copyWith(name: name.trim());
    _changes.add(null);
  }

  @override
  Future<void> updateGroupGoal(String groupId, int minutes) async {
    final g = _groups[groupId];
    if (g == null) return;
    _groups[groupId] = g.copyWith(dailyGoalMinutes: minutes.clamp(1, 24 * 60));
    _changes.add(null);
  }

  @override
  Future<void> updateGroupAccess(
    String groupId, {
    required GroupVisibility visibility,
    required int memberLimit,
  }) async {
    final group = _groups[groupId];
    if (group == null) throw const GroupException('Grup bulunamadı.');
    if (memberLimit < 2 || memberLimit > 100) {
      throw const GroupException('Üye sınırı 2 ile 100 arasında olmalı.');
    }
    final memberCount = _members[groupId]?.length ?? 0;
    if (memberLimit < memberCount) {
      throw const GroupException(
        'Üye sınırı mevcut üye sayısından düşük olamaz.',
      );
    }
    _groups[groupId] = group.copyWith(
      visibility: visibility,
      memberLimit: memberLimit,
    );
    _changes.add(null);
  }

  @override
  Future<String> regenerateInviteCode(String groupId) async {
    final g = _groups[groupId];
    if (g == null) throw const GroupException('Grup bulunamadı.');
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
