// WP-421: okunmamış yanıt / yeni başarım rozetinin zinciri ve gecikmesi.
//
// Sahip: "profil + ayarlarda kırmızı ya da başka nokta yoktu, kendim girip
// gördüm, sadece bildirim geliyor." Yani rozet **hiç yoktu**; tek sinyal
// push'tu. Başarımlarda da rozet ~2 dk sonra düşüyordu.
//
// Zincir: Profil → Ayarlar → Geri bildirim → bilet. Her halka aynı kaynağı
// (`unreadFeedbackReplyCountProvider`) okur; halka koparsa bu testler kırmızı
// düşer.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/notification_preferences.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/features/profile/feedback_screen.dart';
import 'package:online_study_room/features/profile/settings_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yönetici yanıtı gelmiş, kullanıcının henüz okumadığı bir bilet üretir.
Future<InMemoryAdminRepository> _repoWithUnreadReply() async {
  final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
  final ticket = await repo.submitFeedback(
    userId: 'u1',
    kind: FeedbackTicketKind.bug,
    subject: 'Sayaç durmuyor',
    message: 'Gövde.',
  );
  await repo.sendTicketMessage(
    userId: 'admin',
    ticketId: ticket.id,
    message: 'Bakıyoruz.',
  );
  return repo;
}

Widget _wrap(InMemoryAdminRepository repo, SharedPreferences prefs, Widget home) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          Profile(id: 'u1', displayName: 'Ben', createdAt: DateTime(2026)),
        ),
      ),
      adminRepositoryProvider.overrideWithValue(repo),
      notificationPreferencesProvider.overrideWith(
        () => NotificationPreferencesNotifier(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

String _read(String path) =>
    File(path).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('unreadFeedbackReplyCountProvider', () {
    test('yalnız kendi biletindeki okunmamış yönetici yanıtını sayar', () async {
      final repo = await _repoWithUnreadReply();
      addTearDown(repo.dispose);
      // Başkasının bileti sayıya girmemeli.
      final other = await repo.submitFeedback(
        userId: 'u2',
        kind: FeedbackTicketKind.feedback,
        subject: 'Başkasının bileti',
        message: 'Gövde.',
      );
      await repo.sendTicketMessage(
        userId: 'admin',
        ticketId: other.id,
        message: 'Ona da bakıyoruz.',
      );

      expect(await repo.fetchUnreadTicketReplyCount('u1'), 1);
      expect(await repo.fetchUnreadTicketReplyCount('u2'), 1);
    });

    test('kullanıcının kendi mesajı okunmamış sayılmaz', () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.feedback,
        subject: 'Kendi mesajım',
        message: 'Gövde.',
      );
      await repo.sendTicketMessage(
        userId: 'u1',
        ticketId: ticket.id,
        message: 'Ek bilgi.',
      );

      expect(await repo.fetchUnreadTicketReplyCount('u1'), 0);
    });

    test('okundu işaretlenince sıfırlanır', () async {
      final repo = await _repoWithUnreadReply();
      addTearDown(repo.dispose);
      final tickets = await repo.fetchMyFeedbackTickets('u1');
      await repo.markTicketMessagesRead(
        userId: 'u1',
        ticketId: tickets.single.id,
      );

      expect(await repo.fetchUnreadTicketReplyCount('u1'), 0);
    });

    test('sağlayıcı auto-dispose değil — dinleyicisiz de tek kez okur', () async {
      // 🔴 Riverpod 3 tuzağı: `autoDispose` bir sağlayıcı dinleyicisiz her
      // `read`'de yeniden kurulur. Rozet o hâlde her karede yeniden yüklenir
      // (yanıp söner) ve regresyon testi sessizce etkisizleşir.
      final repo = _CountingAdminRepository(await _repoWithUnreadReply());
      addTearDown(repo.inner.dispose);
      final container = ProviderContainer(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              Profile(id: 'u1', displayName: 'Ben', createdAt: DateTime(2026)),
            ),
          ),
          adminRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);
      // Oturum akışı çözülmeden profil null olur ve sayaç 0 döner; bu testin
      // konusu o değil.
      container.listen(authStateProvider, (_, _) {});
      await container.read(authStateProvider.future);

      expect(await container.read(unreadFeedbackReplyCountProvider.future), 1);
      // Dinleyici yok; yine de sonuç önbellekte kalmalı.
      expect(await container.read(unreadFeedbackReplyCountProvider.future), 1);
      expect(
        repo.unreadCalls,
        1,
        reason: 'sağlayıcı her okumada yeniden kuruldu (auto-dispose tuzağı)',
      );
    });
  });

  group('zincir yüzeyleri', () {
    testWidgets('Ayarlar → Geri bildirim satırında renkli rozet çıkar', (
      tester,
    ) async {
      final repo = await _repoWithUnreadReply();
      addTearDown(repo.dispose);
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap(repo, prefs, const SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('feedback-row-reply-badge')), findsOneWidget);
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('Geri bildirim ekranında sekme rozeti çıkar ve okununca söner', (
      tester,
    ) async {
      final repo = await _repoWithUnreadReply();
      addTearDown(repo.dispose);
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_wrap(repo, prefs, const FeedbackScreen()));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('feedback-tab-reply-badge')), findsOneWidget);

      // Bileti aç → yazışma okundu işaretlenir → zincir temizlenir.
      await tester.tap(find.byKey(const Key('feedback-tab-tickets')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sayaç durmuyor'));
      await tester.pumpAndSettle();
      expect(find.text('Bakıyoruz.'), findsOneWidget);

      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('feedback-tab-reply-badge')), findsNothing);
      expect(await repo.fetchUnreadTicketReplyCount('u1'), 0);
    });
  });

  group('zincir kaynak sözleşmesi', () {
    // 🔴 Her halka aynı sağlayıcıyı okumalı. Biri kendi sayacını türetirse
    // "okundu" işaretlemesi yüzeyler arasında ayrışır ve rozet asla sönmez.
    test('üç yüzey de unreadFeedbackReplyCountProvider okur', () {
      final surfaces = {
        'Profil → Ayarlar satırı': 'lib/features/profile/profile_screen.dart',
        'Ayarlar → Geri bildirim satırı':
            'lib/features/profile/settings_screen.dart',
        'Geri bildirim → sekme': 'lib/features/profile/feedback_screen.dart',
      };
      surfaces.forEach((name, path) {
        expect(
          _read(path).contains('unreadFeedbackReplyCountProvider'),
          isTrue,
          reason: '$name artık tek kaynağı okumuyor ($path)',
        );
      });
    });

    test('okundu işaretlemesi zinciri geçersiz kılar', () {
      final source = _read('lib/features/profile/feedback_tickets_screen.dart');
      expect(source, contains('markTicketMessagesRead'));
      expect(
        source,
        contains('ref.invalidate(unreadFeedbackReplyCountProvider)'),
        reason: 'okundu sonrası üst seviyeler tazelenmiyor, rozet asılı kalır',
      );
    });

    test('başarım ekranı açılışta önbelleği tazeler', () {
      // ~2 dakikalık gecikmenin kaynağı push değil önbellekti.
      final source = _read('lib/features/profile/social_profile_screen.dart');
      expect(source, contains('void initState()'));
      expect(
        source,
        contains('ref.invalidate(pendingAchievementRewardSummaryProvider)'),
      );
    });

    test('rozet zinciri push servisine bağlı değil', () {
      // Rozet push ile **aynı olaydan** beslenir ama onu beklemez: çevrimdışı
      // açılışta da sunucu satırından okunur.
      for (final path in const [
        'lib/features/profile/settings_screen.dart',
        'lib/features/profile/feedback_screen.dart',
        'lib/data/providers/admin_providers.dart',
      ]) {
        expect(
          _read(path).contains('push_notification'),
          isFalse,
          reason: '$path rozeti push servisinden türetiyor',
        );
      }
    });
  });
}

/// `fetchUnreadTicketReplyCount` çağrılarını sayan ince sarmalayıcı.
class _CountingAdminRepository extends InMemoryAdminRepository {
  _CountingAdminRepository(this.inner);

  final InMemoryAdminRepository inner;
  int unreadCalls = 0;

  @override
  Future<int> fetchUnreadTicketReplyCount(String userId) {
    unreadCalls++;
    return inner.fetchUnreadTicketReplyCount(userId);
  }
}
