import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/announcement.dart';
import '../../models/study_reminder.dart';
import '../notification_repository.dart';

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<StudyReminder>> fetchReminders(String userId) async {
    try {
      final rows = await _client
          .from('study_reminders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);
      return rows.map((e) => StudyReminder.fromMap(e)).toList();
    } catch (e) {
      throw NotificationException('Hatırlatıcılar alınamadı: $e');
    }
  }

  @override
  Future<StudyReminder> upsertReminder(StudyReminder reminder) async {
    try {
      if (reminder.isNew) {
        final row = await _client
            .from('study_reminders')
            .insert(reminder.toWriteMap())
            .select()
            .single();
        return StudyReminder.fromMap(row);
      }
      final row = await _client
          .from('study_reminders')
          .update(reminder.toWriteMap())
          .eq('id', reminder.id)
          .select()
          .single();
      return StudyReminder.fromMap(row);
    } catch (e) {
      throw NotificationException('Hatırlatıcı kaydedilemedi: $e');
    }
  }

  @override
  Future<void> deleteReminder(String reminderId) async {
    try {
      await _client.from('study_reminders').delete().eq('id', reminderId);
    } catch (e) {
      throw NotificationException('Hatırlatıcı silinemedi: $e');
    }
  }

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
