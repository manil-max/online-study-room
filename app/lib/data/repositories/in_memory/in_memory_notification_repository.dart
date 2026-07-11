import 'package:uuid/uuid.dart';

import '../../models/announcement.dart';
import '../../models/study_reminder.dart';
import '../notification_repository.dart';

/// Bildirim Merkezi'nin demo/offline (InMemory) uygulaması. Uygulama Supabase
/// olmadan çalışırken hatırlatıcı ve duyuru akışının kırılmaması için kullanılır.
class InMemoryNotificationRepository implements NotificationRepository {
  final _uuid = const Uuid();
  final List<StudyReminder> _reminders = [];
  final Set<String> _readAnnouncementIds = {};

  /// Demo modda merkez boş görünmesin diye örnek bir hoş geldin duyurusu.
  late final List<Announcement> _announcements = [
    Announcement(
      id: 'demo-welcome',
      title: 'Odak Kampı’na hoş geldin 🏕️',
      message:
          'Bildirim Merkezi’nden hatırlatıcılarını, sessiz saatlerini ve '
          'duyuruları tek yerden yönetebilirsin.',
      targetType: 'all',
      createdAt: DateTime.now(),
      createdBy: 'system',
    ),
  ];

  @override
  Future<List<StudyReminder>> fetchReminders(String userId) async {
    final mine = _reminders.where((r) => r.userId == userId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return mine;
  }

  @override
  Future<StudyReminder> upsertReminder(StudyReminder reminder) async {
    if (reminder.isNew) {
      final created = reminder.copyWith(
        id: _uuid.v4(),
        createdAt: DateTime.now(),
      );
      _reminders.add(created);
      return created;
    }
    final index = _reminders.indexWhere((r) => r.id == reminder.id);
    if (index == -1) {
      throw const NotificationException('Hatırlatıcı bulunamadı.');
    }
    _reminders[index] = reminder;
    return reminder;
  }

  @override
  Future<void> deleteReminder(String reminderId) async {
    _reminders.removeWhere((r) => r.id == reminderId);
  }

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
