// WP-434: geri bildirim akışının uçtan uca denetimi.
//
// Bu dosya ürün kodu **değiştirmez**; akışın bugünkü gerçeğini ölçer ve iki
// grubu birbirinden ayırır:
//
//  * `sözleşme` grubu → bugün DOĞRU olan ve WP-435…438 boyunca bozulmaması
//    gereken bağlar (tek `ticket_id`, tek `message_id`, katılımcı sınırı).
//  * `🔴 kilitli kusur` grubu → bugün YANLIŞ olan davranış. Test bilerek
//    yanlış davranışı doğrular; böylece kusur sessizce yaşamaz ve düzeltme
//    geldiğinde test kırmızı düşüp buradaki iddianın çevrilmesini zorunlu
//    kılar. Her birinin sahibi ve çevrilecek satırı
//    `docs/qa/V57-FEEDBACK-EVIDENCE.md` içinde yazılıdır.
//
// Kanıt etiketi: Kodda doğrulandı.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/announcement.dart';
import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/feedback_ticket_message.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/notification_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/data/repositories/notification_repository.dart';
import 'package:online_study_room/features/profile/feedback_tickets_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sunucu davranışını taklit eden duyuru kanalı.
///
/// `0074_feedback_ticket_conversations.sql`, admin yanıtında hem
/// `feedback_ticket_messages` satırı hem de kullanıcıya hedefli bir
/// `announcements` satırı üretir. InMemory admin repository ikincisini
/// üretmediği için rozet çift sayımı yalnız bu sahte kanalla görünür.
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

Announcement _adminReplyAnnouncement(String ticketId, String userId) {
  return Announcement(
    id: 'ann-$ticketId',
    title: 'Geri bildiriminize yanıt verildi',
    message: 'Bakıyoruz.',
    targetType: 'user',
    targetId: userId,
    relatedFeedbackTicketId: ticketId,
    createdAt: DateTime(2026, 7, 30, 2),
    createdBy: 'admin',
  );
}

Future<FeedbackTicket> _openTicket(
  InMemoryAdminRepository repo, {
  String userId = 'u1',
  String subject = 'Sayaç durmuyor',
  String message = 'Bildirimden durdurunca sayaç devam ediyor.',
}) {
  return repo.submitFeedback(
    userId: userId,
    kind: FeedbackTicketKind.bug,
    subject: subject,
    message: message,
  );
}

Widget _wrapConversation(InMemoryAdminRepository repo, String userId) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          Profile(id: userId, displayName: userId, createdAt: DateTime(2026)),
        ),
      ),
      adminRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: MyFeedbackTicketsView()),
    ),
  );
}

String _readSource(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  group('sözleşme — mesajın kimliği ve bileti tektir', () {
    test(
      'bilet → kullanıcı → admin → kullanıcı akışında bağlar sapmaz',
      () async {
        final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
        addTearDown(repo.dispose);
        final ticket = await _openTicket(repo);

        final first = await repo.sendTicketMessage(
          userId: 'u1',
          ticketId: ticket.id,
          message: 'Ek bilgi: bildirimden durdurdum.',
        );
        final reply = await repo.sendTicketMessage(
          userId: 'admin',
          ticketId: ticket.id,
          message: 'Bakıyoruz.',
        );
        final second = await repo.sendTicketMessage(
          userId: 'u1',
          ticketId: ticket.id,
          message: 'Teşekkürler.',
        );

        final messages = await repo.fetchTicketMessages(
          userId: 'u1',
          ticketId: ticket.id,
        );
        expect(messages.map((m) => m.id).toSet().length, 4);
        expect(messages.map((m) => m.ticketId).toSet(), {ticket.id});
        expect(messages.map((m) => m.senderRole).toList(), [
          FeedbackTicketSenderRole.user,
          FeedbackTicketSenderRole.user,
          FeedbackTicketSenderRole.admin,
          FeedbackTicketSenderRole.user,
        ]);
        expect(messages.map((m) => m.id).toList(), [
          isNotEmpty,
          first.id,
          reply.id,
          second.id,
        ]);
        expect(messages.map((m) => m.senderId).toList(), [
          'u1',
          'u1',
          'admin',
          'u1',
        ]);
        expect(messages.map((m) => m.message).first, ticket.message);
        expect(messages.map((m) => m.messageSeq).toList(), [1, 2, 3, 4]);
      },
    );

    test('iki bilet eşzamanlı yazışırken mesaj karşı bilete düşmez', () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final a = await _openTicket(repo, subject: 'Bilet A');
      final b = await _openTicket(repo, subject: 'Bilet B');

      await repo.sendTicketMessage(
        userId: 'u1',
        ticketId: a.id,
        message: 'A mesajı',
      );
      await repo.sendTicketMessage(
        userId: 'admin',
        ticketId: b.id,
        message: 'B yanıtı',
      );

      final aMessages = await repo.fetchTicketMessages(
        userId: 'u1',
        ticketId: a.id,
      );
      final bMessages = await repo.fetchTicketMessages(
        userId: 'u1',
        ticketId: b.id,
      );
      expect(aMessages.map((m) => m.message).toList(), [a.message, 'A mesajı']);
      expect(bMessages.map((m) => m.message).toList(), [b.message, 'B yanıtı']);
    });

    test('yeniden fetch aynı kimlikleri ve aynı sırayı verir', () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await _openTicket(repo);
      for (var i = 1; i <= 5; i++) {
        await repo.sendTicketMessage(
          userId: i.isEven ? 'admin' : 'u1',
          ticketId: ticket.id,
          message: 'Mesaj $i',
        );
      }

      final firstRead = await repo.fetchTicketMessages(
        userId: 'u1',
        ticketId: ticket.id,
      );
      final secondRead = await repo.fetchTicketMessages(
        userId: 'u1',
        ticketId: ticket.id,
      );
      expect(
        secondRead.map((m) => m.id).toList(),
        firstRead.map((m) => m.id).toList(),
      );
      expect(secondRead.map((m) => m.message).toList(), const [
        'Bildirimden durdurunca sayaç devam ediyor.',
        'Mesaj 1',
        'Mesaj 2',
        'Mesaj 3',
        'Mesaj 4',
        'Mesaj 5',
      ]);
    });

    test('katılımcı olmayan kullanıcı yazışmayı ne okur ne yazar', () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await _openTicket(repo);

      await expectLater(
        repo.fetchTicketMessages(userId: 'u2', ticketId: ticket.id),
        throwsA(isA<AdminException>()),
      );
      await expectLater(
        repo.sendTicketMessage(
          userId: 'u2',
          ticketId: ticket.id,
          message: 'Araya girdim.',
        ),
        throwsA(isA<AdminException>()),
      );
      await expectLater(
        repo.markTicketMessagesRead(userId: 'u2', ticketId: ticket.id),
        throwsA(isA<AdminException>()),
      );
    });
  });

  group('WP-435 — sunucu tek gerçeği', () {
    test('biletin ilk mesajı kanonik mesaj dizisinde yer alır', () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await _openTicket(repo, message: 'İlk kayıt.');

      expect(ticket.message, 'İlk kayıt.');
      final messages = await repo.fetchTicketMessages(
        userId: 'u1',
        ticketId: ticket.id,
      );
      expect(messages, hasLength(1));
      expect(messages.single.message, ticket.message);
      expect(messages.single.messageSeq, 1);
    });

    test('aynı istemci komutu yeniden denendiğinde tek satır kalır', () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await _openTicket(repo);

      final a = await repo.sendTicketMessage(
        userId: 'u1',
        ticketId: ticket.id,
        message: 'Aynı metin',
        clientMessageId: '00000000-0000-0000-0000-000000000435',
      );
      final b = await repo.sendTicketMessage(
        userId: 'u1',
        ticketId: ticket.id,
        message: 'Aynı metin',
        clientMessageId: '00000000-0000-0000-0000-000000000435',
      );

      expect(a.id, b.id);
      final messages = await repo.fetchTicketMessages(
        userId: 'u1',
        ticketId: ticket.id,
      );
      expect(
        messages.length,
        2,
        reason: 'ilk mesaj + idempotent devam mesajı kalmalı',
      );
    });

    test('mesaj modeli istemci kimliği ve sıra imlecini taşır', () {
      final message = FeedbackTicketMessage.fromMap({
        'id': 'm1',
        'ticket_id': 't1',
        'sender_id': 'u1',
        'sender_role': 'user',
        'message': 'Gövde',
        'created_at': '2026-07-30T02:00:00.000Z',
        'client_message_id': 'c1',
        'message_seq': 7,
      });
      expect(message.id, 'm1');
      expect(message.clientMessageId, 'c1');
      expect(message.messageSeq, 7);

      final supabaseSource = _readSource(
        'lib/data/repositories/supabase/supabase_admin_repository.dart',
      );
      expect(supabaseSource, contains(".order('message_seq')"));
      expect(supabaseSource, contains('message_seq'));
      expect(supabaseSource, contains('client_message_id'));
    });

    test('admin yanıtı ikinci bir duyuru olayı üretmez', () async {
      final sql = _readSource(
        '../supabase/migrations/0103_feedback_thread_single_truth.sql',
      );
      expect(sql, isNot(contains('insert into public.announcements')));

      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await _openTicket(repo);
      final before = (await repo.fetchAnnouncements()).length;
      await repo.sendTicketMessage(
        userId: 'admin',
        ticketId: ticket.id,
        message: 'Bakıyoruz.',
      );

      expect(
        (await repo.fetchAnnouncements()).length,
        before,
        reason: 'tek konuşma olayı tek okunmamış gerçeğine bırakılır',
      );
    });
  });

  group('WP-436 — watermark ve canlı konuşma', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'tek admin yanıtı tek rozet artırır ve konuşma görülünce söner',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
        addTearDown(repo.dispose);
        final ticket = await _openTicket(repo);
        await repo.sendTicketMessage(
          userId: 'admin',
          ticketId: ticket.id,
          message: 'Bakıyoruz.',
        );

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            authStateProvider.overrideWith(
              (ref) => Stream.value(
                Profile(
                  id: 'u1',
                  displayName: 'Ben',
                  createdAt: DateTime(2026),
                ),
              ),
            ),
            adminRepositoryProvider.overrideWithValue(repo),
            notificationRepositoryProvider.overrideWithValue(
              _FakeNotificationRepository([
                _adminReplyAnnouncement(ticket.id, 'u1'),
              ]),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.listen(authStateProvider, (_, _) {});
        await container.read(authStateProvider.future);
        await container.read(myAnnouncementsProvider.future);
        await container.read(readAnnouncementIdsProvider.future);
        await container.read(unreadFeedbackReplyCountProvider.future);

        expect(
          container.read(settingsBadgeCountProvider),
          1,
          reason: 'feedback duyurusu konuşma rozetiyle çift sayılmamalı',
        );

        // Yazışma görüldü: watermark tek kaynaktır, iki yüzey birlikte söner.
        await repo.markTicketMessagesRead(userId: 'u1', ticketId: ticket.id);
        container.invalidate(unreadFeedbackReplyCountProvider);
        await container.read(unreadFeedbackReplyCountProvider.future);

        expect(
          container.read(settingsBadgeCountProvider),
          0,
          reason: 'görülen konuşma sonrası rozet asılı kalmamalı',
        );
      },
    );

    testWidgets('yazışma açıkken gelen yeni yanıt ekrana düşer', (
      tester,
    ) async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await _openTicket(repo, subject: 'Canlılık bileti');
      await repo.sendTicketMessage(
        userId: 'u1',
        ticketId: ticket.id,
        message: 'İlk mesajım.',
      );

      await tester.pumpWidget(_wrapConversation(repo, 'u1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Canlılık bileti'));
      await tester.pumpAndSettle();
      expect(find.text('İlk mesajım.'), findsOneWidget);

      // Pencere açıkken admin yanıt yazıyor.
      await repo.sendTicketMessage(
        userId: 'admin',
        ticketId: ticket.id,
        message: 'Canlı yanıt.',
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      expect(
        find.text('Canlı yanıt.'),
        findsOneWidget,
        reason: 'realtime akışı yeni yanıtı açık konuşmaya eklemeli',
      );

      // Akış yenilense de doğru ticket dizisi korunur.
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Canlılık bileti'));
      await tester.pumpAndSettle();
      expect(find.text('Canlı yanıt.'), findsOneWidget);
    });
  });
}
