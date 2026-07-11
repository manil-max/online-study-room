import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/achievement.dart';
import 'package:online_study_room/data/models/gamification_profile.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_gamification_repository.dart';

void main() {
  group('InMemoryGamificationRepository', () {
    late InMemoryGamificationRepository repository;

    setUp(() {
      repository = InMemoryGamificationRepository();
    });

    test('should update profile and notify listeners', () async {
      final profile = GamificationProfile(
        userId: 'u1',
        streakFreezes: 2,
        xp: 1500,
        crownRank: 'bronze_beginner',
        selectedBadges: const ['b1', 'b2'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.updateProfile(profile);

      final updatedProfile = await repository.watchProfile('u1').first;
      expect(updatedProfile.xp, 1500);
      expect(updatedProfile.streakFreezes, 2);
      expect(updatedProfile.crownRank, 'bronze_beginner');
      expect(updatedProfile.selectedBadges, ['b1', 'b2']);
    });

    test('should update achievements and notify listeners', () async {
      final ach1 = UserAchievement(
        id: '1',
        userId: 'u1',
        achievementId: 'a1',
        tier: 2,
        progress: 10,
        unlockedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await repository.updateUserAchievements([ach1]);

      var achs = await repository.watchUserAchievements('u1').first;
      expect(achs.length, 1);
      expect(achs.first.achievementId, 'a1');
      expect(achs.first.tier, 2);

      // Aynı başarıyı güncelle
      final ach1Updated = ach1.copyWith(progress: 20, tier: 3);
      await repository.updateUserAchievements([ach1Updated]);

      achs = await repository.watchUserAchievements('u1').first;
      expect(achs.length, 1);
      expect(achs.first.tier, 3);
      expect(achs.first.progress, 20);

      // Yeni başarı ekle
      final ach2 = UserAchievement(
        id: '2',
        userId: 'u1',
        achievementId: 'a2',
        tier: 1,
        progress: 5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await repository.updateUserAchievements([ach2]);

      achs = await repository.watchUserAchievements('u1').first;
      expect(achs.length, 2);
    });
  });
}
