import '../models/admin_user_insight.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/net/read_retry_policy.dart';
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
}, retry: readRetryPolicy);

/// Tek raporun detay/timeline verisi.
final moderationCaseDetailProvider =
    FutureProvider.family<ModerationCaseDetail, String>((ref, reportId) async {
  return ref.watch(adminModerationRepositoryProvider).fetchDetail(reportId);
}, retry: readRetryPolicy);

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
}, retry: readRetryPolicy);

/// WP-442: İtiraz kuyruğu. Açık itirazlar başta gelir.
final moderationAppealsProvider = FutureProvider<List<ModerationAppeal>>((
  ref,
) async {
  return ref.watch(adminModerationRepositoryProvider).fetchAppeals();
}, retry: readRetryPolicy);

/// WP-775: kullanıcının moderasyon dosyası — vaka sayfasındaki isme dokununca
/// açılan profil panelini besler.
///
/// 🔴 `family` anahtarı kullanıcı kimliğidir; aynı vakada iki farklı kişiye
/// bakmak iki ayrı çağrıdır ve birbirinin önbelleğini EZMEZ. Tek bir
/// `FutureProvider` kullanmak, şikâyet edenin dosyasını açıp geri dönünce
/// şikâyet edilenin dosyasında onun sayılarını gösterirdi.
final adminUserInsightProvider =
    FutureProvider.family<AdminUserInsight, String>((ref, userId) async {
  return ref.watch(adminModerationRepositoryProvider).fetchUserInsight(userId);
}, retry: readRetryPolicy);
