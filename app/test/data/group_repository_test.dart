import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/repositories/group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';

Profile _profile(String id, String name) =>
    Profile(id: id, displayName: name, createdAt: DateTime.now());

void main() {
  test(
    'createGroup 6 haneli davet kodu üretir ve oluşturanı üye yapar',
    () async {
      final repo = InMemoryGroupRepository();
      final group = await repo.createGroup(
        name: 'Test',
        creator: _profile('u1', 'Ali'),
      );

      expect(group.inviteCode.length, 6);
      expect(group.name, 'Test');
      expect(await repo.watchMembers(group.id).first, hasLength(1));
    },
  );

  test('joinGroup doğru kodla katar, üye sayısı artar', () async {
    final repo = InMemoryGroupRepository();
    final group = await repo.createGroup(
      name: 'Test',
      creator: _profile('u1', 'Ali'),
    );

    final joined = await repo.joinGroup(
      inviteCode: group.inviteCode,
      member: _profile('u2', 'Veli'),
    );

    expect(joined.id, group.id);
    expect(await repo.watchMembers(group.id).first, hasLength(2));
  });

  test(
    'public keşif yalnız açık grupların davet kodsuz özetini döndürür',
    () async {
      final repo = InMemoryGroupRepository();
      await repo.createGroup(
        name: 'Kapalı Aile',
        creator: _profile('u1', 'Ali'),
      );
      final public = await repo.createGroup(
        name: 'Global Focus',
        creator: _profile('u2', 'Veli'),
        visibility: GroupVisibility.public,
      );

      final results = await repo.discoverPublicGroups(query: 'focus');

      expect(results, hasLength(1));
      expect(results.single.id, public.id);
      expect(results.single.name, 'Global Focus');
      expect(results.single.memberCount, 1);
      expect(results.single.memberLimit, 50);
      expect(results.single.toString(), isNot(contains(public.inviteCode)));
    },
  );

  test(
    'public katılım grubu üyeye ekler ve private grup RPC ile katılamaz',
    () async {
      final repo = InMemoryGroupRepository();
      final public = await repo.createGroup(
        name: 'Global Focus',
        creator: _profile('u1', 'Ali'),
        visibility: GroupVisibility.public,
      );
      final private = await repo.createGroup(
        name: 'Kapalı Aile',
        creator: _profile('u2', 'Veli'),
      );

      final joined = await repo.joinPublicGroup(
        groupId: public.id,
        member: _profile('u3', 'Deniz'),
      );

      expect(joined.id, public.id);
      expect(await repo.watchUserGroups('u3').first, [public]);
      await expectLater(
        repo.joinPublicGroup(
          groupId: private.id,
          member: _profile('u3', 'Deniz'),
        ),
        throwsA(isA<GroupException>()),
      );
    },
  );

  test(
    'üye sınırı aşılmaz ve zaten üyenin tekrar katılımı idempotenttir',
    () async {
      final repo = InMemoryGroupRepository();
      final group = await repo.createGroup(
        name: 'Küçük Klan',
        creator: _profile('u1', 'Ali'),
        visibility: GroupVisibility.public,
        memberLimit: 2,
      );

      await repo.joinPublicGroup(
        groupId: group.id,
        member: _profile('u2', 'Veli'),
      );
      await repo.joinPublicGroup(
        groupId: group.id,
        member: _profile('u2', 'Veli'),
      );
      await expectLater(
        repo.joinPublicGroup(
          groupId: group.id,
          member: _profile('u3', 'Deniz'),
        ),
        throwsA(isA<GroupException>()),
      );
      expect(await repo.watchMembers(group.id).first, hasLength(2));
    },
  );

  test('admin erişimi üye sayısının altına indiremez', () async {
    final repo = InMemoryGroupRepository();
    final group = await repo.createGroup(
      name: 'Global Focus',
      creator: _profile('u1', 'Ali'),
      visibility: GroupVisibility.public,
    );
    await repo.joinPublicGroup(
      groupId: group.id,
      member: _profile('u2', 'Veli'),
    );

    await expectLater(
      repo.updateGroupAccess(
        group.id,
        visibility: GroupVisibility.private,
        memberLimit: 1,
      ),
      throwsA(isA<GroupException>()),
    );
    await repo.updateGroupAccess(
      group.id,
      visibility: GroupVisibility.private,
      memberLimit: 2,
    );
    expect(await repo.discoverPublicGroups(), isEmpty);
  });

  test('hatalı kodla katılma GroupException fırlatır', () async {
    final repo = InMemoryGroupRepository();
    await repo.createGroup(name: 'Test', creator: _profile('u1', 'Ali'));

    expect(
      () =>
          repo.joinGroup(inviteCode: 'ZZZZZZ', member: _profile('u2', 'Veli')),
      throwsA(isA<GroupException>()),
    );
  });

  test('boş adla oluşturma GroupException fırlatır', () async {
    final repo = InMemoryGroupRepository();
    expect(
      () => repo.createGroup(name: '   ', creator: _profile('u1', 'Ali')),
      throwsA(isA<GroupException>()),
    );
  });

  test(
    'updateGroupName / regenerateInviteCode adı ve kodu değiştirir',
    () async {
      final repo = InMemoryGroupRepository();
      final g = await repo.createGroup(
        name: 'Eski',
        creator: _profile('u1', 'Ali'),
      );

      await repo.updateGroupName(g.id, 'Yeni Ad');
      final newCode = await repo.regenerateInviteCode(g.id);

      final mine = await repo.watchUserGroups('u1').first;
      expect(mine.single.name, 'Yeni Ad');
      expect(mine.single.inviteCode, newCode);
      expect(newCode, isNot(g.inviteCode));
    },
  );

  test(
    'updateGroupGoal günlük hedefi değiştirir ve 1..1440 aralığına sıkıştırır',
    () async {
      final repo = InMemoryGroupRepository();
      final g = await repo.createGroup(
        name: 'A',
        creator: _profile('u1', 'Ali'),
      );
      expect(g.dailyGoalMinutes, 360); // varsayılan

      await repo.updateGroupGoal(g.id, 240);
      expect(
        (await repo.watchUserGroups('u1').first).single.dailyGoalMinutes,
        240,
      );

      // Sınır dışı değerler sıkıştırılır.
      await repo.updateGroupGoal(g.id, 0);
      expect(
        (await repo.watchUserGroups('u1').first).single.dailyGoalMinutes,
        1,
      );
      await repo.updateGroupGoal(g.id, 5000);
      expect(
        (await repo.watchUserGroups('u1').first).single.dailyGoalMinutes,
        1440,
      );
    },
  );

  test('removeMember üyeyi çıkarır, sınıfından düşer', () async {
    final repo = InMemoryGroupRepository();
    final g = await repo.createGroup(name: 'A', creator: _profile('u1', 'Ali'));
    await repo.joinGroup(
      inviteCode: g.inviteCode,
      member: _profile('u2', 'Veli'),
    );

    await repo.removeMember(g.id, 'u2');

    expect(await repo.watchMembers(g.id).first, hasLength(1));
    expect(await repo.watchUserGroups('u2').first, isEmpty);
  });

  test('deleteGroup sınıfı herkesten kaldırır', () async {
    final repo = InMemoryGroupRepository();
    final g = await repo.createGroup(name: 'A', creator: _profile('u1', 'Ali'));
    await repo.joinGroup(
      inviteCode: g.inviteCode,
      member: _profile('u2', 'Veli'),
    );

    await repo.deleteGroup(g.id);

    expect(await repo.watchUserGroups('u1').first, isEmpty);
    expect(await repo.watchUserGroups('u2').first, isEmpty);
  });

  test(
    'watchUserGroups kullanıcının tüm sınıflarını verir (çoklu sınıf)',
    () async {
      final repo = InMemoryGroupRepository();
      final ali = _profile('u1', 'Ali');
      final g1 = await repo.createGroup(name: 'Sınıf A', creator: ali);
      final g2 = await repo.createGroup(name: 'Sınıf B', creator: ali);
      // Başka birinin sınıfına da katıl.
      final g3 = await repo.createGroup(
        name: 'Sınıf C',
        creator: _profile('u2', 'Veli'),
      );
      await repo.joinGroup(inviteCode: g3.inviteCode, member: ali);

      final mine = await repo.watchUserGroups('u1').first;
      expect(mine.map((g) => g.id).toSet(), {g1.id, g2.id, g3.id});

      // u2 yalnızca kendi sınıfını görür.
      final others = await repo.watchUserGroups('u2').first;
      expect(others.map((g) => g.id).toList(), [g3.id]);
    },
  );
}
