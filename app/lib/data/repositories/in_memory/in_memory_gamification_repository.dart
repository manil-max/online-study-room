import 'dart:async';

import '../../models/achievement.dart';
import '../../models/gamification_profile.dart';
import '../gamification_repository.dart';

class InMemoryGamificationRepository implements GamificationRepository {
  final Map<String, GamificationProfile> _profiles = {};
  final Map<String, List<UserAchievement>> _achievements = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Stream<GamificationProfile> watchProfile(String userId) async* {
    yield _profileFor(userId);
    await for (final _ in _changes.stream) {
      yield _profileFor(userId);
    }
  }

  @override
  Future<void> setStreakFreezes(String userId, int value) async {
    final current = _profileFor(userId);
    _profiles[userId] = current.copyWith(
      streakFreezes: value.clamp(0, 99),
      updatedAt: DateTime.now(),
    );
    _changes.add(null);
  }

  @override
  Future<void> updateProfile(GamificationProfile profile) async {
    _profiles[profile.userId] = profile.copyWith(updatedAt: DateTime.now());
    _changes.add(null);
  }

  @override
  Stream<List<UserAchievement>> watchUserAchievements(String userId) async* {
    yield _achievements[userId] ?? [];
    await for (final _ in _changes.stream) {
      yield _achievements[userId] ?? [];
    }
  }

  @override
  Future<void> updateUserAchievements(List<UserAchievement> achievements) async {
    if (achievements.isEmpty) return;
    final userId = achievements.first.userId;
    final current = _achievements[userId] ?? [];
    final updated = List<UserAchievement>.from(current);
    
    for (final ach in achievements) {
      final index = updated.indexWhere((e) => e.achievementId == ach.achievementId);
      if (index >= 0) {
        updated[index] = ach;
      } else {
        updated.add(ach);
      }
    }
    
    _achievements[userId] = updated;
    _changes.add(null);
  }

  GamificationProfile _profileFor(String userId) {
    return _profiles.putIfAbsent(
      userId,
      () => GamificationProfile.initial(userId),
    );
  }

  void dispose() => _changes.close();
}
