import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/admin_case_timeline_event.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/admin_moderation_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_moderation_repository.dart';
import 'package:online_study_room/features/admin/detail/admin_case_timeline_section.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-796 — zaman cizelgesi bolumu: kullanicinin GORDUGU satirlar olculur.
///
/// Zincir (`moderation_audit_events`) 0106'dan beri doluyor ve hic
/// okunmuyordu; bu dosya ekranin GERCEK veriden cizdigini kilitler (bellek
/// ici depo tohumsuz BOS doner, uydurmaz).
AdminCaseTimelineEvent _event({
  required String id,
  required String entity,
  required String action,
  Map<String, dynamic>? old,
  Map<String, dynamic>? next,
  String? reason,
  String? actor = 'admin-1',
  String at = '2026-09-05T18:00:00Z',
}) => AdminCaseTimelineEvent(
  id: id,
  occurredAt: DateTime.parse(at),
  actorId: actor,
  entityType: entity,
  entityId: 'case-1',
  action: action,
  oldValue: old,
  newValue: next,
  reason: reason,
);

Future<void> _pump(
  WidgetTester tester,
  InMemoryAdminModerationRepository repo, {
  String? caseId = 'case-1',
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminModerationRepositoryProvider.overrideWithValue(repo),
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            Profile(id: 'admin-1', displayName: 'Admin', createdAt: DateTime(2026)),
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: AdminCaseTimelineSection(caseId: caseId),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  late AppLocalizations tr;
  setUpAll(() {
    tr = lookupAppLocalizations(const Locale('tr'));
  });

  testWidgets('olaylar eskiden yeniye, yerel etiketle ve aktorle cizilir', (
    tester,
  ) async {
    final repo = InMemoryAdminModerationRepository()
      ..caseTimelines['case-1'] = [
        _event(
          id: 'e3',
          entity: 'case',
          action: 'updated',
          old: {'status': 'in_review'},
          next: {'status': 'resolved'},
          at: '2026-09-05T21:14:00Z',
        ),
        _event(id: 'e1', entity: 'case', action: 'opened', at: '2026-09-03T18:02:00Z'),
        _event(
          id: 'e2',
          entity: 'sanction',
          action: 'opened',
          next: {'action': 'warn', 'state': 'pending'},
          reason: 'tekrarlayan hakaret',
          at: '2026-09-05T21:12:00Z',
        ),
      ];
    await _pump(tester, repo);

    expect(find.byKey(kAdminCaseTimelineKey), findsOneWidget);
    expect(find.text(tr.adminZcVakaAcildi), findsOneWidget);
    expect(find.text(tr.adminZcDurum(tr.adminUgcStatusResolved)), findsOneWidget);
    expect(find.text('tekrarlayan hakaret'), findsOneWidget);
    // Aktor benim -> "Sen".
    expect(find.textContaining(tr.feedbackYou), findsNWidgets(3));

    // Sira: e1 (3 Eyl) en ustte, e3 (21:14) en altta.
    final y1 = tester.getRect(find.byKey(adminCaseTimelineRowKey('e1'))).top;
    final y2 = tester.getRect(find.byKey(adminCaseTimelineRowKey('e2'))).top;
    final y3 = tester.getRect(find.byKey(adminCaseTimelineRowKey('e3'))).top;
    expect(y1, lessThan(y2));
    expect(y2, lessThan(y3));
  });

  testWidgets('karantina, itiraz ve silinmis yonetici satirlari', (tester) async {
    final repo = InMemoryAdminModerationRepository()
      ..caseTimelines['case-1'] = [
        _event(
          id: 'q',
          entity: 'case',
          action: 'updated',
          old: {'status': 'open', 'quarantined': false},
          next: {'status': 'open', 'quarantined': true},
          actor: null,
        ),
        _event(
          id: 'a',
          entity: 'appeal',
          action: 'decided',
          old: {'status': 'open'},
          next: {'status': 'upheld'},
          at: '2026-09-06T09:00:00Z',
        ),
      ];
    await _pump(tester, repo);
    expect(find.text(tr.adminZcKarantinaAlindi), findsOneWidget);
    expect(find.text(tr.adminZcItirazKarar('upheld')), findsOneWidget);
    expect(find.textContaining(tr.adminZcSilinmisYonetici), findsOneWidget);
  });

  /// 🔴 Bos ile okunamayan AYRI seylerdir. Ikisi de "olay yok" gosterseydi,
  /// dusen bir sorgu temiz bir gecmis gibi okunurdu.
  testWidgets('bos zincir bos metin, tekrar dene yok', (tester) async {
    await _pump(tester, InMemoryAdminModerationRepository());
    expect(find.text(tr.adminZamanCizelgesiBos), findsOneWidget);
    expect(find.byKey(kAdminCaseTimelineRetryKey), findsNothing);
  });

  // Ayri test: ayni ProviderScope'un override kumesi degistirilemez
  // (Riverpod "not overridden before" iddiasi).
  testWidgets('dusen okuma bos gibi gorunmez; tekrar dene verir', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminCaseTimelineProvider('case-1').overrideWith(
            (ref) async => throw const ModerationException('down'),
          ),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: AdminCaseTimelineSection(caseId: 'case-1')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(tr.adminZamanCizelgesiOkunamadi), findsOneWidget);
    expect(find.byKey(kAdminCaseTimelineRetryKey), findsOneWidget);
    expect(find.text(tr.adminZamanCizelgesiBos), findsNothing);
  });

  testWidgets('tarihsel kayit (caseId yok) sorgu atmaz, bos metin', (tester) async {
    await _pump(tester, InMemoryAdminModerationRepository(), caseId: null);
    expect(find.text(tr.adminZamanCizelgesiBos), findsOneWidget);
  });

  test('tanimadigi eylem ham metinle gecer, yuvarlanmaz', () {
    final label = timelineEventLabel(
      tr,
      _event(id: 'x', entity: 'case', action: 'escalated'),
    );
    expect(label, 'case:escalated');
  });
}
