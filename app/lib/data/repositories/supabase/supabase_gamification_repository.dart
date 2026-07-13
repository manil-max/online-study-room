import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/achievement.dart';
import '../../models/gamification_profile.dart';
import '../gamification_repository.dart';

class SupabaseGamificationRepository implements GamificationRepository {
  SupabaseGamificationRepository(this._client);

  final SupabaseClient _client;

  @override
  Stream<GamificationProfile> watchProfile(String userId) {
    return _client
        .from('gamification_profiles')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', userId)
        .map((rows) {
          if (rows.isEmpty) return GamificationProfile.initial(userId);
          return GamificationProfile.fromMap(rows.first);
        });
  }

  @override
  Future<void> setStreakFreezes(String userId, int value) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('gamification_profiles').upsert({
      'user_id': userId,
      'streak_freezes': value.clamp(0, 99),
      'updated_at': now,
    });
  }

  @override
  Future<void> updateProfile(GamificationProfile profile) async {
    // WP-56: istemci XP / crown_rank yazamaz (0024 guard + bu dar yazım).
    // Yalnız seri koruma ve vitrin rozetleri.
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('gamification_profiles').upsert({
      'user_id': profile.userId,
      'streak_freezes': profile.streakFreezes.clamp(0, 99),
      'selected_badges': profile.selectedBadges,
      'updated_at': now,
    });
  }

  @override
  Stream<List<UserAchievement>> watchUserAchievements(String userId) {
    return _client
        .from('user_achievements')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) => rows.map((e) => UserAchievement.fromMap(e)).toList());
  }

  @override
  Future<void> updateUserAchievements(
    List<UserAchievement> achievements,
  ) async {
    // WP-56 server-authoritative: başarı/tier yalnız process_achievement_event
    // + xp_ledger trigger yazar. İstemci no-op (eski yolu kırmaz, hile yolunu kapatır).
    return;
  }
}
