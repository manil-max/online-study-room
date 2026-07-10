import '../models/gamification_profile.dart';

abstract class GamificationRepository {
  Stream<GamificationProfile> watchProfile(String userId);

  Future<void> setStreakFreezes(String userId, int value);
}
