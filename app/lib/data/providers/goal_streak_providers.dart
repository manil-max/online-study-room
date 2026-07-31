import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/goal_streak.dart';
import '../repositories/goal_streak_repository.dart';
import '../repositories/in_memory/in_memory_goal_streak_repository.dart';
import '../repositories/supabase/supabase_goal_streak_repository.dart';

/// WP-453 Faz 2: seri durumunun tek okuma kaynağı.
///
/// Faz 1 saf Dart durum makinesini indirmiş ama hiçbir yere bağlamamıştı;
/// WP-454'ün alev göstergesi "durum yalnız server projection'dan" diyor, o
/// yüzden bağ burada kuruluyor. Supabase yapılandırılmışsa gerçek projeksiyon
/// RPC'si, değilse demo/offline için bellek-içi eş kullanılır.
final goalStreakRepositoryProvider = Provider<GoalStreakRepository>((ref) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseGoalStreakRepository(Supabase.instance.client);
  }
  return InMemoryGoalStreakRepository();
});

/// Bir kapsamın güncel seri projeksiyonu.
///
/// 🔴 Bilinçli olarak yalnız OKUR. Seri artırma yolu ne burada ne de
/// [GoalStreakRepository] arayüzünde var: uygulama açılışı, sayaç başlangıcı
/// ve kısmi ilerleme kodu seriye hiçbir şekilde dokunamasın diye. Tek yazıcı
/// sunucudaki `record_goal_completion` RPC'sidir ve o da hedefe gerçekten
/// ulaşıldığını `study_sessions` üzerinden doğrular.
final goalStreakProjectionProvider =
    StreamProvider.family<GoalStreakProjection, GoalStreakScope>((ref, scope) {
      return ref.watch(goalStreakRepositoryProvider).watchProjection(scope);
    });
