import 'dart:async';

import '../../models/gamification_profile.dart';
import '../gamification_repository.dart';

class InMemoryGamificationRepository implements GamificationRepository {
  final Map<String, GamificationProfile> _profiles = {};
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

  GamificationProfile _profileFor(String userId) {
    return _profiles.putIfAbsent(
      userId,
      () => GamificationProfile.initial(userId),
    );
  }

  void dispose() => _changes.close();
}
