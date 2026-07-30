import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/repositories/group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';

Profile _profile(String id, String name) =>
    Profile(id: id, displayName: name, createdAt: DateTime.now());

/// WP-445: gruptan çıkış idempotency ve sahiplik sözleşmesi.
///
/// Bu testler `0108_leave_group_command.sql` ile aynı semantiği bellek-içi
/// yolda doğrular; SQL tarafı `supabase/tests/033_leave_group_command.test.sql`.
void main() {
  late InMemoryGroupRepository repo;
  late String groupId;

  setUp(() async {
    repo = InMemoryGroupRepository();
    final group = await repo.createGroup(
      name: 'Çıkış Testi',
      creator: _profile('owner', 'Sahip'),
    );
    groupId = group.id;
    await repo.joinGroup(
      inviteCode: group.inviteCode,
      member: _profile('member', 'Üye'),
    );
  });

  test('aynı komut anahtarıyla 20 hızlı tap tek çıkış üretir', () async {
    final outcomes = <GroupLeaveOutcome>[];
    for (var i = 0; i < 20; i++) {
      outcomes.add(
        await repo.leaveGroup(groupId, 'member', commandId: 'cmd-1'),
      );
    }

    // Tekrar eden çağrılar işi yeniden yapmaz; hepsi ilk sonucu döndürür.
    expect(outcomes, everyElement(GroupLeaveOutcome.left));
    final members = await repo.watchMembers(groupId).first;
    expect(members.where((m) => m.id == 'member'), isEmpty);
    expect(members.length, 1);
  });

  test('çıkış sonrası yeni komut anahtarı alreadyLeft döndürür, hata değil', () async {
    await repo.leaveGroup(groupId, 'member', commandId: 'cmd-1');

    // Çevrimdışı retry yeni anahtarla gelse bile sahte hata gösterilmez.
    expect(
      await repo.leaveGroup(groupId, 'member', commandId: 'cmd-2'),
      GroupLeaveOutcome.alreadyLeft,
    );
  });

  test('grup sahibi çıkamaz: sahipsiz grup bırakılmaz', () async {
    await expectLater(
      repo.leaveGroup(groupId, 'owner', commandId: 'cmd-owner'),
      throwsA(isA<GroupOwnerCannotLeaveException>()),
    );

    final members = await repo.watchMembers(groupId).first;
    expect(members.where((m) => m.id == 'owner'), isNotEmpty);
  });

  test('sahibin başarısız çıkışı komutu tüketmez', () async {
    await expectLater(
      repo.leaveGroup(groupId, 'owner', commandId: 'cmd-owner'),
      throwsA(isA<GroupOwnerCannotLeaveException>()),
    );

    // Aynı anahtar "işlenmiş" sayılsaydı devretme sonrası retry sessizce
    // alreadyLeft döner ve sahip hiç çıkmamış olurdu.
    await expectLater(
      repo.leaveGroup(groupId, 'owner', commandId: 'cmd-owner'),
      throwsA(isA<GroupOwnerCannotLeaveException>()),
    );
  });

  test('başka kullanıcının komut anahtarı kabul edilmez', () async {
    await repo.leaveGroup(groupId, 'member', commandId: 'cmd-1');

    await expectLater(
      repo.leaveGroup(groupId, 'owner', commandId: 'cmd-1'),
      throwsA(isA<GroupException>()),
    );
  });

  test('hiç üye olmayan kullanıcı için sonuç alreadyLeft', () async {
    expect(
      await repo.leaveGroup(groupId, 'yabanci', commandId: 'cmd-x'),
      GroupLeaveOutcome.alreadyLeft,
    );
  });
}
