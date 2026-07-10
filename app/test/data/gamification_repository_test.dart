import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_gamification_repository.dart';

void main() {
  test('watchProfile varsayılan seri koruma hakkıyla başlar', () async {
    final repo = InMemoryGamificationRepository();
    addTearDown(repo.dispose);

    final profile = await repo.watchProfile('u1').first;
    expect(profile.userId, 'u1');
    expect(profile.streakFreezes, 1);
  });

  test('setStreakFreezes değeri sınırlar ve yayınlar', () async {
    final repo = InMemoryGamificationRepository();
    addTearDown(repo.dispose);

    await repo.setStreakFreezes('u1', 120);
    final profile = await repo.watchProfile('u1').first;
    expect(profile.streakFreezes, 99);

    await repo.setStreakFreezes('u1', -5);
    final updated = await repo.watchProfile('u1').first;
    expect(updated.streakFreezes, 0);
  });
}
