import 'package:flutter/foundation.dart';

import '../models/admin_audit_log.dart';
import '../models/admin_user_dto.dart';
import '../models/announcement.dart';
import '../models/feedback_ticket.dart';
import '../models/feedback_ticket_note.dart';
import '../models/feedback_ticket_message.dart';
import '../models/feedback_ticket_thread_summary.dart';
import '../models/profile.dart';
import '../models/study_group.dart';

const int kMaxFeedbackSubjectLength = 80;
const int kMaxFeedbackMessageLength = 1200;
const int kMaxFeedbackTicketReplyLength = 1200;

class AdminException implements Exception {
  const AdminException(this.message, {this.code});

  final String message;

  /// Makine kodu (UI dallanması): `session_required`, `rls_denied`, …
  final String? code;

  @override
  String toString() => message;
}

/// Postgrest hata kodu/mesajından geri bildirim gönderim sınıflandırması
/// (WP-168/177/193).
///
/// Dönüş: `session_or_rls` | `schema_missing` | `storage` | null
///
/// WP-193: `schema_missing` yalnız gerçek tablo/şema önbellek hatalarına.
/// Geniş `relation`+`feedback` eşlemesi RLS/permission'ı yanlış etiketliyordu.
String? classifyFeedbackSubmitError({String? postgrestCode, String? message}) {
  final code = (postgrestCode ?? '').toLowerCase().trim();
  final msg = (message ?? '').toLowerCase();

  // Tablo yok / PostgREST şema önbelleği — dar kurallar.
  final isSchemaCode = code == '42p01' || code == 'pgrst205';
  final isSchemaMsg =
      msg.contains('schema cache') ||
      msg.contains('could not find the table') ||
      (msg.contains('relation') &&
          msg.contains('does not exist') &&
          msg.contains('feedback'));
  if (isSchemaCode || isSchemaMsg) {
    return 'schema_missing';
  }

  if (msg.contains('support_ticket_rate_limited')) {
    return 'support_ticket_rate_limited';
  }

  if (code == '42501' ||
      msg.contains('row-level security') ||
      msg.contains('violates row-level') ||
      msg.contains('permission denied') ||
      msg.contains('jwt') ||
      msg.contains('not authenticated') ||
      msg.contains('invalid claim')) {
    return 'session_or_rls';
  }
  return null;
}

/// Kullanıcı mesajı + ham PostgREST detayı (cihaz teşhisi, release'te de).
String feedbackErrorDisplay({
  required String userMessage,
  String? postgrestCode,
  String? rawMessage,
}) {
  final code = (postgrestCode ?? '').trim();
  final raw = (rawMessage ?? '').trim();
  if (code.isEmpty && raw.isEmpty) return userMessage;
  final detail = [if (code.isNotEmpty) code, if (raw.isNotEmpty) raw].join(' ');
  return '$userMessage\nDetay: $detail';
}

/// Kullanıcıya gösterilecek net mesaj (release build'de de, kDebugMode bağımsız).
String feedbackUserMessageForCode(String? code, {String? fallback}) {
  return switch (code) {
    'session_required' || 'session_or_rls' =>
      'Oturumun sona ermiş veya sunucu erişimi reddetti. Tekrar giriş yapıp dene.',
    'schema_missing' =>
      'Geri bildirim sunucusu henüz hazır değil. Lütfen daha sonra dene '
          '(yönetici: feedback migration/ensure SQL).',
    'storage' =>
      'Görsel yüklenemedi. İnternetini kontrol et veya görselsiz gönder.',
    'support_ticket_rate_limited' =>
      'Kısa sürede çok fazla destek bileti oluşturdun. Lütfen biraz sonra tekrar dene.',
    _ => fallback ?? 'Geri bildirim gönderilemedi.',
  };
}

class AdminDashboardSummary {
  const AdminDashboardSummary({
    required this.userCount,
    required this.groupCount,
    required this.sessionCount,
    required this.openTicketCount,
  });

  final int userCount;
  final int groupCount;
  final int sessionCount;
  final int openTicketCount;

  factory AdminDashboardSummary.fromMap(Map<String, dynamic> map) {
    return AdminDashboardSummary(
      userCount: (map['user_count'] as num?)?.toInt() ?? 0,
      groupCount: (map['group_count'] as num?)?.toInt() ?? 0,
      sessionCount: (map['session_count'] as num?)?.toInt() ?? 0,
      openTicketCount: (map['open_ticket_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Kuyrugun tek cumlelik hali. `healthy` DISINDAKI her sey kullaniciya
/// gorunur bir uyaridir.
enum AccountPurgeHealthLevel {
  /// Yapilandirma yazili ve birikmis/kilitli/kalici hatali is yok.
  healthy,

  /// `account_purge_runtime_config` satiri yok — worker HIC kosmuyor.
  ///
  /// 🔴 Bu durum `failing` ile ayni ciddiyettedir ama AYRI bir seviyedir:
  /// sayaclar sifirdir, cunku hicbir is baslamamistir.
  notConfigured,

  /// Kuyruk kosuyor ama takilmis: kilitli lease, kalici hata ya da birikme.
  failing,
}

/// `get_account_purge_health()` ciktisinin tek satiri
/// (`supabase/migrations/0113_account_purge_scheduler.sql:300`).
///
/// 🔴 [level] neden [isConfigured] ile BASLAR: yapilandirilmamis bir kuyruk
/// sifir hata uretir ve "saglikli" gorunur. Bu tuzak migration'in kendi
/// yorumunda (`0113:295`) ve `production-purge-activation.yml:15`te yazili;
/// hata sayilarina bakip once yapilandirmayi sormayan her saglik iddiasi
/// ayni yanilgiyi tekrar eder.
@immutable
class AccountPurgeHealth {
  const AccountPurgeHealth({
    required this.configurationStatus,
    required this.dueCount,
    required this.processingCount,
    required this.staleLeaseCount,
    required this.terminalFailedCount,
    required this.oldestDueAgeSeconds,
    required this.purgedLast30d,
  });

  /// Sunucunun "yapilandirma yazili" dedigi TEK deger.
  static const String configuredStatus = 'configured';

  /// Birikme esigi. `0113`teki zamanlayici **saatlik** kosar; ucuncu turu da
  /// kaciran bir is artik normal gecikme degildir. Yeni sayi uretilmedi,
  /// esik cron periyodundan turedi.
  static const int backlogToleranceSeconds = 3 * 3600;

  final String configurationStatus;
  final int dueCount;
  final int processingCount;
  final int staleLeaseCount;
  final int terminalFailedCount;
  final int oldestDueAgeSeconds;
  final int purgedLast30d;

  bool get isConfigured => configurationStatus == configuredStatus;

  AccountPurgeHealthLevel get level {
    // 🔴 SIRA onemli: once yapilandirma, sonra sayaclar.
    if (!isConfigured) return AccountPurgeHealthLevel.notConfigured;
    if (staleLeaseCount > 0 ||
        terminalFailedCount > 0 ||
        oldestDueAgeSeconds > backlogToleranceSeconds) {
      return AccountPurgeHealthLevel.failing;
    }
    return AccountPurgeHealthLevel.healthy;
  }

  factory AccountPurgeHealth.fromMap(Map<String, dynamic> map) {
    int intOf(String key) => (map[key] as num?)?.toInt() ?? 0;
    return AccountPurgeHealth(
      // Bilinmeyen/eksik alan `configured` SAYILMAZ: eksik kanit saglik
      // kaniti degildir.
      configurationStatus: (map['configuration_status'] as String?) ?? '',
      dueCount: intOf('due_count'),
      processingCount: intOf('processing_count'),
      staleLeaseCount: intOf('stale_lease_count'),
      terminalFailedCount: intOf('terminal_failed_count'),
      oldestDueAgeSeconds: intOf('oldest_due_age_seconds'),
      purgedLast30d: intOf('purged_last_30d'),
    );
  }
}

/// WP-780: vakanin bir tarafi.
///
/// Sunucu bu iki degeri `feedback_tickets.case_party` CHECK'i ve
/// `admin_send_case_message`in `p_party` kontrolu ile kabul eder
/// (`supabase/migrations/0138_case_conversation_and_message_photo.sql`).
enum CaseConversationParty {
  reporter('reporter'),
  reported('reported');

  const CaseConversationParty(this.dbValue);

  final String dbValue;

  /// 🔴 Tanimadigi degeri bir tarafa **yuvarlamaz**. `FeedbackTicketSenderRole`
  /// gibi varsayilana dusseydi, sunucu tarafi yeniden adlandirildigi anda
  /// yonetici sikayet edilene yazdigini sanip sikayet edene yazardi.
  static CaseConversationParty fromDb(String value) =>
      values.firstWhere((party) => party.dbValue == value);
}

/// `admin_case_conversation_channels(p_report_id)` ciktisinin bir satiri.
///
/// [ticketId] `null` ise o tarafla **henuz kanal yoktur**; kanali ilk mesaj
/// acar ([AdminRepository.sendCaseMessage]).
@immutable
class CaseConversationChannel {
  const CaseConversationChannel({
    required this.party,
    required this.userId,
    this.displayName,
    this.ticketId,
  });

  final CaseConversationParty party;
  final String userId;

  /// Profili silinmis kisi icin `null` doner; taraf yine de gorunur.
  final String? displayName;
  final String? ticketId;

  factory CaseConversationChannel.fromMap(Map<String, dynamic> map) {
    return CaseConversationChannel(
      party: CaseConversationParty.fromDb(map['party'] as String),
      userId: map['user_id'] as String,
      displayName: map['display_name'] as String?,
      ticketId: map['ticket_id'] as String?,
    );
  }
}

abstract class AdminRepository {
  Future<bool> isSuperAdmin(String userId);

  Future<AdminDashboardSummary> fetchDashboardSummary(String userId);

  Future<List<FeedbackTicket>> fetchFeedbackTickets(
    String userId, {
    FeedbackTicketStatus? status,
    FeedbackTicketType? type,
    bool includeArchived = false,
  });

  Future<void> setFeedbackArchived({
    required String userId,
    required String ticketId,
    required bool archived,
  });

  Future<List<FeedbackTicket>> fetchMyFeedbackTickets(String userId);

  Future<FeedbackTicket> submitFeedback({
    required String userId,
    required FeedbackTicketKind kind,
    required String subject,
    required String message,
    Uint8List? attachmentBytes,
    String? attachmentExt,
  });

  Future<void> updateFeedbackStatus({
    required String userId,
    required String ticketId,
    required FeedbackTicketStatus status,
  });

  Future<String?> getFeedbackAttachmentUrl(String path);

  Future<List<AdminUserDto>> fetchUsers();

  Future<void> performUserAction({
    required String action,
    required String targetUserId,
    required String reason,
  });

  Future<void> performGroupAction({
    required String action,
    required String targetGroupId,
    String? targetUserId,
    required String reason,
  });

  Future<List<StudyGroup>> fetchGroups();

  /// WP-F: **yoneticinin** bir grubun uye listesi.
  ///
  /// 🔴 Neden ayri bir yol: `group_member_directory`
  /// (`supabase/migrations/0115_profile_titles.sql:103`) cagirani
  /// `is_group_member` ile suzer ve uyesi olmayan yoneticiye `42501` doner;
  /// `group_members` uzerinde de yonetici SELECT politikasi yoktur
  /// (`0001_initial_schema.sql:156`). Yani yonetici bir gruptan uye
  /// *atabiliyor* ama kimin uye oldugunu *goremiyordu*.
  ///
  /// Sunucu tarafi: `admin-operations` edge fonksiyonunun
  /// `list_group_members` eylemi — servis rolu ile calisir (RLS'i asar) ve
  /// yonetici kapisinin arkasindadir. RLS'e kalici bir yonetici istisnasi
  /// acilmadi.
  ///
  /// Reddedilen okuma **bos liste degil** hata dondurur: bos grup ile
  /// okunamayan liste ayni sey degildir.
  Future<List<Profile>> fetchGroupMembers(String groupId);

  Future<List<Announcement>> fetchAnnouncements();

  Future<void> createAnnouncement({
    required String title,
    required String message,
    required String targetType,
    String? targetId,
    required String adminId,
  });

  Future<void> deleteAnnouncement(String announcementId);

  Future<List<FeedbackTicketNote>> fetchTicketNotes(String ticketId);

  Future<void> addTicketNote({
    required String ticketId,
    required String note,
    required String adminId,
  });

  Future<List<FeedbackTicketMessage>> fetchTicketMessages({
    required String userId,
    required String ticketId,
  });

  Stream<List<FeedbackTicketMessage>> watchTicketMessages({
    required String userId,
    required String ticketId,
  });

  /// Kullanicinin kendi biletleri + konusmanin son hali (son mesaj, tarih,
  /// okunmamis sayisi). WP-437: liste satiri ilk mesajda donmaz.
  Future<List<FeedbackTicketThreadSummary>> fetchMyTicketThreadSummaries(
    String userId,
  );

  /// Bir bilete mesaj — kullanici ya da yonetici ucu.
  ///
  /// WP-784: ek opsiyoneldir ama [sendCaseMessage] ile ayni kurala tabidir —
  /// yukleme basarisiz olursa mesaj da gonderilmez ve [AdminException] atilir.
  /// Kullanici yazma seridindeki onizlemede fotografi gordu; sessizce eksiz
  /// gondermek, gondermedigi bir seyi gonderdi sanmasidir.
  Future<FeedbackTicketMessage> sendTicketMessage({
    required String userId,
    required String ticketId,
    required String message,
    String? clientMessageId,
    Uint8List? attachmentBytes,
    String? attachmentExt,
  });

  /// Kullanicinin kendi biletlerinde **okunmamis yonetici yaniti** sayisi.
  ///
  /// WP-421: Rozet zinciri bu tek sayidan beslenir. Push ile ayni olaydan
  /// (yonetici yaniti) turer ama pushu **beklemez** — cevrimdisi acilista da
  /// sunucudan okunur.
  Future<int> fetchUnreadTicketReplyCount(String userId);

  Future<void> markTicketMessagesRead({
    required String userId,
    required String ticketId,
  });

  /// WP-E: hesap silme kuyrugunun sagligi (`get_account_purge_health`).
  ///
  /// 🔴 Neden UI'a tasindi: RPC `0113`ten beri sunucuda duruyordu ama
  /// `app/lib/` icinde adi HIC gecmiyordu. Yani kuyruk tikanirsa (kilitli
  /// lease, tukenmis deneme sayaci, hic yazilmamis runtime config) kimsenin
  /// haberi olmuyordu; kullanicinin "hesabimi sil" istegi sessizce oluyordu.
  ///
  /// Reddedilen/okunamayan saglik **bos sonuc degil** [AdminException] doner:
  /// "sorulamadi" ile "sorun yok" ayni sey degildir.
  Future<AccountPurgeHealth> fetchAccountPurgeHealth();

  /// WP-780: vakanin iki taraf kanali (`admin_case_conversation_channels`).
  ///
  /// Grup/grup adi raporunda sikayet edilen tek bir kisi yoktur; sunucu o
  /// vakada **yalniz** sikayet eden satirini doner. Yani liste bir ya da iki
  /// elemanlidir.
  Future<List<CaseConversationChannel>> fetchCaseConversationChannels({
    required String userId,
    required String reportId,
  });

  /// WP-780: yoneticinin taraf kanalina mesaji (`admin_send_case_message`).
  ///
  /// Kanal **tembeldir**: sikayet edilen kisi, yonetici gercekten yazana kadar
  /// hicbir destek kaydi gormez. Bu yuzden donus tipi `void` degildir — ilk
  /// mesajdan sonra o tarafin gecmisi ancak donen mesajin
  /// [FeedbackTicketMessage.ticketId]'siyle okunabilir; cagiran kimligi
  /// saklamazsa yeni acilan kanal ekranda bos gorunur.
  ///
  /// Ek opsiyoneldir ama **sessizce dusmez**: yukleme basarisiz olursa mesaj da
  /// gonderilmez ve [AdminException] atilir.
  Future<FeedbackTicketMessage> sendCaseMessage({
    required String userId,
    required String reportId,
    required CaseConversationParty party,
    required String message,
    String? clientMessageId,
    Uint8List? attachmentBytes,
    String? attachmentExt,
  });

  /// WP-780: mesaja ekli fotografin imzali adresi (`ticket_message_attachments`
  /// bucket'i, `0138`). `null` = gosterilemiyor.
  Future<String?> getTicketMessageAttachmentUrl(String path);

  Future<List<AdminAuditLog>> fetchAuditLogs();
}

String normalizeFeedbackSubject(String subject) {
  final normalized = subject.trim();
  if (normalized.isEmpty) {
    throw const AdminException('Konu boş olamaz.');
  }
  if (normalized.length > kMaxFeedbackSubjectLength) {
    throw const AdminException('Konu en fazla 80 karakter olabilir.');
  }
  return normalized;
}

String normalizeFeedbackMessage(String message) {
  final normalized = message.trim();
  if (normalized.isEmpty) {
    throw const AdminException('Mesaj boş olamaz.');
  }
  if (normalized.length > kMaxFeedbackMessageLength) {
    throw const AdminException('Mesaj en fazla 1200 karakter olabilir.');
  }
  return normalized;
}

String normalizeFeedbackTicketReply(String message) {
  final normalized = message.trim();
  if (normalized.isEmpty) {
    throw const AdminException('Yanıt boş olamaz.');
  }
  if (normalized.length > kMaxFeedbackTicketReplyLength) {
    throw const AdminException('Yanıt en fazla 1200 karakter olabilir.');
  }
  return normalized;
}
