// WP-B (WP-691 FAZ 2) — sikayet inceleme: KANIT + KARAR TEK EKRANDA.
//
// ONCE KIRMIZI. Bes kabul olcutu `docs/design/ADMIN-PANEL-PLAN.md` §5 WP-B'den
// birebir alindi; liderin iki ek sarti (geri al seridi · serit kaydirmayla
// kaybolmaz) sonda. Bu dosyanin ilk kosumunda BESI DE kirmiziydi:
//   - kabul 1: `attachment_path` / `reason` / `created_at` / `sanctions[].action`
//     istemci modelinde HIC yoktu (derleme hatasi).
//   - kabul 2/3/4 + serit: `moderation-case-row-*` bulunamadi (0 widget) —
//     vaka satiri secilebilir bile degildi.
//   - kabul 5: '7 gün askıya al' icin 0 widget bulundu.
//
// 🔴 Olculen sey KULLANICININ GORDUGU seydir. Bir alan adinin kaynakta gecmesi
// kanit degildir; her duzen iddiasinin yaninda GOVDENIN GERCEK oldugunu
// gosteren bir metin araniyor — `find.byType(X)` bos/hatali bir kabukla da
// eslesir (2026-08-11'de bes ajan bu tuzaga dustu).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/moderation_appeal.dart';
import 'package:online_study_room/data/models/moderation_case.dart';
import 'package:online_study_room/data/models/moderation_sanction.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/report_target.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/admin_moderation_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_moderation_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/data/repositories/supabase/supabase_admin_moderation_repository.dart';
import 'package:online_study_room/features/admin/admin_screen.dart';
import 'package:online_study_room/features/admin/sanctions/admin_case_target_link.dart';
import 'package:online_study_room/features/admin/sanctions/admin_person_dossier.dart';
import 'package:online_study_room/features/admin/shell/admin_shell.dart';
import 'package:online_study_room/features/admin/tabs/admin_moderation_tab.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../support/supabase_wire_harness.dart';

const _targetA = '22222222-2222-4222-8222-222222222222';
const _targetB = '33333333-3333-4333-8333-333333333333';

/// Ekranin kaydirilmasi gereken kadar uzun kanit metni: serit testi gercek bir
/// kaydirma olcmeli, tasmayan bir listede `drag` hicbir sey yapmaz ve iddia
/// sahte yesile duser.
final String _longSnapshot = List.generate(
  40,
  (i) => 'kufur satiri $i',
).join('\n');

ModerationCase _case({
  required String targetId,
  required String reportId,
  String name = 'Mehmet',
}) => ModerationCase(
  caseId: 'case-$reportId',
  targetType: ReportTargetType.message,
  targetId: targetId,
  targetIdentity: ModerationIdentity(id: targetId, displayName: name),
  status: ModerationCaseStatus.open,
  reportCount: 2,
  reasons: const ['hate'],
  latestAt: DateTime(2026, 8, 10, 9),
  reporters: const [
    ModerationIdentity(
      id: '11111111-1111-4111-8111-111111111111',
      displayName: 'Ayse',
    ),
  ],
  reportIds: [reportId],
);

ModerationCaseDetail _detail({required String snapshot, String? attachmentPath}) =>
    ModerationCaseDetail(
      snapshot: snapshot,
      details: 'derste surekli hakaret ediyor',
      contextMessages: const [
        ModerationContextMessage(
          displayName: 'Mehmet',
          body: 'sen sus',
          isTarget: true,
        ),
      ],
      reportCount: 2,
      attachmentPath: attachmentPath,
      reason: 'hate',
      createdAt: DateTime(2026, 8, 10, 9),
      status: 'open',
      sanctions: const [
        ModerationSanctionHistoryEntry(
          action: 'mute_24h',
          reason: 'onceki uyari',
        ),
      ],
    );

Future<void> _pump(
  WidgetTester tester,
  InMemoryAdminModerationRepository repo, {
  Size window = const Size(1280, 900),
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [adminModerationRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(
        locale: Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: AdminModerationTab()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _row(String targetId) =>
    find.byKey(Key('moderation-case-row-message:$targetId'));

void main() {
  // --- KABUL 1: sunucunun gonderdigi alanlar istemcide DURUYOR -----------
  test('detay ek yolu, gerekce, zaman ve sanctions[].action tasir', () async {
    final wire = SupabaseWireHarness();
    wire.respond('admin_ugc_report_detail', {
      // Gövde birebir `0097_moderation_report_detail.sql:73-83`.
      'report': {
        'id': 'report-a',
        'target_type': 'message',
        'target_id': _targetA,
        'reason': 'hate',
        'details': 'derste surekli hakaret ediyor',
        'content_snapshot': 'aptal herif',
        'attachment_path': 'uid/evidence.png',
        'status': 'open',
        'created_at': '2026-08-10T09:00:00Z',
      },
      'context': [
        {'display_name': 'Mehmet', 'body': 'sen sus', 'is_target': true},
      ],
      'history': {
        'report_count': 3,
        'sanctions': [
          {
            'action': 'mute_24h',
            'reason': 'onceki uyari',
            'created_at': '2026-08-01T10:00:00Z',
          },
        ],
      },
    });
    final repo = SupabaseAdminModerationRepository(wire.client());

    final detail = await repo.fetchDetail('report-a');

    expect(
      detail.attachmentPath,
      'uid/evidence.png',
      reason: 'ADMIN-PANEL-PLAN §2.1: kullanicinin ekledigi ekran goruntusu '
          'ayristirilmiyordu.',
    );
    expect(detail.reason, 'hate');
    expect(detail.createdAt, isNotNull);
    expect(detail.status, 'open');
    expect(detail.reportCount, 3);
    expect(
      detail.sanctions.single.moderationAction,
      ModerationAction.mute24h,
      reason: 'history.sanctions[].action atiliyordu; "bu kisiye daha once ne '
          'yapildi" cevapsizdi.',
    );
    // Eski cagri yerleri kirilmadi.
    expect(detail.sanctionReasons, ['onceki uyari']);
  });

  test('bos ek yolu null olur; olmayan ek dugme uretmez', () async {
    final wire = SupabaseWireHarness();
    wire.respond('admin_ugc_report_detail', {
      'report': {'content_snapshot': 'x', 'attachment_path': '   '},
      'context': const [],
      'history': const {},
    });
    final detail = await SupabaseAdminModerationRepository(
      wire.client(),
    ).fetchDetail('report-a');
    expect(detail.attachmentPath, isNull);
  });

  // --- KABUL 2: ek gorsel onizleme dugmesi -------------------------------
  testWidgets('ek yolu dolu vakada gorsel onizleme dugmesi bulunur', (
    tester,
  ) async {
    final repo =
        InMemoryAdminModerationRepository(
            seed: [
              _case(targetId: _targetA, reportId: 'report-a'),
              _case(targetId: _targetB, reportId: 'report-b', name: 'Kemal'),
            ],
          )
          ..details['report-a'] = _detail(
            snapshot: 'aptal herif diye yazmis',
            attachmentPath: 'uid/evidence.png',
          )
          ..details['report-b'] = _detail(snapshot: 'spam linki atmis');
    await _pump(tester, repo);

    expect(_row(_targetA), findsOneWidget, reason: 'Vaka satiri yok.');
    await tester.tap(_row(_targetA));
    await tester.pumpAndSettle();

    // Govde GERCEK mi? Once kanit metnini bul, sonra dugmeyi olc.
    expect(find.text('aptal herif diye yazmis'), findsOneWidget);
    expect(
      find.byKey(const Key('moderation-attachment-open')),
      findsOneWidget,
      reason: 'ADMIN-PANEL-PLAN §5 WP-B kabul 2: ekran goruntusu admin e hic '
          'gosterilmiyordu (0097 attachment_path donduruyor).',
    );

    // Sabotaj kapisi: eki OLMAYAN vakada dugme HIC cikmamali; yoksa "her
    // vakada duran ama hicbir sey acmayan dugme" olur.
    await tester.tap(_row(_targetB));
    await tester.pumpAndSettle();
    expect(find.text('spam linki atmis'), findsOneWidget);
    expect(
      find.byKey(const Key('moderation-attachment-open')),
      findsNothing,
      reason: 'Eksiz vakada onizleme dugmesi cizilmemeli.',
    );
    expect(find.text('Şikâyete görsel eklenmemiş.'), findsOneWidget);
  });

  // --- KABUL 3: kanit ve karar AYNI ANDA ---------------------------------
  testWidgets('vaka secili iken icerik metni ve "Cozuldu" ayni anda agacta', (
    tester,
  ) async {
    final repo =
        InMemoryAdminModerationRepository(
            seed: [_case(targetId: _targetA, reportId: 'report-a')],
          )
          ..details['report-a'] = _detail(snapshot: 'aptal herif diye yazmis');
    await _pump(tester, repo);

    await tester.tap(_row(_targetA));
    await tester.pumpAndSettle();

    expect(
      find.text('aptal herif diye yazmis'),
      findsOneWidget,
      reason: 'Sikayet edilen icerik ekranda degil.',
    );
    expect(
      find.byKey(const Key('moderation-decision-resolved')),
      findsOneWidget,
      reason: 'ADMIN-PANEL-PLAN §2.2 kok neden: kanitin gorundugu yuzey ile '
          'kararin verildigi yuzey ayni anda ekranda degildi.',
    );
    // Sikayet edenin yazdigi aciklama ve hedefin gecmisi de ayni ekranda.
    expect(find.text('derste surekli hakaret ediyor'), findsOneWidget);
    expect(find.textContaining('24 saat yazma kısıtı'), findsOneWidget);
  });

  // --- KABUL 4: sonraki vaka + geri al -----------------------------------
  testWidgets('karar verilince sonraki vaka secilir ve "Geri al" belirir', (
    tester,
  ) async {
    final repo =
        InMemoryAdminModerationRepository(
            seed: [
              _case(targetId: _targetA, reportId: 'report-a'),
              _case(targetId: _targetB, reportId: 'report-b', name: 'Kemal'),
            ],
          )
          ..details['report-a'] = _detail(snapshot: 'aptal herif diye yazmis')
          ..details['report-b'] = _detail(snapshot: 'spam linki atmis');
    await _pump(tester, repo);

    await tester.tap(_row(_targetA));
    await tester.pumpAndSettle();
    expect(find.text('aptal herif diye yazmis'), findsOneWidget);

    await tester.tap(find.byKey(const Key('moderation-decision-resolved')));
    await tester.pumpAndSettle();

    expect(repo.statusWrites.single, 'message:$_targetA=resolved');
    expect(
      find.text('spam linki atmis'),
      findsOneWidget,
      reason: 'PLAN §4.2: karardan sonra imlec siradaki vakaya gecmeli.',
    );
    expect(
      find.byKey(const Key('moderation-undo-bar')),
      findsOneWidget,
      reason: 'PLAN §4.4.2: geri alinabilir karar teyit degil 10 sn serit ister.',
    );

    await tester.tap(find.byKey(const Key('moderation-undo-button')));
    await tester.pumpAndSettle();

    expect(repo.statusWrites.last, 'message:$_targetA=open');
    expect(find.byKey(const Key('moderation-undo-bar')), findsNothing);
    final queue = await repo.fetchQueue();
    expect(queue.first.status, ModerationCaseStatus.open);
  });

  // --- KABUL 5: itirazda yaptirim etiketi --------------------------------
  testWidgets('itiraz detayinda sanctionAction etiketi bulunur', (tester) async {
    final repo = InMemoryAdminModerationRepository()
      ..appeals.add(
        ModerationAppeal.fromWire(const {
          'id': 'appeal-1',
          'sanction_id': 'sanction-1',
          'statement': 'ben yapmadim',
          'status': 'open',
          'created_at': '2026-08-01T10:00:00Z',
          'sanction_action': 'suspend_7d',
          'sanction_reason': 'tekrarlayan hakaret',
        }),
      );
    await _pump(tester, repo);

    // Once govde gercek mi: itiraz karti gercekten cizildi mi?
    expect(find.text('ben yapmadim'), findsOneWidget);
    expect(
      find.textContaining('7 gün askıya al'),
      findsOneWidget,
      reason: 'ADMIN-PANEL-PLAN §2.1: admin HANGI cezaya itiraz edildigini '
          'gormeden "koru/kaldir" diyordu.',
    );
  });

  // --- LIDER SARTI 7: karar seridi kaydirmayla KAYBOLMAZ -----------------
  testWidgets('karar seridi uzun kanit kaydirilinca piksel piksel yerinde', (
    tester,
  ) async {
    final repo =
        InMemoryAdminModerationRepository(
            seed: [_case(targetId: _targetA, reportId: 'report-a')],
          )
          ..details['report-a'] = _detail(snapshot: _longSnapshot);
    await _pump(tester, repo, window: const Size(1280, 620));

    await tester.tap(_row(_targetA));
    await tester.pumpAndSettle();

    final bar = find.byKey(const Key('moderation-decision-bar'));
    expect(bar, findsOneWidget);
    final before = tester.getRect(bar);
    final evidence = find.byKey(const Key('moderation-evidence'));
    final firstLine = find.text(_longSnapshot);
    final textBefore = tester.getRect(firstLine).top;

    await tester.drag(evidence, const Offset(0, -400));
    await tester.pumpAndSettle();

    // Kaydirma GERCEKTEN oldu mu? Olmadiysa asagidaki iddia bedavaya yesil.
    expect(
      tester.getRect(firstLine).top,
      lessThan(textBefore),
      reason: 'Kanit hic kaymadi; serit iddiasi olcum degil.',
    );
    expect(bar, findsOneWidget, reason: 'Serit kaydirmayla kayboldu.');
    expect(
      tester.getRect(bar),
      before,
      reason: 'PLAN §4.6: serit `Column`+`Expanded` ile sabitlenir, '
          '`Scaffold.bottomSheet` ile degil (depoda kayitli tuzak).',
    );
  });

  // --- LIDER EKI: vakadan hedefin dosyasina KOPRU ------------------------
  // PLAN §2.3 / WP-C olcut 5. WP-C varis noktasini kurdu; kopruyu vaka karti
  // tasir ve o dosya bu WP'nin yolunda. Widget'in VARLIGI kanit degil:
  // dokunuluyor ve dosyanin GERCEKTEN cizildigi metinle olculuyor.
  testWidgets('vakadan hedefin dosyasina tek dokunusla gidilir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final adminRepo = InMemoryAdminRepository(
      superAdminUserIds: const {'admin'},
    );
    addTearDown(adminRepo.dispose);
    final repo =
        InMemoryAdminModerationRepository(
            seed: [_case(targetId: _targetA, reportId: 'report-a')],
          )
          ..details['report-a'] = _detail(snapshot: 'aptal herif diye yazmis');

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
          adminRepositoryProvider.overrideWithValue(adminRepo),
          adminModerationRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AdminModerationTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(_row(_targetA));
    await tester.pumpAndSettle();
    expect(find.text('aptal herif diye yazmis'), findsOneWidget);

    final link = find.byKey(kAdminCaseTargetLinkKey);
    expect(link, findsOneWidget, reason: 'Vakadan kisiye kopru yok.');
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(find.byKey(kAdminPersonDossierKey), findsOneWidget);
    // Kabuk degil GOVDE: dosyanin icindeki gercek bir blok cizildi mi?
    expect(find.text('Ceza geçmişi'), findsOneWidget);
    expect(
      find.text('Bu kişiye daha önce yaptırım uygulanmadı.'),
      findsOneWidget,
    );
  });

  // --- KABLO: yuzey GERCEKTEN panelden ulasilir mi? ----------------------
  // "Bitmis backend + baglanmamis UI" sinifi: widget'i dogrudan kuran test,
  // onun gercek kabuga hic baglanmadigini goremez.
  testWidgets('inceleme akisi yonetim panelinin Kuyruk yuzeyinden acilir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final adminRepo = InMemoryAdminRepository(
      superAdminUserIds: const {'admin'},
    );
    addTearDown(adminRepo.dispose);
    await adminRepo.submitFeedback(
      userId: 'u1',
      kind: FeedbackTicketKind.bug,
      subject: 'Bildirim aksiyonu',
      message: 'Durdur butonu uygulamayi aciyor.',
    );
    final repo =
        InMemoryAdminModerationRepository(
            seed: [_case(targetId: _targetA, reportId: 'report-a')],
          )
          ..details['report-a'] = _detail(
            snapshot: 'aptal herif diye yazmis',
            attachmentPath: 'uid/evidence.png',
          );

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
          adminRepositoryProvider.overrideWithValue(adminRepo),
          adminModerationRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Kuyruk yuzeyi -> Icerik Sikayetleri bolumu.
    await tester.tap(
      find
          .descendant(
            of: find.byKey(kAdminMasterPaneKey),
            matching: find.text('İçerik Şikayetleri'),
          )
          .first,
    );
    await tester.pumpAndSettle();

    await tester.tap(_row(_targetA));
    await tester.pumpAndSettle();

    expect(find.text('aptal herif diye yazmis'), findsOneWidget);
    expect(find.byKey(const Key('moderation-decision-resolved')), findsOneWidget);
    expect(find.byKey(const Key('moderation-attachment-open')), findsOneWidget);
  });
}
