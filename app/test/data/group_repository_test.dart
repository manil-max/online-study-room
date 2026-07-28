import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/repositories/group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';

Profile _profile(String id, String name) =>
    Profile(id: id, displayName: name, createdAt: DateTime.now());

void main() {
  test(
    'group avatar validates format, versions path and exposes no public URL',
    () async {
      final repo = InMemoryGroupRepository();
      final group = await repo.createGroup(
        name: 'Avatar Test',
        creator: _profile('u1', 'Ali'),
      );

      final first = await repo.uploadGroupAvatar(
        groupId: group.id,
        bytes: Uint8List.fromList([1, 2, 3]),
        extension: '.PNG',
      );
      final second = await repo.uploadGroupAvatar(
        groupId: group.id,
        bytes: Uint8List.fromList([4, 5, 6]),
        extension: 'webp',
      );

      expect(first.avatarPath, startsWith('${group.id}/'));
      expect(first.avatarPath, endsWith('.png'));
      expect(second.avatarPath, isNot(first.avatarPath));
      expect(second.avatarUpdatedAt, isNotNull);
      expect(
        await repo.createGroupAvatarSignedUrl(second.avatarPath),
        startsWith('data:image/webp;base64,'),
      );
      expect(await repo.createGroupAvatarSignedUrl(first.avatarPath), isNull);

      await expectLater(
        repo.uploadGroupAvatar(
          groupId: group.id,
          bytes: Uint8List.fromList([1]),
          extension: 'gif',
        ),
        throwsA(isA<GroupException>()),
      );
      await expectLater(
        repo.uploadGroupAvatar(
          groupId: group.id,
          bytes: Uint8List(2 * 1024 * 1024 + 1),
          extension: 'jpg',
        ),
        throwsA(isA<GroupException>()),
      );
    },
  );

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
        timeZone: 'Asia/Kolkata',
      );

      final results = await repo.discoverPublicGroups(query: 'focus');

      expect(results, hasLength(1));
      expect(results.single.id, public.id);
      expect(results.single.name, 'Global Focus');
      expect(results.single.memberCount, 1);
      expect(results.single.memberLimit, kDefaultGroupMemberLimit);
      expect(results.single.timeZone, 'Asia/Kolkata');
      expect(results.single.toString(), isNot(contains(public.inviteCode)));
    },
  );

  test(
    'public keşif bölge, kontenjan ve anlık saat farkına göre filtreler',
    () async {
      final repo = InMemoryGroupRepository();
      final newYork = await repo.createGroup(
        name: 'New York Focus',
        creator: _profile('u1', 'Ali'),
        visibility: GroupVisibility.public,
        timeZone: 'America/New_York',
      );
      await repo.createGroup(
        name: 'Tokyo Focus',
        creator: _profile('u2', 'Veli'),
        visibility: GroupVisibility.public,
        timeZone: 'Asia/Tokyo',
      );
      final full = await repo.createGroup(
        name: 'Full New York',
        creator: _profile('u3', 'Deniz'),
        visibility: GroupVisibility.public,
        memberLimit: 2,
        timeZone: 'America/New_York',
      );
      await repo.joinPublicGroup(
        groupId: full.id,
        member: _profile('u4', 'Ece'),
      );

      final ordered = await repo.discoverPublicGroups(
        userTimeZone: 'America/New_York',
      );
      expect(ordered.first.timeZone, newYork.timeZone);

      final regional = await repo.discoverPublicGroups(
        userTimeZone: 'America/New_York',
        timeZone: 'America/New_York',
        onlyWithCapacity: true,
      );
      expect(regional.map((group) => group.id), [newYork.id]);
    },
  );

  test(
    'birincil grup hesap-genelidir, stale seçimi reddeder ve üyelikte uzlaşır',
    () async {
      final repo = InMemoryGroupRepository();
      final user = _profile('u1', 'Ali');
      final first = await repo.createGroup(name: 'İlk', creator: user);
      final second = await repo.createGroup(name: 'İkinci', creator: user);

      final initial = await repo.watchPrimaryGroupPreference(user.id).first;
      expect(initial.primaryGroupId, first.id);
      expect(initial.selectionRevision, 1);

      final selected = await repo.setPrimaryGroup(
        userId: user.id,
        groupId: second.id,
        expectedRevision: initial.selectionRevision,
      );
      expect(selected.primaryGroupId, second.id);
      expect(selected.selectionRevision, 2);
      await expectLater(
        repo.setPrimaryGroup(
          userId: user.id,
          groupId: first.id,
          expectedRevision: initial.selectionRevision,
        ),
        throwsA(isA<GroupException>()),
      );

      await repo.leaveGroup(second.id, user.id);
      final reconciled = await repo.watchPrimaryGroupPreference(user.id).first;
      expect(reconciled.primaryGroupId, first.id);
      expect(reconciled.selectionRevision, 3);
    },
  );

  test(
    'birincil grup cooldownı yalnız açık hedef değişiminde başlar ve no-op tüketmez',
    () async {
      var clock = DateTime.utc(2026, 7, 26, 12);
      final repo = InMemoryGroupRepository(now: () => clock);
      final user = _profile('u1', 'Ali');
      final first = await repo.createGroup(name: 'İlk', creator: user);
      final second = await repo.createGroup(name: 'İkinci', creator: user);
      final initial = await repo.watchPrimaryGroupPreference(user.id).first;

      final firstExplicit = await repo.setPrimaryGroup(
        userId: user.id,
        groupId: second.id,
        expectedRevision: initial.selectionRevision,
      );
      expect(
        firstExplicit.nextChangeAllowedAt,
        clock.add(const Duration(hours: 24)),
      );

      await expectLater(
        repo.setPrimaryGroup(
          userId: user.id,
          groupId: first.id,
          expectedRevision: firstExplicit.selectionRevision,
        ),
        throwsA(isA<GroupException>()),
      );

      final noOp = await repo.setPrimaryGroup(
        userId: user.id,
        groupId: second.id,
        expectedRevision: firstExplicit.selectionRevision,
      );
      expect(noOp.selectionRevision, firstExplicit.selectionRevision);
      expect(noOp.nextChangeAllowedAt, firstExplicit.nextChangeAllowedAt);

      clock = clock.add(const Duration(hours: 24, seconds: 1));
      final changed = await repo.setPrimaryGroup(
        userId: user.id,
        groupId: first.id,
        expectedRevision: noOp.selectionRevision,
      );
      expect(changed.primaryGroupId, first.id);
      expect(changed.selectionRevision, noOp.selectionRevision + 1);
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

  test('grup adı süzgeci boşluk ve noktalama varyantını reddeder', () async {
    final repo = InMemoryGroupRepository();
    await expectLater(
      repo.createGroup(name: 'a_m-k', creator: _profile('u1', 'Ali')),
      throwsA(isA<GroupException>()),
    );
    final group = await repo.createGroup(
      name: 'Odak Arkadaşları',
      creator: _profile('u1', 'Ali'),
    );
    await expectLater(
      repo.updateGroupName(group.id, 'f.u_c-k'),
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

  test(
    'grup yasağı üyeyi çıkarır, katılımı reddeder ve kaldırılabilir',
    () async {
      final repo = InMemoryGroupRepository();
      final group = await repo.createGroup(
        name: 'Yasak Testi',
        creator: _profile('u1', 'Ali'),
      );
      final member = _profile('u2', 'Veli');
      await repo.joinGroup(inviteCode: group.inviteCode, member: member);

      await repo.banMember(group.id, member.id);

      expect(await repo.watchMembers(group.id).first, hasLength(1));
      expect(await repo.listBannedMembers(group.id), [member]);
      await expectLater(
        repo.joinGroup(inviteCode: group.inviteCode, member: member),
        throwsA(isA<GroupException>()),
      );

      await repo.unbanMember(group.id, member.id);
      await repo.joinGroup(inviteCode: group.inviteCode, member: member);
      expect(await repo.watchMembers(group.id).first, hasLength(2));
    },
  );

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

  group('grup üye sınırı 8 (sahip kararı 2026-07-26)', () {
    // Bu sayılar `0071_group_member_limit_8.sql` ile **birebir** aynı olmalı.
    // Ayrışırsa istemci, sunucunun reddedeceği bir grubu kurulmuş sayar ve
    // hata ancak ağ katmanında görünür — bu test o ayrışmayı erken yakalar.
    test('varsayılan ve üst sınır 8', () {
      expect(kDefaultGroupMemberLimit, 8);
      expect(kMaxGroupMemberLimit, 8);
      expect(kMinGroupMemberLimit, 2);
    });

    test('yeni grup 8 sınırıyla açılır', () async {
      final repo = InMemoryGroupRepository();
      final group = await repo.createGroup(
        name: 'Sekizlik',
        creator: _profile('u1', 'Ali'),
      );
      expect(group.memberLimit, 8);
    });

    test('8 üstü sınır reddedilir', () async {
      final repo = InMemoryGroupRepository();
      await expectLater(
        repo.createGroup(
          name: 'Kalabalık',
          creator: _profile('u1', 'Ali'),
          memberLimit: 9,
        ),
        throwsA(isA<GroupException>()),
      );

      final group = await repo.createGroup(
        name: 'Normal',
        creator: _profile('u2', 'Veli'),
      );
      await expectLater(
        repo.updateGroupAccess(
          group.id,
          visibility: GroupVisibility.public,
          memberLimit: 9,
        ),
        throwsA(isA<GroupException>()),
      );
    });

    test('9. üye gruba giremez', () async {
      final repo = InMemoryGroupRepository();
      final group = await repo.createGroup(
        name: 'Dolan Grup',
        creator: _profile('u0', 'Kurucu'),
        visibility: GroupVisibility.public,
      );

      // Kurucu dahil 8 kişi.
      for (var i = 1; i < 8; i++) {
        await repo.joinPublicGroup(
          groupId: group.id,
          member: _profile('u$i', 'Üye $i'),
        );
      }

      await expectLater(
        repo.joinPublicGroup(
          groupId: group.id,
          member: _profile('u8', 'Dokuzuncu'),
        ),
        throwsA(isA<GroupException>()),
      );
    });
  });

  test('grup IANA zaman dilimini saklar ve admin akışı günceller', () async {
    final repo = InMemoryGroupRepository();
    final group = await repo.createGroup(
      name: 'Dünya Çapında',
      creator: _profile('u1', 'Ali'),
      timeZone: 'America/New_York',
    );
    expect(group.timeZone, 'America/New_York');

    await repo.updateGroupTimeZone(group.id, 'Asia/Kolkata');
    expect(
      (await repo.watchUserGroups('u1').first).single.timeZone,
      'Asia/Kolkata',
    );

    final defaultGroup = await repo.createGroup(
      name: 'Varsayılan',
      creator: _profile('u2', 'Veli'),
    );
    expect(defaultGroup.timeZone, kDefaultGroupTimeZone);
  });
}
