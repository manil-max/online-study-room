// WP-778 — vakada IKI TARAFLA ayri yazisma + mesaja tek fotograf.
//
// Sahip: *"yanit ve geri bildirim kismi yenilensin. iki taraflara ayri chat
// sohbeti olsun, direkt gecmis konusmalarida gorebileyim ben sormak istersem
// diye. ek olarak bu sohbet ve sikayetlerde foto yuklenebilsin 1 tane."*
//
// 🔴 Bu depoda tekrar eden kusur: "dogruluk kaynagi dogru ama ekran bos"
// (`kullanicinin-gordugu-satiri-test-et`). Bu yuzden her olcu EKRANDAN alinir:
// saglayici/gateway durumu tek basina kanit sayilmaz. Gonderme testleri bile
// once ekranda mesaji arar.
//
// Olculenler:
//   1. Iki sekme var ve degistirince mesaj listesi GERCEKTEN degisir.
//   2. Gecmis mesajlar sirali ve gonderen ayirt edilebilir (etiket + taraf).
//   3. Foto eklenince onizleme cikar; IKINCI foto eklenemez (tek adet).
//   4. Kanali olmayan tarafta bos-durum cumlesi VAR ve gonder CALISIR.
//   5. Dar telefon (360 dp) tasma uretmez.
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/feedback_ticket_message.dart';
import 'package:online_study_room/features/admin/detail/admin_case_conversations_page.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// 1x1 saydam PNG. Gercek goruntu bayti sart: bozuk bayt `MemoryImage`
/// cozumlemesinde asenkron hata firlatir ve 5. olcuyu (takeException) sahte
/// kirmiziya dusururdu.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQ'
  'DwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

const _reporter = CaseParty(
  role: CasePartyRole.reporter,
  userId: 'u-reporter',
  displayName: 'Ayse',
  ticketId: 't-reporter',
);

/// Kanali **olmayan** taraf: `ticketId` yok.
const _reported = CaseParty(
  role: CasePartyRole.reported,
  userId: 'u-reported',
  displayName: 'Mehmet',
);

FeedbackTicketMessage _message({
  required String ticketId,
  required String text,
  required FeedbackTicketSenderRole role,
  required int seq,
  String? attachmentPath,
}) {
  return FeedbackTicketMessage(
    id: '$ticketId-$seq',
    ticketId: ticketId,
    senderId: role == FeedbackTicketSenderRole.admin ? 'admin' : 'user',
    senderRole: role,
    message: text,
    createdAt: DateTime(2026, 9, 5, 10, seq),
    messageSeq: seq,
    attachmentPath: attachmentPath,
  );
}

class _SentMessage {
  const _SentMessage({
    required this.role,
    required this.message,
    required this.photoExt,
  });

  final CasePartyRole role;
  final String message;
  final String? photoExt;
}

/// Sahte dikis. Gercek sunucu gibi davranir: gonderilen mesaj o tarafin
/// gecmisine eklenir, boylece ekran onu geri okuyabilir.
class _FakeGateway implements CaseConversationGateway {
  _FakeGateway(this.threads);

  final Map<CasePartyRole, List<FeedbackTicketMessage>> threads;
  final List<_SentMessage> sent = [];

  /// `null` = imzalanamadi; ekran "gorsel yuklenemedi" dalina duser ve testte
  /// hic ag istegi olmaz.
  String? signedUrl;
  Object? sendError;

  @override
  Future<List<FeedbackTicketMessage>> messages(CaseParty party) async {
    return List<FeedbackTicketMessage>.of(threads[party.role] ?? const []);
  }

  @override
  Future<void> send({
    required CaseParty party,
    required String message,
    Uint8List? photoBytes,
    String? photoExt,
  }) async {
    final error = sendError;
    if (error != null) throw error;
    sent.add(
      _SentMessage(
        role: party.role,
        message: message,
        photoExt: photoBytes == null ? null : photoExt,
      ),
    );
    final thread = threads.putIfAbsent(party.role, () => []);
    thread.add(
      _message(
        ticketId: party.ticketId ?? 'yeni-${party.role.name}',
        text: message,
        role: FeedbackTicketSenderRole.admin,
        seq: thread.length + 1,
        attachmentPath: photoBytes == null ? null : 'admin/yeni.$photoExt',
      ),
    );
  }

  @override
  Future<String?> photoUrl(String attachmentPath) async => signedUrl;
}

Widget _host({
  required _FakeGateway gateway,
  List<CaseParty> parties = const [_reporter, _reported],
  CaseConversationPhotoPicker? photoPicker,
}) {
  return MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Builder(
        builder: (context) => TextButton(
          key: const Key('ac-yazismalar'),
          onPressed: () => openAdminCaseConversations(
            context,
            parties: parties,
            gateway: gateway,
            photoPicker: photoPicker,
          ),
          child: const Text('ac'),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('ac-yazismalar')));
  await tester.pumpAndSettle();
}

void _phone(WidgetTester tester, {Size size = const Size(900, 1600)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('iki sekme var; sekme degisince mesaj listesi gercekten degisir', (
    tester,
  ) async {
    _phone(tester);
    final gateway = _FakeGateway({
      CasePartyRole.reporter: [
        _message(
          ticketId: 't-reporter',
          text: 'Sikayetini aldik',
          role: FeedbackTicketSenderRole.admin,
          seq: 1,
        ),
      ],
      CasePartyRole.reported: [
        _message(
          ticketId: 't-reported',
          text: 'Bu mesaji sen mi yazdin',
          role: FeedbackTicketSenderRole.admin,
          seq: 1,
        ),
      ],
    });

    await tester.pumpWidget(_host(gateway: gateway));
    await _open(tester);

    expect(find.byKey(kCaseConversationsKey), findsOneWidget);
    expect(
      find.byKey(kCaseConversationTabKey(CasePartyRole.reporter)),
      findsOneWidget,
    );
    expect(
      find.byKey(kCaseConversationTabKey(CasePartyRole.reported)),
      findsOneWidget,
    );

    // Ilk sekme: yalniz sikayet EDENin gecmisi.
    expect(find.text('Sikayetini aldik'), findsOneWidget);
    expect(find.text('Bu mesaji sen mi yazdin'), findsNothing);

    await tester.tap(
      find.byKey(kCaseConversationTabKey(CasePartyRole.reported)),
    );
    await tester.pumpAndSettle();

    // 🔴 Asil olcu: sekme degisince liste GERCEKTEN degisti mi?
    expect(find.text('Bu mesaji sen mi yazdin'), findsOneWidget);
    expect(find.text('Sikayetini aldik'), findsNothing);
  });

  testWidgets('gecmis mesajlar sirali ve gonderen ayirt edilebilir', (
    tester,
  ) async {
    _phone(tester);
    final gateway = _FakeGateway({
      CasePartyRole.reporter: [
        _message(
          ticketId: 't-reporter',
          text: 'ilk satir',
          role: FeedbackTicketSenderRole.user,
          seq: 1,
        ),
        _message(
          ticketId: 't-reporter',
          text: 'ikinci satir',
          role: FeedbackTicketSenderRole.admin,
          seq: 2,
        ),
        _message(
          ticketId: 't-reporter',
          text: 'ucuncu satir',
          role: FeedbackTicketSenderRole.user,
          seq: 3,
        ),
      ],
    });

    await tester.pumpWidget(_host(gateway: gateway));
    await _open(tester);

    // Sira: eskiden yeniye, yukaridan asagiya.
    final first = tester.getTopLeft(find.text('ilk satir')).dy;
    final second = tester.getTopLeft(find.text('ikinci satir')).dy;
    final third = tester.getTopLeft(find.text('ucuncu satir')).dy;
    expect(first, lessThan(second));
    expect(second, lessThan(third));

    // Gonderen ETIKETI: yonetici "Sen", karsi taraf kendi adiyla.
    expect(find.textContaining('Sen · '), findsOneWidget);
    expect(find.textContaining('Ayse · '), findsNWidgets(2));

    // Gonderen TARAFI: yonetici sagda, kullanici solda.
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    expect(
      tester.getCenter(find.text('ikinci satir')).dx,
      greaterThan(width / 2),
      reason: 'yonetici balonu sagda durmali',
    );
    expect(
      tester.getCenter(find.text('ilk satir')).dx,
      lessThan(width / 2),
      reason: 'kullanici balonu solda durmali',
    );
  });

  testWidgets('foto eklenince onizleme cikar; ikinci foto eklenemez', (
    tester,
  ) async {
    _phone(tester);
    final gateway = _FakeGateway({CasePartyRole.reporter: []});
    var pickCount = 0;

    await tester.pumpWidget(
      _host(
        gateway: gateway,
        parties: const [_reporter],
        photoPicker: (_) async {
          pickCount++;
          return CaseConversationPhoto(bytes: _png, ext: 'png');
        },
      ),
    );
    await _open(tester);

    expect(find.byKey(kCaseConversationPhotoPreviewKey), findsNothing);
    expect(find.byKey(kCaseConversationAttachKey), findsOneWidget);

    await tester.tap(find.byKey(kCaseConversationAttachKey));
    await tester.pumpAndSettle();

    // (a) Ek gercekten EKRANDA gorunuyor.
    expect(find.byKey(kCaseConversationPhotoPreviewKey), findsOneWidget);
    // (b) TEK adet: ikinci foto icin dokunulacak dugme kalmadi.
    expect(find.byKey(kCaseConversationAttachKey), findsNothing);
    expect(pickCount, 1);

    // (c) Ek olu degil: gonderilen mesajla birlikte gidiyor.
    await tester.enterText(
      find.byKey(kCaseConversationInputKey),
      'ekran goruntusu ektedir',
    );
    await tester.pump();
    await tester.tap(find.byKey(kCaseConversationSendKey));
    await tester.pumpAndSettle();

    expect(gateway.sent.single.photoExt, 'png');
    // Gonderdikten sonra serit temizlenir: bir sonraki mesaj icin atac geri gelir.
    expect(find.byKey(kCaseConversationPhotoPreviewKey), findsNothing);
    expect(find.byKey(kCaseConversationAttachKey), findsOneWidget);
  });

  testWidgets('kanali olmayan tarafta bos-durum cumlesi var ve gonder calisir', (
    tester,
  ) async {
    _phone(tester);
    final gateway = _FakeGateway({
      CasePartyRole.reporter: [
        _message(
          ticketId: 't-reporter',
          text: 'Sikayetini aldik',
          role: FeedbackTicketSenderRole.admin,
          seq: 1,
        ),
      ],
    });

    await tester.pumpWidget(_host(gateway: gateway));
    await _open(tester);
    await tester.tap(
      find.byKey(kCaseConversationTabKey(CasePartyRole.reported)),
    );
    await tester.pumpAndSettle();

    // 🔴 Bos ekran DEGIL: ne yapilacagini soyleyen cumle.
    expect(
      find.text('Bu kişiyle henüz yazışmadınız. İlk mesajı siz yazın.'),
      findsOneWidget,
    );
    // Yazma seridi ACIK.
    expect(find.byKey(kCaseConversationInputKey), findsOneWidget);

    await tester.enterText(
      find.byKey(kCaseConversationInputKey),
      'Merhaba, bir konuyu sormak istiyoruz.',
    );
    await tester.pump();
    await tester.tap(find.byKey(kCaseConversationSendKey));
    await tester.pumpAndSettle();

    // Gonder OLU DEGIL: dogru tarafa gitti ve EKRANDA goruldu.
    expect(gateway.sent.single.role, CasePartyRole.reported);
    expect(find.text('Merhaba, bir konuyu sormak istiyoruz.'), findsOneWidget);
    expect(
      find.text('Bu kişiyle henüz yazışmadınız. İlk mesajı siz yazın.'),
      findsNothing,
    );
  });

  testWidgets('dar telefon (360 dp) tasma uretmez', (tester) async {
    _phone(tester, size: const Size(360, 640));
    final gateway = _FakeGateway({
      CasePartyRole.reporter: [
        _message(
          ticketId: 't-reporter',
          text:
              'Cok uzun bir sikayet metni; balonun satir kirmasi gerekiyor '
              'yoksa dar ekranda tasma olur.',
          role: FeedbackTicketSenderRole.user,
          seq: 1,
        ),
      ],
      CasePartyRole.reported: [],
    });

    await tester.pumpWidget(
      _host(
        gateway: gateway,
        parties: const [
          CaseParty(
            role: CasePartyRole.reporter,
            userId: 'u-reporter',
            displayName: 'Cok Uzun Bir Kullanici Adi Buraya',
            ticketId: 't-reporter',
          ),
          CaseParty(
            role: CasePartyRole.reported,
            userId: 'u-reported',
            displayName: 'Digerinin De Cok Uzun Adi Var',
          ),
        ],
      ),
    );
    await _open(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(
      find.byKey(kCaseConversationTabKey(CasePartyRole.reported)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(kCaseConversationInputKey), 'kisa mesaj');
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
