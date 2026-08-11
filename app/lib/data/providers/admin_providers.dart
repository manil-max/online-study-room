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

/// WP-692 — reddedilen okuma **yarim dakika donen cark** olarak gorunuyordu.
///
/// Riverpod 3 varsayilani (`ProviderContainer.defaultRetry`) yalniz `Error` ve
/// `ProviderException` icin durur; her `Exception` **10 kez / ~38 sn** boyunca
/// yeniden denenir. O sure boyunca durum `AsyncLoading(retrying: true)` kalir
/// (donen cark, kayip yazilmaz) ve `.future` **tamamlanmaz** — onu bekleyen
/// kod da bagli saglayicilar da kilitlenir.
///
/// Bu depoda okuma saglayicilarina ulasan baskin hata sinifi
/// [AdminException]'dir ve icerigi **sunucunun kesin reddidir**: `403`,
/// `42501`/RLS, `not_super_admin`, oturum yok, dogrulama. Bunlarin hicbiri
/// tekrar denemekle duzelmez — bu yuzden varsayilan **kapali**.
///
/// 🔴 Kapatma TOPTAN DEGIL. Ayni tip gercekten gecici bir hatayi da sarar:
/// depo katmanindaki genis `catch (e)` dallari ag hatasini
/// (`SocketException`, `ClientException`, zaman asimi) yine [AdminException]
/// olarak firlatir. Bu izler yakalanip yeniden deneme **acik birakilir**;
/// olcumu `test/features/admin/admin_provider_retry_wp692_test.dart` WP-692/3.
Duration? adminRetryPolicy(int retryCount, Object error) {
  if (_isPermanentFailure(error)) return null;
  return ProviderContainer.defaultRetry(retryCount, error);
}

/// Gecici (yeniden denemeye deger) ag izleri. Kullaniciya gosterilen metin
/// degil, istisna sinifi adlari/soket hata metinleridir — l10n kapsami disi.
const List<String> _transientErrorMarkers = <String>[
  'socketexception',
  'clientexception',
  'httpexception',
  'handshakeexception',
  'timeoutexception',
  'timed out',
  'failed host lookup',
  'connection closed',
  'connection reset',
  'connection refused',
  'connection attempt failed',
  'network is unreachable',
  'software caused connection abort',
];

bool _looksTransient(String message) {
  final normalized = message.toLowerCase();
  return _transientErrorMarkers.any(normalized.contains);
}

bool _isPermanentFailure(Object error) {
  if (error is AdminException) {
    // Varsayilan: kalici. `AdminException` = "sunucu/istemci kapisi HAYIR
    // dedi". Yalniz acikca gecici bir ag izi tasiyorsa istisna yapilir.
    return !_looksTransient('${error.code ?? ''} ${error.message}');
  }
  if (error is PostgrestException) {
    // Ham PostgREST hatasi da saglayiciya ulasabilir (ornegin
    // `fetchMyFeedbackTickets` sarmalamaz). Siniflandirma icin **yeni bir
    // kaynak acilmaz**, deponun kendi esleyicisi kullanilir.
    return classifyFeedbackSubmitError(
          postgrestCode: error.code,
          message: error.message,
        ) ==
        'session_or_rls';
  }
  return false;
}

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
