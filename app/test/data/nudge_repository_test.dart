import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_nudge_repository.dart';
import 'package:online_study_room/data/repositories/nudge_repository.dart';

Profile _profile(String id, String name) =>
    Profile(id: id, displayName: name, createdAt: DateTime(2026));

void main() {
  test('sendNudge alıcının akışına düşer ve gönderen adını taşır', () async {
    final repo = InMemoryNudgeRepository();
    addTearDown(repo.dispose);

    final nudge = await repo.sendNudge(
      groupId: 'g1',
      sender: _profile('u1', 'Ada'),
      recipient: _profile('u2', 'Ece'),
    );

    final received = await repo.watchReceivedNudges('u2').first;
    expect(received, hasLength(1));
    expect(received.single.id, nudge.id);
    expect(received.single.senderDisplayName, 'Ada');
  });

  test('kendine dürtme ve cooldown reddedilir', () async {
    final repo = InMemoryNudgeRepository();
    addTearDown(repo.dispose);
    final ada = _profile('u1', 'Ada');
    final ece = _profile('u2', 'Ece');

    expect(
      () => repo.sendNudge(groupId: 'g1', sender: ada, recipient: ada),
      throwsA(isA<NudgeException>()),
    );

    await repo.sendNudge(groupId: 'g1', sender: ada, recipient: ece);
    expect(
      () => repo.sendNudge(groupId: 'g1', sender: ada, recipient: ece),
      throwsA(isA<NudgeException>()),
    );
  });

  test('markRead dürtmeyi okundu yapar', () async {
    final repo = InMemoryNudgeRepository();
    addTearDown(repo.dispose);

    final nudge = await repo.sendNudge(
      groupId: 'g1',
      sender: _profile('u1', 'Ada'),
      recipient: _profile('u2', 'Ece'),
    );
    await repo.markRead(nudge.id);

    final received = await repo.watchReceivedNudges('u2').first;
    expect(received.single.readAt, isNotNull);
  });
}
