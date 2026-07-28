import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'package:uuid/uuid.dart';

import '../../models/profile.dart';
import '../../models/study_group.dart';
import '../group_repository.dart';

/// Bellek-içi (kalıcı olmayan) sınıf deposu. Supabase entegrasyonuna kadar geçicidir.
class InMemoryGroupRepository implements GroupRepository {
  InMemoryGroupRepository({DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final _uuid = const Uuid();
  final _random = Random();
  final DateTime Function() _now;

  final Map<String, StudyGroup> _groups = {};
  final Map<String, Uint8List> _avatarBytes = {};
  // Çoklu sınıf: bir kullanıcı birden çok sınıfa üye olabilir (katılım sırasıyla).
  final Map<String, List<String>> _userGroups = {}; // userId -> [groupId...]
  final Map<String, List<Profile>> _members = {}; // groupId -> üyeler
  final Map<String, Map<String, Profile>> _bannedMembers = {};
  final Map<String, PrimaryGroupPreference> _primaryPreferences = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  static const _codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  @override
  Future<StudyGroup> uploadGroupAvatar({
    required String groupId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final group = _groups[groupId];
    if (group == null) throw const GroupException('Grup bulunamadı.');
    final normalizedExtension = extension.toLowerCase().replaceAll('.', '');
    if (bytes.isEmpty ||
        bytes.lengthInBytes > 2 * 1024 * 1024 ||
        !const {'jpg', 'jpeg', 'png', 'webp'}.contains(normalizedExtension)) {
      throw const GroupException(
        'Fotoğraf JPEG, PNG veya WebP ve en fazla 2 MB olmalı.',
      );
    }
    final path = '$groupId/${_uuid.v4()}.$normalizedExtension';
    final oldPath = group.avatarPath;
    _avatarBytes[path] = Uint8List.fromList(bytes);
    if (oldPath != null) _avatarBytes.remove(oldPath);
    final next = group.copyWith(
      avatarPath: path,
      avatarUpdatedAt: DateTime.now().toUtc(),
    );
    _groups[groupId] = next;
    _changes.add(null);
    return next;
  }

  @override
  Future<String?> createGroupAvatarSignedUrl(String? avatarPath) async {
    if (avatarPath == null) return null;
    final bytes = _avatarBytes[avatarPath];
    if (bytes == null) return null;
    final mime = avatarPath.endsWith('.png')
        ? 'image/png'
        : avatarPath.endsWith('.webp')
        ? 'image/webp'
        : 'image/jpeg';
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }

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

  void _reconcilePrimaryGroup(String userId) {
    final groups = _groupsForUser(userId);
    final current = _primaryPreferences[userId];
    String? desired;
    if (groups.length == 1) {
      desired = groups.single.id;
    } else if (groups.length > 1 &&
        groups.any((group) => group.id == current?.primaryGroupId)) {
      desired = current?.primaryGroupId;
    }
    if (current?.primaryGroupId != desired) {
      _primaryPreferences[userId] = PrimaryGroupPreference(
        primaryGroupId: desired,
        selectionRevision: (current?.selectionRevision ?? 0) + 1,
        nextChangeAllowedAt: current?.nextChangeAllowedAt,
      );
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
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || normalizedName.length > 64) {
      throw const GroupException('Grup adı 1 ile 64 karakter arasında olmalı.');
    }
    if (memberLimit < kMinGroupMemberLimit ||
        memberLimit > kMaxGroupMemberLimit) {
      throw const GroupException('Üye sınırı 2 ile 8 arasında olmalı.');
    }
    final group = StudyGroup(
      id: _uuid.v4(),
      name: normalizedName,
      inviteCode: _generateInviteCode(),
      createdBy: creator.id,
      createdAt: DateTime.now(),
      visibility: visibility,
      memberLimit: memberLimit,
      timeZone: timeZone.trim().isEmpty
          ? kDefaultGroupTimeZone
          : timeZone.trim(),
    );
    _groups[group.id] = group;
    _members[group.id] = [creator];
    _userGroups.putIfAbsent(creator.id, () => []).add(group.id);
    _reconcilePrimaryGroup(creator.id);
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
    String? timeZone,
    String userTimeZone = kDefaultGroupTimeZone,
    bool onlyWithCapacity = false,
    int offset = 0,
    int limit = 20,
  }) async {
    final normalized = query.trim().toLowerCase();
    final normalizedTimeZone = timeZone?.trim();
    final safeOffset = offset < 0 ? 0 : offset;
    final safeLimit = limit.clamp(1, 50).toInt();
    final now = DateTime.now().toUtc();
    final userOffset = _timeZoneOffsetMinutes(userTimeZone, now);
    final visible =
        _groups.values
            .where((group) => group.visibility == GroupVisibility.public)
            .where(
              (group) =>
                  normalized.isEmpty ||
                  group.name.toLowerCase().contains(normalized),
            )
            .where(
              (group) =>
                  normalizedTimeZone == null ||
                  normalizedTimeZone.isEmpty ||
                  group.timeZone == normalizedTimeZone,
            )
            .where(
              (group) =>
                  !onlyWithCapacity ||
                  (_members[group.id]?.length ?? 0) < group.memberLimit,
            )
            .toList()
          ..sort((a, b) {
            final aDistance =
                (_timeZoneOffsetMinutes(a.timeZone, now) - userOffset).abs();
            final bDistance =
                (_timeZoneOffsetMinutes(b.timeZone, now) - userOffset).abs();
            final byDistance = aDistance.compareTo(bDistance);
            if (byDistance != 0) return byDistance;
            final byCreatedAt = b.createdAt.compareTo(a.createdAt);
            return byCreatedAt != 0 ? byCreatedAt : a.id.compareTo(b.id);
          });

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
            timeZone: group.timeZone,
          ),
        )
        .toList(growable: false);
  }

  int _timeZoneOffsetMinutes(String timeZone, DateTime now) {
    try {
      tzdata.initializeTimeZones();
      return tz.TZDateTime.from(
        now,
        tz.getLocation(timeZone),
      ).timeZoneOffset.inMinutes;
    } catch (_) {
      return 0;
    }
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
    if (_bannedMembers[group.id]?.containsKey(member.id) ?? false) {
      throw const GroupException('Bu gruba katılmanız engellendi.');
    }
    final members = _members.putIfAbsent(group.id, () => []);
    final isAlreadyMember = members.any((profile) => profile.id == member.id);
    if (!isAlreadyMember && members.length >= group.memberLimit) {
      throw const GroupException('Grup dolu.');
    }
    if (!isAlreadyMember) members.add(member);
    final mine = _userGroups.putIfAbsent(member.id, () => []);
    if (!mine.contains(group.id)) mine.add(group.id);
    _reconcilePrimaryGroup(member.id);
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
  Stream<PrimaryGroupPreference> watchPrimaryGroupPreference(
    String userId,
  ) async* {
    yield _primaryPreferences[userId] ??
        const PrimaryGroupPreference(
          primaryGroupId: null,
          selectionRevision: 0,
        );
    await for (final _ in _changes.stream) {
      yield _primaryPreferences[userId] ??
          const PrimaryGroupPreference(
            primaryGroupId: null,
            selectionRevision: 0,
          );
    }
  }

  @override
  Future<PrimaryGroupPreference> setPrimaryGroup({
    required String userId,
    required String groupId,
    required int expectedRevision,
  }) async {
    _reconcilePrimaryGroup(userId);
    final current =
        _primaryPreferences[userId] ??
        const PrimaryGroupPreference(
          primaryGroupId: null,
          selectionRevision: 0,
        );
    if (current.selectionRevision != expectedRevision) {
      throw const GroupException('Birincil grup seçimi güncel değil.');
    }
    if (!_groupsForUser(userId).any((group) => group.id == groupId)) {
      throw const GroupException('Bu grubun aktif üyesi değilsiniz.');
    }
    final next = PrimaryGroupPreference(
      primaryGroupId: groupId,
      selectionRevision: current.primaryGroupId == groupId
          ? current.selectionRevision
          : current.selectionRevision + 1,
      nextChangeAllowedAt: current.primaryGroupId == groupId
          ? current.nextChangeAllowedAt
          : _now().toUtc().add(const Duration(hours: 24)),
    );
    if (current.primaryGroupId != groupId &&
        current.nextChangeAllowedAt != null &&
        _now().toUtc().isBefore(current.nextChangeAllowedAt!)) {
      throw const GroupException(
        'Birincil grup değişikliği için 24 saat beklemelisiniz.',
      );
    }
    _primaryPreferences[userId] = next;
    _changes.add(null);
    return next;
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
  Future<void> updateGroupTimeZone(String groupId, String timeZone) async {
    final group = _groups[groupId];
    final normalized = timeZone.trim();
    if (group == null) throw const GroupException('Grup bulunamadı.');
    if (normalized.isEmpty) {
      throw const GroupException('Geçerli bir zaman dilimi seçin.');
    }
    _groups[groupId] = group.copyWith(timeZone: normalized);
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
    if (memberLimit < kMinGroupMemberLimit ||
        memberLimit > kMaxGroupMemberLimit) {
      throw const GroupException('Üye sınırı 2 ile 8 arasında olmalı.');
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
  Future<void> banMember(String groupId, String userId) async {
    final group = _groups[groupId];
    if (group == null) throw const GroupException('Grup bulunamadı.');
    if (group.createdBy == userId) {
      throw const GroupException('Grup yöneticisi engellenemez.');
    }
    Profile? member;
    for (final item in _members[groupId] ?? const <Profile>[]) {
      if (item.id == userId) {
        member = item;
        break;
      }
    }
    if (member == null) {
      throw const GroupException('Bu kullanıcı grubun aktif üyesi değil.');
    }
    _bannedMembers.putIfAbsent(groupId, () => {})[userId] = member;
    await removeMember(groupId, userId);
  }

  @override
  Future<void> unbanMember(String groupId, String userId) async {
    _bannedMembers[groupId]?.remove(userId);
    _changes.add(null);
  }

  @override
  Future<List<Profile>> listBannedMembers(String groupId) async =>
      List.unmodifiable(_bannedMembers[groupId]?.values ?? const <Profile>[]);

  @override
  Future<void> removeMember(String groupId, String userId) async {
    _members[groupId]?.removeWhere((m) => m.id == userId);
    _userGroups[userId]?.remove(groupId);
    _reconcilePrimaryGroup(userId);
    _changes.add(null);
  }

  @override
  Future<void> leaveGroup(String groupId, String userId) =>
      removeMember(groupId, userId);

  @override
  Future<void> deleteGroup(String groupId) async {
    final removed = _groups.remove(groupId);
    if (removed?.avatarPath case final path?) {
      _avatarBytes.remove(path);
    }
    final affectedUserIds =
        _members[groupId]?.map((member) => member.id).toSet() ?? <String>{};
    _members.remove(groupId);
    _bannedMembers.remove(groupId);
    for (final ids in _userGroups.values) {
      ids.remove(groupId);
    }
    for (final userId in affectedUserIds) {
      _reconcilePrimaryGroup(userId);
    }
    _changes.add(null);
  }

  void dispose() => _changes.close();
}
