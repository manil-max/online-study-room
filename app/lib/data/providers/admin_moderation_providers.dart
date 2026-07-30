import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../models/moderation_appeal.dart';
import '../models/moderation_case.dart';
import '../models/moderation_sanction.dart';
import '../repositories/admin_moderation_repository.dart';
import '../repositories/in_memory/in_memory_admin_moderation_repository.dart';
import '../repositories/supabase/supabase_admin_moderation_repository.dart';

/// WP-440: Yönetici moderasyon kuyruğu bağımlılıkları.
///
/// Ajan B'nin feedback `admin_repository.dart` sağlayıcısıyla paylaşılmaz.
final adminModerationRepositoryProvider = Provider<AdminModerationRepository>((
  ref,
) {
  if (SupabaseConfig.isConfigured) {
    return SupabaseAdminModerationRepository(Supabase.instance.client);
  }
  return InMemoryAdminModerationRepository();
});

/// Kuyruk listesi. Durum yazımından sonra `ref.invalidate` ile tazelenir.
final moderationQueueProvider = FutureProvider<List<ModerationCase>>((
  ref,
) async {
  return ref.watch(adminModerationRepositoryProvider).fetchQueue();
});

/// Tek raporun detay/timeline verisi.
final moderationCaseDetailProvider =
    FutureProvider.family<ModerationCaseDetail, String>((ref, reportId) async {
  return ref.watch(adminModerationRepositoryProvider).fetchDetail(reportId);
});

/// WP-441: Hedefin yaptırım geçmişi.
///
/// Kart hangi basamağın **şu an** yürürlükte olduğunu buradan okur; aksi hâlde
/// yönetici zaten susturulmuş kullanıcıya ikinci kez yaptırım denerdi.
final moderationSanctionsProvider =
    FutureProvider.family<List<ModerationSanction>, String>((
  ref,
  targetUserId,
) async {
  return ref
      .watch(adminModerationRepositoryProvider)
      .fetchSanctions(targetUserId);
});

/// WP-442: İtiraz kuyruğu. Açık itirazlar başta gelir.
final moderationAppealsProvider = FutureProvider<List<ModerationAppeal>>((
  ref,
) async {
  return ref.watch(adminModerationRepositoryProvider).fetchAppeals();
});
