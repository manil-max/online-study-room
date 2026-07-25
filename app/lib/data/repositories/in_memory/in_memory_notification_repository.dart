import '../../models/announcement.dart';
import '../notification_repository.dart';

/// Bildirim Merkezi'nin demo/offline (InMemory) uygulaması. Uygulama Supabase
/// olmadan çalışırken duyuru akışının kırılmaması için kullanılır.
class InMemoryNotificationRepository implements NotificationRepository {
  final Set<String> _readAnnouncementIds = {};

  /// Demo modda merkez boş görünmesin diye örnek bir hoş geldin duyurusu.
  late final List<Announcement> _announcements = [
    Announcement(
      id: 'demo-welcome',
      title: 'Odak Kampı’na hoş geldin 🏕️',
      message:
          'Bildirim Merkezi’nden sessiz saatlerini ve duyuruları tek yerden '
          'yönetebilirsin.',
      targetType: 'all',
      createdAt: DateTime.now(),
      createdBy: 'system',
    ),
  ];

  @override
  Future<List<Announcement>> fetchMyAnnouncements(String userId) async {
    return List.unmodifiable(
      _announcements.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
    );
  }

  @override
  Future<Set<String>> fetchReadAnnouncementIds(String userId) async {
    return {..._readAnnouncementIds};
  }

  @override
  Future<void> markAnnouncementRead({
    required String userId,
    required String announcementId,
  }) async {
    _readAnnouncementIds.add(announcementId);
  }
}
