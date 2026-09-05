// WP-784 — KULLANICI da destek yazismasinda tek foto gonderebilir.
//
// Sunucu bunu `0138`den beri kabul ediyordu (`send_feedback_ticket_message`
// `p_attachment_path` alir), yonetici ucu de gonderiyordu; eksik olan tek sey
// KULLANICININ ucuydu. Yani "bitmis backend, baglanmamis UI" halinin ta
// kendisi: kullanici, yoneticinin gonderdigi fotografa foto ile cevap
// veremiyordu.
//
// Bu dosya dikisi uc yerden birden olcer:
//
//   1. **Depo davranisi** (bellek ici) — bayt + uzanti gercekten tasiniyor mu,
//      yol sunucunun bekledigi `<uid>/<uuid>.<ext>` bicimini mi tutuyor.
//   2. **Gercek Supabase uygulamasi** (kablo) — yukleme dusunce mesaj RPC'si
//      HIC gitmiyor mu (kullanici onizlemede gordugu fotografi gonderdigini
//      sanmamali), ve eksiz gonderim eskisi gibi calisiyor mu.
//   3. **Ekran** — atac dugmesi -> onizleme -> gonderim zinciri; basarisiz
//      gonderimde fotografin kaybolmamasi.
//
// 🔴 `find.byType(X)` bos bir kabukla da eslesir; bu yuzden her ekran iddiasi
// ya cizilen ONIZLEMEYI ya da depoya ULASAN baytlari olcer.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/feedback_ticket_message.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_admin_repository.dart';
import 'package:online_study_room/features/profile/feedback_tickets_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../support/supabase_wire_harness.dart';

const _user = 'u1';

/// 1x1 saydam PNG — gercek goruntu bayti.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQ'
  'DwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Ilk gonderimi reddeden depo: fotografin bekleyen kayitta kalmasini ve
/// yeniden denemede yine gitmesini kanitlar.
class _FlakyRepository extends InMemoryAdminRepository {
  _FlakyRepository() : super(superAdminUserIds: const {});

  int failures = 0;

  @override
  Future<FeedbackTicketMessage> sendTicketMessage({
    required String userId,
    required String ticketId,
    required String message,
    String? clientMessageId,
    Uint8List? attachmentBytes,
    String? attachmentExt,
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
      attachmentBytes: attachmentBytes,
      attachmentExt: attachmentExt,
    );
  }
}

Future<FeedbackTicket> _seedTicket(InMemoryAdminRepository repo) {
  return repo.submitFeedback(
    userId: _user,
    kind: FeedbackTicketKind.bug,
    subject: 'Foto denemesi',
    message: 'İlk mesaj.',
  );
}

/// Ekran kosumu: gercek yazisma govdesi, sahte galeri.
Widget _app(
  InMemoryAdminRepository repo,
  FeedbackTicket ticket, {
  FeedbackReplyPhoto? picked,
}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          Profile(id: _user, displayName: _user, createdAt: DateTime(2026)),
        ),
      ),
      adminRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: FeedbackTicketConversationView(
          ticket: ticket,
          photoPicker: (_) async => picked,
        ),
      ),
    ),
  );
}

/// Ekranda gorunen tek bekleyen/gonderilmis fotografin depodaki yolu.
String _onlyAttachmentPath(InMemoryAdminRepository repo) {
  final paths = repo.ticketMessageAttachments.keys.toList();
  expect(paths, hasLength(1));
  return paths.single;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bellek ici veri yolu', () {
    test('kullanicinin ekli mesaji bayt + uzantiyi depoya tasir', () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: const {});
      addTearDown(repo.dispose);
      final ticket = await _seedTicket(repo);

      final sent = await repo.sendTicketMessage(
        userId: _user,
        ticketId: ticket.id,
        message: 'ekli yanit',
        attachmentBytes: _png,
        attachmentExt: 'png',
      );

      // 1) Sunucunun bekledigi yol bicimi: `<uid>/<uuid>.<ext>`
      //    (`assert_ticket_message_attachment_allowed` ilk klasoru
      //    `auth.uid()` ile karsilastirir).
      final path = sent.attachmentPath;
      expect(path, isNotNull);
      expect(path!.split('/').first, _user);
      expect(path.endsWith('.png'), isTrue);

      // 2) Yol GERI OKUNAN satirda da duruyor.
      final history = await repo.fetchTicketMessages(
        userId: _user,
        ticketId: ticket.id,
      );
      expect(history.last.attachmentPath, path);

      // 3) Baytlar gercekten yuklendi ve yol imzalanabiliyor.
      expect(repo.ticketMessageAttachments[path], _png);
      expect(await repo.getTicketMessageAttachmentUrl(path), isNotNull);
    });

    test('fotosuz gonderim davranisi degismez', () async {
      final repo = InMemoryAdminRepository(superAdminUserIds: const {});
      addTearDown(repo.dispose);
      final ticket = await _seedTicket(repo);

      final sent = await repo.sendTicketMessage(
        userId: _user,
        ticketId: ticket.id,
        message: 'eksiz yanit',
      );

      expect(sent.attachmentPath, isNull);
      expect(repo.ticketMessageAttachments, isEmpty);
    });
  });

  group('gercek Supabase uygulamasi (kablo)', () {
    late SupabaseWireHarness wire;
    setUp(() => wire = SupabaseWireHarness());

    // 🔴 Kartin cekirdegi: ek dusup mesaj gitseydi kullanici, onizlemede
    // gordugu fotografi gonderdigini sanirdi. Kosumda oturum yok, yani
    // `uploadReportAttachment` yolu uretemez — yukleme dusmus sayilir.
    test('yukleme dusunce mesaj RPC\'si HIC gitmez', () async {
      final repo = SupabaseAdminRepository(wire.client());

      await expectLater(
        repo.sendTicketMessage(
          userId: _user,
          ticketId: 't1',
          message: 'ekli yanit',
          attachmentBytes: _png,
          attachmentExt: 'png',
        ),
        throwsA(isA<AdminException>()),
      );

      expect(
        wire.calls.where((c) => c.rpcName == 'send_feedback_ticket_message'),
        isEmpty,
        reason: 'ek yuklenemediyse mesaj da gonderilmemeli',
      );
    });

    test('fotosuz gonderim ayni RPC ve parametrelerle gider', () async {
      wire.respond('send_feedback_ticket_message', {
        'id': 'm1',
        'ticket_id': 't1',
        'sender_id': _user,
        'sender_role': 'user',
        'message': 'eksiz yanit',
        'created_at': '2026-09-05T10:00:00Z',
        'message_seq': 2,
        'client_message_id': 'cmd-1',
        'attachment_path': null,
      });
      final repo = SupabaseAdminRepository(wire.client());

      final sent = await repo.sendTicketMessage(
        userId: _user,
        ticketId: 't1',
        message: '  eksiz yanit  ',
        clientMessageId: 'cmd-1',
      );

      final json = wire.rpc('send_feedback_ticket_message').json;
      expect(json['p_ticket_id'], 't1');
      expect(json['p_message'], 'eksiz yanit');
      expect(json['p_client_message_id'], 'cmd-1');
      // 🔴 Yalniz `isNull` demek yetmez: eksik anahtar da `null` okunur.
      // Sunucunun `0138`deki ad ile eslesmesi ayrica olculur.
      expect(json.containsKey('p_attachment_path'), isTrue);
      expect(json['p_attachment_path'], isNull);
      expect(sent.attachmentPath, isNull);
    });
  });

  group('ekran', () {
    testWidgets('foto secilince onizleme cizilir, atac dugmesi cekilir', (
      tester,
    ) async {
      final repo = InMemoryAdminRepository(superAdminUserIds: const {});
      addTearDown(repo.dispose);
      final ticket = await _seedTicket(repo);

      await tester.pumpWidget(
        _app(
          repo,
          ticket,
          picked: FeedbackReplyPhoto(bytes: _png, ext: 'png'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(kFeedbackReplyPhotoPreviewKey), findsNothing);
      await tester.tap(find.byKey(kFeedbackReplyAttachKey));
      await tester.pumpAndSettle();

      // Onizlemenin gercekten SECILEN baytlari cizdigi olculur; bos bir kutu
      // da anahtari tasiyabilirdi.
      final preview = tester.widget<Container>(
        find.byKey(kFeedbackReplyPhotoPreviewKey),
      );
      final image =
          (preview.decoration! as BoxDecoration).image!.image as MemoryImage;
      expect(image.bytes, _png);

      // Tek adet: atac dugmesi yerini kaldir dugmesine birakir.
      expect(find.byKey(kFeedbackReplyAttachKey), findsNothing);
      expect(find.byKey(kFeedbackReplyPhotoRemoveKey), findsOneWidget);

      await tester.tap(find.byKey(kFeedbackReplyPhotoRemoveKey));
      await tester.pumpAndSettle();
      expect(find.byKey(kFeedbackReplyPhotoPreviewKey), findsNothing);
      expect(find.byKey(kFeedbackReplyAttachKey), findsOneWidget);
    });

    testWidgets('gonderilen fotograf depoya ulasir ve balonda cizilir', (
      tester,
    ) async {
      final repo = InMemoryAdminRepository(superAdminUserIds: const {});
      addTearDown(repo.dispose);
      final ticket = await _seedTicket(repo);

      await tester.pumpWidget(
        _app(
          repo,
          ticket,
          picked: FeedbackReplyPhoto(bytes: _png, ext: 'png'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(kFeedbackReplyAttachKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Ekran görüntüsü.');
      await tester.tap(find.byKey(const Key('feedback-send-reply')));
      await tester.pumpAndSettle();

      // 1) Bayt + uzanti gercekten depoya gecti.
      final path = _onlyAttachmentPath(repo);
      expect(repo.ticketMessageAttachments[path], _png);
      expect(path.endsWith('.png'), isTrue);

      // 2) Gonderilen satir o yolu tasiyor ve balon fotografi ciziyor.
      final history = await repo.fetchTicketMessages(
        userId: _user,
        ticketId: ticket.id,
      );
      expect(history.last.attachmentPath, path);
      expect(find.byKey(ValueKey(path)), findsOneWidget);

      // 3) Serit temizlendi: ayni foto ikinci kez gonderilmez.
      expect(find.byKey(kFeedbackReplyPhotoPreviewKey), findsNothing);
    });

    testWidgets('fotosuz gonderim ek uretmez', (tester) async {
      final repo = InMemoryAdminRepository(superAdminUserIds: const {});
      addTearDown(repo.dispose);
      final ticket = await _seedTicket(repo);

      await tester.pumpWidget(_app(repo, ticket));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Sadece metin.');
      await tester.tap(find.byKey(const Key('feedback-send-reply')));
      await tester.pumpAndSettle();

      expect(find.text('Sadece metin.'), findsOneWidget);
      expect(repo.ticketMessageAttachments, isEmpty);
      final history = await repo.fetchTicketMessages(
        userId: _user,
        ticketId: ticket.id,
      );
      expect(history.last.attachmentPath, isNull);
    });

    testWidgets('gonderim dusunce fotograf kaybolmaz, yeniden denemede gider', (
      tester,
    ) async {
      final repo = _FlakyRepository();
      addTearDown(repo.dispose);
      final ticket = await _seedTicket(repo);
      repo.failures = 1;

      await tester.pumpWidget(
        _app(
          repo,
          ticket,
          picked: FeedbackReplyPhoto(bytes: _png, ext: 'png'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(kFeedbackReplyAttachKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Yeniden denenecek.');
      await tester.tap(find.byKey(const Key('feedback-send-reply')));
      await tester.pumpAndSettle();

      // Gonderim dustu: hicbir sey yuklenmedi ama foto bekleyen kayitta
      // duruyor ve kullaniciya cizilmeye devam ediyor.
      expect(repo.ticketMessageAttachments, isEmpty);
      expect(find.text('Gönderilemedi. Yeniden denemek için dokun.'),
          findsOneWidget);
      final pendingPhoto = tester.widget<Image>(
        find.byKey(const Key('feedback-pending-photo')),
      );
      expect((pendingPhoto.image as MemoryImage).bytes, _png);

      // Balona dokunmak ayni komut kimligiyle yeniden dener; foto da gider.
      await tester.tap(find.text('Yeniden denenecek.'));
      await tester.pumpAndSettle();

      final path = _onlyAttachmentPath(repo);
      expect(repo.ticketMessageAttachments[path], _png);
      final history = await repo.fetchTicketMessages(
        userId: _user,
        ticketId: ticket.id,
      );
      expect(history.last.attachmentPath, path);
    });
  });
}
