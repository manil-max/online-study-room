import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../models/nudge.dart';
import '../../models/nudge_mute.dart';
import '../../models/profile.dart';
import '../nudge_repository.dart';

/// Susturulmuş alıcıya yapılan gönderim denemesi.
///
/// Satır üretilmese de cooldown penceresi işlemek zorundadır: aksi hâlde
/// gönderen "ikinci dürtme hemen kabul edildi" farkından susturulduğunu
/// anlardı (WP-444 yan kanal).
class _NudgeAttempt {
  const _NudgeAttempt({
    required this.groupId,
    required this.senderId,
    required this.recipientId,
    required this.createdAt,
  });

  final String groupId;
  final String senderId;
  final String recipientId;
  final DateTime createdAt;
}

class InMemoryNudgeRepository implements NudgeRepository {
  InMemoryNudgeRepository({this.currentUserId = 'demo-user'});

  /// Susturma tercihi hesap kapsamlıdır; demo modda "oturumdaki hesap" budur.
  String currentUserId;

  final _uuid = const Uuid();
  final List<Nudge> _nudges = [];
  final List<_NudgeAttempt> _attempts = [];

  /// alıcı kimliği → susturduğu gönderen kimlikleri.
  final Map<String, Set<String>> _mutedSendersByAccount = {};

  final Map<String, DateTime> _mutedAt = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<List<Nudge>> watchReceivedNudges(String userId) async* {
    yield _receivedFor(userId);
    await for (final _ in _changes.stream) {
      yield _receivedFor(userId);
    }
  }

  @override
  Future<Nudge> sendNudge({
    required String groupId,
    required Profile sender,
    required Profile recipient,
    String? message,
  }) async {
    if (sender.id == recipient.id) {
      throw const NudgeException('Kendine dürtme gönderemezsin.');
    }
    final now = DateTime.now();
    final recent = _attempts.any(
      (a) =>
          a.groupId == groupId &&
          a.senderId == sender.id &&
          a.recipientId == recipient.id &&
          now.difference(a.createdAt) < kNudgeCooldown,
    );
    if (recent) {
      throw const NudgeException(
        'Aynı kişiye 10 dakikada bir dürtme gönderebilirsin.',
      );
    }

    final nudge = Nudge(
      id: _uuid.v4(),
      groupId: groupId,
      senderId: sender.id,
      recipientId: recipient.id,
      message: normalizeNudgeMessage(message),
      createdAt: now,
      senderDisplayName: sender.displayName,
      senderAvatarUrl: sender.avatarUrl,
    );
    _attempts.add(
      _NudgeAttempt(
        groupId: groupId,
        senderId: sender.id,
        recipientId: recipient.id,
        createdAt: now,
      ),
    );

    // WP-444: alıcı bu göndereni susturmuşsa satır yazılmaz ve akış tetiklenmez.
    // Gönderene dönen sonuç susturulmamış durumla birebir aynıdır.
    if (_isMuted(recipientId: recipient.id, senderId: sender.id)) {
      return nudge;
    }

    _nudges.add(nudge);
    _changes.add(null);
    return nudge;
  }

  @override
  Future<void> markRead(String nudgeId) async {
    final index = _nudges.indexWhere((n) => n.id == nudgeId);
    if (index < 0) return;
    _nudges[index] = _nudges[index].copyWith(readAt: DateTime.now());
    _changes.add(null);
  }

  @override
  Future<List<String>> listMutedNudgeSenderIds() async =>
      (_mutedSendersByAccount[currentUserId] ?? const <String>{}).toList();

  @override
  Future<List<NudgeMute>> fetchNudgeMutes() async {
    final ids =
        (_mutedSendersByAccount[currentUserId] ?? const <String>{}).toList()
          ..sort();
    return [
      for (final id in ids)
        NudgeMute(
          mutedUserId: id,
          mutedAt:
              _mutedAt['$currentUserId|$id'] ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
    ];
  }

  @override
  Future<void> muteNudgesFrom(String userId) async {
    if (userId == currentUserId) {
      throw const NudgeException('Kendini susturamazsın.');
    }
    _mutedSendersByAccount
        .putIfAbsent(currentUserId, () => <String>{})
        .add(userId);
    _mutedAt.putIfAbsent('$currentUserId|$userId', DateTime.now);
  }

  @override
  Future<void> unmuteNudgesFrom(String userId) async {
    _mutedSendersByAccount[currentUserId]?.remove(userId);
    _mutedAt.remove('$currentUserId|$userId');
  }

  bool _isMuted({required String recipientId, required String senderId}) =>
      _mutedSendersByAccount[recipientId]?.contains(senderId) ?? false;

  List<Nudge> _receivedFor(String userId) {
    final nudges = _nudges.where((n) => n.recipientId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(nudges.take(50));
  }

  void dispose() => _changes.close();
}
