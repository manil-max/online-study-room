import '../models/feedback_ticket.dart';

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
  });

  Future<void> updateFeedbackStatus({
    required String userId,
    required String ticketId,
    required FeedbackTicketStatus status,
  });
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
