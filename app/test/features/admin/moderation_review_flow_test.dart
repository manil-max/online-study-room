// WP-768 / WP-769 — TEK KUYRUK + VAKANIN KENDI SAYFASI.
//
// Bu dosya WP-B'nin (kanit + karar tek ekranda) kabul olcutlerini devralir ve
// sahip kararina gore yeniden yazar:
//
//   *"sikayet/oneri/soru gibi filtrelenebilen bir liste olsun. Orada her kartta
//    sadece detayli incele butonu olsun ve ona basinca ayri bir sayfa acilsin o
//    karta ozel ve her sey orada olsun; baska bir ekrani istemiyorum."*
//
// Degisen sey duzendir, sozlesme degil: kanit hala karar dugmesiyle ayni anda
// agactadir — ama artik bir bolmede degil, vakanin **kendi sayfasinda**.
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
import 'package:online_study_room/features/admin/cards/admin_work_card.dart';
import 'package:online_study_room/features/admin/detail/admin_case_detail_page.dart';
import 'package:online_study_room/features/admin/detail/admin_user_profile_page.dart';
import 'package:online_study_room/features/admin/queue/admin_queue_entry.dart';
import 'package:online_study_room/features/admin/queue/admin_queue_view.dart';
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

ModerationCaseDetail _detail({
  required String snapshot,
  String? attachmentPath,
}) => ModerationCaseDetail(
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
    ModerationSanctionHistoryEntry(action: 'mute_24h', reason: 'onceki uyari'),
  ],
);

FeedbackTicket _ticket({
  required String id,
  required FeedbackTicketType type,
  String subject = 'Konu',
  String message = 'Mesaj',
  String? ugcReportId,
}) => FeedbackTicket(
  id: id,
  userId: 'u1',
  kind: FeedbackTicketKind.feedback,
  subject: subject,
  message: message,
  status: FeedbackTicketStatus.open,
  createdAt: DateTime(2026, 8, 10, 8),
  updatedAt: DateTime(2026, 8, 10, 8),
  type: type,
  ugcReportId: ugcReportId,
);

Future<void> _pumpQueue(
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
        home: Scaffold(body: AdminQueueView()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Karttaki **tek** dugme.
Finder _open(String targetId) =>
    find.byKey(Key('admin-queue-open-case:message:$targetId'));

Future<void> _pumpCase(
  WidgetTester tester,
  InMemoryAdminModerationRepository repo,
  ModerationCase moderationCase, {
  Size window = const Size(1280, 900),
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [adminModerationRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminCaseDetailPage(moderationCase: moderationCase),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // --- WP-768 KABUL 1: birlestirme kurallari (saf) -----------------------
  group('buildAdminQueue', () {
    test('UGC sikayetinin AYNA bileti listede ikinci kez gorunmez', () {
      final moderationCase = _case(targetId: _targetA, reportId: 'report-a');
      final entries = buildAdminQueue(
        cases: [moderationCase],
        tickets: [
          // `report_ugc` her sikayet icin bir bilet de acar (0110:160-167).
          _ticket(
            id: 't-mirror',
            type: FeedbackTicketType.report,
            ugcReportId: 'report-a',
          ),
          _ticket(id: 't-soru', type: FeedbackTicketType.question),
        ],
        appeals: const [],
      );

      expect(
        entries.whereType<AdminQueueTicketEntry>().map((e) => e.ticket.id),
        ['t-soru'],
        reason:
            'Ayni sikayet hem vaka hem bilet olarak listelenirse sahip ayni '
            'isi iki kez gorur.',
      );
      expect(entries.whereType<AdminQueueCaseEntry>(), hasLength(1));
    });

    test('karara baglanmis itiraz kuyrukta durmaz', () {
      final entries = buildAdminQueue(
        cases: const [],
        tickets: const [],
        appeals: [
          ModerationAppeal.fromWire(const {
            'id': 'a-open',
            'sanction_id': 's1',
            'statement': 'ben yapmadim',
            'status': 'open',
            'created_at': '2026-08-01T10:00:00Z',
          }),
          ModerationAppeal.fromWire(const {
            'id': 'a-done',
            'sanction_id': 's2',
            'statement': 'karar verildi',
            'status': 'upheld',
            'created_at': '2026-08-02T10:00:00Z',
          }),
        ],
      );
      expect(entries.map((e) => e.id), ['appeal:a-open']);
    });

    test('acik isler kapanmislarin ustunde durur', () {
      final entries = buildAdminQueue(
        cases: const [],
        tickets: [
          _ticket(id: 't-eski', type: FeedbackTicketType.question),
          FeedbackTicket(
            id: 't-kapali',
            userId: 'u1',
            kind: FeedbackTicketKind.feedback,
            subject: 'Kapali',
            message: 'x',
            status: FeedbackTicketStatus.closed,
            createdAt: DateTime(2026, 9),
            // Daha YENI ama kapali: yine de altta kalmali.
            updatedAt: DateTime(2026, 9),
          ),
        ],
        appeals: const [],
      );
      expect(entries.map((e) => e.id), ['ticket:t-eski', 'ticket:t-kapali']);
    });

    test('adminMirrorTicket vakanin destek kaydini bulur', () {
      final moderationCase = _case(targetId: _targetA, reportId: 'report-a');
      final mirror = _ticket(
        id: 't-mirror',
        type: FeedbackTicketType.report,
        ugcReportId: 'report-a',
      );
      expect(
        adminMirrorTicket([mirror], moderationCase)?.id,
        't-mirror',
        reason:
            'Sikayet edenle yazismanin tek kanali bu bilettir; kuyruk onu '
            'gizledigi icin bagi vaka detayi kurmali.',
      );
      expect(
        adminMirrorTicket(
          [_ticket(id: 't-baska', type: FeedbackTicketType.report)],
          moderationCase,
        ),
        isNull,
      );
    });
  });

  // --- WP-768 KABUL 2: kartta TEK dugme ---------------------------------
  testWidgets('kuyruk kartinda yalniz "Detayli incele" dugmesi var', (
    tester,
  ) async {
    final repo = InMemoryAdminModerationRepository(
      seed: [_case(targetId: _targetA, reportId: 'report-a')],
    )..details['report-a'] = _detail(snapshot: 'aptal herif diye yazmis');
    await _pumpQueue(tester, repo);

    expect(_open(_targetA), findsOneWidget, reason: 'Tek dugme yok.');
    expect(find.text('Detaylı incele'), findsOneWidget);

    // Sahibin sikayeti: "tus neyi ne oldugu belli degil". Gizli menuler kalkti.
    expect(
      find.byKey(const Key('moderation-secondary-actions')),
      findsNothing,
      reason: 'Karttaki `…` menusu (yaptirim/karantina/kopyala) kaldirildi.',
    );
    expect(
      find.byType(PopupMenuButton<ModerationCaseStatus>),
      findsNothing,
      reason: 'Durum hapi artik menu acmaz; durum detay sayfasinda degisir.',
    );
    // Durum yine de OKUNUR: bilgi kaybi yok.
    expect(find.byType(AdminWorkStatusLabel), findsOneWidget);
    expect(find.text('Açık'), findsOneWidget);
  });

  // --- WP-768 KABUL 3: tur filtresi -------------------------------------
  testWidgets('filtre cipi turu suzer; bos sonuctan filtre temizlenir', (
    tester,
  ) async {
    final adminRepo = InMemoryAdminRepository(
      superAdminUserIds: const {'admin'},
    );
    addTearDown(adminRepo.dispose);
    await adminRepo.submitFeedback(
      userId: 'u1',
      kind: FeedbackTicketKind.feedback,
      subject: 'Karanlik tema',
      message: 'Daha koyu olsun',
    );
    final repo = InMemoryAdminModerationRepository(
      seed: [_case(targetId: _targetA, reportId: 'report-a')],
    )..details['report-a'] = _detail(snapshot: 'aptal herif diye yazmis');

    tester.view.physicalSize = const Size(1280, 900);
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
          adminRepositoryProvider.overrideWithValue(adminRepo),
          adminModerationRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AdminQueueView()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Once GOVDE gercek mi: iki tur de listede mi?
    expect(find.text('Karanlik tema'), findsOneWidget);
    expect(_open(_targetA), findsOneWidget);

    // Oneri filtresi: sikayet duser.
    await tester.tap(
      find.byKey(adminQueueFilterKey(AdminQueueCategory.suggestion)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Karanlik tema'), findsOneWidget);
    expect(_open(_targetA), findsNothing);

    // Soru filtresi: hicbir sey kalmaz ve filtre temizlenebilir.
    await tester.tap(
      find.byKey(adminQueueFilterKey(AdminQueueCategory.question)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(kAdminQueueEmptyKey), findsOneWidget);
    expect(find.text('Bekleyen iş yok.'), findsOneWidget);
    await tester.tap(find.text('Filtreyi temizle'));
    await tester.pumpAndSettle();
    expect(find.text('Karanlik tema'), findsOneWidget);
    expect(_open(_targetA), findsOneWidget);
  });

  // --- WP-769 KABUL 1: sunucunun gonderdigi alanlar istemcide DURUYOR ----
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
      reason:
          'ADMIN-PANEL-PLAN §2.1: kullanicinin ekledigi ekran goruntusu '
          'ayristirilmiyordu.',
    );
    expect(detail.reason, 'hate');
    expect(detail.createdAt, isNotNull);
    expect(detail.status, 'open');
    expect(detail.reportCount, 3);
    expect(
      detail.sanctions.single.moderationAction,
      ModerationAction.mute24h,
      reason:
          'history.sanctions[].action atiliyordu; "bu kisiye daha once ne '
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

  // --- WP-769 KABUL 2: dugme AYRI SAYFA acar ----------------------------
  testWidgets('"Detayli incele" vakanin kendi sayfasini acar', (tester) async {
    final repo = InMemoryAdminModerationRepository(
      seed: [_case(targetId: _targetA, reportId: 'report-a')],
    )..details['report-a'] = _detail(snapshot: 'aptal herif diye yazmis');
    await _pumpQueue(tester, repo);

    expect(find.byKey(kAdminCaseDetailKey), findsNothing);
    await tester.tap(_open(_targetA));
    await tester.pumpAndSettle();

    expect(
      find.byKey(kAdminCaseDetailKey),
      findsOneWidget,
      reason: 'Sahip karti degil AYRI SAYFA istedi.',
    );
    expect(find.text('Şikâyet detayı'), findsOneWidget);
    // Kuyruk artik ekranda degil: sayfa tam ekran.
    expect(find.byKey(kAdminQueueListKey), findsNothing);
    // Govde gercek mi?
    expect(find.text('aptal herif diye yazmis'), findsOneWidget);
  });

  // --- WP-769 KABUL 3: kanit ve karar AYNI ANDA -------------------------
  testWidgets('sayfada icerik metni ve "Cozuldu" ayni anda agacta', (
    tester,
  ) async {
    final moderationCase = _case(targetId: _targetA, reportId: 'report-a');
    final repo = InMemoryAdminModerationRepository(seed: [moderationCase])
      ..details['report-a'] = _detail(snapshot: 'aptal herif diye yazmis');
    await _pumpCase(tester, repo, moderationCase);

    expect(
      find.text('aptal herif diye yazmis'),
      findsOneWidget,
      reason: 'Sikayet edilen icerik ekranda degil.',
    );
    expect(
      find.byKey(kModerationDecisionResolvedKey),
      findsOneWidget,
      reason:
          'ADMIN-PANEL-PLAN §2.2 kok neden: kanitin gorundugu yuzey ile '
          'kararin verildigi yuzey ayni anda ekranda degildi.',
    );
    // Sikayet edenin yazdigi aciklama da ayni ekranda.
    expect(find.text('derste surekli hakaret ediyor'), findsOneWidget);

    // Sayfanin geri kalani (taraflar, hedefin dosyasi, ceza gecmisi) ayni
    // listede; kaydirilarak okunur, baska ekrana gecilmez.
    await tester.drag(
      find.byKey(kModerationEvidenceKey),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(find.text('Taraflar'), findsOneWidget);
    expect(
      find.byKey(kModerationDecisionResolvedKey),
      findsOneWidget,
      reason: 'Karar seridi kaydirmayla kaybolmamali.',
    );
    // 🔴 IDDIA YON DEGISTIRDI (WP-775). Eskiden ceza gecmisi bu sayfada duz
    // metin satirlar halinde basiliyordu ve iddia onu ariyordu.
    //
    // Sahibin 2026-09-05 istegi: *"ceza gecmisi kismi yerine kullanicilar
    // olsun... basinca detayli profil ekrani acilsin."* Gecmis artik kisinin
    // profilinde, tarih / tur / gerekce ayri sutunlarda. Vaka sayfasinda
    // kalan sey, panele girmeden karar verebilmek icin tek bakislik isaret.
    //
    // Olculen: gecmis bu sayfadan KALKTI ama kisiye giden yol DURUYOR.
    expect(
      find.textContaining('24 saat yazma kısıtı'),
      findsNothing,
      reason: 'Ceza gecmisi profil paneline tasindi.',
    );
    expect(
      find.byKey(adminCaseUserRowKey(_targetA)),
      findsOneWidget,
      reason: 'Gecmise giden yol kapanmamali; satir yerinde durmali.',
    );
  });

  // --- WP-775 KABUL 4: kullanicilar TEK bolumde, ayrinti profilde --------
  //
  // 🔴 IDDIA YON DEGISTIRDI (zayiflatilmadi). WP-769'da bu test "hedefin
  // aktif kisiti ve yaptirim yolu sayfanin icinde" diyordu; sahibin o
  // zamanki sarti "bu panele hic ihtiyacim olmasin"di ve dogruydu.
  //
  // Sahip 2026-09-05'te kendi kurdugu bu yapiya bakti ve sordu:
  // *"hedef dosyasini anlamadim, kisit uygula kismi yaptirim degil mi
  // zaten?"* Haklıydı: `Kisi dosyasi > Kisit uygula` ile karar seridindeki
  // `Yaptirim` AYNI islemdi, iki ayri yerde duruyordu.
  //
  // Yeni sozlesme: yaptirim KISIYE uygulanir ve kisinin profilinde, oranlari
  // ile ceza gecmisi gorunurken verilir. Vaka sayfasinda kalan sey, karari
  // panele girmeden verebilmek icin tek bakislik isarettir — yani WP-769'un
  // asil derdi korunur.
  testWidgets('taraflar ve gecmis tek Kullanicilar bolumunde toplanir', (
    tester,
  ) async {
    final moderationCase = _case(targetId: _targetA, reportId: 'report-a');
    final repo = InMemoryAdminModerationRepository(seed: [moderationCase])
      ..details['report-a'] = _detail(snapshot: 'aptal herif diye yazmis');
    await _pumpCase(tester, repo, moderationCase);

    expect(
      find.byKey(adminCaseUserRowKey(_targetA)),
      findsOneWidget,
      reason: 'Sikayet edilen kisi satiri Kullanicilar bolumunde olmali.',
    );
    expect(
      find.byKey(kAdminCaseSanctionApplyKey),
      findsNothing,
      reason:
          'Yaptirim vaka sayfasindan KALKTI; ayni islem iki yerde duruyordu.',
    );
  });

  // --- WP-769 KABUL 5: ek gorsel onizleme -------------------------------
  testWidgets('ek yolu dolu vakada gorsel onizleme dugmesi bulunur', (
    tester,
  ) async {
    final withAttachment = _case(targetId: _targetA, reportId: 'report-a');
    final withoutAttachment = _case(
      targetId: _targetB,
      reportId: 'report-b',
      name: 'Kemal',
    );
    final repo =
        InMemoryAdminModerationRepository(
            seed: [withAttachment, withoutAttachment],
          )
          ..details['report-a'] = _detail(
            snapshot: 'aptal herif diye yazmis',
            attachmentPath: 'uid/evidence.png',
          )
          ..details['report-b'] = _detail(snapshot: 'spam linki atmis');

    await _pumpCase(tester, repo, withAttachment);
    expect(find.text('aptal herif diye yazmis'), findsOneWidget);
    expect(
      find.byKey(const Key('moderation-attachment-open')),
      findsOneWidget,
      reason:
          'ADMIN-PANEL-PLAN §5 WP-B kabul 2: ekran goruntusu admin e hic '
          'gosterilmiyordu (0097 attachment_path donduruyor).',
    );

    // Sabotaj kapisi: eki OLMAYAN vakada dugme HIC cikmamali.
    await _pumpCase(tester, repo, withoutAttachment);
    expect(find.text('spam linki atmis'), findsOneWidget);
    expect(
      find.byKey(const Key('moderation-attachment-open')),
      findsNothing,
      reason: 'Eksiz vakada onizleme dugmesi cizilmemeli.',
    );
    expect(find.text('Şikâyete görsel eklenmemiş.'), findsOneWidget);
  });

  // --- WP-769 KABUL 6: karar + geri alma --------------------------------
  testWidgets('karar verilince "Geri al" belirir ve gercekten geri alir', (
    tester,
  ) async {
    final moderationCase = _case(targetId: _targetA, reportId: 'report-a');
    final repo = InMemoryAdminModerationRepository(seed: [moderationCase])
      ..details['report-a'] = _detail(snapshot: 'aptal herif diye yazmis');
    await _pumpCase(tester, repo, moderationCase);

    await tester.tap(find.byKey(kModerationDecisionResolvedKey));
    await tester.pumpAndSettle();

    expect(repo.statusWrites.single, 'message:$_targetA=resolved');
    expect(
      find.byKey(kModerationUndoBarKey),
      findsOneWidget,
      reason:
          'PLAN §4.4.2: geri alinabilir karar teyit degil 10 sn serit ister.',
    );

    await tester.tap(find.byKey(kModerationUndoButtonKey));
    await tester.pumpAndSettle();

    expect(repo.statusWrites.last, 'message:$_targetA=open');
    expect(find.byKey(kModerationUndoBarKey), findsNothing);
    final queue = await repo.fetchQueue();
    expect(queue.first.status, ModerationCaseStatus.open);
  });

  // --- WP-769 HATA (a): SIFIR satirda basari iddia edilmez --------------
  //
  // `admin_set_ugc_report_group_status` `returns bigint`; `0104` oncesi
  // kapanmis raporlarin vakasi yok ve RPC sifir satir gunceller. Ekran bu
  // sayiyi hic okumuyordu: "Cozuldu" yazip geri alma seridi aciyordu.
  testWidgets('sunucu 0 satir guncellerse ekran "Cozuldu" demez', (
    tester,
  ) async {
    final orphan = _case(targetId: _targetA, reportId: 'report-a');
    // Vaka repoda YOK -> setCaseStatus 0 doner (in-memory repo:104).
    final repo = InMemoryAdminModerationRepository()
      ..details['report-a'] = _detail(snapshot: 'aptal herif diye yazmis');
    await _pumpCase(tester, repo, orphan);

    await tester.tap(find.byKey(kModerationDecisionResolvedKey));
    await tester.pumpAndSettle();

    expect(repo.statusWrites, isEmpty);
    expect(
      find.text('Bu kayıt bir vakaya bağlı değil; durum sunucuda değişmedi.'),
      findsOneWidget,
      reason: 'Sifir satirda basari iddia edilemez.',
    );
    expect(
      find.byKey(kModerationUndoBarKey),
      findsNothing,
      reason: 'Yapilmamis bir kararin "geri al"i olmaz.',
    );
  });

  // --- LIDER SARTI: karar seridi kaydirmayla KAYBOLMAZ ------------------
  testWidgets('karar seridi uzun kanit kaydirilinca piksel piksel yerinde', (
    tester,
  ) async {
    final moderationCase = _case(targetId: _targetA, reportId: 'report-a');
    final repo = InMemoryAdminModerationRepository(seed: [moderationCase])
      ..details['report-a'] = _detail(snapshot: _longSnapshot);
    await _pumpCase(
      tester,
      repo,
      moderationCase,
      window: const Size(1280, 620),
    );

    final bar = find.byKey(kModerationDecisionBarKey);
    expect(bar, findsOneWidget);
    final before = tester.getRect(bar);
    final evidence = find.byKey(kModerationEvidenceKey);
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
      reason:
          'PLAN §4.6: serit `Column`+`Expanded` ile sabitlenir, '
          '`Scaffold.bottomSheet` ile degil (depoda kayitli tuzak).',
    );
  });

  /// 🔴 DIKIS NOBETCISI — bu depoda tekrar eden kusur icin.
  ///
  /// Profil paneli ayri bir lane'de yazildi ve o lane kendi raporunda
  /// *"ekran hicbir yerden acilmiyor"* diye bildirdi. Bu deponun kayitli
  /// deseni tam olarak budur: iki ajan birbirinin SAHIP yoluna saygi gosterir,
  /// ozellik ortada baglanmadan kalir, testler yesil gecer ve ozellik YOKTUR.
  ///
  /// Iddia paneli DEGIL, dokunusun onu ACTIGINI olcer.
  testWidgets('kullanici satirina dokununca profil paneli GERCEKTEN acilir', (
    tester,
  ) async {
    final moderationCase = _case(targetId: _targetA, reportId: 'report-a');
    final repo = InMemoryAdminModerationRepository(seed: [moderationCase])
      ..details['report-a'] = _detail(snapshot: 'kanıt');
    await _pumpCase(tester, repo, moderationCase);

    final row = find.byKey(adminCaseUserRowKey(_targetA));
    expect(row, findsOneWidget);
    await tester.ensureVisible(row);
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(
      find.byKey(kAdminUserProfileKey),
      findsOneWidget,
      reason:
          'Satir dokunulabiliyor ama profil acilmiyor: ozellik baglanmamis.',
    );
  });

  /// 🔴 SAHIBIN ASIL SIKAYETI OLCULUR: *"altta reject vs nin oldugu kisimda
  /// ... cok yer kapliyor."*
  ///
  /// Eski serit dar telefonda 196 dp idi: baslik 20 + gerekce alani 48 +
  /// iki satira saran dort dugme 88 + ic bosluk ve aralar 40. Ekranin
  /// dortte biri, daha kaniti okurken.
  ///
  /// Bu iddia SAYIYI kilitler, "daha kucuk" gibi olculemez bir sey degil.
  /// 96 dp esigi kasten gercek olcumun (~68) uzerinde: dugme yuksekligi tema
  /// ile birkac piksel oynayabilir, ama iki satira SARARSA esik derhal asilir.
  testWidgets('karar seridi dar telefonda 96 dp ustune cikmaz', (tester) async {
    final moderationCase = _case(targetId: _targetA, reportId: 'report-a');
    final repo = InMemoryAdminModerationRepository(seed: [moderationCase])
      ..details['report-a'] = _detail(snapshot: 'kanıt');
    await _pumpCase(
      tester,
      repo,
      moderationCase,
      window: const Size(360, 740),
    );

    final bar = find.byKey(kModerationDecisionBarKey);
    expect(bar, findsOneWidget);
    expect(
      tester.getRect(bar).height,
      lessThan(96),
      reason:
          'Serit yine iki satira sardi ya da kalici bir alan geri geldi; '
          'sahibin sikayeti aynen geri gelir.',
    );
    expect(tester.takeException(), isNull);
  });

  // 🔴 IDDIA YON DEGISTIRDI (WP-775). Eski test yaptirimi KARAR SERIDINDEN
  // uyguluyordu. Serit 196 dp idi ve sahip cihazda gorup "cok yer kapliyor"
  // dedi; olculdu ki gerekce alani seridin yarisini kapliyor ama dort
  // eylemden yalniz BIRI (karantina) onu okuyor — `setCaseStatus` imzasinda
  // gerekce alani YOK.
  //
  // Serit artik tek satir: Reddet · Coz · tasma menusu. Yaptirim kisiye ait
  // oldugu icin profil panelinde. Bu test seridin KUCULDUGUNU degil,
  // ICERIGINI olcer: yaptirim dugmesi seritte OLMAMALI, iki karar dugmesi
  // OLMALI.
  testWidgets('karar seridi tek satir: iki karar + tasma menusu', (
    tester,
  ) async {
    final moderationCase = _case(targetId: _targetA, reportId: 'report-a');
    final repo = InMemoryAdminModerationRepository(seed: [moderationCase])
      ..details['report-a'] = _detail(snapshot: 'kanıt');
    await _pumpCase(
      tester,
      repo,
      moderationCase,
      window: const Size(1366, 768),
    );

    expect(find.byKey(kModerationDecisionRejectedKey), findsOneWidget);
    expect(find.byKey(kModerationDecisionResolvedKey), findsOneWidget);
    expect(find.byKey(kModerationDecisionMoreKey), findsOneWidget);

    expect(
      find.byKey(kModerationDecisionReasonKey),
      findsNothing,
      reason:
          'Kalici gerekce alani kalkti: dort eylemden yalniz biri okuyordu.',
    );

    // Karantina tasma menusunde durur ve gerekceyi ACILDIGINDA sorar.
    await tester.tap(find.byKey(kModerationDecisionMoreKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(kModerationDecisionQuarantineKey));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('moderation-reason-field')),
      findsOneWidget,
      reason: 'Gerekce, GEREKTIGI anda sorulmali.',
    );
  });

  // --- WP-769 KABUL 7: itiraz kendi sayfasinda karara baglanir -----------
  testWidgets('itiraz karti yaptirimi yazar, karar kendi sayfasinda verilir', (
    tester,
  ) async {
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
    await _pumpQueue(tester, repo);

    // Kartta: hangi cezaya itiraz edildigi YAZAR, karar dugmesi YOKTUR.
    expect(find.text('ben yapmadim'), findsOneWidget);
    expect(
      find.textContaining('7 gün askıya al'),
      findsOneWidget,
      reason:
          'ADMIN-PANEL-PLAN §2.1: admin HANGI cezaya itiraz edildigini '
          'gormeden "koru/kaldir" diyordu.',
    );
    expect(find.byKey(const Key('appeal-overturn-appeal-1')), findsNothing);

    await tester.tap(find.byKey(const Key('admin-queue-open-appeal:appeal-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('appeal-uphold-appeal-1')), findsOneWidget);
    expect(find.byKey(const Key('appeal-overturn-appeal-1')), findsOneWidget);
    expect(find.text('tekrarlayan hakaret'), findsOneWidget);
  });

  // --- KABLO: yuzey GERCEKTEN panelden ulasilir mi? ----------------------
  // "Bitmis backend + baglanmamis UI" sinifi: widget'i dogrudan kuran test,
  // onun gercek kabuga hic baglanmadigini goremez.
  testWidgets('kuyruk ve vaka sayfasi yonetim panelinden acilir', (
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

    // Kuyruk yuzeyi varsayilan; ARA BOLUM SECIMI YOK (tek liste).
    expect(find.byKey(kAdminQueueListKey), findsOneWidget);
    // Sikayet ve destek kaydi AYNI listede.
    expect(find.text('Bildirim aksiyonu'), findsOneWidget);
    expect(_open(_targetA), findsOneWidget);

    await tester.tap(_open(_targetA));
    await tester.pumpAndSettle();

    expect(find.byKey(kAdminCaseDetailKey), findsOneWidget);
    expect(find.text('aptal herif diye yazmis'), findsOneWidget);
    expect(find.byKey(kModerationDecisionResolvedKey), findsOneWidget);
    expect(find.byKey(const Key('moderation-attachment-open')), findsOneWidget);
  });
}
