import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../models/admin_audit_log.dart';
import '../../models/admin_user_dto.dart';
import '../../models/announcement.dart';
import '../../models/feedback_ticket.dart';
import '../../models/feedback_ticket_note.dart';
import '../../models/study_group.dart';
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
      final rows =
          await _client.rpc(
                'admin_feedback_tickets',
                params: {'p_status': status?.dbValue},
              )
              as List<dynamic>;
      return rows
          .map(
            (row) =>
                FeedbackTicket.fromMap(Map<String, dynamic>.from(row as Map)),
          )
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
    Uint8List? attachmentBytes,
    String? attachmentExt,
  }) async {
    // WP-168: RLS `user_id = auth.uid()` — oturum yoksa/mismatch ise net hata.
    final authUid = _client.auth.currentUser?.id;
    final session = _client.auth.currentSession;
    if (authUid == null || session == null) {
      _debugLogFeedback(
        'submitFeedback: no session '
        '(currentUser=${authUid == null ? "null" : "set"}, '
        'session=${session == null ? "null" : "set"})',
      );
      throw const AdminException(
        'Geri bildirim göndermek için giriş yapmalısın.',
        code: 'session_required',
      );
    }
    if (authUid != userId) {
      _debugLogFeedback(
        'submitFeedback: userId mismatch authUid=$authUid userId=$userId',
      );
      throw const AdminException(
        'Oturumun sona ermiş veya geçersiz. Tekrar giriş yapıp dene.',
        code: 'session_required',
      );
    }

    try {
      String? attachmentPath;
      if (attachmentBytes != null && attachmentExt != null) {
        final ext = attachmentExt.startsWith('.')
            ? attachmentExt
            : '.$attachmentExt';
        final fileName = '${const Uuid().v4()}$ext';
        final path = '$userId/$fileName';

        await _client.storage
            .from('feedback_attachments')
            .uploadBinary(
              path,
              attachmentBytes,
              fileOptions: const FileOptions(upsert: true),
            );
        attachmentPath = path;
      }

      final row = await _client
          .from('feedback_tickets')
          .insert({
            'user_id': userId,
            'kind': kind.dbValue,
            'subject': normalizeFeedbackSubject(subject),
            'message': normalizeFeedbackMessage(message),
            'status': 'open',
            'attachment_path': ?attachmentPath,
          })
          .select()
          .single();
      return FeedbackTicket.fromMap(row);
    } on StorageException catch (e, st) {
      _debugLogFeedback(
        'submitFeedback StorageException '
        'statusCode=${e.statusCode} message=${e.message} error=${e.error}',
        st,
      );
      throw AdminException('Görsel yüklenemedi: ${e.message}');
    } on PostgrestException catch (e, st) {
      _debugLogFeedback(
        'submitFeedback PostgrestException '
        'code=${e.code} message=${e.message} '
        'details=${e.details} hint=${e.hint}',
        st,
      );
      final classified = classifyFeedbackSubmitError(
        postgrestCode: e.code,
        message: e.message,
      );
      if (classified == 'session_or_rls') {
        throw AdminException(
          'Oturumun sona ermiş veya sunucu erişimi reddetti. '
          'Tekrar giriş yapıp dene.',
          code: 'session_or_rls',
        );
      }
      throw AdminException(
        'Geri bildirim gönderilemedi: ${e.message}',
        code: e.code,
      );
    } catch (e, st) {
      _debugLogFeedback('submitFeedback unexpected: $e', st);
      throw AdminException('Beklenmeyen bir hata oluştu: $e');
    }
  }

  void _debugLogFeedback(String message, [StackTrace? st]) {
    if (!kDebugMode) return;
    debugPrint(message);
    if (st != null) debugPrint('$st');
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
      throw AdminException('Durum güncellenemedi: ${e.message}');
    }
  }

  @override
  Future<String?> getFeedbackAttachmentUrl(String path) async {
    try {
      return await _client.storage
          .from('feedback_attachments')
          .createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<AdminUserDto>> fetchUsers() async {
    try {
      final response = await _client.functions.invoke(
        'admin-user-actions',
        body: {'action': 'list_users'},
      );
      if (response.status != 200) {
        throw AdminException('Kullanıcılar alınamadı: ${response.data}');
      }
      final items = (response.data['data'] as List<dynamic>?) ?? [];
      return items
          .map((e) => AdminUserDto.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } on FunctionException catch (e) {
      throw AdminException('Servis hatası: ${e.details}');
    } catch (e) {
      throw AdminException('Beklenmeyen hata: $e');
    }
  }

  @override
  Future<void> performUserAction({
    required String action,
    required String targetUserId,
    required String reason,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'admin-user-actions',
        body: {
          'action': action,
          'targetUserId': targetUserId,
          'reason': reason,
        },
      );
      if (response.status != 200) {
        throw AdminException('İşlem başarısız: ${response.data}');
      }
    } on FunctionException catch (e) {
      throw AdminException('Servis hatası: ${e.details}');
    } catch (e) {
      throw AdminException('Beklenmeyen hata: $e');
    }
  }

  @override
  Future<void> performGroupAction({
    required String action,
    required String targetGroupId,
    String? targetUserId,
    required String reason,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'admin-operations',
        body: {
          'action': action,
          'targetGroupId': targetGroupId,
          'targetUserId': ?targetUserId,
          'reason': reason,
        },
      );
      if (response.status != 200) {
        throw AdminException('İşlem başarısız: ${response.data}');
      }
    } on FunctionException catch (e) {
      throw AdminException('Servis hatası: ${e.details}');
    } catch (e) {
      throw AdminException('Beklenmeyen hata: $e');
    }
  }

  @override
  Future<List<StudyGroup>> fetchGroups() async {
    try {
      final response = await _client
          .from('groups')
          .select()
          .order('created_at', ascending: false);
      return response.map((e) => StudyGroup.fromMap(e)).toList();
    } catch (e) {
      throw AdminException('Gruplar alınamadı: $e');
    }
  }

  @override
  Future<List<Announcement>> fetchAnnouncements() async {
    try {
      final response = await _client
          .from('announcements')
          .select()
          .order('created_at', ascending: false);
      return response.map((e) => Announcement.fromMap(e)).toList();
    } catch (e) {
      throw AdminException('Duyurular alınamadı: $e');
    }
  }

  @override
  Future<void> createAnnouncement({
    required String title,
    required String message,
    required String targetType,
    String? targetId,
    required String adminId,
  }) async {
    try {
      await _client.from('announcements').insert({
        'title': title,
        'message': message,
        'target_type': targetType,
        'target_id': targetId,
        'created_by': adminId,
      });
    } catch (e) {
      throw AdminException('Duyuru oluşturulamadı: $e');
    }
  }

  @override
  Future<void> deleteAnnouncement(String announcementId) async {
    try {
      await _client.from('announcements').delete().eq('id', announcementId);
    } catch (e) {
      throw AdminException('Duyuru silinemedi: $e');
    }
  }

  @override
  Future<List<FeedbackTicketNote>> fetchTicketNotes(String ticketId) async {
    try {
      final response = await _client
          .from('feedback_ticket_notes')
          .select()
          .eq('ticket_id', ticketId)
          .order('created_at');
      return response.map((e) => FeedbackTicketNote.fromMap(e)).toList();
    } catch (e) {
      throw AdminException('Notlar alınamadı: $e');
    }
  }

  @override
  Future<void> addTicketNote({
    required String ticketId,
    required String note,
    required String adminId,
  }) async {
    try {
      await _client.from('feedback_ticket_notes').insert({
        'ticket_id': ticketId,
        'admin_id': adminId,
        'note': note,
      });
    } catch (e) {
      throw AdminException('Not eklenemedi: $e');
    }
  }

  @override
  Future<List<AdminAuditLog>> fetchAuditLogs() async {
    try {
      final response = await _client
          .from('admin_audit_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(100);
      return response.map((e) => AdminAuditLog.fromMap(e)).toList();
    } catch (e) {
      throw AdminException('Denetim kayıtları alınamadı: $e');
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
