import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_presence_repository.dart';

Presence _presence(
  String userId,
  String groupId,
  PresenceStatus status,
) {
  return Presence(
    userId: userId,
    groupId: groupId,
    status: status,
    todaySeconds: 0,
    startedAt: status == PresenceStatus.studying ? DateTime(2026, 6, 21, 9) : null,
  );
}

void main() {
  test('watchGroupPresence yalnızca o sınıfın durumlarını verir', () async {
    final repo = InMemoryPresenceRepository();
    await repo.setPresence(_presence('u1', 'g1', PresenceStatus.studying));
    await repo.setPresence(_presence('u2', 'g1', PresenceStatus.offline));
    await repo.setPresence(_presence('u3', 'g2', PresenceStatus.studying));

    final g1 = await repo.watchGroupPresence('g1').first;
    expect(g1.map((p) => p.userId).toSet(), {'u1', 'u2'});
  });

  test('setPresence kullanıcı başına tek satır tutar (upsert)', () async {
    final repo = InMemoryPresenceRepository();
    await repo.setPresence(_presence('u1', 'g1', PresenceStatus.studying));
    await repo.setPresence(_presence('u1', 'g1', PresenceStatus.offline));

    final g1 = await repo.watchGroupPresence('g1').first;
    expect(g1, hasLength(1));
    expect(g1.single.status, PresenceStatus.offline);
  });

  test('Presence toMap/fromMap gidiş-dönüş tutarlı', () {
    final p = _presence('u1', 'g1', PresenceStatus.studying);
    final round = Presence.fromMap(p.toMap());
    expect(round.userId, p.userId);
    expect(round.groupId, p.groupId);
    expect(round.status, p.status);
    expect(round.startedAt, p.startedAt);
  });
}
