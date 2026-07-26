import 'dart:async';
import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../models/admin_audit_log.dart';
import '../../models/admin_user_dto.dart';
import '../../models/announcement.dart';
import '../../models/feedback_ticket.dart';
import '../../models/feedback_ticket_note.dart';
import '../../models/feedback_ticket_message.dart';
import '../../models/study_group.dart';
import '../admin_repository.dart';

class InMemoryAdminRepository implements AdminRepository {
  InMemoryAdminRepository({Set<String> superAdminUserIds = const {}})
    : _superAdminUserIds = {...superAdminUserIds};

  final _uuid = const Uuid();
  final Set<String> _superAdminUserIds;
  final List<FeedbackTicket> _tickets = [];
  final List<FeedbackTicketMessage> _ticketMessages = [];
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
    Uint8List? attachmentBytes,
    String? attachmentExt,
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
      attachmentPath: attachmentBytes != null
          ? 'dummy/path.$attachmentExt'
          : null,
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

  @override
  Future<String?> getFeedbackAttachmentUrl(String path) async {
    return null; // InMemory için desteklenmiyor
  }

  @override
  Future<List<AdminUserDto>> fetchUsers() async {
    return [
      AdminUserDto(
        id: _uuid.v4(),
        email: 'test1@example.com',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      AdminUserDto(
        id: _uuid.v4(),
        email: 'test2@example.com',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        bannedUntil: '876000h', // suspended
      ),
    ];
  }

  @override
  Future<void> performUserAction({
    required String action,
    required String targetUserId,
    required String reason,
  }) async {
    // Dummy successful action
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> performGroupAction({
    required String action,
    required String targetGroupId,
    String? targetUserId,
    required String reason,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<List<StudyGroup>> fetchGroups() async {
    return [
      StudyGroup(
        id: _uuid.v4(),
        name: 'Test Grubu 1',
        inviteCode: 'TEST01',
        createdBy: 'admin',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
    ];
  }

  @override
  Future<List<Announcement>> fetchAnnouncements() async {
    return [
      Announcement(
        id: _uuid.v4(),
        title: 'Sistem Bakımı',
        message: 'Bu gece 03:00 - 05:00 arası bakım çalışması olacaktır.',
        targetType: 'all',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        createdBy: 'admin',
      ),
    ];
  }

  @override
  Future<void> createAnnouncement({
    required String title,
    required String message,
    required String targetType,
    String? targetId,
    required String adminId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> deleteAnnouncement(String announcementId) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<List<FeedbackTicketNote>> fetchTicketNotes(String ticketId) async {
    return [
      FeedbackTicketNote(
        id: _uuid.v4(),
        ticketId: ticketId,
        adminId: 'admin',
        note: 'Bu konu inceleniyor.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
    ];
  }

  @override
  Future<void> addTicketNote({
    required String ticketId,
    required String note,
    required String adminId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<List<FeedbackTicketMessage>> fetchTicketMessages({
    required String userId,
    required String ticketId,
  }) async {
    _requireTicketParticipant(userId, ticketId);
    final rows =
        _ticketMessages
            .where((message) => message.ticketId == ticketId)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List.unmodifiable(rows);
  }

  @override
  Future<FeedbackTicketMessage> sendTicketMessage({
    required String userId,
    required String ticketId,
    required String message,
  }) async {
    final ticketIndex = _requireTicketParticipant(userId, ticketId);
    final senderRole = _superAdminUserIds.contains(userId)
        ? FeedbackTicketSenderRole.admin
        : FeedbackTicketSenderRole.user;
    final now = DateTime.now();
    final item = FeedbackTicketMessage(
      id: _uuid.v4(),
      ticketId: ticketId,
      senderId: userId,
      senderRole: senderRole,
      message: normalizeFeedbackTicketReply(message),
      createdAt: now,
    );
    _ticketMessages.add(item);
    _tickets[ticketIndex] = _tickets[ticketIndex].copyWith(
      status: FeedbackTicketStatus.inProgress,
      updatedAt: now,
    );
    _changes.add(null);
    return item;
  }

  @override
  Future<void> markTicketMessagesRead({
    required String userId,
    required String ticketId,
  }) async {
    _requireTicketParticipant(userId, ticketId);
    final readerRole = _superAdminUserIds.contains(userId)
        ? FeedbackTicketSenderRole.admin
        : FeedbackTicketSenderRole.user;
    final now = DateTime.now();
    for (var index = 0; index < _ticketMessages.length; index++) {
      final item = _ticketMessages[index];
      if (item.ticketId == ticketId &&
          item.senderRole != readerRole &&
          item.readAt == null) {
        _ticketMessages[index] = FeedbackTicketMessage(
          id: item.id,
          ticketId: item.ticketId,
          senderId: item.senderId,
          senderRole: item.senderRole,
          message: item.message,
          createdAt: item.createdAt,
          readAt: now,
        );
      }
    }
  }

  @override
  Future<List<AdminAuditLog>> fetchAuditLogs() async {
    return [
      AdminAuditLog(
        id: _uuid.v4(),
        adminId: 'admin',
        targetUserId: 'test2',
        action: 'suspend_user',
        reason: 'Spam kurallarını ihlal',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  void _requireAdmin(String userId) {
    if (!_superAdminUserIds.contains(userId)) {
      throw const AdminException('Bu işlem için admin yetkisi gerekiyor.');
    }
  }

  int _requireTicketParticipant(String userId, String ticketId) {
    final index = _tickets.indexWhere((ticket) => ticket.id == ticketId);
    if (index < 0) {
      throw const AdminException('Geri bildirim bulunamadı.');
    }
    if (_tickets[index].userId != userId &&
        !_superAdminUserIds.contains(userId)) {
      throw const AdminException('Bu yazışmaya erişim iznin yok.');
    }
    return index;
  }

  void dispose() => _changes.close();
}
