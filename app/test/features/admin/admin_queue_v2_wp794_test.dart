// WP-794 — admin kuyrugu v2: Bekleyen / Arsiv gorunumleri.
//
// Sahip onayli onizleme: iki segment (Bekleyen N / Arsiv N), sayili tur
// cipleri, siralama cipi (En yeni <-> En eski), Arsiv'de arsivlenmis
// biletler + "Geri ac" / "Arsivden cikar", Bekleyen'de "Incelemeye al".
//
// 🔴 OLCULEN SEY KULLANICININ GORDUGUDUR: her iddia cizilen karti, cip
// metnini, kartlarin ekrandaki sirasini ya da sahte deponun yazdigi satiri
// olcer; saglayicinin dondugu listeyi degil. Bilet tarafi gercek yoldan
// gelir: `InMemoryAdminRepository` bileti acar, arsivler; ekran onu
// `adminArchivedFeedbackTicketsProvider` uzerinden okur.
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
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/features/admin/queue/admin_queue_entry.dart';
import 'package:online_study_room/features/admin/queue/admin_queue_view.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _adminId = 'admin';
const _targetA = '22222222-2222-4222-8222-222222222222';
const _targetB = '33333333-3333-4333-8333-333333333333';

ModerationCase _case({
  String id = _targetA,
  ModerationCaseStatus status = ModerationCaseStatus.open,
  DateTime? latestAt,
  String? caseId = 'case-1',
  int reportCount = 1,
}) => ModerationCase(
  targetType: ReportTargetType.message,
  targetId: id,
  targetIdentity: ModerationIdentity(id: id, displayName: 'Mehmet'),
  status: status,
  reportCount: reportCount,
  reasons: const ['hate'],
  latestAt: latestAt ?? DateTime.now(),
  reporters: const [ModerationIdentity(id: 'r1', displayName: 'Ayse')],
  reportIds: ['report-$id'],
  caseId: caseId,
);

Finder _open(String id) =>
    find.byKey(Key('admin-queue-open-case:message:$id'));
Finder _row(String id) => find.byKey(Key('admin-queue-row-case:message:$id'));
Finder _claim(String id) =>
    find.byKey(Key('admin-queue-claim-case:message:$id'));
Finder _reopen(String id) =>
    find.byKey(Key('admin-queue-reopen-case:message:$id'));
Finder _unarchive(FeedbackTicket ticket) =>
    find.byKey(Key('admin-queue-unarchive-ticket:${ticket.id}'));

InMemoryAdminRepository _adminRepo() =>
    InMemoryAdminRepository(superAdminUserIds: {_adminId});

/// Bilet GERCEK yoldan: kullanici acar, yonetici arsivler.
Future<FeedbackTicket> _seedTicket(
  InMemoryAdminRepository admin, {
  required String subject,
  bool archived = false,
}) async {
  final ticket = await admin.submitFeedback(
    userId: 'u1',
    kind: FeedbackTicketKind.feedback,
    subject: subject,
    message: 'govde',
  );
  if (archived) {
    await admin.setFeedbackArchived(
      userId: _adminId,
      ticketId: ticket.id,
      archived: true,
    );
  }
  return ticket;
}

Future<void> _pump(
  WidgetTester tester, {
  required InMemoryAdminModerationRepository moderation,
  InMemoryAdminRepository? admin,
  double width = 390,
  double height = 2400,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            Profile(
              id: _adminId,
              displayName: 'Admin',
              createdAt: DateTime(2026),
            ),
          ),
        ),
        adminRepositoryProvider.overrideWithValue(admin ?? _adminRepo()),
        adminModerationRepositoryProvider.overrideWithValue(moderation),
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
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('WP-794/1 — Bekleyen / Arsiv segmentleri ve sayilar', () {
    testWidgets('kapali vaka Bekleyen\'de yok, Arsiv\'de var; sayilar gercek', (
      tester,
    ) async {
      final admin = _adminRepo();
      await _seedTicket(admin, subject: 'Karanlik tema');
      final moderation = InMemoryAdminModerationRepository(
        seed: [
          _case(id: _targetA),
          _case(id: _targetB, status: ModerationCaseStatus.resolved),
        ],
      );
      await _pump(tester, moderation: moderation, admin: admin);

      // Bekleyen: acik vaka + acik bilet; kapali vaka YOK.
      expect(_open(_targetA), findsOneWidget);
      expect(_open(_targetB), findsNothing);
      expect(find.text('Karanlik tema'), findsOneWidget);
      // Sayilar listeden: 2 bekleyen, 1 arsiv.
      expect(find.text('Bekleyen 2'), findsOneWidget);
      expect(find.text('Arşiv 1'), findsOneWidget);
      // Tur cipleri segmentin sayisini tasir; sifir olan yalniz etiket.
      expect(find.text('Tümü 2'), findsOneWidget);
      expect(find.text('Şikâyet 1'), findsOneWidget);
      expect(find.text('Öneri 1'), findsOneWidget);
      expect(find.text('Soru'), findsOneWidget);
      expect(find.text('İtiraz'), findsOneWidget);

      await _tap(tester, find.byKey(kAdminQueueClosedFilterKey));
      // Arsiv: yalniz kapali vaka.
      expect(_open(_targetB), findsOneWidget);
      expect(_open(_targetA), findsNothing);
      expect(find.text('Karanlik tema'), findsNothing);
      expect(find.text('Tümü 1'), findsOneWidget);
      expect(find.text('Şikâyet 1'), findsOneWidget);
      expect(find.text('Öneri'), findsOneWidget);
      // Segment sayilari gorunumden bagimsiz: hala 2 / 1.
      expect(find.text('Bekleyen 2'), findsOneWidget);
      expect(find.text('Arşiv 1'), findsOneWidget);

      await _tap(tester, find.byKey(kAdminQueueOpenFilterKey));
      expect(_open(_targetA), findsOneWidget);
      expect(_open(_targetB), findsNothing);
    });

    testWidgets('tur cipi segmentle birlikte calisir; temizle ikisini sifirlar', (
      tester,
    ) async {
      final admin = _adminRepo();
      await _seedTicket(admin, subject: 'Karanlik tema');
      final moderation = InMemoryAdminModerationRepository(
        seed: [_case(id: _targetA)],
      );
      await _pump(tester, moderation: moderation, admin: admin);

      // Tur seridi 390dp'de kayar (WP-792 tasarimi); kullanici once kaydirir.
      final suggestion = find.byKey(
        adminQueueFilterKey(AdminQueueCategory.suggestion),
      );
      await tester.ensureVisible(suggestion);
      await _tap(tester, suggestion);
      expect(find.text('Karanlik tema'), findsOneWidget);
      expect(_open(_targetA), findsNothing);

      // Oneri + Arsiv: hicbir sey yok, Arsiv'in kendi bos metni.
      await _tap(tester, find.byKey(kAdminQueueClosedFilterKey));
      expect(find.byKey(kAdminQueueEmptyKey), findsOneWidget);
      expect(find.text('Arşiv boş.'), findsOneWidget);
      expect(find.text('Bekleyen iş yok.'), findsNothing);

      await _tap(tester, find.text('Filtreyi temizle'));
      expect(find.text('Karanlik tema'), findsOneWidget);
      expect(_open(_targetA), findsOneWidget);
    });
  });

  group('WP-794/2 — arsivlenmis bilet Arsiv\'de', () {
    testWidgets('arsivli bilet Bekleyen\'de gorunmez, Arsiv\'de gorunur', (
      tester,
    ) async {
      final admin = _adminRepo();
      final archived = await _seedTicket(
        admin,
        subject: 'Eski oneri',
        archived: true,
      );
      await _seedTicket(admin, subject: 'Yeni oneri');
      await _pump(
        tester,
        moderation: InMemoryAdminModerationRepository(),
        admin: admin,
      );

      expect(find.text('Yeni oneri'), findsOneWidget);
      expect(
        find.text('Eski oneri'),
        findsNothing,
        reason: 'Arsivlenmis bilet bekleyen isin arasina sizdi.',
      );
      expect(find.text('Arşiv 1'), findsOneWidget);

      await _tap(tester, find.byKey(kAdminQueueClosedFilterKey));
      expect(
        find.text('Eski oneri'),
        findsOneWidget,
        reason:
            'Arsivlenmis bilet Arsiv\'de yok: ekran hala yalniz arsivsiz '
            'listeyi okuyor.',
      );
      expect(find.text('Arşivde'), findsOneWidget);
      expect(_unarchive(archived), findsOneWidget);
      expect(find.text('Yeni oneri'), findsNothing);
    });
  });

  group('WP-794/3 — Geri ac', () {
    testWidgets('Arsiv\'deki vaka Geri ac ile =open yazar ve Bekleyen\'e doner', (
      tester,
    ) async {
      final moderation = InMemoryAdminModerationRepository(
        seed: [
          _case(
            id: _targetB,
            status: ModerationCaseStatus.resolved,
            caseId: 'case-2',
          ),
        ],
      );
      await _pump(tester, moderation: moderation);

      // Bekleyen'de ne kart ne Geri ac.
      expect(_open(_targetB), findsNothing);
      expect(_reopen(_targetB), findsNothing);

      await _tap(tester, find.byKey(kAdminQueueClosedFilterKey));
      expect(_reopen(_targetB), findsOneWidget);
      expect(find.text('Geri aç'), findsOneWidget);
      // Kapali vakada "Incelemeye al" yok.
      expect(_claim(_targetB), findsNothing);

      await _tap(tester, _reopen(_targetB));
      expect(moderation.statusWrites, ['message:$_targetB=open']);
      // Kart Arsiv'den gitti...
      expect(_open(_targetB), findsNothing);
      expect(find.text('Arşiv boş.'), findsOneWidget);
      // ...ve Bekleyen'e dondu; artik acik: Geri ac yok, Incelemeye al var.
      await _tap(tester, find.byKey(kAdminQueueOpenFilterKey));
      expect(_open(_targetB), findsOneWidget);
      expect(_reopen(_targetB), findsNothing);
      expect(_claim(_targetB), findsOneWidget);
    });

    testWidgets('sifir satir guncellenirse basari iddia edilmez', (
      tester,
    ) async {
      // Sahte depo `setCaseStatus` icin rapor sayisini doner; 0 rapor =
      // sunucunun "0 satir" cevabinin karsiligi (`0104` oncesi tarihsel kayit).
      final moderation = InMemoryAdminModerationRepository(
        seed: [
          _case(
            id: _targetB,
            status: ModerationCaseStatus.rejected,
            reportCount: 0,
          ),
        ],
      );
      await _pump(tester, moderation: moderation);
      await _tap(tester, find.byKey(kAdminQueueClosedFilterKey));
      await _tap(tester, _reopen(_targetB));

      expect(
        find.text('Bu kayıt bir vakaya bağlı değil; durum sunucuda değişmedi.'),
        findsOneWidget,
      );
      // Liste tazelenmedi: kart hala Arsiv'de duruyor.
      expect(_reopen(_targetB), findsOneWidget);
    });
  });

  group('WP-794/4 — Arsivden cikar', () {
    testWidgets('arsivli bilet karttan cikar, depoda archived=false', (
      tester,
    ) async {
      final admin = _adminRepo();
      final ticket = await _seedTicket(
        admin,
        subject: 'Eski oneri',
        archived: true,
      );
      await _pump(
        tester,
        moderation: InMemoryAdminModerationRepository(),
        admin: admin,
      );
      await _tap(tester, find.byKey(kAdminQueueClosedFilterKey));
      expect(find.text('Arşivden çıkar'), findsOneWidget);

      await _tap(tester, _unarchive(ticket));

      final stored = await admin.fetchFeedbackTickets(
        _adminId,
        includeArchived: true,
      );
      expect(stored.single.id, ticket.id);
      expect(
        stored.single.archivedAt,
        isNull,
        reason: 'Dugme depoya archived=false yazmadi.',
      );
      // Arsiv bosaldi, bilet Bekleyen'e dondu; arsiv isareti kalkti.
      expect(find.text('Arşiv boş.'), findsOneWidget);
      await _tap(tester, find.byKey(kAdminQueueOpenFilterKey));
      expect(find.text('Eski oneri'), findsOneWidget);
      expect(find.text('Arşivde'), findsNothing);
      expect(_unarchive(ticket), findsNothing);
    });
  });

  group('WP-794/5 — Incelemeye al', () {
    testWidgets('acik vaka =in_review yazar; dugme gider, hap Inceleniyor', (
      tester,
    ) async {
      final moderation = InMemoryAdminModerationRepository(
        seed: [_case(id: _targetA)],
      );
      await _pump(tester, moderation: moderation);

      expect(_claim(_targetA), findsOneWidget);
      expect(find.text('İncelemeye al'), findsOneWidget);
      expect(find.text('Açık'), findsOneWidget);
      expect(find.text('İnceleniyor'), findsNothing);

      await _tap(tester, _claim(_targetA));
      expect(moderation.statusWrites, ['message:$_targetA=in_review']);
      // Kart Bekleyen'de kalir (in_review acik istir), dugme kaybolur.
      expect(_open(_targetA), findsOneWidget);
      expect(_claim(_targetA), findsNothing);
      expect(find.text('İnceleniyor'), findsOneWidget);
      expect(find.text('Açık'), findsNothing);
    });

    testWidgets('zaten inceleniyorsa dugme cizilmez', (tester) async {
      await _pump(
        tester,
        moderation: InMemoryAdminModerationRepository(
          seed: [_case(id: _targetA, status: ModerationCaseStatus.inReview)],
        ),
      );
      expect(_open(_targetA), findsOneWidget);
      expect(_claim(_targetA), findsNothing);
      expect(find.text('İnceleniyor'), findsOneWidget);
    });

    testWidgets('tarihsel kayit (case_id yok) dugme cizilmez', (tester) async {
      await _pump(
        tester,
        moderation: InMemoryAdminModerationRepository(
          seed: [_case(id: _targetA, caseId: null)],
        ),
      );
      expect(_open(_targetA), findsOneWidget);
      expect(_claim(_targetA), findsNothing);
    });
  });

  group('WP-794/6 — siralama', () {
    test('buildAdminQueue(oldestFirst) yonu cevirir, acik/kapali gruplamasi durur', () {
      final now = DateTime(2026, 9, 6, 12);
      final entries = buildAdminQueue(
        cases: [
          _case(id: 'a', latestAt: now.subtract(const Duration(hours: 1))),
          _case(id: 'b', latestAt: now.subtract(const Duration(hours: 5))),
          _case(
            id: 'c',
            status: ModerationCaseStatus.resolved,
            latestAt: now.subtract(const Duration(hours: 9)),
          ),
          _case(
            id: 'd',
            status: ModerationCaseStatus.resolved,
            latestAt: now.subtract(const Duration(hours: 2)),
          ),
        ],
        tickets: const [],
        appeals: const [],
        oldestFirst: true,
      );
      expect(entries.map((e) => e.id), [
        'case:message:b',
        'case:message:a',
        'case:message:c',
        'case:message:d',
      ]);
      // Varsayilan degismedi: en yeni ustte.
      final newest = buildAdminQueue(
        cases: [
          _case(id: 'a', latestAt: now.subtract(const Duration(hours: 1))),
          _case(id: 'b', latestAt: now.subtract(const Duration(hours: 5))),
        ],
        tickets: const [],
        appeals: const [],
      );
      expect(newest.map((e) => e.id), ['case:message:a', 'case:message:b']);
    });

    testWidgets('cip ekrandaki kart sirasini gercekten cevirir', (tester) async {
      final now = DateTime.now();
      await _pump(
        tester,
        moderation: InMemoryAdminModerationRepository(
          seed: [
            _case(id: _targetA, latestAt: now.subtract(const Duration(hours: 1))),
            _case(id: _targetB, latestAt: now.subtract(const Duration(hours: 5))),
          ],
        ),
      );

      expect(find.text('En yeni'), findsOneWidget);
      expect(
        tester.getRect(_row(_targetA)).top,
        lessThan(tester.getRect(_row(_targetB)).top),
        reason: 'Varsayilan: en son hareket (A) ustte.',
      );

      await _tap(tester, find.byKey(kAdminQueueSortKey));
      expect(find.text('En eski'), findsOneWidget);
      expect(find.text('En yeni'), findsNothing);
      expect(
        tester.getRect(_row(_targetB)).top,
        lessThan(tester.getRect(_row(_targetA)).top),
        reason: 'En eski secildi ama en uzun bekleyen (B) uste cikmadi.',
      );

      await _tap(tester, find.byKey(kAdminQueueSortKey));
      expect(find.text('En yeni'), findsOneWidget);
      expect(
        tester.getRect(_row(_targetA)).top,
        lessThan(tester.getRect(_row(_targetB)).top),
      );
    });
  });

  group('WP-794/7 — 390dp telefon', () {
    testWidgets('segmentler ve siralama cipi ekranda ve dokunulabilir', (
      tester,
    ) async {
      await _pump(
        tester,
        width: 390,
        height: 844,
        moderation: InMemoryAdminModerationRepository(
          seed: [
            _case(id: _targetA),
            _case(id: _targetB, status: ModerationCaseStatus.resolved),
          ],
        ),
      );

      // WP-792/2'de cip x=706'ya dusmustu: telefonda yatay kaydirmadan
      // bulunamiyordu. Uc kontrol de 0..390 icinde olmali.
      for (final key in [
        kAdminQueueOpenFilterKey,
        kAdminQueueClosedFilterKey,
        kAdminQueueSortKey,
      ]) {
        final rect = tester.getRect(find.byKey(key));
        expect(rect.left, greaterThanOrEqualTo(0), reason: '$key: $rect');
        expect(rect.right, lessThanOrEqualTo(390), reason: '$key: $rect');
        expect(rect.height, greaterThanOrEqualTo(32), reason: '$key: $rect');
      }

      // Dokunma ETKISIYLE olculur: kacan tap durumu degistirmez.
      await _tap(tester, find.byKey(kAdminQueueClosedFilterKey));
      expect(_open(_targetB), findsOneWidget);
      expect(_open(_targetA), findsNothing);

      await _tap(tester, find.byKey(kAdminQueueSortKey));
      expect(find.text('En eski'), findsOneWidget);

      await _tap(tester, find.byKey(kAdminQueueOpenFilterKey));
      expect(_open(_targetA), findsOneWidget);
      expect(_open(_targetB), findsNothing);

      expect(tester.takeException(), isNull);
    });
  });
}
