import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/moderation_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_moderation_repository.dart';

void main() {
  final seed = {
    'user-b': Profile(
      id: 'user-b',
      displayName: 'Blocked Bob',
      createdAt: DateTime.utc(2024, 1, 1),
      avatarUrl: null,
    ),
  };

  test('block fills blocked profiles; unblock empties list + invalidation',
      () async {
    final repo = InMemoryModerationRepository(profileSeed: seed);
    final container = ProviderContainer(
      overrides: [
        moderationRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(blockedUserIdsProvider.future), isEmpty);
    expect(await container.read(blockedProfilesProvider.future), isEmpty);

    await repo.blockUser('user-b');
    container.invalidate(blockedUserIdsProvider);
    container.invalidate(blockedProfilesProvider);

    final ids = await container.read(blockedUserIdsProvider.future);
    expect(ids, {'user-b'});
    final profiles = await container.read(blockedProfilesProvider.future);
    expect(profiles, hasLength(1));
    expect(profiles.single.displayName, 'Blocked Bob');

    await repo.unblockUser('user-b');
    container.invalidate(blockedUserIdsProvider);
    container.invalidate(blockedProfilesProvider);

    expect(await container.read(blockedUserIdsProvider.future), isEmpty);
    expect(await container.read(blockedProfilesProvider.future), isEmpty);
  });

  test('fetchBlockedProfiles falls back to masked id without seed', () async {
    final repo = InMemoryModerationRepository();
    await repo.blockUser('abcdefghij');
    final list = await repo.fetchBlockedProfiles();
    expect(list, hasLength(1));
    expect(list.single.id, 'abcdefghij');
    expect(list.single.displayName, 'abcdefgh…');
  });
}
