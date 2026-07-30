import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/features/profile/feedback_tickets_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-438 — Feedback zincirinin kapanis kapisi.
///
/// Kabul matrisi tek yerde kosulur: kullanici→admin→kullanici 20 tur, iki bilet
/// esz amanli, iki cihaz, reconnect/relogin, duplicate retry, archive/reopen,
/// ek dosya ve profil/ayarlar rozeti. Dort sifir kilitlenir: yanlis thread 0,
/// kayip mesaj 0, sahte gonderildi 0, okunduktan sonra kalan rozet 0.

ProviderContainer _device(InMemoryAdminRepository repo, {String userId = 'u1'}) {
  final container = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          Profile(
            id: userId,
            displayName: 'Kullanıcı',
            createdAt: DateTime(2026),
          ),
        ),
      ),
      adminRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Future<int> _badge(ProviderContainer container) async {
  // Riverpod 3 tuzagi: dinleyicisiz provider her okumada yeniden kurulur ve
  // rozet regresyonu sessizce etkisizlesir.
  container.listen(settingsBadgeCountProvider, (_, _) {});
  await container.read(unreadFeedbackReplyCountProvider.future);
  return container.read(settingsBadgeCountProvider);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('WP-438 — konusma butunlugu', () {
    test('kullanici→admin→kullanici 20 tur: sira, kimlik ve thread korunur',
        () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.bug,
        subject: 'Yirmi tur',
        message: 'Açılış mesajı.',
      );

      for (var round = 1; round <= 20; round++) {
        await repo.sendTicketMessage(
          userId: 'admin',
          ticketId: ticket.id,
          message: 'admin-$round',
        );
        await repo.sendTicketMessage(
          userId: 'u1',
          ticketId: ticket.id,
          message: 'user-$round',
        );
      }

      final messages = await repo.fetchTicketMessages(
        userId: 'u1',
        ticketId: ticket.id,
      );
      expect(messages.length, 41, reason: 'kayıp mesaj 0');
      expect(
        messages.every((message) => message.ticketId == ticket.id),
        isTrue,
        reason: 'yanlış thread 0',
      );
      expect(
        messages.map((message) => message.messageSeq).toList(),
        List<int>.generate(41, (index) => index + 1),
        reason: 'sıra imleci boşluksuz ve artan olmalı',
      );
      expect(
        messages.map((message) => message.id).toSet().length,
        41,
        reason: 'her mesajın tek kimliği var',
      );
      expect(messages.last.message, 'user-20');
    });

    test('iki bilet eszamanli yazisirken mesaj karsi bilete dusmez', () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final first = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.bug,
        subject: 'Birinci',
        message: 'Birinci açılış.',
      );
      final second = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.feedback,
        subject: 'İkinci',
        message: 'İkinci açılış.',
      );

      for (var round = 1; round <= 5; round++) {
        await repo.sendTicketMessage(
          userId: 'admin',
          ticketId: first.id,
          message: 'birinci-$round',
        );
        await repo.sendTicketMessage(
          userId: 'admin',
          ticketId: second.id,
          message: 'ikinci-$round',
        );
      }

      final firstMessages = await repo.fetchTicketMessages(
        userId: 'u1',
        ticketId: first.id,
      );
      final secondMessages = await repo.fetchTicketMessages(
        userId: 'u1',
        ticketId: second.id,
      );
      expect(
        firstMessages.every((m) => m.message.startsWith('birinci') ||
            m.message == 'Birinci açılış.'),
        isTrue,
      );
      expect(
        secondMessages.every((m) => m.message.startsWith('ikinci') ||
            m.message == 'İkinci açılış.'),
        isTrue,
      );
      expect(
        firstMessages.map((m) => m.messageSeq).toList(),
        [1, 2, 3, 4, 5, 6],
        reason: 'sıra imleci bilet başına bağımsız ilerler',
      );
    });

    test('ayni komut kimligiyle yeniden deneme tek satir birakir', () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.bug,
        subject: 'Duplicate',
        message: 'Açılış.',
      );

      final first = await repo.sendTicketMessage(
        userId: 'u1',
        ticketId: ticket.id,
        message: 'Tek kalmalı.',
        clientMessageId: 'cmd-1',
      );
      final retry = await repo.sendTicketMessage(
        userId: 'u1',
        ticketId: ticket.id,
        message: 'Tek kalmalı.',
        clientMessageId: 'cmd-1',
      );

      expect(retry.id, first.id, reason: 'sahte gönderildi 0');
      final messages = await repo.fetchTicketMessages(
        userId: 'u1',
        ticketId: ticket.id,
      );
      expect(messages.where((m) => m.message == 'Tek kalmalı.').length, 1);
    });
  });

  group('WP-438 — okunmamis gercegi', () {
    test('ikinci cihazda okunan konusma ilk cihazin rozetini de sondurur',
        () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.bug,
        subject: 'İki cihaz',
        message: 'Açılış.',
      );
      await repo.sendTicketMessage(
        userId: 'admin',
        ticketId: ticket.id,
        message: 'Yanıt.',
      );

      final phone = _device(repo);
      final desktop = _device(repo);
      expect(await _badge(phone), 1);
      expect(await _badge(desktop), 1);

      // Masaüstünde konuşma görüldü.
      await repo.markTicketMessagesRead(userId: 'u1', ticketId: ticket.id);
      desktop.invalidate(unreadFeedbackReplyCountProvider);
      phone.invalidate(unreadFeedbackReplyCountProvider);

      expect(await _badge(desktop), 0);
      expect(
        await _badge(phone),
        0,
        reason: 'okundu gerçeği sunucuda; ikinci cihazda geri gelmez',
      );
    });

    test('relogin/reconnect sonrasi okundu durumu ve sira geri donmez',
        () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.bug,
        subject: 'Relogin',
        message: 'Açılış.',
      );
      await repo.sendTicketMessage(
        userId: 'admin',
        ticketId: ticket.id,
        message: 'Yanıt.',
      );
      await repo.markTicketMessagesRead(userId: 'u1', ticketId: ticket.id);

      final before = await repo.fetchTicketMessages(
        userId: 'u1',
        ticketId: ticket.id,
      );
      final fresh = _device(repo);
      expect(await _badge(fresh), 0, reason: 'okunduktan sonra kalan rozet 0');

      final after = await repo.fetchTicketMessages(
        userId: 'u1',
        ticketId: ticket.id,
      );
      expect(
        after.map((m) => m.id).toList(),
        before.map((m) => m.id).toList(),
        reason: 'yeniden bağlanma sırayı ve kimlikleri değiştirmez',
      );
    });

    test('kullanicinin kendi mesaji okunmamis uretmez', () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.feedback,
        subject: 'Kendi mesajım',
        message: 'Açılış.',
      );
      await repo.sendTicketMessage(
        userId: 'u1',
        ticketId: ticket.id,
        message: 'Kendi devamım.',
      );

      expect(await repo.fetchUnreadTicketReplyCount('u1'), 0);
      final summaries = await repo.fetchMyTicketThreadSummaries('u1');
      expect(summaries.single.unreadCount, 0);
      expect(summaries.single.lastMessage, 'Kendi devamım.');
    });

    test('arsivleme ve geri acma okunmus rozeti diriltmez', () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.bug,
        subject: 'Arşiv',
        message: 'Açılış.',
      );
      await repo.sendTicketMessage(
        userId: 'admin',
        ticketId: ticket.id,
        message: 'Yanıt.',
      );
      await repo.markTicketMessagesRead(userId: 'u1', ticketId: ticket.id);

      await repo.setFeedbackArchived(
        userId: 'admin',
        ticketId: ticket.id,
        archived: true,
      );
      expect(await repo.fetchUnreadTicketReplyCount('u1'), 0);

      await repo.setFeedbackArchived(
        userId: 'admin',
        ticketId: ticket.id,
        archived: false,
      );
      expect(await repo.fetchUnreadTicketReplyCount('u1'), 0);
      final messages = await repo.fetchTicketMessages(
        userId: 'u1',
        ticketId: ticket.id,
      );
      expect(messages.length, 2, reason: 'arşiv turu mesaj kaybettirmez');
    });

    test('ek dosyali bilet konusmayi bozmaz', () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.bug,
        subject: 'Ekli bilet',
        message: 'Ekran görüntüsü ekledim.',
        attachmentBytes: Uint8List.fromList(const [1, 2, 3]),
        attachmentExt: 'png',
      );

      expect(ticket.attachmentPath, isNotNull);
      final summaries = await repo.fetchMyTicketThreadSummaries('u1');
      expect(summaries.single.ticket.attachmentPath, isNotNull);
      expect(summaries.single.lastMessage, 'Ekran görüntüsü ekledim.');
      expect(summaries.single.messageCount, 1);
    });
  });

  testWidgets(
    'WP-438 — kapanis: yazismayi gorunce liste ve ayarlar rozeti birlikte soner',
    (tester) async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.bug,
        subject: 'Kapanış kapısı',
        message: 'Açılış.',
      );
      await repo.sendTicketMessage(
        userId: 'admin',
        ticketId: ticket.id,
        message: 'Yönetim yanıtı.',
      );

      expect(await repo.fetchUnreadTicketReplyCount('u1'), 1);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authStateProvider.overrideWith(
              (ref) => Stream.value(
                Profile(
                  id: 'u1',
                  displayName: 'Kullanıcı',
                  createdAt: DateTime(2026),
                ),
              ),
            ),
            adminRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            locale: Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FeedbackTicketsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(Key('feedback-ticket-unread-${ticket.id}')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(Key('feedback-ticket-${ticket.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Yönetim yanıtı.'), findsOneWidget);
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();

      // Rozet zincirinin saglayici ayagi saf Dart testlerinde olculur; duyuru
      // ayagini canli tutan konteyner widget agacina baglanirsa periyodik
      // zamanlayicilar `pumpAndSettle`'i hic bitirmez.
      expect(
        await repo.fetchUnreadTicketReplyCount('u1'),
        0,
        reason: 'okunduktan sonra kalan rozet 0',
      );
      expect(
        find.byKey(Key('feedback-ticket-unread-${ticket.id}')),
        findsNothing,
      );
      expect(
        (await repo.fetchTicketMessages(userId: 'u1', ticketId: ticket.id))
            .length,
        2,
        reason: 'kayıp mesaj 0',
      );
    },
  );
}
