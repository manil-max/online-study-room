import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_notification_repository.dart';

void main() {
  group('InMemoryNotificationRepository', () {
    late InMemoryNotificationRepository repository;

    setUp(() {
      repository = InMemoryNotificationRepository();
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
