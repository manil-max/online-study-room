import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/announcement.dart';
import '../notification_repository.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<Announcement>> fetchMyAnnouncements(String userId) async {
    try {
      // RLS `announcements_select_user` politikası kullanıcıya görünür
      // duyuruları (all/kendi/grup) zaten filtreler.
      final rows = await _client
          .from('announcements')
          .select()
          .order('created_at', ascending: false);
      return rows.map((e) => Announcement.fromMap(e)).toList();
    } catch (e) {
      throw NotificationException('Duyurular alınamadı: $e');
    }
  }

  @override
  Future<Set<String>> fetchReadAnnouncementIds(String userId) async {
    try {
      final rows = await _client
          .from('announcement_reads')
          .select('announcement_id')
          .eq('user_id', userId);
      return rows.map((e) => e['announcement_id'] as String).toSet();
    } catch (e) {
      throw NotificationException('Okunma bilgisi alınamadı: $e');
    }
  }

  @override
  Future<void> markAnnouncementRead({
    required String userId,
    required String announcementId,
  }) async {
    try {
      await _client.from('announcement_reads').upsert({
        'user_id': userId,
        'announcement_id': announcementId,
      }, onConflict: 'user_id,announcement_id');
    } catch (e) {
      throw NotificationException('Duyuru okundu işaretlenemedi: $e');
    }
  }
}
