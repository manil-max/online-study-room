import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/feedback_ticket_message.dart';
import 'package:online_study_room/data/models/feedback_ticket_thread_summary.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/features/profile/feedback_tickets_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Ilk `failures` gonderimi reddeden depo: basarisiz mesajin kaybolmadigini ve
/// ayni komut kimligiyle yeniden denendigini kanitlar.
class _FlakySendRepository extends InMemoryAdminRepository {
  _FlakySendRepository({required super.superAdminUserIds});

  int failures = 0;

  @override
  Future<FeedbackTicketMessage> sendTicketMessage({
    required String userId,
    required String ticketId,
    required String message,
    String? clientMessageId,
  }) async {
    if (failures > 0) {
      failures -= 1;
      throw const AdminException('Ağ hatası.');
    }
    return super.sendTicketMessage(
      userId: userId,
      ticketId: ticketId,
      message: message,
      clientMessageId: clientMessageId,
    );
  }
}

/// Akisin yanlis bilete ait satirlar tasidigi durumu taklit eder.
class _CrossTalkRepository extends InMemoryAdminRepository {
  _CrossTalkRepository({required super.superAdminUserIds});

  @override
  Stream<List<FeedbackTicketMessage>> watchTicketMessages({
    required String userId,
    required String ticketId,
  }) async* {
    final rows = <FeedbackTicketMessage>[];
    for (final id in _knownTicketIds) {
      rows.addAll(await fetchTicketMessages(userId: userId, ticketId: id));
    }
    yield rows;
  }

  final List<String> _knownTicketIds = [];

  void register(String ticketId) => _knownTicketIds.add(ticketId);
}

/// Liste yuklemesi patlayan depo: hata + yeniden dene yolu icin.
class _FailingSummaryRepository extends InMemoryAdminRepository {
  _FailingSummaryRepository() : super(superAdminUserIds: const {});

  bool fail = true;

  @override
  Future<List<FeedbackTicketThreadSummary>> fetchMyTicketThreadSummaries(
    String userId,
  ) async {
    if (fail) throw const AdminException('Bağlantı yok.');
    return super.fetchMyTicketThreadSummaries(userId);
  }
}

Widget _app(InMemoryAdminRepository repo, {Widget? home}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          Profile(id: 'u1', displayName: 'Kullanıcı', createdAt: DateTime(2026)),
        ),
      ),
      adminRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home ?? const FeedbackTicketsScreen(),
    ),
  );
}

void main() {
  group('WP-437 — bilet listesi konusmanin son halini gosterir', () {
    testWidgets('satirda son mesaj, durum ve okunmamis rozeti vardir', (
      tester,
    ) async {
      final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.bug,
        subject: 'Bildirim sorunu',
        message: 'Durdur aksiyonu çalışmıyor.',
      );
      await repo.sendTicketMessage(
        userId: 'admin',
        ticketId: ticket.id,
        message: 'İnceliyoruz, sürüm bilgisi paylaşır mısın?',
      );

      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('İnceliyoruz, sürüm bilgisi paylaşır mısın?'),
        findsOneWidget,
        reason: 'liste satırı ilk mesajda donmamalı',
      );
      expect(find.text('İnceleniyor'), findsOneWidget);
      expect(
        find.byKey(Key('feedback-ticket-unread-${ticket.id}')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(Key('feedback-ticket-${ticket.id}')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(Key('feedback-conversation-${ticket.id}')),
        findsOneWidget,
      );
      await tester.tap(find.text('Kapat'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(Key('feedback-ticket-unread-${ticket.id}')),
        findsNothing,
        reason: 'konuşma görülünce satır rozeti de sönmeli',
      );
    });

    testWidgets('liste hatasi yeniden dene yolu birakir', (tester) async {
      final repo = _FailingSummaryRepository();
      addTearDown(repo.dispose);

      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('feedback-tickets-retry')), findsOneWidget);

      repo.fail = false;
      await tester.tap(find.byKey(const Key('feedback-tickets-retry')));
      await tester.pumpAndSettle();

      expect(find.text('Henüz geri bildirimin yok.'), findsOneWidget);
    });
  });

  group('WP-437 — konusma baglami ve gonderim durumu', () {
    testWidgets('baska biletin mesaji acik konusmaya cizilemez', (
      tester,
    ) async {
      final repo = _CrossTalkRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final mine = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.feedback,
        subject: 'Kendi biletim',
        message: 'Kendi ilk mesajım.',
      );
      final other = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.feedback,
        subject: 'Diğer bilet',
        message: 'Diğer biletin ilk mesajı.',
      );
      repo
        ..register(mine.id)
        ..register(other.id);

      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('feedback-ticket-${mine.id}')));
      await tester.pumpAndSettle();

      expect(find.text('Kendi ilk mesajım.'), findsOneWidget);
      expect(
        find.text('Diğer biletin ilk mesajı.'),
        findsNothing,
        reason: 'thread bağlamı sabittir; yabancı satır çizilmemeli',
      );
    });

    testWidgets('basarisiz mesaj kaybolmaz ve tek kopya olarak yeniden gider', (
      tester,
    ) async {
      final repo = _FlakySendRepository(superAdminUserIds: {'admin'});
      addTearDown(repo.dispose);
      final ticket = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.bug,
        subject: 'Çevrimdışı deneme',
        message: 'İlk mesaj.',
      );

      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('feedback-ticket-${ticket.id}')));
      await tester.pumpAndSettle();

      repo.failures = 1;
      await tester.enterText(find.byType(TextField), 'Ek ayrıntı gönderdim.');
      await tester.tap(find.byKey(const Key('feedback-send-reply')));
      await tester.pumpAndSettle();

      expect(find.text('Ek ayrıntı gönderdim.'), findsOneWidget);
      expect(
        find.text('Gönderilemedi. Yeniden denemek için dokun.'),
        findsOneWidget,
        reason: 'başarısız mesaj sahte gönderildi görünmemeli',
      );
      expect(
        (await repo.fetchTicketMessages(
          userId: 'u1',
          ticketId: ticket.id,
        )).length,
        1,
      );

      await tester.tap(find.text('Ek ayrıntı gönderdim.'));
      await tester.pumpAndSettle();

      final stored = await repo.fetchTicketMessages(
        userId: 'u1',
        ticketId: ticket.id,
      );
      expect(stored.length, 2, reason: 'yeniden deneme tek satır üretmeli');
      expect(stored.last.message, 'Ek ayrıntı gönderdim.');
      expect(find.text('Gönderilemedi. Yeniden denemek için dokun.'), findsNothing);
    });
  });

  testWidgets('uzun metin, kucuk ekran ve buyuk yazi olcusunde tasma yok', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = InMemoryAdminRepository(superAdminUserIds: {'admin'});
    addTearDown(repo.dispose);
    final longText = List.filled(
      30,
      'çok uzun bir geri bildirim metni',
    ).join(' ');
    final longSubject = List.filled(3, 'çok uzun konu başlığı').join(' ');
    final ticket = await repo.submitFeedback(
      userId: 'u1',
      kind: FeedbackTicketKind.feedback,
      subject: longSubject,
      message: longText,
    );
    await repo.sendTicketMessage(
      userId: 'admin',
      ticketId: ticket.id,
      message: longText,
    );

    await tester.pumpWidget(
      _app(
        repo,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: const FeedbackTicketsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(Key('feedback-ticket-${ticket.id}')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
