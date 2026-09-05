// WP-795 — vaka detayinda **Ic Notlar** bolumu.
//
// Sahibin onayladigi onizleme: Kullanicilar'dan sonra, yazisma katindan once;
// not listesi ("sen"/admin kimligi · tarih) + tek satir giris + "Not ekle".
//
// Migration yok: notlar vakanin AYNA biletine yazilir (`report_ugc`, 0110).
// Sayfa bileti `mirrorTicket` olarak alir; bilet yoksa bolum bunu soyler.
//
// 🔴 Olculen sey KULLANICININ GORDUGU seydir. `InMemoryAdminRepository`
// bilet notunu SAKLAMAZ (`fetchTicketNotes` sabit tek satir doner,
// `addTicketNote` yalniz bekler). Bu yuzden asagidaki `_NotesRepo` yalniz o
// iki ucu gercek bir bellek listesine baglar; geri kalan her sey bellek-ici
// depodur. Gonderimin sunucuya GITTIGI `added` ile, satirin ekranda
// BELIRDIGI metinle olculur — ikisi ayri iddiadir.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/feedback_ticket_note.dart';
import 'package:online_study_room/data/models/moderation_case.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/report_target.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/admin_moderation_repository.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_moderation_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/features/admin/detail/admin_case_detail_page.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _adminId = 'admin-1';
const _otherAdminId = 'admin-2';
const _targetA = '22222222-2222-4222-8222-222222222222';
const _mirrorTicketId = 't-mirror';

/// Ayna biletin notlarini GERCEKTEN saklayan depo. Bellek-ici ucun uzerine
/// yalniz olculecek iki davranisi ekler.
class _NotesRepo extends InMemoryAdminRepository {
  _NotesRepo() : super(superAdminUserIds: const {_adminId});

  final List<FeedbackTicketNote> notes = [];

  /// `ticketId|adminId|note` — sunucuya ne gittiginin kaydi.
  final List<String> added = [];
  int fetchCount = 0;
  bool fail = false;

  @override
  Future<List<FeedbackTicketNote>> fetchTicketNotes(String ticketId) async {
    fetchCount++;
    if (fail) throw const AdminException('Notlar okunamadi.');
    return notes.where((n) => n.ticketId == ticketId).toList();
  }

  @override
  Future<void> addTicketNote({
    required String ticketId,
    required String note,
    required String adminId,
  }) async {
    added.add('$ticketId|$adminId|$note');
    notes.add(
      FeedbackTicketNote(
        id: 'n${notes.length + 1}',
        ticketId: ticketId,
        adminId: adminId,
        note: note,
        createdAt: DateTime(2026, 9, 6, 10, 30),
      ),
    );
  }
}

FeedbackTicketNote _note({
  required String id,
  required String adminId,
  required String note,
}) => FeedbackTicketNote(
  id: id,
  ticketId: _mirrorTicketId,
  adminId: adminId,
  note: note,
  createdAt: DateTime(2026, 9, 6, 10, 30),
);

ModerationCase _case() => ModerationCase(
  caseId: 'case-report-a',
  targetType: ReportTargetType.message,
  targetId: _targetA,
  targetIdentity: const ModerationIdentity(id: _targetA, displayName: 'Mehmet'),
  status: ModerationCaseStatus.open,
  reportCount: 1,
  reasons: const ['hate'],
  latestAt: DateTime(2026, 8, 10, 9),
  reporters: const [
    ModerationIdentity(
      id: '11111111-1111-4111-8111-111111111111',
      displayName: 'Ayse',
    ),
  ],
  reportIds: const ['report-a'],
);

FeedbackTicket _mirror() => FeedbackTicket(
  id: _mirrorTicketId,
  userId: 'u1',
  kind: FeedbackTicketKind.feedback,
  subject: 'Konu',
  message: 'Mesaj',
  status: FeedbackTicketStatus.open,
  createdAt: DateTime(2026, 8, 10, 8),
  updatedAt: DateTime(2026, 8, 10, 8),
  type: FeedbackTicketType.report,
  ugcReportId: 'report-a',
);

ModerationCaseDetail _detail() => ModerationCaseDetail(
  snapshot: 'kanıt',
  details: 'derste surekli hakaret ediyor',
  contextMessages: const [],
  reportCount: 1,
  reason: 'hate',
  createdAt: DateTime(2026, 8, 10, 9),
  status: 'open',
  sanctions: const [],
);

Future<_NotesRepo> _pump(
  WidgetTester tester, {
  required FeedbackTicket? mirrorTicket,
  _NotesRepo? adminRepo,
  Size window = const Size(1280, 900),
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = adminRepo ?? _NotesRepo();
  addTearDown(repo.dispose);
  final moderationCase = _case();
  final moderationRepo = InMemoryAdminModerationRepository(
    seed: [moderationCase],
  )..details['report-a'] = _detail();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminModerationRepositoryProvider.overrideWithValue(moderationRepo),
        adminRepositoryProvider.overrideWithValue(repo),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            Profile(
              id: _adminId,
              displayName: 'Admin',
              createdAt: DateTime(2026),
            ),
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminCaseDetailPage(
          moderationCase: moderationCase,
          mirrorTicket: mirrorTicket,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

/// Kanit listesinin KENDI kaydiricisi. `.first` sart: `SelectableText` ve
/// `TextField` icindeki `EditableText` de bir `Scrollable` tasir.
Finder _scrollable() => find
    .descendant(
      of: find.byKey(kModerationEvidenceKey),
      matching: find.byType(Scrollable),
    )
    .first;

/// Bolumu kaydirilan listede gorunur yapar. `ensureVisible` YETMEZ: liste
/// tembel kurulur, gorunmeyen cocuk henuz agacta olmayabilir.
Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 120, scrollable: _scrollable());
  await tester.pumpAndSettle();
}

void main() {
  // --- KANIT 1: ayna bilet varken bolum gorunur, depodaki notlar listelenir --
  testWidgets('ayna bilet varken Ic Notlar bolumu ve depodaki notlar gorunur', (
    tester,
  ) async {
    final repo = _NotesRepo()
      ..notes.addAll([
        _note(id: 'n1', adminId: _otherAdminId, note: 'ilk uyari verildi'),
        _note(id: 'n2', adminId: _adminId, note: 'tekrar bakilacak'),
      ]);
    await _pump(tester, mirrorTicket: _mirror(), adminRepo: repo);

    final section = find.byKey(kAdminCaseNotesKey);
    await _reveal(tester, section);
    expect(section, findsOneWidget, reason: 'Bolum sayfada yok.');
    expect(find.text('İç Notlar'), findsOneWidget);
    expect(find.byKey(kAdminCaseNoteFieldKey), findsOneWidget);
    expect(find.byKey(kAdminCaseNoteSendKey), findsOneWidget);
    expect(find.text('Not ekle'), findsOneWidget);

    // Depodaki notlar EKRANDA: metin + kim · tarih.
    expect(repo.fetchCount, 1, reason: 'Sayfa notlari depodan okumadi.');
    expect(find.byKey(adminCaseNoteRowKey('n1')), findsOneWidget);
    expect(find.byKey(adminCaseNoteRowKey('n2')), findsOneWidget);
    expect(find.text('ilk uyari verildi'), findsOneWidget);
    expect(find.text('tekrar bakilacak'), findsOneWidget);
    expect(
      find.text('$_otherAdminId · 2026-09-06 10:30'),
      findsOneWidget,
      reason: 'Baska yoneticinin notu kimligiyle imzalanmali.',
    );
    expect(
      find.text('Sen · 2026-09-06 10:30'),
      findsOneWidget,
      reason: 'Oturumdaki yoneticinin notu "Sen" ile imzalanmali.',
    );
    expect(find.text('Henüz not yok.'), findsNothing);
    expect(
      find.text('Bu vakanın destek kaydı yok; iç not tutulamıyor.'),
      findsNothing,
    );

    // Yer: Kullanicilar'dan SONRA, yazisma katindan ONCE.
    final usersRow = find.byKey(adminCaseUserRowKey(_targetA));
    final fold = find.byKey(const Key('admin-case-contact-fold'));
    await _reveal(tester, fold);
    expect(
      tester.getRect(section).top,
      greaterThan(tester.getRect(usersRow).top),
      reason: 'Bolum Kullanicilar bolumunun altinda olmali.',
    );
    expect(
      tester.getRect(section).bottom,
      lessThanOrEqualTo(tester.getRect(fold).top),
      reason: 'Bolum yazisma katinin ustunde olmali.',
    );
    expect(tester.takeException(), isNull);
  });

  // --- KANIT 2: not gonderilir, depoya gider ve satir belirir --------------
  testWidgets(
    'not yazilip gonderilince depoya gider ve satir ekranda belirir',
    (tester) async {
      final repo = await _pump(tester, mirrorTicket: _mirror());
      await _reveal(tester, find.byKey(kAdminCaseNotesKey));
      expect(find.text('Henüz not yok.'), findsOneWidget);

      final field = find.byKey(kAdminCaseNoteFieldKey);
      await tester.enterText(field, '  ikinci uyari  ');
      await _reveal(tester, find.byKey(kAdminCaseNoteSendKey));
      await tester.tap(find.byKey(kAdminCaseNoteSendKey));
      await tester.pumpAndSettle();

      expect(
        repo.added,
        ['$_mirrorTicketId|$_adminId|ikinci uyari'],
        reason:
            'Not ayna bilete, oturumdaki yonetici kimligiyle ve kirpilmis '
            'gitmeli.',
      );
      expect(
        find.byKey(adminCaseNoteRowKey('n1')),
        findsOneWidget,
        reason: 'Gonderim sonrasi liste yenilenmedi; satir ekranda yok.',
      );
      expect(find.text('ikinci uyari'), findsOneWidget);
      expect(find.text('Sen · 2026-09-06 10:30'), findsOneWidget);
      expect(find.text('Henüz not yok.'), findsNothing);
      expect(
        tester.widget<TextField>(field).controller!.text,
        isEmpty,
        reason: 'Gonderilen metin giris alaninda kalmamali.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  // --- KANIT 3: bos not gonderilmez ---------------------------------------
  testWidgets('bos ya da yalniz bosluktan olusan not gonderilmez', (
    tester,
  ) async {
    final repo = await _pump(tester, mirrorTicket: _mirror());
    await _reveal(tester, find.byKey(kAdminCaseNoteSendKey));

    await tester.tap(find.byKey(kAdminCaseNoteSendKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(kAdminCaseNoteFieldKey), '   ');
    await tester.tap(find.byKey(kAdminCaseNoteSendKey));
    await tester.pumpAndSettle();

    expect(repo.added, isEmpty, reason: 'Bos not sunucuya gitti.');
    expect(repo.fetchCount, 1, reason: 'Bos gonderim listeyi yenilemez.');
    expect(find.text('Henüz not yok.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // --- KANIT 4: ayna bilet yoksa aciklama var, giris alani yok -------------
  testWidgets(
    'ayna bilet yoksa neden not tutulamadigi yazar, giris alani yok',
    (tester) async {
      final repo = await _pump(tester, mirrorTicket: null);

      final section = find.byKey(kAdminCaseNotesKey);
      await _reveal(tester, section);
      expect(find.text('İç Notlar'), findsOneWidget);
      expect(
        find.text('Bu vakanın destek kaydı yok; iç not tutulamıyor.'),
        findsOneWidget,
        reason: 'Sessiz bosluk degil; neden yazilmali.',
      );
      expect(find.byKey(kAdminCaseNoteFieldKey), findsNothing);
      expect(find.byKey(kAdminCaseNoteSendKey), findsNothing);
      expect(find.text('Not ekle'), findsNothing);
      expect(repo.fetchCount, 0, reason: 'Bilet yokken depo sorgulanmaz.');
      expect(tester.takeException(), isNull);
    },
  );

  // --- HATA YOLU: okuma hatasi yutulmaz -----------------------------------
  testWidgets('not okumasi hata verirse govde bos kalmaz, hata yazar', (
    tester,
  ) async {
    final repo = _NotesRepo()..fail = true;
    await _pump(tester, mirrorTicket: _mirror(), adminRepo: repo);
    await _reveal(tester, find.byKey(kAdminCaseNotesKey));

    expect(find.text('İç notlar okunamadı.'), findsOneWidget);
    expect(find.text('Henüz not yok.'), findsNothing);

    // Tekrar dene GERCEKTEN yeniden okur.
    repo.fail = false;
    await tester.tap(find.byTooltip('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(repo.fetchCount, 2);
    expect(find.text('İç notlar okunamadı.'), findsNothing);
    expect(find.text('Henüz not yok.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // --- LIDER SARTI: bolum karar seridini UZATMAZ, kaydirilan listede durur -
  testWidgets('dar telefonda bolum kaydirilan listede, serit 96 dp altinda', (
    tester,
  ) async {
    final repo = _NotesRepo()
      ..notes.addAll([
        for (var i = 0; i < 6; i++)
          _note(id: 'n$i', adminId: _adminId, note: 'not satiri $i'),
      ]);
    await _pump(
      tester,
      mirrorTicket: _mirror(),
      adminRepo: repo,
      window: const Size(360, 740),
    );

    final bar = find.byKey(kModerationDecisionBarKey);
    expect(bar, findsOneWidget);
    expect(
      tester.getRect(bar).height,
      lessThan(96),
      reason: 'Not bolumu karar seridini uzatti.',
    );

    final section = find.byKey(kAdminCaseNotesKey);
    await _reveal(tester, section);
    expect(
      find.descendant(
        of: find.byKey(kModerationEvidenceKey),
        matching: section,
      ),
      findsOneWidget,
      reason: 'Bolum kaydirilan listenin DISINDA; ekrani sabit yer kaplar.',
    );
    expect(
      tester.getRect(bar).height,
      lessThan(96),
      reason: 'Kaydirma sonrasi serit buyudu.',
    );
    expect(tester.takeException(), isNull);
  });
}
