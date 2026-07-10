import 'package:supabase_flutter/supabase_flutter.dart';

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
}
