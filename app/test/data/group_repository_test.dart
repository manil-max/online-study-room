import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/repositories/group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';

Profile _profile(String id, String name) =>
    Profile(id: id, displayName: name, createdAt: DateTime.now());

void main() {
  test('createGroup 6 haneli davet kodu üretir ve oluşturanı üye yapar', () async {
    final repo = InMemoryGroupRepository();
    final group = await repo.createGroup(name: 'Test', creator: _profile('u1', 'Ali'));

    expect(group.inviteCode.length, 6);
    expect(group.name, 'Test');
    expect(await repo.watchMembers(group.id).first, hasLength(1));
  });

  test('joinGroup doğru kodla katar, üye sayısı artar', () async {
    final repo = InMemoryGroupRepository();
    final group = await repo.createGroup(name: 'Test', creator: _profile('u1', 'Ali'));

    final joined = await repo.joinGroup(
      inviteCode: group.inviteCode,
      member: _profile('u2', 'Veli'),
    );

    expect(joined.id, group.id);
    expect(await repo.watchMembers(group.id).first, hasLength(2));
  });

  test('hatalı kodla katılma GroupException fırlatır', () async {
    final repo = InMemoryGroupRepository();
    await repo.createGroup(name: 'Test', creator: _profile('u1', 'Ali'));

    expect(
      () => repo.joinGroup(inviteCode: 'ZZZZZZ', member: _profile('u2', 'Veli')),
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
}
