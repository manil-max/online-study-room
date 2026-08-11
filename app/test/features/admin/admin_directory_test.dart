// WP-D (WP-691 FAZ 2) — yonetim panelinde arama, grup uye listesi, denetim
// kaydi ve etiketler.
//
// ONCE KIRMIZI. Bu dosyadaki yedi kabul olcutu `docs/design/ADMIN-PANEL-PLAN.md`
// §5 WP-D'den birebir alindi. Sayilar `docs/design/DESKTOP-UI-SPEC.md`
// merdiveninden gelir (640/1008/1200/1600; doseme tavani 320) — burada yeni
// sayi turetilmedi.
//
// 🔴 Olculen sey KULLANICININ GORDUGU seydir:
//   - arama `tester.enterText` ile YAZILIR, sonuc `find` ile SAYILIR; kaynakta
//     `TextField` gecmesi kanit degildir,
//   - izgara sutun sayisi `tester.getRect` ile satir satir olculur, sabit
//     okunmaz,
//   - her duzen iddiasinin yaninda GOVDENIN GERCEK oldugunu gosteren bir metin
//     aranir: `find.byType(X)` bos/hatali bir kabukla da eslesir (2026-08-11'de
//     bes ajan bu tuzaga dustu).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/admin_audit_log.dart';
import 'package:online_study_room/data/models/admin_user_dto.dart';
import 'package:online_study_room/data/models/feedback_ticket.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/features/admin/tabs/admin_audit_log_tab.dart';
import 'package:online_study_room/features/admin/tabs/admin_dashboard_tab.dart';
import 'package:online_study_room/features/admin/tabs/admin_groups_tab.dart';
import 'package:online_study_room/features/admin/tabs/admin_reports_tab.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _alfaId = '11111111-1111-4111-8111-111111111111';
const _betaId = '22222222-2222-4222-8222-222222222222';
const _ayseId = '33333333-3333-4333-8333-333333333333';
const _mehmetId = '44444444-4444-4444-8444-444444444444';

StudyGroup _group(String id, String name) => StudyGroup(
  id: id,
  name: name,
  inviteCode: id.substring(0, 6),
  createdBy: 'admin',
  createdAt: DateTime(2026, 8),
);

Profile _profile(String id, String name) =>
    Profile(id: id, displayName: name, createdAt: DateTime(2026));

FeedbackTicket _ticket({
  required String subject,
  FeedbackTicketType type = FeedbackTicketType.feedback,
}) => FeedbackTicket(
  id: 'ticket-$subject',
  userId: 'u1',
  kind: FeedbackTicketKind.bug,
  subject: subject,
  message: 'Durdur butonu uygulamayi aciyor.',
  status: FeedbackTicketStatus.open,
  createdAt: DateTime(2026, 8, 10),
  updatedAt: DateTime(2026, 8, 10),
  type: type,
);

Future<void> _pump(
  WidgetTester tester,
  Widget body, {
  List<Override> overrides = const [],
  Size window = const Size(1280, 900),
}) async {
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith(
          (ref) => Stream.value(
            Profile(id: 'admin', displayName: 'Admin', createdAt: DateTime(2026)),
          ),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: body),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<Override> _groupOverrides() {
  final repo = InMemoryAdminRepository(superAdminUserIds: const {'admin'});
  addTearDown(repo.dispose);
  return [
    adminRepositoryProvider.overrideWithValue(repo),
    adminGroupsProvider.overrideWith(
      (ref) async => [_group(_alfaId, 'Alfa Grubu'), _group(_betaId, 'Beta Grubu')],
    ),
    adminUsersProvider.overrideWith(
      (ref) async => [
        AdminUserDto(
          id: _ayseId,
          email: 'ayse@example.com',
          createdAt: DateTime(2026),
        ),
        AdminUserDto(
          id: _mehmetId,
          email: 'mehmet@example.com',
          createdAt: DateTime(2026),
        ),
      ],
    ),
    groupMembersByIdProvider(_alfaId).overrideWith(
      (ref) =>
          Stream.value([_profile(_ayseId, 'Ayse'), _profile(_mehmetId, 'Mehmet')]),
    ),
    groupMembersByIdProvider(_betaId).overrideWith(
      (ref) => Stream.value([_profile(_ayseId, 'Ayse')]),
    ),
  ];
}

/// Bir bolgedeki `Card`'larin ekran dikdortgenleri — izgara olcumu icin.
List<Rect> _cardRects(WidgetTester tester, Finder host) {
  final cards = find.descendant(of: host, matching: find.byType(Card));
  return [
    for (var i = 0; i < cards.evaluate().length; i++)
      tester.getRect(cards.at(i)),
  ];
}

/// Ayni satirdaki (dy'si esit) doseme sayisi.
int _firstRowCount(List<Rect> rects) {
  if (rects.isEmpty) return 0;
  final top = rects.first.top;
  return rects.where((r) => (r.top - top).abs() < 1).length;
}

void main() {
  // --- KABUL 1: arama kutusu -------------------------------------------
  testWidgets('grup listesinde arama kutusu ad parcasiyla filtreler', (
    tester,
  ) async {
    await _pump(tester, const AdminGroupsTab(), overrides: _groupOverrides());

    // Govde GERCEK mi? Once iki grup da cizilmis olmali.
    expect(find.text('Alfa Grubu'), findsOneWidget);
    expect(find.text('Beta Grubu'), findsOneWidget);

    final search = find.widgetWithText(TextField, 'Grup ara');
    expect(
      search,
      findsOneWidget,
      reason: 'ADMIN-PANEL-PLAN §5 WP-D kabul 1: dizinde arama kutusu yok.',
    );

    await tester.enterText(search, 'beta');
    await tester.pumpAndSettle();

    expect(find.text('Beta Grubu'), findsOneWidget);
    expect(
      find.text('Alfa Grubu'),
      findsNothing,
      reason: 'Arama yazildi ama liste filtrelenmedi.',
    );
  });

  testWidgets('uye secici e-posta parcasiyla filtreler', (tester) async {
    await _pump(tester, const AdminGroupsTab(), overrides: _groupOverrides());

    await tester.tap(find.text('Üye At').first);
    await tester.pumpAndSettle();

    // Secici gercek mi? Iki kullanici da e-postasiyla listelenmis olmali.
    expect(
      find.text('ayse@example.com'),
      findsOneWidget,
      reason:
          'ADMIN-PANEL-PLAN §5 WP-D kabul 2: uye secici e-posta ile listelemiyor.',
    );
    expect(find.text('mehmet@example.com'), findsOneWidget);

    final search = find.widgetWithText(TextField, 'Kişi ara (e-posta)');
    expect(search, findsOneWidget, reason: 'Secicide arama kutusu yok.');

    await tester.enterText(search, 'mehmet');
    await tester.pumpAndSettle();

    expect(find.text('mehmet@example.com'), findsOneWidget);
    expect(
      find.text('ayse@example.com'),
      findsNothing,
      reason: 'E-posta parcasi yazildi ama liste filtrelenmedi.',
    );
  });

  // --- KABUL 2: grup dosyasi + UUID yok ---------------------------------
  testWidgets('grup dosyasi uye listesini cizer', (tester) async {
    await _pump(tester, const AdminGroupsTab(), overrides: _groupOverrides());

    expect(
      find.text('Ayse'),
      findsWidgets,
      reason:
          'ADMIN-PANEL-PLAN §5 WP-D kabul 2: grup dosyasi uye listesi gostermiyor.',
    );
    expect(find.text('Mehmet'), findsWidgets);
  });

  testWidgets('"Uye At" elle UUID istemez', (tester) async {
    await _pump(tester, const AdminGroupsTab(), overrides: _groupOverrides());

    await tester.tap(find.text('Üye At').first);
    await tester.pumpAndSettle();

    expect(
      find.text('Hedef Kullanıcı ID (Zorunlu)'),
      findsNothing,
      reason:
          'ADMIN-PANEL-PLAN §5 WP-D kabul 2: "Uye At" hala elle UUID yazdiriyor '
          '(admin_groups_tab.dart:68-77).',
    );
  });

  // --- KABUL 3: denetim satiri ------------------------------------------
  testWidgets('denetim satiri yoneticiyi ve hedef e-postasini cizer', (
    tester,
  ) async {
    await _pump(
      tester,
      const AdminAuditLogTab(),
      overrides: [
        adminAuditLogsProvider.overrideWith(
          (ref) async => [
            AdminAuditLog(
              id: 'log-1',
              adminId: 'admin-42',
              targetUserId: _mehmetId,
              targetUserEmail: 'mehmet@example.com',
              action: 'suspend_user',
              reason: 'Spam',
              createdAt: DateTime(2026, 8, 10, 9),
            ),
          ],
        ),
      ],
    );

    // Govde gercek mi?
    expect(find.textContaining('suspend_user'), findsOneWidget);

    expect(
      find.textContaining('admin-42'),
      findsOneWidget,
      reason:
          'ADMIN-PANEL-PLAN §5 WP-D kabul 3: admin kimligi (admin_audit_log.dart:18) '
          'cizilmiyor.',
    );
    expect(
      find.textContaining('mehmet@example.com'),
      findsOneWidget,
      reason:
          'ADMIN-PANEL-PLAN §5 WP-D kabul 3: hedef e-postasi '
          '(admin_audit_log.dart:21) cizilmiyor.',
    );
  });

  // --- KABUL 4: bos sonucta filtreyi temizleme --------------------------
  testWidgets('rapor listesi bos kalinca filtre temizlenebilir', (tester) async {
    await _pump(
      tester,
      const AdminReportsTab(),
      overrides: [
        adminFeedbackTicketsProvider(
          null,
        ).overrideWith((ref) async => [_ticket(subject: 'Bildirim aksiyonu')]),
        adminFeedbackTicketsProvider(
          FeedbackTicketType.question,
        ).overrideWith((ref) async => const <FeedbackTicket>[]),
        adminArchivedFeedbackTicketsProvider(
          null,
        ).overrideWith((ref) async => const <FeedbackTicket>[]),
        adminArchivedFeedbackTicketsProvider(
          FeedbackTicketType.question,
        ).overrideWith((ref) async => const <FeedbackTicket>[]),
      ],
    );

    expect(find.text('Bildirim aksiyonu'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilterChip, 'Soru'));
    await tester.pumpAndSettle();

    expect(find.text('Bildirim aksiyonu'), findsNothing);

    final clear = find.text('Filtreyi temizle');
    expect(
      clear,
      findsOneWidget,
      reason:
          'ADMIN-PANEL-PLAN §2.4 filtre cikmazi / §5 WP-D kabul 4: bos sonucta '
          'filtreyi kaldiracak kontrol ekranda yok.',
    );

    await tester.tap(clear);
    await tester.pumpAndSettle();

    expect(
      find.text('Bildirim aksiyonu'),
      findsOneWidget,
      reason: '"Filtreyi temizle" basildi ama liste geri gelmedi.',
    );
  });

  testWidgets('grup aramasi bos kalinca filtre temizlenebilir', (tester) async {
    await _pump(tester, const AdminGroupsTab(), overrides: _groupOverrides());

    await tester.enterText(find.widgetWithText(TextField, 'Grup ara'), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('Alfa Grubu'), findsNothing);
    final clear = find.text('Filtreyi temizle');
    expect(clear, findsOneWidget, reason: 'WP-D kabul 4 (dizin tarafi).');

    await tester.tap(clear);
    await tester.pumpAndSettle();

    expect(find.text('Alfa Grubu'), findsOneWidget);
    expect(find.text('Beta Grubu'), findsOneWidget);
  });

  // --- KABUL 5: arsiv etiketi -------------------------------------------
  testWidgets('arsiv cipi "Arsivle" yazar, "Tamamlandi" yazmaz', (tester) async {
    await _pump(
      tester,
      const AdminReportsTab(),
      overrides: [
        adminFeedbackTicketsProvider(
          null,
        ).overrideWith((ref) async => [_ticket(subject: 'Bildirim aksiyonu')]),
        adminArchivedFeedbackTicketsProvider(
          null,
        ).overrideWith((ref) async => const <FeedbackTicket>[]),
      ],
    );

    expect(find.text('Bildirim aksiyonu'), findsOneWidget);
    expect(
      find.text('Tamamlandı'),
      findsNothing,
      reason:
          'ADMIN-PANEL-PLAN §5 WP-D kabul 5: arsiv cipinin ustunde "Tamamlandi" '
          'yaziyor (admin_reports_tab.dart:240) — etiket yalan.',
    );
    expect(
      find.text('Arşivle'),
      findsOneWidget,
      reason: 'Arsiv cipinin metni "Arsivle" olmali.',
    );
  });

  test('profileTamamland anahtari admin_reports_tab.dart icinde gecmez', () {
    final source = File(
      'lib/features/admin/tabs/admin_reports_tab.dart',
    ).readAsStringSync();
    expect(
      source.contains('profileTamamland'),
      isFalse,
      reason:
          'ADMIN-PANEL-PLAN §5 WP-D kabul 5: "Tamamlandi" anahtari bu dosyada '
          'hic gecmemeli.',
    );
  });

  // --- KABUL 6: ozet izgarasi -------------------------------------------
  group('ozet izgarasi sabit 2 sutun degil', () {
    Future<List<Rect>> pumpGrid(WidgetTester tester, double width) async {
      await _pump(
        tester,
        Center(
          child: SizedBox(width: width, child: const AdminDashboardTab()),
        ),
        overrides: [
          adminDashboardSummaryProvider.overrideWith(
            (ref) async => null, // sifirlarla dolu ozet — dort doseme cizilir
          ),
        ],
        window: Size(width + 200, 1000),
      );
      // Govde gercek mi? Doseme etiketleri okunabilir olmali.
      expect(find.text('Kullanıcılar'), findsOneWidget);
      expect(find.text('Oturumlar'), findsOneWidget);
      return _cardRects(tester, find.byType(AdminDashboardTab));
    }

    testWidgets('390 px: tek sutun', (tester) async {
      final rects = await pumpGrid(tester, 390);
      expect(rects.length, 4);
      expect(
        _firstRowCount(rects),
        1,
        reason: 'ADMIN-PANEL-PLAN §4.5: `minimal` bandinda tek sutun.',
      );
    });

    testWidgets('700 px: iki sutun ve doseme <= 320', (tester) async {
      final rects = await pumpGrid(tester, 700);
      expect(_firstRowCount(rects), 2);
      for (final rect in rects) {
        expect(
          rect.width,
          lessThanOrEqualTo(320.0),
          reason: 'DESKTOP-UI-SPEC §2.3: doseme tavani 320 px.',
        );
      }
    });

    testWidgets('1100 px: dort sutun', (tester) async {
      final rects = await pumpGrid(tester, 1100);
      expect(
        _firstRowCount(rects),
        4,
        reason:
            'ADMIN-PANEL-PLAN §5 WP-D kabul 6: izgara sabit 2 sutun '
            '(admin_dashboard_tab.dart:53).',
      );
      for (final rect in rects) {
        expect(rect.width, lessThanOrEqualTo(320.0));
      }
    });

    testWidgets('1700 px: alti sutun — dort doseme izgarayi doldurmaz', (
      tester,
    ) async {
      final rects = await pumpGrid(tester, 1700);
      expect(_firstRowCount(rects), 4);
      final gridLeft = rects.first.left;
      final lastRight = rects.last.right;
      // Alti sutunda dort doseme izgaranin ~2/3'unu kaplar; dort sutunda
      // tamamini. 0.75 esigi ikisini ayirir.
      expect(
        lastRight - gridLeft,
        lessThan(1700 * 0.75),
        reason:
            'ADMIN-PANEL-PLAN §5 WP-D kabul 6: `xlarge` bandinda alti sutun '
            'olmali; dort doseme izgarayi bastan sona dolduruyor.',
      );
      for (final rect in rects) {
        expect(rect.width, lessThanOrEqualTo(320.0));
      }
    });
  });

  // --- KABUL 7: yalniz-ikon dugmelerde tooltip ---------------------------
  //
  // 🔴 Bu sozlesme TUM `app/lib/features/admin/**` uzerinde kosar ama iki
  // kademelidir:
  //   - WP-D'nin SAHIP oldugu dosyalarda **sert**: sifir tolerans.
  //   - Diger lane'lerin (WP-A/B/C) dosyalarinda **cirit**: bugunku sayi taban
  //     kabul edilir, artmasi yasak. Boylece bu tur bugun kirmizi dusmez ama
  //     kimse yeni etiketsiz dugme ekleyemez.
  //     Taban DUSURULEREK degil, tooltip EKLENEREK gecilir.
  group('yalniz-ikon dugmelerde tooltip sozlesmesi', () {
    // Bugun (WP-D oncesi) olculen taban. `moderation_queue_card.dart` WP-B'nin,
    // `admin_announcements_tab.dart` hicbir WP'nin SAHIP yolunda degil.
    const baseline = <String, int>{
      'tabs/admin_announcements_tab.dart': 1,
      'widgets/moderation_queue_card.dart': 2,
    };
    const owned = <String>{
      'tabs/admin_reports_tab.dart',
      'tabs/admin_groups_tab.dart',
      'tabs/admin_audit_log_tab.dart',
      'tabs/admin_dashboard_tab.dart',
    };

    test('WP-D dosyalarinda sifir, digerlerinde taban asilmaz', () {
      final counts = _tooltiplessCounts();

      for (final entry in counts.entries) {
        final isOwned =
            owned.contains(entry.key) || entry.key.startsWith('directory/');
        if (isOwned) {
          expect(
            entry.value,
            0,
            reason:
                'ADMIN-PANEL-PLAN §4.6 / §5 WP-D kabul 7: ${entry.key} icinde '
                '${entry.value} yalniz-ikon dugme tooltipsiz.',
          );
        } else {
          expect(
            entry.value,
            lessThanOrEqualTo(baseline[entry.key] ?? 0),
            reason:
                '${entry.key} icinde yeni tooltipsiz yalniz-ikon dugme var. '
                'Tabani yukseltme — `tooltip:` ekle (PLAN §4.6).',
          );
        }
      }
    });
  });
}

/// `app/lib/features/admin/**` altindaki her dosya icin tooltip'siz yalniz-ikon
/// kontrol sayisi. Kaynak taramasi: bu sozlesme baska lane'lerin dosyalarini da
/// **olcer** ama duzeltmez.
Map<String, int> _tooltiplessCounts() {
  const root = 'lib/features/admin';
  const constructors = <String>[
    'IconButton(',
    'IconButton.outlined(',
    'IconButton.filled(',
    'IconButton.filledTonal(',
    'FloatingActionButton(',
    'FloatingActionButton.small(',
    'FloatingActionButton.extended(',
    'PopupMenuButton<',
    'PopupMenuButton(',
  ];

  final result = <String, int>{};
  final files =
      Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final file in files) {
    final source = file.readAsStringSync();
    var missing = 0;
    for (final ctor in constructors) {
      var from = 0;
      while (true) {
        final at = source.indexOf(ctor, from);
        if (at < 0) break;
        from = at + 1;
        final open = source.indexOf('(', at + ctor.length - 1);
        if (open < 0) break;
        var depth = 0;
        var close = -1;
        for (var i = open; i < source.length; i++) {
          final ch = source[i];
          if (ch == '(') {
            depth++;
          } else if (ch == ')') {
            depth--;
            if (depth == 0) {
              close = i;
              break;
            }
          }
        }
        if (close < 0) break;
        final body = source.substring(open, close + 1);
        if (!RegExp(r'\btooltip\s*:').hasMatch(body)) missing++;
      }
    }
    final rel = file.path
        .replaceAll(r'\', '/')
        .replaceFirst('$root/', '');
    result[rel] = missing;
  }
  return result;
}
