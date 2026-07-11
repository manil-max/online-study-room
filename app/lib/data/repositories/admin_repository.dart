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
  const AdminException(this.message);

  final String message;

  @override
  String toString() => message;
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
