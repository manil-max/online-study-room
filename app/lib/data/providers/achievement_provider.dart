import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/achievement_ledger.dart';
import '../models/study_session.dart';
import '../repositories/achievement_repository.dart';
import '../repositories/in_memory/in_memory_achievement_repository.dart';
import '../repositories/supabase/supabase_achievement_repository.dart';
import 'auth_providers.dart';
import 'study_providers.dart';

/// WP-56: Server-authoritative başarım API (istemci XP yazmaz).
final achievementRepositoryProvider = Provider<AchievementRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseAchievementRepository(Supabase.instance.client);
  }
  return InMemoryAchievementRepository();
});

/// Sözlük (seed). Supabase: `achievements_dict`; offline: yerel kopya.
final achievementDictionaryProvider =
    FutureProvider<List<AchievementDictEntry>>((ref) async {
      return ref.watch(achievementRepositoryProvider).fetchDictionary();
    });

/// Oturum bitti / profil açıldı / manuel yenileme sonrası sunucuya olay fırlatır.
///
/// Dönüş: yeni kazanılan kademeler + güncel total_xp (ledger toplamı).
/// Aynı event_key ikinci kez XP vermez (idempotency — sunucu/engine).
final processAchievementEventProvider = Provider<
  Future<AchievementEventResult> Function({
    required String eventType,
    Map<String, dynamic> payload,
  })
>((ref) {
  return ({
    required String eventType,
    Map<String, dynamic> payload = const {},
  }) async {
    final user = ref.read(authStateProvider).value;
    final repo = ref.read(achievementRepositoryProvider);

    List<StudySession> sessions = const [];
    var goalMinutes = 360;
    if (!SupabaseConfig.isConfigured) {
      // InMemory: metrik istemci oturumlarından (demo); XP yine engine ledger'da.
      try {
        sessions = await ref.read(userSessionsProvider.future);
      } catch (_) {
        sessions = const [];
      }
      try {
        goalMinutes = ref.read(dailyGoalMinutesProvider);
      } catch (_) {
        goalMinutes = 360;
      }
    }

    return repo.processEvent(
      eventType: eventType,
      payload: payload,
      sessions: sessions,
      dailyGoalMinutes: goalMinutes,
      userId: user?.id,
    );
  };
});

/// Kolay API: oturum tamamlandı olayı.
final notifySessionCompletedForAchievementsProvider =
    Provider<Future<AchievementEventResult> Function()>(
  (ref) {
    final process = ref.watch(processAchievementEventProvider);
    return () => process(eventType: 'session_completed');
  },
);

/// Kolay API: profil / başarım ekranı açılışında yeniden değerlendirme.
final refreshAchievementsProvider =
    Provider<Future<AchievementEventResult> Function()>((ref) {
      final process = ref.watch(processAchievementEventProvider);
      return () => process(eventType: 'profile_opened');
    });
