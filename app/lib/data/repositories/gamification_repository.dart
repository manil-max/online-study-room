import '../models/achievement.dart';
import '../models/gamification_profile.dart';

abstract class GamificationRepository {
  Stream<GamificationProfile> watchProfile(String userId);

  Future<void> setStreakFreezes(String userId, int value);
  Future<void> updateProfile(GamificationProfile profile);

  Stream<List<UserAchievement>> watchUserAchievements(String userId);
  Future<void> updateUserAchievements(List<UserAchievement> achievements);
}
