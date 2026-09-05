// WP-698 — yonetim panelinde **tek kart dili**.
//
// Sahip: *"sikayet, oneri, istek vs hepsinde sisteme dusen kart sistemi ayni.
// bunu tamamen bastan tasarlasin."*
//
// ## ONCE OLCULDU (2026-08-11, bu dosyanin prob surumuyle)
//
// | olcu | vaka karti (eski) | bilet karti (eski) |
// | --- | --- | --- |
// | yukseklik @280 px | 242 | **610** |
// | yukseklik @390 px | 216 | **500** |
// | yukseklik @1280 px | 216 | 198 |
// | cizilen font boyutu kumesi | {11,0 · 11,2 · 12 · 14} | {11 · 14 · 16} |
// | `Chip`/`ActionChip` | 0 | **7** (3 bilgi + 4 eylem, hepsi ayni 34 px) |
// | 48 px altinda dokunma hedefi | — | **8/8** |
//
// Iki kart ayni isi (gelen is) gosteriyordu ve **tek widget paylasmiyordu**;
// 280 px'te aralarinda 2,5 kat yukseklik farki vardi. Asagidaki iddialar bu
// olculerin dogrudan cevirisidir.
//
// ## 🔴 OLCULEN SEY KULLANICININ GORDUGUDUR
//   - yukseklik/genislik `tester.getSize` ile **cizilen kutudan** okunur,
//   - her duzen iddiasinin yaninda **govdenin gercek** oldugunu gosteren bir
//     metin aranir: `find.byType(X)` bos ya da hatali bir kabukla da eslesir,
//   - font boyutu `RichText`in cozulmus `TextSpan.style`indan alinir; ikon
//     glifleri (`MaterialIcons`) sayilmaz.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/moderation_case.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/report_target.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_moderation_repository.dart';
import 'package:online_study_room/features/admin/cards/admin_work_card.dart';
import 'package:online_study_room/features/admin/queue/admin_queue_view.dart';
import 'package:online_study_room/features/admin/widgets/moderation_queue_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _reporterId = '11111111-1111-4111-8111-111111111111';
const _targetId = '22222222-2222-4222-8222-222222222222';

/// Eski kartin olculen yukseklikleri — iddialarin referans cizgisi.
const _oldTicketHeight = <int, double>{280: 610, 390: 500};
const _oldModerationHeight = <int, double>{280: 242, 390: 216};

/// 🔴 WP-768 sonrasi tavan. Vaka karti **buyudu** ve bu bilincli bir takas:
/// durum menusu, `…` menusu ve kisi dosyasi kopru dugmesi karttan kalkti,
/// yerine tek gorunur eylem ("Detayli incele", 48 px serit) geldi. Kart hala
/// eski 610/500 px'lik bilet kartinin cok altinda.
const _moderationHeightCeiling = <int, double>{280: 320, 390: 300};

ModerationCase _case({
  ModerationSeverity severity = ModerationSeverity.high,
  bool overdue = true,
  ModerationCaseStatus status = ModerationCaseStatus.open,
}) => ModerationCase(
  targetType: ReportTargetType.message,
  targetId: _targetId,
  targetIdentity: const ModerationIdentity(
    id: _targetId,
    displayName: 'Mehmet Yilmaz',
  ),
  status: status,
  reportCount: 4,
  reasons: const ['hate', 'spam'],
  latestAt: DateTime.now().subtract(const Duration(hours: 3)),
  reporters: const [ModerationIdentity(id: _reporterId, displayName: 'Ayse')],
  reportIds: const ['report-1'],
  severity: severity,
  slaDueAt: overdue
      ? DateTime.now().subtract(const Duration(hours: 1))
      : DateTime.now().add(const Duration(hours: 4)),
  caseId: 'case-1',
);

FeedbackTicket _ticket({DateTime? archivedAt}) => FeedbackTicket(
  id: 'ticket-1',
  userId: _reporterId,
  kind: FeedbackTicketKind.feedback,
  subject: 'Sayac geri sayimda duruyor',
  message:
      'Pomodoro sayacini baslatinca ekrani kapatip acinca sifirlaniyor. '
      'Bu her seferinde oluyor ve calisma sureleri kaydedilmiyor.',
  status: FeedbackTicketStatus.open,
  createdAt: DateTime.now().subtract(const Duration(days: 2)),
  updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
  type: FeedbackTicketType.report,
  reporterDisplayName: 'Ayse',
  attachmentPath: 'shot.png',
  archivedAt: archivedAt,
);

Future<void> _pumpModeration(
  WidgetTester tester, {
  required double width,
  ModerationCase? moderationCase,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ModerationQueueCard(
            moderationCase: moderationCase ?? _case(),
            // WP-768: kartin TEK dugmesi. Durum/yaptirim/karantina detay
            // sayfasina tasindi; kart bir ozettir.
            openKey: const Key('queue-open'),
            onOpenDetail: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpTickets(
  WidgetTester tester, {
  required double width,
  FeedbackTicket? ticket,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            Profile(
              id: 'admin',
              displayName: 'Admin',
              createdAt: DateTime(2026),
            ),
          ),
        ),
        adminFeedbackTicketsProvider(
          null,
        ).overrideWith((ref) async => [ticket ?? _ticket()]),
        adminArchivedFeedbackTicketsProvider(
          null,
        ).overrideWith((ref) async => const <FeedbackTicket>[]),
        // Kuyruk uc kaynagi birlestirir; bu dosya yalniz bilet kartini
        // olcer, moderasyon tarafi bos kalir.
        adminModerationRepositoryProvider.overrideWithValue(
          InMemoryAdminModerationRepository(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery.withClampedTextScaling(
          minScaleFactor: textScale,
          maxScaleFactor: textScale,
          child: child!,
        ),
        home: const Scaffold(body: AdminQueueView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Cizilen kartin kok kutusu. `find.byType(AdminWorkCard)` yerine **govdesi
/// dogrulanmis** kart: icinde beklenen metin gercekten var mi?
Finder _card(WidgetTester tester, String bodyText) {
  final body = find.textContaining(bodyText);
  expect(
    body,
    findsWidgets,
    reason:
        'Kart govdesi cizilmedi ("$bodyText" yok); asagidaki olcum bos bir '
        'kabugu olcerdi.',
  );
  final card = find.ancestor(
    of: body.first,
    matching: find.byWidgetPredicate((w) => w is AdminWorkCard),
  );
  expect(
    card,
    findsOneWidget,
    reason:
        'WP-698: "$bodyText" iceren kart ortak kart dilinden (AdminWorkCard) '
        'turemiyor.',
  );
  return card;
}

/// Kartta cizilen gercek font boyutlari (ikon glifleri haric).
Set<double> _fontSizes(Finder card) {
  final sizes = <double>{};
  for (final element
      in find
          .descendant(of: card, matching: find.byType(RichText))
          .evaluate()) {
    final span = (element.widget as RichText).text;
    if (span is! TextSpan || span.style?.fontSize == null) continue;
    if (span.style?.fontFamily == 'MaterialIcons') continue;
    sizes.add(span.style!.fontSize!);
  }
  return sizes;
}

/// Kart icindeki her dokunma hedefinin **jest alani** yuksekligi.
///
/// Olculen sey `InkWell` degil, onu saran dugmedir: Material dokunma hedefini
/// `MaterialTapTargetSize.padded` ile buyutur ve kullanicinin parmagi o alana
/// dokunur. Mureekkep alani (`InkWell`) daha kucuk olabilir.
List<double> _tapTargetHeights(WidgetTester tester, Finder card) {
  final heights = <double>[];
  for (final element
      in find
          .descendant(
            of: card,
            matching: find.byWidgetPredicate(
              (w) =>
                  w is IconButton ||
                  w is ButtonStyleButton ||
                  w is PopupMenuButton ||
                  w is Chip ||
                  w is RawChip,
            ),
          )
          .evaluate()) {
    heights.add(tester.getSize(find.byWidget(element.widget)).height);
  }
  return heights;
}

/// Kullanicinin gordugu en uzun metin satirinin genisligi.
double _widestTextLine(WidgetTester tester, Finder card) {
  var widest = 0.0;
  for (final element
      in find
          .descendant(of: card, matching: find.byType(RichText))
          .evaluate()) {
    final span = (element.widget as RichText).text;
    if (span is TextSpan && span.style?.fontFamily == 'MaterialIcons') continue;
    final width = tester.getSize(find.byWidget(element.widget)).width;
    if (width > widest) widest = width;
  }
  return widest;
}

/// Sol ton seridinin rengi — kuyrukta gozle taranan sey.
Color _toneRail(Finder card) {
  final containers = find
      .descendant(
        of: card,
        matching: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration! as BoxDecoration).border is BorderDirectional,
        ),
      )
      .evaluate();
  expect(
    containers,
    hasLength(1),
    reason: 'WP-698: kartta ton seridi yok; aciliyet tek bakista secilemez.',
  );
  final decoration =
      (containers.single.widget as Container).decoration! as BoxDecoration;
  return (decoration.border! as BorderDirectional).start.color;
}

void main() {
  group('WP-698/1 — tek kart dili', () {
    testWidgets('iki yuzey de ayni bilesenden turer', (tester) async {
      await _pumpModeration(tester, width: 390);
      _card(tester, 'Nefret');

      await _pumpTickets(tester, width: 390);
      _card(tester, 'Sayac geri sayimda duruyor');
    });

    testWidgets('iki kart ailesi ayni font boyutu kumesini cizer', (
      tester,
    ) async {
      await _pumpModeration(tester, width: 390);
      final moderationSizes = _fontSizes(_card(tester, 'Nefret'));

      await _pumpTickets(tester, width: 390);
      final ticketSizes = _fontSizes(
        _card(tester, 'Sayac geri sayimda duruyor'),
      );

      expect(
        moderationSizes,
        isNotEmpty,
        reason: 'Hic metin olculemedi; iddia bedavaya yesil olurdu.',
      );
      expect(
        ticketSizes,
        equals(moderationSizes),
        reason:
            'WP-698: sikayet karti ve bilet karti farkli tipografi olcegi '
            'kullaniyor. Olculen eski kumeler: vaka {11,0 11,2 12 14}, '
            'bilet {11 14 16}.',
      );
    });

    testWidgets('bilgi cip degildir — kartta Chip/ActionChip kalmadi', (
      tester,
    ) async {
      await _pumpTickets(tester, width: 390);
      final card = _card(tester, 'Sayac geri sayimda duruyor');
      expect(
        find.descendant(of: card, matching: find.byType(Chip)),
        findsNothing,
        reason:
            'WP-698: bilet kartinda 7 cip vardi (3 bilgi + 4 eylem, hepsi ayni '
            '34 px pill) — hangisine basilabilecegi gorunmuyordu.',
      );
      expect(
        find.descendant(of: card, matching: find.byType(ActionChip)),
        findsNothing,
      );
    });
  });

  group('WP-698/2 — tarama: aciliyet tek bakista', () {
    testWidgets('acil vaka ile yeni vaka farkli ton seridi cizer', (
      tester,
    ) async {
      await _pumpModeration(
        tester,
        width: 390,
        moderationCase: _case(overdue: true),
      );
      final urgent = _toneRail(_card(tester, 'Nefret'));

      await _pumpModeration(
        tester,
        width: 390,
        moderationCase: _case(
          overdue: false,
          severity: ModerationSeverity.normal,
        ),
      );
      final fresh = _toneRail(_card(tester, 'Nefret'));

      await _pumpModeration(
        tester,
        width: 390,
        moderationCase: _case(
          overdue: false,
          severity: ModerationSeverity.normal,
          status: ModerationCaseStatus.resolved,
        ),
      );
      final closed = _toneRail(_card(tester, 'Nefret'));

      expect(
        {urgent, fresh, closed},
        hasLength(3),
        reason:
            'WP-698: acil / yeni / kapali ayni rengi cizerse yonetici kuyrukta '
            'gozle tarayamaz.',
      );
    });
  });

  group('WP-698/3 — yogunluk: 280 px kuyruk sutunu ve 390 px telefon', () {
    for (final width in <int>[280, 390]) {
      testWidgets('$width px: bilet karti kisalir ve tasmaz', (tester) async {
        await _pumpTickets(tester, width: width.toDouble());
        final card = _card(tester, 'Sayac geri sayimda duruyor');
        final height = tester.getSize(card).height;

        expect(
          tester.takeException(),
          isNull,
          reason: '$width px genislikte kart tasti.',
        );
        // Sert tavan: olculen 362 px + ~%10 pay. Yalniz "eskisinden kisa"
        // demek yetmiyordu — 610'un altindaki her sisme yesil kaliyordu.
        expect(
          height,
          lessThanOrEqualTo(400),
          reason:
              'WP-698: bilet karti $width px genislikte eskiden '
              '${_oldTicketHeight[width]} px idi; olculen $height px.',
        );
      });

      testWidgets('$width px: vaka karti kisalir ve tasmaz', (tester) async {
        await _pumpModeration(tester, width: width.toDouble());
        final card = _card(tester, 'Nefret');
        final height = tester.getSize(card).height;

        expect(
          tester.takeException(),
          isNull,
          reason: '$width px genislikte kart tasti.',
        );
        expect(
          height,
          lessThanOrEqualTo(_moderationHeightCeiling[width]!),
          reason:
              'WP-768: vaka karti $width px genislikte eskiden '
              '${_oldModerationHeight[width]} px idi; tek eylem seridiyle '
              '${_moderationHeightCeiling[width]} px tavani kondu, '
              'olculen $height px.',
        );
      });
    }

    for (final width in <int>[280, 390]) {
      testWidgets('$width px + metin olcegi 1.3: bilet karti tasmaz', (
        tester,
      ) async {
        await _pumpTickets(tester, width: width.toDouble(), textScale: 1.3);
        // Govde gercek mi? Kabuk olcmuyoruz.
        expect(find.text('Sayac geri sayimda duruyor'), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason:
              'WP-698: $width px + 1.3 olcekte kart tasti (RenderFlex '
              'overflowed).',
        );
      });
    }

    testWidgets('iki kart ailesinin yukseklik farki 2 kati asmaz', (
      tester,
    ) async {
      await _pumpModeration(tester, width: 280);
      final moderation = tester.getSize(_card(tester, 'Nefret')).height;

      await _pumpTickets(tester, width: 280);
      final ticket = tester
          .getSize(_card(tester, 'Sayac geri sayimda duruyor'))
          .height;

      expect(
        ticket / moderation,
        lessThan(2),
        reason:
            'WP-698: ayni isi gosteren iki kart 280 px genislikte 610/242 = '
            '2,52 kat farkliydi; ortak dil bunu kapatmali.',
      );
    });
  });

  group('WP-698/4 — DESKTOP-UI-SPEC 2.2 sert tavani', () {
    testWidgets('1280 px listede metin satiri 600 px asmaz', (tester) async {
      await _pumpTickets(tester, width: 1280);
      final card = _card(tester, 'Sayac geri sayimda duruyor');
      final widest = _widestTextLine(tester, card);

      expect(
        widest,
        greaterThan(0),
        reason: 'Hic metin olculemedi; iddia bedavaya yesil olurdu.',
      );
      // 🔴 Sayi BURAYA yazilir, `kAdminWorkCardMaxContentWidth` ile
      // karsilastirilmaz: o sabiti yukseltmek iddiayi da yukseltir ve sabotaj
      // yesil kalir (2026-08-11 sabotaj turunda tam boyle oldu).
      expect(
        widest,
        lessThanOrEqualTo(600),
        reason:
            'DESKTOP-UI-SPEC 2.2: etiket-deger / prose satirinin sert tavani '
            '600 px. Kart genis listede satiri kaba yayiyor.',
      );
      expect(
        kAdminWorkCardMaxContentWidth,
        600,
        reason: 'Bilesenin tavani spec sayisindan kaymis.',
      );
    });
  });

  group('WP-698/5 — dokunma hedefi', () {
    testWidgets('bilet kartindaki her hedef 48 px', (tester) async {
      await _pumpTickets(tester, width: 390);
      final card = _card(tester, 'Sayac geri sayimda duruyor');
      final heights = _tapTargetHeights(tester, card);

      expect(
        heights,
        isNotEmpty,
        reason: 'Hic dokunma hedefi bulunamadi; iddia olcum degil.',
      );
      expect(
        heights.where((h) => h < kAdminWorkCardTapTarget),
        isEmpty,
        reason:
            'WP-698: eski bilet kartinda sekiz hedefin sekizi de 48 px altinda '
            'idi (40 ve 7x34). Olculen: $heights',
      );
    });

    testWidgets('vaka kartindaki her hedef 48 px', (tester) async {
      await _pumpModeration(tester, width: 390);
      final heights = _tapTargetHeights(tester, _card(tester, 'Nefret'));
      expect(heights, isNotEmpty);
      expect(
        heights.where((h) => h < kAdminWorkCardTapTarget),
        isEmpty,
        reason: 'Olculen: $heights',
      );
    });
  });

  group('WP-698/6 — islev kaybi yok', () {
    testWidgets('vaka: tekrar sayaci, rozet, durum ve TEK eylem yerinde', (
      tester,
    ) async {
      await _pumpModeration(tester, width: 390);

      // Tekrar sayaci: 4 rapor => sikayet edenin yaninda (+3).
      expect(
        find.textContaining('(+3)'),
        findsOneWidget,
        reason: 'WP-698: tekrar sayaci kayboldu.',
      );
      // Rozetler.
      expect(find.byKey(const Key('moderation-case-badges')), findsOneWidget);
      expect(find.text('Yüksek risk'), findsOneWidget);
      expect(find.text('Süresi aştı'), findsOneWidget);

      // 🔴 WP-768: durum artik okunur bir etikettir, menu degil.
      expect(find.byType(AdminWorkStatusLabel), findsOneWidget);
      expect(find.text('Açık'), findsOneWidget);
      expect(find.byType(PopupMenuButton<ModerationCaseStatus>), findsNothing);

      // `…` menusu kalkti; yerine kartin tek gorunur eylemi geldi.
      expect(
        find.byKey(const Key('moderation-secondary-actions')),
        findsNothing,
      );
      expect(find.text('Detaylı incele'), findsOneWidget);
    });

    testWidgets('bilet: kimlik ve durum yerinde, TEK eylem detayi acar', (
      tester,
    ) async {
      await _pumpTickets(tester, width: 390);

      // 🔴 WP-768: "Yanit yaz", "Ic Notlar", "Ekran Goruntusu" ve "Arsivle"
      // karttan kalkti — hepsi biletin kendi sayfasinda, tek yerde
      // (`admin_ticket_detail_wp770_test.dart`). Kartta yalniz ozet + tek yol.
      expect(find.text('Yanıt yaz'), findsNothing);
      expect(find.text('İç Notlar'), findsNothing);
      expect(find.text('Ekran Görüntüsü'), findsNothing);
      expect(find.text('Arşivle'), findsNothing);
      expect(find.byKey(const Key('feedback-more-ticket-1')), findsNothing);

      expect(find.text('Detaylı incele'), findsOneWidget);
      // Durum hapi bilette de tek kontrol.
      expect(find.text('Açık'), findsOneWidget);
      // Gonderen taraf satirinda.
      expect(find.textContaining('Gönderen: Ayse'), findsOneWidget);
    });

    testWidgets('arsivlenmis bilet isaret seridinde belli olur', (
      tester,
    ) async {
      await _pumpTickets(
        tester,
        width: 390,
        ticket: _ticket(archivedAt: DateTime.now()),
      );
      expect(find.text('Arşivde'), findsOneWidget);
    });
  });

  group('WP-698/7 — tehlikeli eylem karttan cikmaz', () {
    testWidgets('vaka kartinda gorunur yaptirim/karantina dugmesi yok', (
      tester,
    ) async {
      await _pumpModeration(tester, width: 390);
      // Kart bir ozettir: tehlikeli eylem yuzune cikmaz, karar vakanin kendi
      // sayfasindadir (WP-769 karar seridi).
      expect(
        find.text('Yaptırım uygula'),
        findsNothing,
        reason:
            'WP-698/WP-768: yaptirim kartin yuzune cikmis; karar yalniz '
            'vakanin kendi sayfasinda verilir.',
      );
      expect(find.text('İçeriği karantinaya al'), findsNothing);
      expect(find.text('Kalıcı yasak'), findsNothing);

      // Eylem seridinde tek dugme var ve o dugme tehlikeli degil: yalnizca
      // vakayi acar.
      final card = _card(tester, 'Nefret');
      final actions = find.descendant(
        of: card,
        matching: find.byWidgetPredicate(
          (w) => w is FilledButton || w is TextButton || w is OutlinedButton,
        ),
      );
      expect(
        actions,
        findsOneWidget,
        reason: 'Vaka kartinda tek gorunur eylem olmali.',
      );
      expect(
        find.descendant(of: actions, matching: find.text('Detaylı incele')),
        findsOneWidget,
      );
    });
  });
}
