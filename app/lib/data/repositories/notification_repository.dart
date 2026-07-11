import '../models/announcement.dart';
import '../models/study_reminder.dart';

class NotificationException implements Exception {
  const NotificationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Bildirim Merkezi verisi: kişisel hatırlatıcılar ve kullanıcıya görünen
/// duyuruların okunma durumu (§WP-36). Dürtme/alarm gibi diğer türler kendi
/// repository/servislerinde kalır; burada yalnız merkeze özgü kalıcı veri var.
abstract class NotificationRepository {
  Future<List<StudyReminder>> fetchReminders(String userId);

  /// Yeni hatırlatıcı ise ekler (id boş), aksi halde günceller; sonucu döner.
  Future<StudyReminder> upsertReminder(StudyReminder reminder);

  Future<void> deleteReminder(String reminderId);

  /// Giriş yapan kullanıcıya görünen duyurular (RLS ile filtrelenir).
  Future<List<Announcement>> fetchMyAnnouncements(String userId);

  Future<Set<String>> fetchReadAnnouncementIds(String userId);

  Future<void> markAnnouncementRead({
    required String userId,
    required String announcementId,
  });
}
