import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import '../../core/net/read_retry_policy.dart';
import '../models/admin_audit_log.dart';
import '../models/admin_user_dto.dart';
import '../models/announcement.dart';
import '../models/feedback_ticket.dart';
import '../models/feedback_ticket_thread_summary.dart';
import '../models/study_group.dart';
import '../repositories/admin_repository.dart';
import '../repositories/in_memory/in_memory_admin_repository.dart';
import '../repositories/supabase/supabase_admin_repository.dart';
import 'auth_providers.dart';
import 'notification_providers.dart';

/// WP-692/WP-702 — reddedilen okuma **yarim dakika donen cark** olarak
/// gorunuyordu: Riverpod 3 varsayilani her `Exception`i 10 kez / ~38 sn
/// yeniden dener.
///
/// Politikanin govdesi WP-702'de tek kanonik kaynaga tasindi
/// (`core/net/read_retry_policy.dart`): ayni tuzak kullaniciya gorunen
/// saglayicilarda da duruyordu ve "admin" adi orada yalan olurdu. Bu ad
/// WP-692 regresyon aginin olctugu semboldur, degismeden korunur.
const adminRetryPolicy = readRetryPolicy;

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final client = _supabaseClientOrNull();
  if (client != null) {
    return SupabaseAdminRepository(client);
  }

  final repo = InMemoryAdminRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final adminIsSuperAdminProvider = FutureProvider<bool>((ref) async {
  final profile = ref.watch(authStateProvider).value;
  if (profile == null) return false;
  return ref.watch(adminRepositoryProvider).isSuperAdmin(profile.id);
}, retry: adminRetryPolicy);

final adminDashboardSummaryProvider = FutureProvider<AdminDashboardSummary?>((
  ref,
) async {
  final profile = ref.watch(authStateProvider).value;
  if (profile == null) return null;
  final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
  if (!isAdmin) return null;
  return ref.watch(adminRepositoryProvider).fetchDashboardSummary(profile.id);
}, retry: adminRetryPolicy);

final adminFeedbackTicketsProvider =
    FutureProvider.family<List<FeedbackTicket>, FeedbackTicketType?>((
      ref,
      type,
    ) async {
      final profile = ref.watch(authStateProvider).value;
      if (profile == null) return const [];
      final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
      if (!isAdmin) return const [];
      return ref
          .watch(adminRepositoryProvider)
          .fetchFeedbackTickets(profile.id, type: type);
    }, retry: adminRetryPolicy);

final adminArchivedFeedbackTicketsProvider =
    FutureProvider.family<List<FeedbackTicket>, FeedbackTicketType?>((
      ref,
      type,
    ) async {
      final profile = ref.watch(authStateProvider).value;
      if (profile == null) return const [];
      final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
      if (!isAdmin) return const [];
      return ref
          .watch(adminRepositoryProvider)
          .fetchFeedbackTickets(profile.id, type: type, includeArchived: true);
    }, retry: adminRetryPolicy);

final myFeedbackTicketsProvider = FutureProvider<List<FeedbackTicket>>((
  ref,
) async {
  final profile = ref.watch(authStateProvider).value;
  if (profile == null) return const [];
  return ref.watch(adminRepositoryProvider).fetchMyFeedbackTickets(profile.id);
}, retry: adminRetryPolicy);

/// Kullanicinin bilet listesi + konusma ozeti (son mesaj, tarih, okunmamis).
///
/// WP-437: Liste satiri artik biletin ilk mesajinda donmaz; ozet WP-435/436'nin
/// kanonik mesaj dizisi ve okundu watermark'i uzerinden turer.
final myFeedbackTicketSummariesProvider =
    FutureProvider<List<FeedbackTicketThreadSummary>>((ref) async {
      final profile = ref.watch(authStateProvider).value;
      if (profile == null) return const [];
      return ref
          .watch(adminRepositoryProvider)
          .fetchMyTicketThreadSummaries(profile.id);
    }, retry: adminRetryPolicy);

/// Okunmamis yonetici yaniti sayisi — rozet zincirinin tek kaynagi.
///
/// WP-421: Sahip "bildirim geliyor ama profilde/ayarlarda nokta yok" dedi.
/// Rozet artik pushtan degil sunucudaki mesaj satirlarindan turuyor; zincirin
/// her halkasi (Profil → Ayarlar → Geri bildirim → bilet) ayni sayiyi okur.
/// `autoDispose` **degil**: dinleyicisiz kalip her okumada yeniden kurulmasi
/// rozetin yanip sonmesine ve regresyon testinin sessizce etkisizlesmesine yol
/// acar (Riverpod 3 tuzagi).
final unreadFeedbackReplyCountProvider = FutureProvider<int>((ref) async {
  final profile = ref.watch(authStateProvider).value;
  if (profile == null) return 0;
  return ref
      .watch(adminRepositoryProvider)
      .fetchUnreadTicketReplyCount(profile.id);
}, retry: adminRetryPolicy);

/// Profil sekmesindeki "Ayarlar" satirinin toplam rozet sayisi.
///
/// Zincir kurali: alt seviyede gorunen her sinyal ust seviyede de gorunur.
/// WP-459: Profil sekmesi, Profil→Ayarlar satiri ve Ayarlar ekrani ayni iki
/// kaynaktan (duyuru + feedback watermark) beslenir; yuzeye ozel sayac yok.
final settingsBadgeCountProvider = Provider<int>((ref) {
  final announcements = ref.watch(unreadAnnouncementCountProvider);
  final replies = ref.watch(unreadFeedbackReplyCountProvider).value ?? 0;
  return announcements + replies;
});

/// WP-780: vakanin iki taraf kanali — vaka sayfasindaki "Yazisma" bolumu bu
/// listeyi okuyup yazisma ekranini acar.
///
/// 🔴 `autoDispose`: sikayet edilen tarafin `ticketId`si, yonetici ilk mesaji
/// gonderene kadar `null`dur ve gonderdiginde DEGISIR. Kalici onbellek, ikinci
/// acilista hala `null` tasiyan bayat bir liste verirdi. `family` anahtari
/// rapor kimligidir; iki vaka birbirinin onbellegini ezmez.
final adminCaseConversationChannelsProvider =
    FutureProvider.autoDispose.family<List<CaseConversationChannel>, String>((
      ref,
      reportId,
    ) async {
      final profile = ref.watch(authStateProvider).value;
      if (profile == null) return const [];
      final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
      if (!isAdmin) return const [];
      return ref
          .watch(adminRepositoryProvider)
          .fetchCaseConversationChannels(
            userId: profile.id,
            reportId: reportId,
          );
    }, retry: adminRetryPolicy);

final adminUsersProvider = FutureProvider.autoDispose<List<AdminUserDto>>((
  ref,
) async {
  final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
  if (!isAdmin) return const [];
  return ref.watch(adminRepositoryProvider).fetchUsers();
}, retry: adminRetryPolicy);

final adminGroupsProvider = FutureProvider.autoDispose<List<StudyGroup>>((
  ref,
) async {
  final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
  if (!isAdmin) return const [];
  return ref.watch(adminRepositoryProvider).fetchGroups();
}, retry: adminRetryPolicy);

final adminAnnouncementsProvider =
    FutureProvider.autoDispose<List<Announcement>>((ref) async {
      final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
      if (!isAdmin) return const [];
      return ref.watch(adminRepositoryProvider).fetchAnnouncements();
    }, retry: adminRetryPolicy);

final adminAuditLogsProvider = FutureProvider.autoDispose<List<AdminAuditLog>>((
  ref,
) async {
  final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
  if (!isAdmin) return const [];
  return ref.watch(adminRepositoryProvider).fetchAuditLogs();
}, retry: adminRetryPolicy);

SupabaseClient? _supabaseClientOrNull() {
  if (!SupabaseConfig.isConfigured) return null;
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}
