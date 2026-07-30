// WP-459: Ayarlar ve profil rozetleri tek feedback gerçeğine bağlı.
//
// Zincir: Profil sekmesi → Profil'deki "Ayarlar" satırı → Ayarlar'daki
// "Geri bildirim" satırı → bilet. Kural: alt seviyede görünen her sinyal üst
// seviyede de görünür, hiçbir yüzey kendi sayacını türetmez ve rozet yalnız
// konuşma gerçekten görülünce (WP-436 watermark ack'i) söner.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/announcement.dart';
import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/notification_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/data/repositories/notification_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeNotificationRepository implements NotificationRepository {
  _FakeNotificationRepository(this._announcements);

  final List<Announcement> _announcements;
  final Set<String> _read = {};

  @override
  Future<List<Announcement>> fetchMyAnnouncements(String userId) async =>
      List.unmodifiable(_announcements);

  @override
  Future<Set<String>> fetchReadAnnouncementIds(String userId) async => {
    ..._read,
  };

  @override
  Future<void> markAnnouncementRead({
    required String userId,
    required String announcementId,
  }) async {
    _read.add(announcementId);
  }
}

Announcement _announcement({required String id, String? ticketId}) {
  return Announcement(
    id: id,
    title: 'Duyuru',
    message: 'Gövde',
    targetType: ticketId == null ? 'all' : 'user',
    targetId: ticketId == null ? null : 'u1',
    relatedFeedbackTicketId: ticketId,
    createdAt: DateTime(2026, 7, 30),
    createdBy: 'admin',
  );
}

Future<ProviderContainer> _chain({
  required InMemoryAdminRepository repo,
  required List<Announcement> announcements,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          Profile(id: 'u1', displayName: 'Ben', createdAt: DateTime(2026)),
        ),
      ),
      adminRepositoryProvider.overrideWithValue(repo),
      notificationRepositoryProvider.overrideWithValue(
        _FakeNotificationRepository(announcements),
      ),
    ],
  );
  addTearDown(container.dispose);
  // Riverpod 3: dinleyicisiz provider her okumada yeniden kurulur ve rozet
  // regresyonu sessizce etkisizleşir.
  container.listen(settingsBadgeCountProvider, (_, _) {});
  container.listen(authStateProvider, (_, _) {});
  await container.read(authStateProvider.future);
  await container.read(myAnnouncementsProvider.future);
  await container.read(readAnnouncementIdsProvider.future);
  await container.read(unreadFeedbackReplyCountProvider.future);
  return container;
}

Future<FeedbackTicket> _ticketWithAdminReply(
  InMemoryAdminRepository repo,
) async {
  final ticket = await repo.submitFeedback(
    userId: 'u1',
    kind: FeedbackTicketKind.bug,
    subject: 'Rozet zinciri',
    message: 'Açılış mesajı.',
  );
  await repo.sendTicketMessage(
    userId: 'admin',
    ticketId: ticket.id,
    message: 'Bakıyoruz.',
  );
  return ticket;
}

String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('WP-459 — tek gerçek, tüm yüzeyler', () {
    test('tek admin yanıtı her yüzeyde 1 sayılır', () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await _ticketWithAdminReply(repo);
      final container = await _chain(
        repo: repo,
        announcements: [_announcement(id: 'ann-1', ticketId: ticket.id)],
      );

      expect(
        container.read(unreadAnnouncementCountProvider),
        0,
        reason: 'feedback duyurusu ayrı bir okunmamış gerçek değildir',
      );
      expect(container.read(unreadFeedbackReplyCountProvider).value, 1);
      expect(
        container.read(settingsBadgeCountProvider),
        1,
        reason: 'sekme ve satır aynı toplamı okur',
      );
    });

    test('feedback dışı duyuru ile yanıt üst üste binmez', () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await _ticketWithAdminReply(repo);
      final container = await _chain(
        repo: repo,
        announcements: [
          _announcement(id: 'ann-genel'),
          _announcement(id: 'ann-feedback', ticketId: ticket.id),
        ],
      );

      expect(container.read(unreadAnnouncementCountProvider), 1);
      expect(
        container.read(settingsBadgeCountProvider),
        2,
        reason: 'genel duyuru + bir yanıt = 2; feedback duyurusu sayılmaz',
      );
    });

    test('konuşma görülünce zincirin tamamı söner', () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await _ticketWithAdminReply(repo);
      final container = await _chain(
        repo: repo,
        announcements: [_announcement(id: 'ann-1', ticketId: ticket.id)],
      );
      expect(container.read(settingsBadgeCountProvider), 1);

      await repo.markTicketMessagesRead(userId: 'u1', ticketId: ticket.id);
      container.invalidate(unreadFeedbackReplyCountProvider);
      await container.read(unreadFeedbackReplyCountProvider.future);

      expect(
        container.read(settingsBadgeCountProvider),
        0,
        reason: 'okundu sonrası hiçbir yüzeyde rozet kalmaz',
      );
    });

    test('duyuruyu okumak feedback rozetini söndürmez', () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await _ticketWithAdminReply(repo);
      final container = await _chain(
        repo: repo,
        announcements: [_announcement(id: 'ann-1', ticketId: ticket.id)],
      );

      container.invalidate(readAnnouncementIdsProvider);
      await container.read(readAnnouncementIdsProvider.future);

      expect(
        container.read(settingsBadgeCountProvider),
        1,
        reason: 'rozet yalnız konuşma görülünce (watermark ack) söner',
      );
    });
  });

  group('WP-459 — kaynak sözleşmesi', () {
    test('hiçbir yüzey kendi okunmamış sayacını türetmiyor', () {
      const surfaces = [
        'lib/core/navigation/home_shell.dart',
        'lib/features/profile/profile_screen.dart',
        'lib/features/profile/settings_screen.dart',
        'lib/features/profile/feedback_screen.dart',
      ];
      for (final path in surfaces) {
        final source = _read(path);
        expect(
          source.contains('unreadFeedbackReplyCountProvider') ||
              source.contains('settingsBadgeCountProvider') ||
              source.contains('unreadAnnouncementCountProvider'),
          isTrue,
          reason: '$path zincirin dışında bir kaynak okuyor',
        );
        expect(
          source.contains('bool _hasUnread') ||
              source.contains('int _unreadCache'),
          isFalse,
          reason: '$path yerel okunmamış bayrağı/önbelleği tutuyor',
        );
      }
    });

    test('profil sekmesi feedback yanıtını da taşıyor', () {
      final source = _read('lib/core/navigation/home_shell.dart');
      expect(
        source.contains('settingsBadgeCountProvider'),
        isTrue,
        reason: 'sekme noktası yalnız duyurudan besleniyor',
      );
      expect(source.contains('unreadProfileSignals > 0'), isTrue);
    });
  });
}
