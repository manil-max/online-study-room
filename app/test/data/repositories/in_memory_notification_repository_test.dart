import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/study_reminder.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_notification_repository.dart';

void main() {
  group('InMemoryNotificationRepository', () {
    late InMemoryNotificationRepository repository;

    setUp(() {
      repository = InMemoryNotificationRepository();
    });

    StudyReminder newReminder({
      String userId = 'u1',
      String title = 'Çalış',
      int hour = 20,
      int minute = 0,
      List<int> weekdays = const [],
    }) {
      return StudyReminder(
        id: '',
        userId: userId,
        title: title,
        hour: hour,
        minute: minute,
        weekdays: weekdays,
        createdAt: DateTime.now(),
      );
    }

    test('upsert yeni hatırlatıcıya id ve tarih atar', () async {
      final created = await repository.upsertReminder(newReminder());
      expect(created.id, isNotEmpty);
      expect(created.isNew, isFalse);

      final all = await repository.fetchReminders('u1');
      expect(all, hasLength(1));
      expect(all.first.title, 'Çalış');
    });

    test('fetchReminders yalnız o kullanıcının kayıtlarını döner', () async {
      await repository.upsertReminder(newReminder(userId: 'u1'));
      await repository.upsertReminder(newReminder(userId: 'u2'));

      expect(await repository.fetchReminders('u1'), hasLength(1));
      expect(await repository.fetchReminders('u2'), hasLength(1));
    });

    test('upsert mevcut hatırlatıcıyı günceller, yeni kayıt eklemez', () async {
      final created = await repository.upsertReminder(newReminder());
      await repository.upsertReminder(created.copyWith(enabled: false));

      final all = await repository.fetchReminders('u1');
      expect(all, hasLength(1));
      expect(all.first.enabled, isFalse);
    });

    test('deleteReminder kaydı kaldırır', () async {
      final created = await repository.upsertReminder(newReminder());
      await repository.deleteReminder(created.id);
      expect(await repository.fetchReminders('u1'), isEmpty);
    });

    test('duyuru okundu işaretlenince okunanlar setine girer', () async {
      final announcements = await repository.fetchMyAnnouncements('u1');
      expect(announcements, isNotEmpty);

      expect(await repository.fetchReadAnnouncementIds('u1'), isEmpty);
      await repository.markAnnouncementRead(
        userId: 'u1',
        announcementId: announcements.first.id,
      );
      final read = await repository.fetchReadAnnouncementIds('u1');
      expect(read, contains(announcements.first.id));
    });
  });
}
