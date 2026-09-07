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
}
