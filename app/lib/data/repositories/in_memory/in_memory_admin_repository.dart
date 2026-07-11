import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../models/feedback_ticket.dart';
import '../admin_repository.dart';

class InMemoryAdminRepository implements AdminRepository {
  InMemoryAdminRepository({Set<String> superAdminUserIds = const {}})
    : _superAdminUserIds = {...superAdminUserIds};

  final _uuid = const Uuid();
  final Set<String> _superAdminUserIds;
  final List<FeedbackTicket> _tickets = [];
  final StreamController<void> _changes = StreamController<void>.broadcast();

  @override
  Future<bool> isSuperAdmin(String userId) async {
    return _superAdminUserIds.contains(userId);
  }

  @override
  Future<AdminDashboardSummary> fetchDashboardSummary(String userId) async {
    _requireAdmin(userId);
    return AdminDashboardSummary(
      userCount: 0,
      groupCount: 0,
      sessionCount: 0,
      openTicketCount: _tickets
          .where((t) => t.status == FeedbackTicketStatus.open)
          .length,
    );
  }

  @override
  Future<List<FeedbackTicket>> fetchFeedbackTickets(
    String userId, {
    FeedbackTicketStatus? status,
  }) async {
    _requireAdmin(userId);
    final rows =
        _tickets
            .where((ticket) => status == null || ticket.status == status)
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(rows);
  }

  @override
  Future<List<FeedbackTicket>> fetchMyFeedbackTickets(String userId) async {
    final rows = _tickets.where((ticket) => ticket.userId == userId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(rows);
  }

  @override
  Future<FeedbackTicket> submitFeedback({
    required String userId,
    required FeedbackTicketKind kind,
    required String subject,
    required String message,
  }) async {
    final now = DateTime.now();
    final ticket = FeedbackTicket(
      id: _uuid.v4(),
      userId: userId,
      kind: kind,
      subject: normalizeFeedbackSubject(subject),
      message: normalizeFeedbackMessage(message),
      status: FeedbackTicketStatus.open,
      createdAt: now,
      updatedAt: now,
    );
    _tickets.add(ticket);
    _changes.add(null);
    return ticket;
  }

  @override
  Future<void> updateFeedbackStatus({
    required String userId,
    required String ticketId,
    required FeedbackTicketStatus status,
  }) async {
    _requireAdmin(userId);
    final index = _tickets.indexWhere((ticket) => ticket.id == ticketId);
    if (index < 0) return;
    _tickets[index] = _tickets[index].copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );
    _changes.add(null);
  }

  void _requireAdmin(String userId) {
    if (!_superAdminUserIds.contains(userId)) {
      throw const AdminException('Bu işlem için admin yetkisi gerekiyor.');
    }
  }

  void dispose() => _changes.close();
}
