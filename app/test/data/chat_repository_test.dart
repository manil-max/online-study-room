import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/repositories/chat_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_chat_repository.dart';

Profile _profile(String id, String name) =>
    Profile(id: id, displayName: name, createdAt: DateTime(2026));

void main() {
  test('sendMessage mesajı kırpar ve gruba göre yayınlar', () async {
    final repo = InMemoryChatRepository();
    addTearDown(repo.dispose);

    await repo.sendMessage(
      groupId: 'g1',
      sender: _profile('u1', 'Ada'),
      text: '  Merhaba kamp  ',
    );

    final messages = await repo.watchGroupMessages('g1').first;
    expect(messages, hasLength(1));
    expect(messages.single.body, 'Merhaba kamp');
    expect(messages.single.authorDisplayName, 'Ada');
  });

  test(
    'watchGroupMessages yalnızca istenen sınıfın mesajlarını verir',
    () async {
      final repo = InMemoryChatRepository();
      addTearDown(repo.dispose);

      await repo.sendMessage(
        groupId: 'g1',
        sender: _profile('u1', 'Ada'),
        text: 'Bir',
      );
      await repo.sendMessage(
        groupId: 'g2',
        sender: _profile('u2', 'Ece'),
        text: 'İki',
      );

      final messages = await repo.watchGroupMessages('g1').first;
      expect(messages.map((m) => m.body), ['Bir']);
    },
  );

  test('boş ve çok uzun mesaj reddedilir', () async {
    final repo = InMemoryChatRepository();
    addTearDown(repo.dispose);

    expect(
      () => repo.sendMessage(
        groupId: 'g1',
        sender: _profile('u1', 'Ada'),
        text: '   ',
      ),
      throwsA(isA<ChatException>()),
    );

    expect(
      () => repo.sendMessage(
        groupId: 'g1',
        sender: _profile('u1', 'Ada'),
        text: List.filled(kMaxChatMessageLength + 1, 'x').join(),
      ),
      throwsA(isA<ChatException>()),
    );
  });
}
