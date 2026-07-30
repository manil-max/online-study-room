import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
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
});

final adminDashboardSummaryProvider = FutureProvider<AdminDashboardSummary?>((
  ref,
) async {
  final profile = ref.watch(authStateProvider).value;
  if (profile == null) return null;
  final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
  if (!isAdmin) return null;
  return ref.watch(adminRepositoryProvider).fetchDashboardSummary(profile.id);
});

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
    });

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
    });

final myFeedbackTicketsProvider = FutureProvider<List<FeedbackTicket>>((
  ref,
) async {
  final profile = ref.watch(authStateProvider).value;
  if (profile == null) return const [];
  return ref.watch(adminRepositoryProvider).fetchMyFeedbackTickets(profile.id);
});

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
    });

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
});

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

final adminUsersProvider = FutureProvider.autoDispose<List<AdminUserDto>>((
  ref,
) async {
  final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
  if (!isAdmin) return const [];
  return ref.watch(adminRepositoryProvider).fetchUsers();
});

final adminGroupsProvider = FutureProvider.autoDispose<List<StudyGroup>>((
  ref,
) async {
  final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
  if (!isAdmin) return const [];
  return ref.watch(adminRepositoryProvider).fetchGroups();
});

final adminAnnouncementsProvider =
    FutureProvider.autoDispose<List<Announcement>>((ref) async {
      final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
      if (!isAdmin) return const [];
      return ref.watch(adminRepositoryProvider).fetchAnnouncements();
    });

final adminAuditLogsProvider = FutureProvider.autoDispose<List<AdminAuditLog>>((
  ref,
) async {
  final isAdmin = await ref.watch(adminIsSuperAdminProvider.future);
  if (!isAdmin) return const [];
  return ref.watch(adminRepositoryProvider).fetchAuditLogs();
});

SupabaseClient? _supabaseClientOrNull() {
  if (!SupabaseConfig.isConfigured) return null;
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}
