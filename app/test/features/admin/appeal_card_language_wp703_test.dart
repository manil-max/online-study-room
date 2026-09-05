// WP-703/3 — itiraz karti WP-698'in tek kart diline cevrilmemisti.
//
// WP-698 yonetim panelindeki her gelen isi tek bilesene indirdi
// (`features/admin/cards/admin_work_card.dart`): sikayet karti ve destek bileti
// karti o turda cevrildi, **itiraz karti atlandi**. `_AppealCard` hala kendi
// `Card > Column`unu, kendi `TextButton`/`FilledButton` ciftini ve kendi
// tipografisini ciziyordu.
//
// ## ONCE OLCULDU (2026-08-11, bu dosyanin ilk kosumu, cevirmeden once)
//
//   - AdminWorkCard atasi:            YOK (findsNothing)
//   - cizilen font boyutu kumesi:     {14.0, 12.0, 14.0*} — vaka kartinin
//                                     kumesiyle esit degil
//   - dokunma hedefi (280 px):        ...px  <- asagidaki iddia yazar
//   - ton seridi:                     YOK
//
// ## ISLEV KAYBI OLCUSU (cevirmeden ONCE sayilan liste)
// Alanlar: (A1) "Itiraz edilen yaptirim: <ceza>", (A2) yaptirim gerekcesi,
// (A3) itiraz metni, (A4) "kendi yaptirimin" cakisma notu.
// Eylemler: (B1) `appeal-uphold-<id>` = Yaptirimi koru,
//           (B2) `appeal-overturn-<id>` = Yaptirimi kaldir (vurgulu),
//           ikisi de gerekce diyalogundan gecer ve kuyrugu tazeler.
// Asagidaki "islev kaybi yok" grubu bu ALTI maddeyi tek tek dogrular.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/moderation_appeal.dart';
import 'package:online_study_room/data/models/moderation_case.dart';
import 'package:online_study_room/data/models/moderation_sanction.dart';
import 'package:online_study_room/data/models/report_target.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_moderation_repository.dart';
import 'package:online_study_room/features/admin/cards/admin_work_card.dart';
import 'package:online_study_room/features/admin/queue/admin_queue_view.dart';
import 'package:online_study_room/features/admin/widgets/moderation_queue_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _statement = 'mesaji ben yazmadim, hesabim paylasimliydi';
const _sanctionReason = 'tekrarlayan hakaret';
const _targetId = '22222222-2222-4222-8222-222222222222';

ModerationAppeal _appeal({bool decidable = true}) => ModerationAppeal(
  id: 'appeal-1',
  sanctionId: 'sanction-1',
  statement: _statement,
  status: ModerationAppealStatus.open,
  createdAt: DateTime(2026, 7, 30, 11),
  sanctionAction: ModerationAction.mute24h,
  sanctionReason: _sanctionReason,
  decidable: decidable,
);

ModerationCase _case() => ModerationCase(
  targetType: ReportTargetType.message,
  targetId: _targetId,
  targetIdentity: const ModerationIdentity(
    id: _targetId,
    displayName: 'Mehmet Yilmaz',
  ),
  status: ModerationCaseStatus.open,
  reportCount: 2,
  reasons: const ['hate'],
  latestAt: DateTime(2026, 7, 30, 8),
  reporters: const [],
  reportIds: const ['report-1'],
  severity: ModerationSeverity.normal,
  caseId: 'case-1',
);

Future<InMemoryAdminModerationRepository> _pumpAppeals(
  WidgetTester tester, {
  double width = 390,
  bool decidable = true,
}) async {
  tester.view.physicalSize = Size(width, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final repo = InMemoryAdminModerationRepository()
    ..appeals.add(_appeal(decidable: decidable));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [adminModerationRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: AdminQueueView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

/// Vaka karti — tipografi kiyasinin oteki ucu (WP-698'de cevrilen kart).
Future<void> _pumpModerationCard(
  WidgetTester tester, {
  double width = 390,
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
            moderationCase: _case(),
            openKey: const Key('queue-open'),
            onOpenDetail: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Itiraz kartinin kok kutusu — **govdesi dogrulanmis**: bos bir kabuk
/// olculmesin diye once itiraz metninin gercekten cizildigi gosterilir.
Finder _appealCard(String bodyText) {
  final body = find.textContaining(bodyText);
  expect(
    body,
    findsWidgets,
    reason: 'Itiraz govdesi cizilmedi ("$bodyText"); olcum bos kabuk olurdu.',
  );
  return find.ancestor(
    of: body.first,
    matching: find.byWidgetPredicate((w) => w is AdminWorkCard),
  );
}

Set<double> _fontSizes(WidgetTester tester, Finder root) {
  final sizes = <double>{};
  for (final element in find
      .descendant(of: root, matching: find.byType(RichText))
      .evaluate()) {
    final span = (element.widget as RichText).text;
    if (span is! TextSpan || span.style?.fontSize == null) continue;
    if (span.style?.fontFamily == 'MaterialIcons') continue;
    sizes.add(span.style!.fontSize!);
  }
  return sizes;
}

List<double> _tapTargetHeights(WidgetTester tester, Finder root) {
  final heights = <double>[];
  for (final element in find
      .descendant(
        of: root,
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

/// 🔴 WP-768: karar dugmeleri karttan kalkti. Kartta tek dugme var ve o
/// dugme itirazin **kendi sayfasini** acar; karar orada verilir.
Future<void> _openAppealPage(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('admin-queue-open-appeal:appeal-1')));
  await tester.pumpAndSettle();
}

void main() {
  group('WP-703/3 — itiraz karti da tek kart dilinden turer', () {
    testWidgets('itiraz karti AdminWorkCard uzerine kurulur', (tester) async {
      await _pumpAppeals(tester);
      expect(
        _appealCard(_statement),
        findsOneWidget,
        reason:
            'WP-698 yonetim panelinde tek kart dili kurdu; itiraz karti o '
            'turda atlandi ve hala kendi Card > Column yapisinda.',
      );
    });

    testWidgets('itiraz karti vaka kartiyla ayni tipografi olcegini cizer', (
      tester,
    ) async {
      await _pumpAppeals(tester);
      final appealSizes = _fontSizes(tester, _appealCard(_statement));

      await _pumpModerationCard(tester);
      final caseSizes = _fontSizes(
        tester,
        find.byType(AdminWorkCard),
      );

      expect(appealSizes, isNotEmpty, reason: 'Hic metin olculemedi.');
      expect(
        appealSizes.difference(caseSizes),
        isEmpty,
        reason:
            'WP-698 tipografi kurali: baslik titleSmall, govde/meta bodySmall, '
            'hap/isaret labelSmall. Itiraz karti kumenin disina cikan boyut '
            'ciziyor. Itiraz: $appealSizes, vaka: $caseSizes',
      );
    });

    testWidgets('280 px kuyruk sutununda tasma yok ve her hedef 48 px', (
      tester,
    ) async {
      await _pumpAppeals(tester, width: 280);
      final card = _appealCard(_statement);
      expect(
        tester.takeException(),
        isNull,
        reason: '280 px genislikte itiraz karti tasti.',
      );
      final heights = _tapTargetHeights(tester, card);
      expect(heights, isNotEmpty, reason: 'Hic dokunma hedefi bulunamadi.');
      expect(
        heights.where((h) => h < kAdminWorkCardTapTarget),
        isEmpty,
        reason:
            'Eski itiraz kartinda karar dugmeleri Material varsayilanindaydi. '
            'Olculen: $heights',
      );
    });

    testWidgets('kartin ton seridi vardir (kuyrukta gozle taranir)', (
      tester,
    ) async {
      await _pumpAppeals(tester);
      final rails = find
          .descendant(
            of: _appealCard(_statement),
            matching: find.byWidgetPredicate(
              (w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration! as BoxDecoration).border is BorderDirectional,
            ),
          )
          .evaluate();
      expect(
        rails,
        hasLength(1),
        reason: 'Itiraz kartinda ton seridi yok; aciliyet secilemiyor.',
      );
    });
  });

  group('WP-703/3 — islev kaybi yok (cevirmeden once sayilan alti madde)', () {
    testWidgets('A1 itiraz edilen yaptirim, A2 gerekce, A3 itiraz metni', (
      tester,
    ) async {
      await _pumpAppeals(tester);
      expect(
        find.textContaining('İtiraz edilen yaptırım'),
        findsOneWidget,
        reason: 'A1: yonetici hangi cezaya itiraz edildigini gormeden karar '
            'veremez (WP-B kabul 5).',
      );
      expect(
        find.textContaining('24 saat yazma kısıtı'),
        findsOneWidget,
        reason: 'A1: yaptirim basamaginin adi kayboldu.',
      );
      expect(
        find.textContaining(_sanctionReason),
        findsOneWidget,
        reason: 'A2: yaptirimin gerekcesi kayboldu.',
      );
      expect(
        find.textContaining(_statement),
        findsOneWidget,
        reason: 'A3: kullanicinin itiraz metni kayboldu.',
      );
    });

    testWidgets('B1/B2 iki karar dugmesi anahtarlariyla durur', (tester) async {
      await _pumpAppeals(tester);
      // Kartta karar yok: sahip her kartta tek dugme istedi.
      expect(find.byKey(const Key('appeal-uphold-appeal-1')), findsNothing);
      expect(find.text('Detaylı incele'), findsOneWidget);

      await _openAppealPage(tester);
      expect(find.byKey(const Key('appeal-uphold-appeal-1')), findsOneWidget);
      expect(find.byKey(const Key('appeal-overturn-appeal-1')), findsOneWidget);
      expect(find.text('Yaptırımı koru'), findsOneWidget);
      expect(find.text('Yaptırımı kaldır'), findsOneWidget);
    });

    testWidgets('A4 kendi yaptirimi: eylem yok, neden yazili', (tester) async {
      await _pumpAppeals(tester, decidable: false);
      expect(
        find.byKey(const Key('appeal-conflict-note')),
        findsOneWidget,
        reason: 'A4: cakisma notu kayboldu.',
      );
      expect(
        find.textContaining('Kendi verdiğin yaptırımın'),
        findsOneWidget,
        reason: 'A4: notun metni kullaniciya ulasmiyor.',
      );
      expect(find.byKey(const Key('appeal-overturn-appeal-1')), findsNothing);
      expect(find.byKey(const Key('appeal-uphold-appeal-1')), findsNothing);

      // Detay sayfasi da **soz vermez**: karara baglayamayan yoneticiye
      // sunucunun reddedecegi bir dugme gosterilmez, nedeni yazilir.
      await _openAppealPage(tester);
      expect(find.byKey(const Key('appeal-overturn-appeal-1')), findsNothing);
      expect(find.byKey(const Key('appeal-uphold-appeal-1')), findsNothing);
      expect(find.textContaining('Kendi verdiğin yaptırımın'), findsOneWidget);
    });

    testWidgets('karar hala gerekce ister ve kuyrugu tazeler', (tester) async {
      final repo = await _pumpAppeals(tester);
      await _openAppealPage(tester);

      await tester.tap(find.byKey(const Key('appeal-overturn-appeal-1')));
      await tester.pumpAndSettle();
      // Gerekce bosken karar yazilmaz.
      await tester.tap(find.byKey(const Key('moderation-reason-confirm')));
      await tester.pumpAndSettle();
      expect(repo.appealDecisions, isEmpty);

      await tester.tap(find.byKey(const Key('appeal-overturn-appeal-1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('moderation-reason-field')),
        'kanit yetersiz',
      );
      await tester.tap(find.byKey(const Key('moderation-reason-confirm')));
      await tester.pumpAndSettle();

      expect(repo.appealDecisions.single, 'appeal-1=overturned');
      expect(find.text('İtiraz karara bağlandı'), findsOneWidget);
    });

    testWidgets('"koru" dugmesi de karari yazar', (tester) async {
      final repo = await _pumpAppeals(tester);
      await _openAppealPage(tester);
      await tester.tap(find.byKey(const Key('appeal-uphold-appeal-1')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('moderation-reason-field')),
        'itiraz yetersiz',
      );
      await tester.tap(find.byKey(const Key('moderation-reason-confirm')));
      await tester.pumpAndSettle();
      expect(repo.appealDecisions.single, 'appeal-1=upheld');
    });
  });
}
