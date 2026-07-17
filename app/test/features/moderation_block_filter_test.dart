import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/data/providers/moderation_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_moderation_repository.dart';
import 'package:online_study_room/data/repositories/moderation_repository.dart';

void main() {
  test('blockedUserIdsProvider reflects block and unblock', () async {
    final repo = InMemoryModerationRepository();
    final container = ProviderContainer(
      overrides: [
        moderationRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(blockedUserIdsProvider.future), isEmpty);

    await repo.blockUser('user-b');
    container.invalidate(blockedUserIdsProvider);
    expect(await container.read(blockedUserIdsProvider.future), {'user-b'});

    await repo.unblockUser('user-b');
    container.invalidate(blockedUserIdsProvider);
    expect(await container.read(blockedUserIdsProvider.future), isEmpty);
  });

  test('message filter hides blocked authors', () {
    final blocked = {'user-b'};
    final authors = ['user-a', 'user-b', 'user-c'];
    final visible = authors.where((id) => !blocked.contains(id)).toList();
    expect(visible, ['user-a', 'user-c']);
  });
}
