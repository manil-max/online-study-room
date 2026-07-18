import 'dart:typed_data';

import '../models/admin_audit_log.dart';
import '../models/admin_user_dto.dart';
import '../models/announcement.dart';
import '../models/feedback_ticket.dart';
import '../models/feedback_ticket_note.dart';
import '../models/study_group.dart';

const int kMaxFeedbackSubjectLength = 80;
const int kMaxFeedbackMessageLength = 1200;

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
String? classifyFeedbackSubmitError({
  String? postgrestCode,
  String? message,
}) {
  final code = (postgrestCode ?? '').toLowerCase().trim();
  final msg = (message ?? '').toLowerCase();

  // Tablo yok / PostgREST şema önbelleği — dar kurallar.
  final isSchemaCode = code == '42p01' || code == 'pgrst205';
  final isSchemaMsg = msg.contains('schema cache') ||
      msg.contains('could not find the table') ||
      (msg.contains('relation') &&
          msg.contains('does not exist') &&
          msg.contains('feedback'));
  if (isSchemaCode || isSchemaMsg) {
    return 'schema_missing';
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
  final detail = [
    if (code.isNotEmpty) code,
    if (raw.isNotEmpty) raw,
  ].join(' ');
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

abstract class AdminRepository {
  Future<bool> isSuperAdmin(String userId);

  Future<AdminDashboardSummary> fetchDashboardSummary(String userId);

  Future<List<FeedbackTicket>> fetchFeedbackTickets(
    String userId, {
    FeedbackTicketStatus? status,
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
