import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/achievement_ledger.dart';
import '../models/achievement_metric_progress.dart';
import '../models/study_session.dart';
import '../repositories/achievement_repository.dart';
import '../repositories/in_memory/in_memory_achievement_repository.dart';
import '../repositories/supabase/supabase_achievement_repository.dart';
import 'auth_providers.dart';
import 'study_providers.dart';
import 'group_providers.dart';

/// WP-56: Server-authoritative başarım API (istemci XP yazmaz).
final achievementRepositoryProvider = Provider<AchievementRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseAchievementRepository(Supabase.instance.client);
  }
  final repository = InMemoryAchievementRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

/// Sözlük (seed). Supabase: `achievements_dict`; offline: yerel kopya.
final achievementDictionaryProvider =
    FutureProvider<List<AchievementDictEntry>>((ref) async {
      return ref.watch(achievementRepositoryProvider).fetchDictionary();
    });

/// Sunucudaki düz ilerleme tablosu (`achievement_metric_progress`).
///
/// Grup metrikleri için bu tablo WP-501'den beri **gruplar arası `max`** tutar:
/// ödül/XP tarafı cihazdaki grup seçimini bilemez, bu yüzden kullanıcının en
/// iyi grubunun değeri yazılır (çift sayım biter, kazanılmış kademe geri
/// alınmaz). Gösterim seçili gruba göre aşağıda düzeltilir.
final _flatMetricProgressProvider =
    StreamProvider<List<AchievementMetricProgress>>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value(const []);
      return ref
          .watch(achievementRepositoryProvider)
          .watchMetricProgress(user.id);
    });

/// Seçili grubun kırılımı (`group_achievement_metric_progress`, `0121`).
final _groupScopedMetricProgressProvider =
    StreamProvider<List<AchievementMetricProgress>>((ref) {
      final user = ref.watch(authStateProvider).value;
      final groupId = ref.watch(userGroupProvider).value?.id;
      if (user == null || groupId == null) return Stream.value(const []);
      return ref
          .watch(achievementRepositoryProvider)
          .watchGroupScopedMetricProgress(user.id, groupId);
    });

/// Private real progress for the signed-in account. Callers cannot request a
/// social profile's secret/raw metric values.
///
/// 🔴 WP-501 (sahip kararı: "hangi grup seçili ise ondan sayılsın"): grup
/// metriklerinde seçili grubun değeri düz tablodakini **ezer**. Seçim yalnız
/// cihazda durduğu için (`activeGroupIdProvider` → `SharedPreferences`) bu
/// birleştirme sunucuda yapılamaz; tek yer burasıdır, böylece rozeti çizen
/// hiçbir widget'ın kuralı bilmesi gerekmez.
final achievementMetricProgressProvider =
    Provider<AsyncValue<List<AchievementMetricProgress>>>((ref) {
      final flat = ref.watch(_flatMetricProgressProvider);
      final scoped = ref.watch(_groupScopedMetricProgressProvider);
      return flat.whenData((rows) {
        final overrides = {
          for (final item in scoped.value ?? const <AchievementMetricProgress>[])
            item.achievementId: item,
        };
        if (overrides.isEmpty) return rows;
        final seen = <String>{};
        final merged = <AchievementMetricProgress>[
          for (final row in rows)
            if (seen.add(row.achievementId))
              overrides[row.achievementId] ?? row,
        ];
        // Düz tabloda hiç satırı olmayan grup metriği de görünmeli.
        for (final entry in overrides.entries) {
          if (seen.add(entry.key)) merged.add(entry.value);
        }
        return merged;
      });
    });

/// Oturum bitti / profil açıldı / manuel yenileme sonrası sunucuya olay fırlatır.
///
/// Dönüş: yeni kazanılan kademeler + güncel total_xp (ledger toplamı).
/// Aynı event_key ikinci kez XP vermez (idempotency — sunucu/engine).
final processAchievementEventProvider =
    Provider<
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
    Provider<Future<AchievementEventResult> Function()>((ref) {
      final process = ref.watch(processAchievementEventProvider);
      return () => process(eventType: 'session_completed');
    });

/// Kolay API: profil / başarım ekranı açılışında yeniden değerlendirme.
final refreshAchievementsProvider =
    Provider<Future<AchievementEventResult> Function()>((ref) {
      final process = ref.watch(processAchievementEventProvider);
      return () => process(eventType: 'profile_opened');
    });
