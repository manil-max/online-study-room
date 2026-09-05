// WP-A (WP-691 FAZ 2) — yonetim paneli kabugu: uc yuzey + masaustu bolmeleri.
//
// ONCE KIRMIZI. Bu dosyadaki dort kabul olcutu `docs/design/ADMIN-PANEL-PLAN.md`
// §5 WP-A'dan birebir alindi; sayilar `docs/design/DESKTOP-UI-SPEC.md`
// merdiveninden gelir (640/1008/1200/1600; master 280; ucuncu bolme 320).
//
// 🔴 Olculen sey KULLANICININ GORDUGU seydir: `tester.getSize` ile bolme
// genisligi, `find` ile gezinme hedefi. Bir sabitin kaynakta gecmesi kanit
// degildir. Ayrica her duzen iddiasinin yaninda GOVDENIN GERCEK oldugunu
// gosteren bir metin araniyor: `find.byType(X)` bos/hatali bir kabukla da
// eslesir (2026-08-11'de dort ajan bu tuzaga dustu).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:online_study_room/features/admin/admin_screen.dart';
import 'package:online_study_room/features/admin/queue/admin_queue_view.dart';
import 'package:online_study_room/features/admin/shell/admin_shell.dart';
import 'package:online_study_room/features/admin/tabs/admin_announcements_tab.dart';
import 'package:online_study_room/features/admin/tabs/admin_audit_log_tab.dart';
import 'package:online_study_room/features/admin/tabs/admin_dashboard_tab.dart';
import 'package:online_study_room/features/admin/tabs/admin_groups_tab.dart';
import 'package:online_study_room/features/admin/tabs/admin_users_tab.dart';
import 'package:online_study_room/features/desktop/desktop_page_scaffold.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _targetId = '22222222-2222-4222-8222-222222222222';
const _reporterId = '11111111-1111-4111-8111-111111111111';

ModerationCase _seedCase() => ModerationCase(
  targetType: ReportTargetType.message,
  targetId: _targetId,
  targetIdentity: const ModerationIdentity(
    id: _targetId,
    displayName: 'Mehmet',
  ),
  status: ModerationCaseStatus.open,
  reportCount: 1,
  reasons: const ['hate'],
  latestAt: DateTime(2026, 8, 10, 9),
  reporters: const [ModerationIdentity(id: _reporterId, displayName: 'Ayse')],
  reportIds: const ['report-1'],
);

Future<void> _pumpAdmin(
  WidgetTester tester, {
  required Size window,
  bool pushed = false,
  Locale locale = const Locale('tr'),
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final repo = InMemoryAdminRepository(superAdminUserIds: const {'admin'});
  addTearDown(repo.dispose);
  await repo.submitFeedback(
    userId: 'u1',
    kind: FeedbackTicketKind.bug,
    subject: 'Bildirim aksiyonu',
    message: 'Durdur butonu uygulamayi aciyor.',
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
        adminRepositoryProvider.overrideWithValue(repo),
        adminModerationRepositoryProvider.overrideWithValue(
          InMemoryAdminModerationRepository(seed: [_seedCase()]),
        ),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: pushed ? const _AdminLaunchHost() : const AdminScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _AdminLaunchHost extends StatelessWidget {
  const _AdminLaunchHost();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        key: const Key('open-admin'),
        onPressed: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const AdminScreen())),
        child: const Text('Aç'),
      ),
    ),
  );
}

/// Yuzeyi degistirir. Genis pencerede `NavigationRail`, telefonda
/// `NavigationBar` — ikisinde de hedef ayni ikonla bulunur.
Future<void> _openSurface(WidgetTester tester, IconData icon) async {
  final nav = find.byKey(kAdminSurfaceNavKey);
  expect(nav, findsOneWidget, reason: 'Gezinme yuzeyi hic cizilmemis.');
  await tester.tap(find.descendant(of: nav, matching: find.byIcon(icon)).first);
  await tester.pumpAndSettle();
}

/// Yuzey icindeki bolumu secer: genis pencerede master listesi, dar pencerede
/// bolum secici.
Future<void> _openSection(WidgetTester tester, String label) async {
  final master = find.byKey(kAdminMasterPaneKey);
  final host = master.evaluate().isNotEmpty
      ? master
      : find.byKey(kAdminSectionSelectorKey);
  expect(host, findsOneWidget, reason: 'Bolum secici hic cizilmemis.');
  await tester.tap(find.descendant(of: host, matching: find.text(label)).first);
  await tester.pumpAndSettle();
}

int _paneCount() =>
    find.byKey(kAdminMasterPaneKey).evaluate().length +
    find.byKey(kAdminDetailPaneKey).evaluate().length +
    find.byKey(kAdminContextPaneKey).evaluate().length;

void main() {
  // --- KABUL 1 + 2 ------------------------------------------------------
  // 🔴 WP-768: Kuyruk yuzeyi TEK bolumlu oldu (tek liste); bolum listesi ve
  // master bolmesi orada cizilmez. Master-detay sozlesmesi cok bolumlu
  // yuzeyde (Kisiler & Gruplar) olculur.
  testWidgets('1280 px: kuyruk yuzeyi tek bolme, tum genislik', (tester) async {
    await _pumpAdmin(tester, window: const Size(1280, 900));

    expect(find.byKey(kAdminQueueListKey), findsOneWidget);
    expect(
      find.byKey(kAdminMasterPaneKey),
      findsNothing,
      reason: 'Tek secenegi olan bolum listesi secim degil gurultudur.',
    );
    expect(find.byKey(kAdminSectionSelectorKey), findsNothing);
    // Sikayet ve destek kaydi AYNI listede.
    expect(find.text('Bildirim aksiyonu'), findsOneWidget);
    expect(find.textContaining('Mehmet'), findsWidgets);
  });

  testWidgets('1280 px: iki bolme, master sutunu 280 px', (tester) async {
    await _pumpAdmin(tester, window: const Size(1280, 900));
    await _openSurface(tester, kAdminDirectoryIcon);

    expect(
      find.byType(DesktopMasterDetail),
      findsOneWidget,
      reason: 'ADMIN-PANEL-PLAN §5 WP-A kabul 1: 1280 pxte master-detay yok.',
    );
    expect(_paneCount(), 2, reason: '`large` bandinda iki bolme olmali.');
    expect(
      tester.getSize(find.byKey(kAdminMasterPaneKey)).width,
      280,
      reason: 'DESKTOP-UI-SPEC §3 A1: master sutunu 280 px.',
    );
    // Govde GERCEK mi? Kabuk degil, icerik olculuyor.
    expect(find.text('test1@example.com'), findsOneWidget);
  });

  testWidgets('800 px: tek bolme', (tester) async {
    await _pumpAdmin(tester, window: const Size(800, 700));

    expect(_paneCount(), 1, reason: 'ADMIN-PANEL-PLAN §5 WP-A kabul 2.');
    expect(find.byKey(kAdminMasterPaneKey), findsNothing);
    expect(find.byKey(kAdminContextPaneKey), findsNothing);
    expect(find.text('Bildirim aksiyonu'), findsOneWidget);
  });

  testWidgets('1600 px: uc bolme, ucuncu bolme <= 320 px', (tester) async {
    await _pumpAdmin(tester, window: const Size(1600, 1000));
    await _openSurface(tester, kAdminDirectoryIcon);

    expect(_paneCount(), 3, reason: 'ADMIN-PANEL-PLAN §5 WP-A kabul 2.');
    expect(tester.getSize(find.byKey(kAdminMasterPaneKey)).width, 280);
    expect(
      tester.getSize(find.byKey(kAdminContextPaneKey)).width,
      lessThanOrEqualTo(320.0),
      reason: 'DESKTOP-UI-SPEC §4.5: ucuncu bolme <= 320 px.',
    );
    expect(find.text('test1@example.com'), findsOneWidget);
  });

  // --- KABUL 3 ----------------------------------------------------------
  testWidgets('TabBar yok; NavigationRail var ve 3 hedefi var', (tester) async {
    await _pumpAdmin(tester, window: const Size(1280, 900));

    expect(
      find.byType(TabBar),
      findsNothing,
      reason: 'ADMIN-PANEL-PLAN §4.5: yatay kaydirilabilir TabBar duser.',
    );
    final rail = find.byType(NavigationRail);
    expect(rail, findsOneWidget);
    expect(
      tester.widget<NavigationRail>(rail).destinations.length,
      3,
      reason: 'Yedi sekme UC yuzeye iner (§4.1).',
    );
  });

  // --- KABUL 4 ----------------------------------------------------------
  testWidgets('gezinme etiketleri l10n; ham "UGC" dizesi yok', (tester) async {
    await _pumpAdmin(tester, window: const Size(1280, 900));

    expect(
      find.text('UGC'),
      findsNothing,
      reason: 'admin_screen.dart:56 ham dizesi l10n anahtarina baglanmali.',
    );
    // TR katalogdan gelen uc yuzey adi ekranda okunabilir olmali.
    for (final label in const [
      'Kuyruk',
      'Kişiler & Gruplar',
      'Kayıt & Yayın',
    ]) {
      expect(
        find.text(label),
        findsWidgets,
        reason: 'Yuzey etiketi "$label" ekranda yok.',
      );
    }
    // WP-768: "İçerik Şikayetleri" bir BOLUM adiydi; bolum kalkti, isin
    // kendisi Kuyruk yuzeyinin tek listesinde duruyor.
    expect(find.text('İçerik Şikayetleri'), findsNothing);
    expect(find.text('Detaylı incele'), findsWidgets);
  });

  // --- LIDER SARTI 5: telefon -------------------------------------------
  testWidgets('390x844 telefonda tek yuzey + alt gezinme', (tester) async {
    await _pumpAdmin(tester, window: const Size(390, 844));

    expect(_paneCount(), 1, reason: 'Bolmeli duzen telefona sizmamali.');
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester
          .widget<NavigationBar>(find.byType(NavigationBar))
          .destinations
          .length,
      3,
    );
    expect(find.text('Bildirim aksiyonu'), findsOneWidget);
  });

  testWidgets('360x800: alt gezinme ve filtreler taşmadan kompakt kalır', (
    tester,
  ) async {
    await _pumpAdmin(tester, window: const Size(360, 800));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('360x800 EN: uzun üçüncü etiket dengeli ve ortalıdır', (
    tester,
  ) async {
    await _pumpAdmin(
      tester,
      window: const Size(360, 800),
      locale: const Locale('en'),
    );

    final label = find.text('Records &\nBroadcast');
    expect(label, findsOneWidget);
    expect(tester.widget<Text>(label).textAlign, TextAlign.center);
    expect(tester.widget<Text>(label).maxLines, 2);
    expect(tester.takeException(), isNull);
  });

  for (final window in const [Size(1366, 768), Size(1920, 1080)]) {
    testWidgets('${window.width.toInt()}x${window.height.toInt()}: '
        'rail ve tek kuyruk birlikte görünür', (tester) async {
      await _pumpAdmin(tester, window: window);

      expect(find.byType(NavigationRail), findsOneWidget);
      // Bolum secmeye gerek yok: kuyruk yuzeyin kendisidir.
      expect(find.byKey(kAdminQueueListKey), findsOneWidget);
      expect(find.byKey(kAdminQueueFilterKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('geri önce admin geçmişini, sonra gerçek rotayı geri alır', (
    tester,
  ) async {
    await _pumpAdmin(tester, window: const Size(360, 800), pushed: true);
    await tester.tap(find.byKey(const Key('open-admin')));
    await tester.pumpAndSettle();

    await _openSurface(tester, kAdminDirectoryIcon);
    await _openSection(tester, 'Gruplar');
    expect(find.byType(AdminGroupsTab), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(AdminUsersTab), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(AdminQueueView), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(kAdminShellKey), findsNothing);
    expect(find.byKey(const Key('open-admin')), findsOneWidget);
  });

  // --- LIDER SARTI 6: islev kaybi YOK -----------------------------------
  testWidgets('yedi eski sekmenin hepsi uc yuzeyden ulasilir', (tester) async {
    await _pumpAdmin(tester, window: const Size(1280, 900));

    // 1+2) Kuyruk  <- eski 4. ve 5. sekme, WP-768'de TEK listede birlesti.
    // Kabuk degil GOVDE olculuyor: iki tur de gercekten cizilmis mi?
    await _openSurface(tester, kAdminQueueIcon);
    expect(find.byType(AdminQueueView), findsOneWidget);
    expect(find.text('Bildirim aksiyonu'), findsOneWidget);
    expect(find.textContaining('Mehmet'), findsWidgets);

    // 3) Kisiler & Gruplar / Kullanicilar  <- eski 2. sekme
    await _openSurface(tester, kAdminDirectoryIcon);
    await _openSection(tester, 'Kullanıcılar');
    expect(find.byType(AdminUsersTab), findsOneWidget);
    expect(find.text('test1@example.com'), findsOneWidget);

    // 4) Kisiler & Gruplar / Gruplar  <- eski 3. sekme
    await _openSection(tester, 'Gruplar');
    expect(find.byType(AdminGroupsTab), findsOneWidget);
    expect(find.text('Test Grubu 1'), findsOneWidget);

    // 5) Kayit & Yayin / Ozet  <- eski 1. sekme
    await _openSurface(tester, kAdminRecordsIcon);
    await _openSection(tester, 'Özet');
    expect(find.byType(AdminDashboardTab), findsOneWidget);

    // 6) Kayit & Yayin / Duyurular  <- eski 6. sekme
    await _openSection(tester, 'Duyurular');
    expect(find.byType(AdminAnnouncementsTab), findsOneWidget);
    expect(find.text('Sistem Bakımı'), findsOneWidget);

    // 7) Kayit & Yayin / Denetim  <- eski 7. sekme
    await _openSection(tester, 'Denetim');
    expect(find.byType(AdminAuditLogTab), findsOneWidget);
  });

  // PLAN §4.5 — `Ctrl+1..3` yuzeyler arasi gecis.
  testWidgets('Ctrl+2 ikinci yuzeye gecer', (tester) async {
    await _pumpAdmin(tester, window: const Size(1280, 900));
    expect(find.text('test1@example.com'), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();

    // Kabuk degil GOVDE: kullanici listesi gercekten cizildi mi?
    expect(find.text('test1@example.com'), findsOneWidget);
  });

  testWidgets('yetkisiz kullanici kabugu hic gormez', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final repo = InMemoryAdminRepository();
    addTearDown(repo.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              Profile(
                id: 'u1',
                displayName: 'Normal',
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
          home: AdminScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(kAdminShellKey), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
  });
}
