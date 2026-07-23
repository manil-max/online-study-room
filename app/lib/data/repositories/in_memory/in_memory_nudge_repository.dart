import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../models/nudge.dart';
import '../../models/profile.dart';
import '../nudge_repository.dart';

class InMemoryNudgeRepository implements NudgeRepository {
  final _uuid = const Uuid();
  final List<Nudge> _nudges = [];
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
    final recent = _nudges.any(
      (n) =>
          n.groupId == groupId &&
          n.senderId == sender.id &&
          n.recipientId == recipient.id &&
          now.difference(n.createdAt) < kNudgeCooldown,
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

  List<Nudge> _receivedFor(String userId) {
    final nudges = _nudges.where((n) => n.recipientId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(nudges.take(50));
  }

  void dispose() => _changes.close();
}
