import '../models/announcement.dart';

class NotificationException implements Exception {
  const NotificationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Bildirim Merkezi verisi: kullanıcıya görünen duyurular ve okunma
/// durumları. Dürtme/alarm gibi diğer türler kendi repository/servislerinde
/// kalır. WP-304: kişisel çalışma hatırlatıcıları kaldırıldı — alarm zaten
/// aynı işi sesli/tam ekran yapıyordu, iki kavram tek işi anlatıyordu.
abstract class NotificationRepository {
  /// Giriş yapan kullanıcıya görünen duyurular (RLS ile filtrelenir).
  Future<List<Announcement>> fetchMyAnnouncements(String userId);

  Future<Set<String>> fetchReadAnnouncementIds(String userId);

  Future<void> markAnnouncementRead({
    required String userId,
    required String announcementId,
  });
}
