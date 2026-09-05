// WP-770 — destek kaydinin TAM SAYFA detayi + dort kanitli hata.
//
// Sahip: *"kartta yalniz 'Detayli incele' olsun, basinca o kayda ozel ayri bir
// tam sayfa acilsin ve her sey orada olsun. baska bir ekrani istemiyorum."*
// Eski akis diyalog uzerine diyalog aciyordu (`tabs/admin_reports_tab.dart`:
// yanit diyalogu, ic not diyalogu, ek onizleme diyalogu — uc ayri kabuk).
//
// 🔴 Kapatilan hatalar ve kirmizi kanitlari (her biri asagida tek testtir):
//   (a) `_setStatus` yalniz `adminFeedbackTicketsProvider`i tazeliyordu; arsiv
//       gorunumunun izledigi `adminArchivedFeedbackTicketsProvider` bayat
//       kaliyordu (`admin_reports_tab.dart:283-284`).
//   (b) `_setArchived`in try/catch'i yoktu (`:293-307`) — yetki reddinde ekran
//       hicbir sey soylemiyordu.
//   (c) Ic not okumasi hata verince `_notes` null kaliyor, uc dal da `false`
//       oluyordu (`:476` + `:552-584`) → **bos govde**.
//   (d) `AdminException.message` (edge function cevabi) atilip yerine genel
//       "beklenmeyen hata" yaziliyordu (`:285-290`).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/feedback_ticket_note.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/features/admin/ticket/admin_ticket_detail_page.dart';
import 'package:online_study_room/features/profile/feedback_tickets_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _adminId = 'admin';
const _subject = 'Sayac geri sayimda duruyor';
const _body = 'Ekrani kapatinca sayac sifirlaniyor.';

/// Sayan/bozan depo. `InMemoryAdminRepository`nin uzerine yalniz olculecek
/// davranisi ekler; geri kalan her sey gercek bellek-ici uctur.
class _TicketRepo extends InMemoryAdminRepository {
  _TicketRepo() : super(superAdminUserIds: const {_adminId});

  /// Arsiv listesinin **kac kez** sunucuya sorduğu — (a)'nin olcusu.
  int archivedFetchCount = 0;
  bool notesFail = false;
  AdminException? archiveError;
  AdminException? statusError;

  @override
  Future<List<FeedbackTicket>> fetchFeedbackTickets(
    String userId, {
    FeedbackTicketStatus? status,
    FeedbackTicketType? type,
    bool includeArchived = false,
  }) {
    if (includeArchived) archivedFetchCount++;
    return super.fetchFeedbackTickets(
      userId,
      status: status,
      type: type,
      includeArchived: includeArchived,
    );
  }

  @override
  Future<List<FeedbackTicketNote>> fetchTicketNotes(String ticketId) {
    if (notesFail) {
      throw const AdminException('Notlar okunamadi.');
    }
    return super.fetchTicketNotes(ticketId);
  }

  @override
  Future<void> setFeedbackArchived({
    required String userId,
    required String ticketId,
    required bool archived,
  }) {
    final error = archiveError;
    if (error != null) throw error;
    return super.setFeedbackArchived(
      userId: userId,
      ticketId: ticketId,
      archived: archived,
    );
  }

  @override
  Future<void> updateFeedbackStatus({
    required String userId,
    required String ticketId,
    required FeedbackTicketStatus status,
  }) {
    final error = statusError;
    if (error != null) throw error;
    return super.updateFeedbackStatus(
      userId: userId,
      ticketId: ticketId,
      status: status,
    );
  }
}

class _RouteSpy extends NavigatorObserver {
  final pushed = <Route<dynamic>>[];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
  }
}

Future<FeedbackTicket> _seed(
  _TicketRepo repo, {
  String? attachmentPath,
  DateTime? archivedAt,
}) async {
  final ticket = await repo.submitFeedback(
    userId: 'u1',
    kind: FeedbackTicketKind.bug,
    subject: _subject,
    message: _body,
  );
  return ticket.copyWith(
    type: FeedbackTicketType.report,
    reporterDisplayName: 'Ayse',
    attachmentPath: attachmentPath,
    archivedAt: archivedAt,
  );
}

/// Kuyrugu taklit eden kosum: tek dugme detayi acar. `probe` arsiv listesini
/// **gercekten izleyen** bir dinleyicidir (Riverpod 3: dinleyicisiz saglayici
/// invalidate'ten sonra yeniden kurulmaz, olcu sessizce olur).
Widget _host(_TicketRepo repo, FeedbackTicket ticket, {_RouteSpy? spy}) {
  return ProviderScope(
    overrides: [
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          Profile(
            id: _adminId,
            displayName: 'Yonetici',
            createdAt: DateTime(2026),
          ),
        ),
      ),
      adminRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      navigatorObservers: [?spy],
      home: Scaffold(
        body: Column(
          children: [
            Consumer(
              builder: (context, ref, _) {
                ref.watch(adminArchivedFeedbackTicketsProvider(ticket.type));
                return const SizedBox.shrink();
              },
            ),
            Builder(
              builder: (context) => TextButton(
                key: const Key('open-detail'),
                onPressed: () =>
                    openAdminTicketDetail(context: context, ticket: ticket),
                child: const Text('ac'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Tam sayfa **tek** yuzeydir: telefonda alt bolumlere kaydirilarak inilir.
/// Olcum yuzeyi bu yuzden uzun tutulur; aksi halde `ListView` alt bolumleri
/// hic kurmaz ve "sayfada var mi" sorusu goruntu penceresi sorusuna doner.
void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _openDetail(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open-detail')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('detay tam sayfa acilir — diyalog degil', (tester) async {
    final repo = _TicketRepo();
    addTearDown(repo.dispose);
    final ticket = await _seed(repo);
    final spy = _RouteSpy();

    await tester.pumpWidget(_host(repo, ticket, spy: spy));
    await tester.pumpAndSettle();
    await _openDetail(tester);

    expect(
      spy.pushed.last,
      isA<MaterialPageRoute<void>>(),
      reason: 'sozlesme: tam sayfa rota (deponun deseni)',
    );
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Destek kaydı'), findsOneWidget);
  });

  testWidgets('mesaj, yazisma ve durum kontrolu ayni anda sayfadadir', (
    tester,
  ) async {
    _tallSurface(tester);
    final repo = _TicketRepo();
    addTearDown(repo.dispose);
    final ticket = await _seed(repo);

    await tester.pumpWidget(_host(repo, ticket));
    await tester.pumpAndSettle();
    await _openDetail(tester);

    // 1) Biletin kendi metni — secilebilir olmali (kopyalanabilir kanit).
    expect(
      find.byWidgetPredicate(
        (widget) => widget is SelectableText && widget.data == _body,
      ),
      findsOneWidget,
    );
    // 2) Yazisma **govdede**: bos kabuk degil, gercek gonderme yolu.
    expect(find.byType(FeedbackTicketConversationView), findsOneWidget);
    expect(find.byKey(const Key('feedback-send-reply')), findsOneWidget);
    // 3) Durum kontrolu ayni ekranda.
    expect(find.byKey(kAdminTicketStatusKey), findsOneWidget);
    expect(find.byKey(kAdminTicketArchiveKey), findsOneWidget);
  });

  testWidgets('ek yolu dolu bilette gorsel yuzeyi cizilir', (tester) async {
    _tallSurface(tester);
    final repo = _TicketRepo();
    addTearDown(repo.dispose);
    final ticket = await _seed(repo, attachmentPath: 'shot.png');

    await tester.pumpWidget(_host(repo, ticket));
    await tester.pumpAndSettle();
    await _openDetail(tester);

    expect(find.byKey(kAdminTicketAttachmentKey), findsOneWidget);
  });

  testWidgets('ek yoksa gorsel yuzeyi hic cizilmez', (tester) async {
    _tallSurface(tester);
    final repo = _TicketRepo();
    addTearDown(repo.dispose);
    final ticket = await _seed(repo);

    await tester.pumpWidget(_host(repo, ticket));
    await tester.pumpAndSettle();
    await _openDetail(tester);

    expect(find.byKey(kAdminTicketAttachmentKey), findsNothing);
  });

  testWidgets('(c) ic not okunamayinca govde bos kalmaz, sebebi yazar', (
    tester,
  ) async {
    _tallSurface(tester);
    final repo = _TicketRepo();
    addTearDown(repo.dispose);
    final ticket = await _seed(repo);
    repo.notesFail = true;

    await tester.pumpWidget(_host(repo, ticket));
    await tester.pumpAndSettle();
    await _openDetail(tester);

    expect(find.text('İç notlar okunamadı.'), findsOneWidget);
    expect(
      find.text('Henüz not yok.'),
      findsNothing,
      reason: '"not yok" ile "okunamadi" ayri seylerdir',
    );
  });

  testWidgets('(a) durum yazildiktan sonra ARSIV listesi de tazelenir', (
    tester,
  ) async {
    _tallSurface(tester);
    final repo = _TicketRepo();
    addTearDown(repo.dispose);
    final ticket = await _seed(repo);

    await tester.pumpWidget(_host(repo, ticket));
    await tester.pumpAndSettle();
    final before = repo.archivedFetchCount;
    expect(before, greaterThan(0), reason: 'dinleyici gercekten kuruldu');

    await _openDetail(tester);
    await tester.tap(find.text('Kapalı'));
    await tester.pumpAndSettle();

    // Kuyruga donuldugunde liste **yeniden** sorulmali. (Riverpod 3 ortulu
    // rotanin aboneligini duraklatir; kirli isaretlenmeyen saglayici donuste
    // de sorulmaz — eski kod tam olarak boyle davraniyordu.)
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(
      repo.archivedFetchCount,
      greaterThan(before),
      reason:
          'ekranin izledigi saglayici tazelenmeli (arsiv gorunumu bayat '
          'kaliyordu)',
    );
  });

  testWidgets('(b)+(d) arsivleme reddedilince sunucunun mesaji gorunur', (
    tester,
  ) async {
    _tallSurface(tester);
    final repo = _TicketRepo();
    addTearDown(repo.dispose);
    final ticket = await _seed(repo);
    repo.archiveError = const AdminException('Bu kaydı arşivleme yetkin yok.');

    await tester.pumpWidget(_host(repo, ticket));
    await tester.pumpAndSettle();
    await _openDetail(tester);

    await tester.tap(find.byKey(kAdminTicketArchiveKey));
    await tester.pumpAndSettle();

    expect(find.text('Bu kaydı arşivleme yetkin yok.'), findsOneWidget);
  });

  testWidgets('(d) durum yazimi reddedilince de sunucunun mesaji gorunur', (
    tester,
  ) async {
    _tallSurface(tester);
    final repo = _TicketRepo();
    addTearDown(repo.dispose);
    final ticket = await _seed(repo);
    repo.statusError = const AdminException('Durum kilitli: vaka kapali.');

    await tester.pumpWidget(_host(repo, ticket));
    await tester.pumpAndSettle();
    await _openDetail(tester);

    await tester.tap(find.text('Kapalı'));
    await tester.pumpAndSettle();

    expect(find.text('Durum kilitli: vaka kapali.'), findsOneWidget);
  });

  // Kriter 7: kullanici tarafi **degismez**. Yazisma govdesi ortak widget'a
  // cikti; diyalog kabugu, tek metin alani ve sona kaydirma aynen kalmali.
  group('kullanici tarafi korunur', () {
    Widget userApp(InMemoryAdminRepository repo) => ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            Profile(
              id: 'u1',
              displayName: 'Kullanici',
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
    );

    testWidgets('bilet satiri hala DIYALOG acar ve tek metin alani vardir', (
      tester,
    ) async {
      final repo = _TicketRepo();
      addTearDown(repo.dispose);
      final ticket = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.bug,
        subject: _subject,
        message: _body,
      );

      await tester.pumpWidget(userApp(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('feedback-ticket-${ticket.id}')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(Key('feedback-conversation-${ticket.id}')),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      // Mevcut testler `find.byType(TextField)` ile yazar; ikinci bir alan
      // eklenirse o testler sessizce kirilir.
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Ek ayrinti.');
      await tester.tap(find.byKey(const Key('feedback-send-reply')));
      await tester.pumpAndSettle();
      expect(
        (await repo.fetchTicketMessages(
          userId: 'u1',
          ticketId: ticket.id,
        )).last.message,
        'Ek ayrinti.',
      );
    });

    testWidgets('sona kaydirma korunur: en yeni gorunur, en eski gorunmez', (
      tester,
    ) async {
      final repo = _TicketRepo();
      addTearDown(repo.dispose);
      final ticket = await repo.submitFeedback(
        userId: 'u1',
        kind: FeedbackTicketKind.bug,
        subject: _subject,
        message: 'Ilk kayit.',
      );
      for (var i = 1; i <= 30; i++) {
        await repo.sendTicketMessage(
          userId: i.isEven ? _adminId : 'u1',
          ticketId: ticket.id,
          message: 'Mesaj $i',
        );
      }

      await tester.pumpWidget(userApp(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('feedback-ticket-${ticket.id}')));
      await tester.pumpAndSettle();

      expect(find.text('Mesaj 30'), findsOneWidget);
      expect(find.text('Mesaj 1'), findsNothing);
    });
  });
}
