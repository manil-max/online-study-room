// WP-776 — yonetim > kullanici profil paneli.
//
// Sahip: *"basinca detayli profil ekrani acilsin, hesap acma tarihi vs vs gibi
// ayri bir panelde her seyi gorebileyim... cok sikayet ettiklerini / sikayet
// edildiklerini ve en ustte de oranlari, aldigi cezalar tarihler gibi cok
// detayli bir sey istiyorum."*
//
// 🔴 Bu dosyadaki her olcum EKRANDAN alinir, saglayicidan degil. Sebep depoda
// kayitli: "bitmis backend, baglanmamis UI" — model dogru sayiyi tasiyip ekran
// hic cizmedigi hâlde kapi yesil yanabiliyor. `AdminUserInsight.
// upheldAgainstRatio` zaten kendi birim testine sahip; burada olculen sey
// **cizilen cubugun genisligi** ve **ekrandaki metin**.
//
// Nobetciler ve sabote edildiklerinde ne olur:
//   1. 5/7 -> ekranda "5/7" + cubuk genisligi yatagin %71'i.  (orani ters
//      cevirince kirmizi)
//   2. `reportsAgainst = 0` -> cubuk YOK + "hic sikayet edilmemis" cumlesi;
//      0/5 ile AYNI GORUNMEZ. (`null` dali silinip 0.0'a yuvarlanirsa kirmizi)
//   3. Cubuk rengi ANLAMA gore ayrisir: hakkinda acilan = tehlike, kendi
//      actigi = basari. (ikisine tek renk verilince kirmizi)
//   4. Ceza gecmisinin tarihleri ve turleri ekranda gorunur.
//   5. Silinmis hesapta yaptirim dugmesi devre disi.
//   6. 360 dp'de tasma yok.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/admin_user_insight.dart';
import 'package:online_study_room/data/models/moderation_sanction.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_moderation_repository.dart';
import 'package:online_study_room/features/admin/detail/admin_user_profile_page.dart';
import 'package:online_study_room/features/admin/sanctions/sanction_ladder.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const String _userId = '8f3c1d2a-77b4-4e19-9a0c-5b6e2f1d8c43';

/// Fikstur uretmeyen depo: kayit YOKSA sifirli bos dosya doner. Testin
/// gordugu her sayi bu dosyadan konulmustur.
InMemoryAdminModerationRepository _repo({AdminUserInsight? insight}) {
  final repo = InMemoryAdminModerationRepository();
  if (insight != null) repo.userInsights[_userId] = insight;
  return repo;
}

AdminUserInsight _insight({
  int against = 0,
  int againstUpheld = 0,
  int filed = 0,
  int filedUpheld = 0,
  bool deleted = false,
  String? displayName = 'Mert K.',
  String? email = 'mert@example.com',
  List<String> groups = const ['Odak Grubu'],
}) => AdminUserInsight(
  userId: _userId,
  reportsAgainst: against,
  reportsAgainstUpheld: againstUpheld,
  reportsFiled: filed,
  reportsFiledUpheld: filedUpheld,
  displayName: displayName,
  email: email,
  accountCreatedAt: DateTime(2026, 3, 12, 9, 15),
  lastSeenAt: DateTime(2026, 9, 5, 14, 40),
  totalStudySeconds: 533_000,
  currentStreakDays: 6,
  groupNames: groups,
  isDeleted: deleted,
);

Widget _host(InMemoryAdminModerationRepository repo) => ProviderScope(
  overrides: [adminModerationRepositoryProvider.overrideWithValue(repo)],
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const AdminUserProfilePage(userId: _userId),
  ),
);

AppLocalizations _l10n(WidgetTester tester) =>
    AppLocalizations.of(tester.element(find.byType(AdminUserProfilePage)));

ColorScheme _scheme(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(AdminUserProfilePage))).colorScheme;

/// Cubugun cizilen rengi — widget agacindan, sabitten degil.
Color _barColor(WidgetTester tester, String slot) {
  final box = tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byKey(adminUserRatioFillKey(slot)),
      matching: find.byType(DecoratedBox),
    ),
  );
  return (box.decoration as BoxDecoration).color!;
}

/// Dolunun yataga orani — yani gozun gordugu genislik.
double _barFraction(WidgetTester tester, String slot) {
  final track = tester.getSize(find.byKey(adminUserRatioTrackKey(slot))).width;
  final fill = tester.getSize(find.byKey(adminUserRatioFillKey(slot))).width;
  expect(track, greaterThan(0));
  return fill / track;
}

void main() {
  testWidgets('5/7 ekranda yazar ve cubuk yatagin %71ini kaplar', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(_repo(insight: _insight(against: 7, againstUpheld: 5))),
    );
    await tester.pumpAndSettle();

    expect(find.text('5/7'), findsOneWidget);
    expect(
      _barFraction(tester, kAdminUserRatioAgainst),
      closeTo(5 / 7, 0.005),
    );
  });

  testWidgets('cubuk rengi anlama gore ayrisir: tehlike vs basari', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        _repo(
          insight: _insight(
            against: 7,
            againstUpheld: 5,
            filed: 2,
            filedUpheld: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final against = _barColor(tester, kAdminUserRatioAgainst);
    final filed = _barColor(tester, kAdminUserRatioFiled);

    // Tek renge indirmek iki blogun anlamini yok eder.
    expect(against, isNot(filed));
    // Hakkinda acilan yuksek oran = kotu isaret.
    expect(against, _scheme(tester).error);
    // Kendi actigi yuksek oran = guvenilir sikayetci (basari tokeni).
    expect(filed, const Color(0xFF22C55E));
  });

  testWidgets('hic sikayet yok ile 0/5 AYNI gorunmez', (tester) async {
    // (a) Hic sikayet edilmemis: cubuk cizilmez, cumle yazilir.
    await tester.pumpWidget(_host(_repo(insight: _insight(against: 0))));
    await tester.pumpAndSettle();

    final l10n = _l10n(tester);
    expect(find.byKey(adminUserRatioTrackKey(kAdminUserRatioAgainst)), findsNothing);
    expect(find.byKey(adminUserRatioFillKey(kAdminUserRatioAgainst)), findsNothing);
    expect(find.text(l10n.adminUserProfileNoReportsAgainst), findsOneWidget);

    // (b) Bes kez sikayet edilmis, hicbiri tutmamis: cubuk VAR, sayi VAR,
    // "hic sikayet yok" cumlesi YOK.
    await tester.pumpWidget(
      _host(_repo(insight: _insight(against: 5, againstUpheld: 0))),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(adminUserRatioTrackKey(kAdminUserRatioAgainst)),
      findsOneWidget,
    );
    expect(
      find.byKey(adminUserRatioFillKey(kAdminUserRatioAgainst)),
      findsOneWidget,
    );
    expect(find.text('0/5'), findsOneWidget);
    expect(find.text(l10n.adminUserProfileNoReportsAgainst), findsNothing);
    expect(_barFraction(tester, kAdminUserRatioAgainst), 0);
  });

  testWidgets('ceza gecmisinin tarihi, turu ve gerekcesi ekranda gorunur', (
    tester,
  ) async {
    final repo = _repo(insight: _insight(against: 3, againstUpheld: 2));
    repo.clock = () => DateTime(2026, 7, 12, 10, 30);
    await repo.applySanction(
      const ModerationSanctionRequest(
        targetUserId: _userId,
        action: ModerationAction.warn,
        reason: 'tekrarlanan spam',
        idempotencyKey: 'wp776-sanction-1',
      ),
    );
    repo.clock = () => DateTime(2026, 8, 3, 9, 0);
    await repo.applySanction(
      const ModerationSanctionRequest(
        targetUserId: _userId,
        action: ModerationAction.suspend7d,
        reason: 'taciz',
        idempotencyKey: 'wp776-sanction-2',
      ),
    );

    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    final l10n = _l10n(tester);
    final history = find.byKey(kAdminUserSanctionsKey);
    // Ceza gecmisi panelin dibinde; liste tembel oldugu icin once gorunur
    // alana getirilir.
    await tester.dragUntilVisible(
      history,
      find.byKey(kAdminUserProfileKey),
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(history, findsOneWidget);

    for (final expected in [
      '2026-07-12',
      '2026-08-03',
      adminSanctionLabel(l10n, ModerationAction.warn),
      adminSanctionLabel(l10n, ModerationAction.suspend7d),
      'tekrarlanan spam',
      'taciz',
    ]) {
      expect(
        find.descendant(of: history, matching: find.text(expected)),
        findsOneWidget,
        reason: 'ceza gecmisinde "$expected" gorunmeli',
      );
    }
  });

  testWidgets('silinmis hesapta yaptirim dugmesi devre disi', (tester) async {
    await tester.pumpWidget(
      _host(_repo(insight: _insight(against: 4, againstUpheld: 2))),
    );
    await tester.pumpAndSettle();

    // Once acik oldugunu goster; yoksa "her zaman kapali" da testi gecerdi.
    expect(
      tester.widget<FilledButton>(find.byKey(kAdminUserSanctionApplyKey)).onPressed,
      isNotNull,
    );

    await tester.pumpWidget(
      _host(
        _repo(
          insight: _insight(against: 4, againstUpheld: 2, deleted: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.widget<FilledButton>(find.byKey(kAdminUserSanctionApplyKey)).onPressed,
      isNull,
    );
    // Oranlarin yerini "hesap silinmis" alir.
    expect(find.text(_l10n(tester).adminUserProfileDeleted), findsOneWidget);
    expect(
      find.byKey(adminUserRatioTrackKey(kAdminUserRatioAgainst)),
      findsNothing,
    );
  });

  testWidgets('360 dp dar telefonda tasma yok', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final repo = _repo(
      insight: _insight(
        against: 7,
        againstUpheld: 5,
        filed: 9,
        filedUpheld: 1,
        displayName: 'Abdurrahman Muhammed Karaosmanoglu',
        email: 'abdurrahman.muhammed.karaosmanoglu@ogrenci-portali.example.com',
        groups: const [
          'YKS 2027 Sayisal Kampi',
          'Sabah Odak Grubu',
          'Gece Calisma Ekibi',
        ],
      ),
    );
    repo.clock = () => DateTime(2026, 8, 3, 9, 0);
    await repo.applySanction(
      const ModerationSanctionRequest(
        targetUserId: _userId,
        action: ModerationAction.suspend14d,
        reason:
            'grup sohbetinde tekrarlanan asagilayici mesajlar ve uyarilara ragmen '
            'surdurulen taciz davranisi',
        idempotencyKey: 'wp776-sanction-wide',
      ),
    );

    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Panel gercekten cizilmis olsun; bos ekran da "tasma yok" derdi.
    expect(find.byKey(kAdminUserProfileKey), findsOneWidget);
    expect(find.byKey(kAdminUserAccountKey), findsOneWidget);
    expect(find.text('5/7'), findsOneWidget);

    // Alt serit sabittir: liste sonuna kadar kaydirilsa da dugme yerinde kalir.
    await tester.drag(find.byKey(kAdminUserProfileKey), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(find.byKey(kAdminUserSanctionApplyKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
