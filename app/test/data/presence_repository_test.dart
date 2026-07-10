import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
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
    // started_at UTC olarak yazılıp okunur → aynı anı temsil etmeli (saat dilimi kaymasın).
    expect(round.startedAt!.isAtSameMomentAs(p.startedAt!), isTrue);
    // updated_at da okunur (bayatlama tespiti buna dayanır).
    expect(round.updatedAt, isNotNull);
  });

  group('applyPresenceStaleness (§WP-5 çevrimdışı tespiti)', () {
    final now = DateTime(2026, 7, 10, 12, 0, 0);

    Presence studying(String id, {DateTime? updatedAt}) => Presence(
          userId: id,
          groupId: 'g1',
          status: PresenceStatus.studying,
          todaySeconds: 0,
          startedAt: now.subtract(const Duration(minutes: 30)),
          updatedAt: updatedAt,
        );

    test('taze satır çalışıyor kalır', () {
      final rows = [studying('u1', updatedAt: now.subtract(const Duration(seconds: 10)))];
      final result = applyPresenceStaleness(rows, now: now);
      expect(result.single.status, PresenceStatus.studying);
    });

    test('bayat satır çevrimdışına çekilir', () {
      final rows = [
        studying('u1', updatedAt: now.subtract(kPresenceStaleThreshold * 2)),
      ];
      final result = applyPresenceStaleness(rows, now: now);
      expect(result.single.status, PresenceStatus.offline);
      // Kimlik/grup korunur; yalnız durum değişir.
      expect(result.single.userId, 'u1');
    });

    test('updatedAt null ise durum korunur (bellek-içi/eski satır)', () {
      final rows = [studying('u1', updatedAt: null)];
      final result = applyPresenceStaleness(rows, now: now);
      expect(result.single.status, PresenceStatus.studying);
    });

    test('eşik sınırındaki satır hâlâ canlı sayılır', () {
      final rows = [studying('u1', updatedAt: now.subtract(kPresenceStaleThreshold))];
      final result = applyPresenceStaleness(rows, now: now);
      expect(result.single.status, PresenceStatus.studying);
    });

    test('zaten çevrimdışı satır olduğu gibi kalır', () {
      final rows = [
        Presence(
          userId: 'u1',
          groupId: 'g1',
          status: PresenceStatus.offline,
          todaySeconds: 0,
          updatedAt: now.subtract(kPresenceStaleThreshold * 3),
        ),
      ];
      final result = applyPresenceStaleness(rows, now: now);
      expect(result.single.status, PresenceStatus.offline);
    });
  });
}
