import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/feedback_ticket.dart';
import '../admin_repository.dart';

class SupabaseAdminRepository implements AdminRepository {
  SupabaseAdminRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> isSuperAdmin(String userId) async {
    try {
      final value = await _client.rpc('is_super_admin');
      return value == true;
    } on PostgrestException catch (e) {
      throw AdminException('Admin yetkisi kontrol edilemedi: ${e.message}');
    }
  }

  @override
  Future<AdminDashboardSummary> fetchDashboardSummary(String userId) async {
    try {
      final row = await _client.rpc('admin_dashboard_summary');
      return AdminDashboardSummary.fromMap(
        Map<String, dynamic>.from(row as Map),
      );
    } on PostgrestException catch (e) {
      throw AdminException(_friendlyMessage(e.message));
    }
  }

  @override
  Future<List<FeedbackTicket>> fetchFeedbackTickets(
    String userId, {
    FeedbackTicketStatus? status,
  }) async {
    try {
      final rows = await _client.rpc(
        'admin_feedback_tickets',
        params: {'p_status': status?.dbValue},
      ) as List<dynamic>;
      return rows
          .map((row) => FeedbackTicket.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } on PostgrestException catch (e) {
      throw AdminException(_friendlyMessage(e.message));
    }
  }

  @override
  Future<List<FeedbackTicket>> fetchMyFeedbackTickets(String userId) async {
    final rows = await _client
        .from('feedback_tickets')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return rows.map<FeedbackTicket>(FeedbackTicket.fromMap).toList();
  }

  @override
  Future<FeedbackTicket> submitFeedback({
    required String userId,
    required FeedbackTicketKind kind,
    required String subject,
    required String message,
  }) async {
    try {
      final row = await _client
          .from('feedback_tickets')
          .insert({
            'user_id': userId,
            'kind': kind.dbValue,
            'subject': normalizeFeedbackSubject(subject),
            'message': normalizeFeedbackMessage(message),
          })
          .select()
          .single();
      return FeedbackTicket.fromMap(row);
    } on PostgrestException catch (e) {
      throw AdminException('Geri bildirim gönderilemedi: ${e.message}');
    }
  }

  @override
  Future<void> updateFeedbackStatus({
    required String userId,
    required String ticketId,
    required FeedbackTicketStatus status,
  }) async {
    try {
      await _client.rpc(
        'admin_update_feedback_status',
        params: {'p_ticket_id': ticketId, 'p_status': status.dbValue},
      );
    } on PostgrestException catch (e) {
      throw AdminException(_friendlyMessage(e.message));
    }
  }

  String _friendlyMessage(String message) {
    if (message.contains('not_super_admin')) {
      return 'Bu işlem için admin yetkisi gerekiyor.';
    }
    if (message.contains('invalid_feedback_status')) {
      return 'Geçersiz rapor durumu.';
    }
    return 'Admin işlemi tamamlanamadı: $message';
  }
}
