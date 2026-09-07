// WP-810 — vaka satirindaki oran rozeti **rolune gore** dogru sayiyi cizer.
//
// 🔴 OLCULEN KUSUR. Rozet (`admin_case_detail_page.dart` `_Signal`) vakadaki
// HER tarafa `reportsAgainstUpheld / reportsAgainst` yaziyordu — yani sikayet
// EDENIN satirinda da "bu kisi kac kez sikayet edildi" gosteriliyordu.
// Sikayetciye bakarken yoneticinin sordugu soru bu degil: *actigi sikayetlerin
// kaci tuttu?*
//
// Zarari somut ve ters yonde: dokuz sikayet acip biri bile tutmayan bir
// sikayetci, sirf KENDISI hic sikayet edilmedigi icin (`reportsAgainst == 0`)
// rozetsiz kaliyordu. Yani kuyrugu kotuye kullanan kisi, ekranda en TEMIZ
// gorunen kisiydi. `AdminUserInsight` dogru sayiyi zaten tasiyordu
// (`reportsFiled`, `reportsFiledUpheld`); eksik olan tek sey, satirin hangi
// yonu sordugunu bilmesiydi.
//
// Bu dosyanin ikinci iddiasi RENK: uyari rengi yalnizca sikayet EDILEN yonde
// yanar. Sikayetci yonunde ayni renk ters anlama gelir (yuksek oran =
// guvenilir sikayetci) ve istemci "kotuye kullanim" damgasini adil olarak
// hesaplayamaz — bkz. `_Signal` doc yorumu, sunucu esiginin paydasi
// REDDEDILEN sikayettir, istemcide o sayi yok.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/admin_user_insight.dart';
import 'package:online_study_room/data/models/moderation_case.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/report_target.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/admin_moderation_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_moderation_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/features/admin/detail/admin_case_detail_page.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _adminId = 'admin-1';
const _targetId = '22222222-2222-4222-8222-222222222222';
const _reporterId = '11111111-1111-4111-8111-111111111111';

const _againstLabel = 'Hakkında açılan şikâyet';
const _filedLabel = 'Kendi açtığı şikâyet';

AdminUserInsight _insight({
  required String userId,
  int against = 0,
  int againstUpheld = 0,
  int filed = 0,
  int filedUpheld = 0,
}) => AdminUserInsight(
  userId: userId,
  reportsAgainst: against,
  reportsAgainstUpheld: againstUpheld,
  reportsFiled: filed,
  reportsFiledUpheld: filedUpheld,
);

ModerationCase _case() => ModerationCase(
  caseId: 'case-report-a',
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
  reporters: const [
    ModerationIdentity(id: _reporterId, displayName: 'Ayse'),
  ],
  reportIds: const ['report-a'],
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

Future<void> _pump(
  WidgetTester tester, {
  required Map<String, AdminUserInsight> insights,
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final adminRepo = InMemoryAdminRepository(
    superAdminUserIds: const {_adminId},
  );
  addTearDown(adminRepo.dispose);

  final moderationCase = _case();
  final moderationRepo = InMemoryAdminModerationRepository(
    seed: [moderationCase],
  )..details['report-a'] = _detail();
  moderationRepo.userInsights.addAll(insights);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        adminModerationRepositoryProvider.overrideWithValue(moderationRepo),
        adminRepositoryProvider.overrideWithValue(adminRepo),
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
          mirrorTicket: null,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Bir satirin ICINDEKI rozet metni. Satir disindaki ayni metni yakalamamak
/// icin arama satir koku altinda yapilir — sayfada baska "5/7" olabilir.
Finder _badgeIn(String rowUserId, String text) => find.descendant(
  of: find.byKey(adminCaseUserRowKey(rowUserId)),
  matching: find.text(text),
);

Finder _tooltipIn(String rowUserId, String message) => find.descendant(
  of: find.byKey(adminCaseUserRowKey(rowUserId)),
  matching: find.byTooltip(message),
);

/// Rozetin arka plan rengi. Uyari rengi `errorContainer`dir.
Color? _badgeColor(WidgetTester tester, String rowUserId, String text) {
  final container = tester.widget<Container>(
    find
        .ancestor(
          of: _badgeIn(rowUserId, text),
          matching: find.byType(Container),
        )
        .first,
  );
  final decoration = container.decoration;
  return decoration is BoxDecoration ? decoration.color : null;
}

void main() {
  // --- ASIL IDDIA -----------------------------------------------------------
  testWidgets(
    '🔴 sikayet EDENIN rozeti ACTIGI sikayetlerin oranini gosterir',
    (tester) async {
      await _pump(
        tester,
        insights: {
          // Hedef: 7 sikayet almis, 5i tutmus.
          _targetId: _insight(
            userId: _targetId,
            against: 7,
            againstUpheld: 5,
          ),
          // Sikayetci: 9 sikayet acmis, YALNIZ 1i tutmus; kendisi hic
          // sikayet edilmemis. WP-810 oncesi bu satirda rozet HIC
          // cizilmiyordu (`reportsAgainst == 0` -> `total <= 0` -> bos).
          _reporterId: _insight(
            userId: _reporterId,
            against: 0,
            againstUpheld: 0,
            filed: 9,
            filedUpheld: 1,
          ),
        },
      );

      expect(
        _badgeIn(_reporterId, '1/9'),
        findsOneWidget,
        reason:
            'Dokuz sikayet acip biri tutan bir sikayetci ekranda gorunmeli. '
            'WP-810 oncesi bu satir BOSTU: kuyrugu kotuye kullanan kisi en '
            'temiz gorunen kisiydi.',
      );
      expect(
        _badgeIn(_targetId, '5/7'),
        findsOneWidget,
        reason: 'Hedef yonu degismedi: hakkindaki sikayetlerin orani.',
      );
    },
  );

  testWidgets('sikayetcinin satirinda HEDEFIN sayisi yazmaz', (tester) async {
    await _pump(
      tester,
      insights: {
        _targetId: _insight(userId: _targetId, against: 7, againstUpheld: 5),
        _reporterId: _insight(
          userId: _reporterId,
          against: 0,
          filed: 9,
          filedUpheld: 1,
        ),
      },
    );

    expect(
      _badgeIn(_reporterId, '5/7'),
      findsNothing,
      reason: 'Iki satir ayni sayiyi tasiyamaz; yon farki gorunur olmali.',
    );
    expect(
      _badgeIn(_targetId, '1/9'),
      findsNothing,
      reason: 'Hedef satiri sikayetcinin sayisini almamali.',
    );
  });

  // --- TOOLTIP: hangi soru yanitlaniyor -------------------------------------
  testWidgets('rozet hangi soruyu yanitladigini SOYLER', (tester) async {
    await _pump(
      tester,
      insights: {
        _targetId: _insight(userId: _targetId, against: 7, againstUpheld: 5),
        _reporterId: _insight(
          userId: _reporterId,
          filed: 9,
          filedUpheld: 1,
        ),
      },
    );

    expect(
      _tooltipIn(_targetId, _againstLabel),
      findsOneWidget,
      reason:
          'Ciplak "5/7" neyin orani oldugunu soylemez. Etiket kisi '
          'profilindeki olcum cubugununkiyle AYNI olmali.',
    );
    expect(
      _tooltipIn(_reporterId, _filedLabel),
      findsOneWidget,
      reason: 'Sikayetci satirinda etiket "kendi actigi sikayet" olmali.',
    );
    expect(
      _tooltipIn(_reporterId, _againstLabel),
      findsNothing,
      reason: 'Sikayetci satiri hedefin etiketini tasiyamaz.',
    );
  });

  // --- RENK: uyari yalnizca sikayet EDILEN yonde -----------------------------
  //
  // 🔴 BU TESTIN ILK HALI HICBIR SEY OLCMUYORDU ve sabotaj turu yakaladi.
  // Sikayetciye yalniz `filed` sayilari verilmisti; `flaggedAsOffender` ise
  // `reportsAgainst` uzerinden hesaplanir, o da 0'di. Yani "sikayetci yonunde
  // de uyari rengini yak" sabotaji uygulandiginda bayrak zaten `false`
  // donuyordu ve test YESIL kaliyordu.
  //
  // Dogru kurulum, bayragi GERCEKTEN yanan bir sikayetci ister: hem cok
  // sikayet edilmis (ve hakli cikilmis) hem de cok sikayet acmis biri. Boyle
  // birinin SIKAYETCI satirinda rozet, kendi actigi sikayetlerin oranini
  // notr renkle gostermelidir — "bu kisi kotu biri" hukmu o satirin sorusu
  // degildir.
  testWidgets('uyari rengi yalniz sikayet EDILEN yonde yanar', (tester) async {
    // Ayni kisi hem cok sikayet edilmis hem cok sikayet acmis olabilir.
    // `flaggedAsOffender`: 5 >= 3 ve 5*2 >= 7 -> **true** (ikisi icin de).
    final both = _insight(
      userId: _reporterId,
      against: 7,
      againstUpheld: 5,
      filed: 9,
      filedUpheld: 1,
    );
    await _pump(
      tester,
      insights: {
        _targetId: _insight(userId: _targetId, against: 7, againstUpheld: 5),
        _reporterId: both,
      },
    );

    expect(
      both.flaggedAsOffender,
      isTrue,
      reason:
          'Testin kurulumu bayragi GERCEKTEN yakmali; yoksa renk dali hic '
          'calismaz ve iddia bos kalir (ilk halinde tam bu oldu).',
    );

    final scheme = Theme.of(
      tester.element(find.byType(AdminCaseDetailPage)),
    ).colorScheme;

    expect(
      _badgeColor(tester, _targetId, '5/7'),
      scheme.errorContainer,
      reason:
          'Tekrar eden ve cogunlukla hakli cikan oruntu uyari rengini hak '
          'eder.',
    );
    expect(
      _badgeColor(tester, _reporterId, '1/9'),
      scheme.surfaceContainerHighest,
      reason:
          'Ayni kisi sikayet EDILEN olarak bayrakli olsa bile, SIKAYETCI '
          'satirindaki rozet notr kalir: o satirin sorusu "actigi sikayetler '
          'tuttu mu". Uyari rengini buraya tasimak, istemcinin adil '
          'hesaplayamadigi bir "kotuye kullanim" hukmu gibi okunurdu '
          '(sunucu esiginin paydasi REDDEDILEN sikayet, istemcide o sayi yok).',
    );
  });

  // --- SIFIR: olculmemis sey cizilmez ---------------------------------------
  testWidgets('hic sikayet acmamis sikayetciye rozet cizilmez', (tester) async {
    await _pump(
      tester,
      insights: {
        _targetId: _insight(userId: _targetId, against: 4, againstUpheld: 1),
        // Hicbir yonde sayi yok.
        _reporterId: _insight(userId: _reporterId),
      },
    );

    expect(
      _tooltipIn(_reporterId, _filedLabel),
      findsNothing,
      reason: '"0/0" olculmus bir sey degildir; rozet hic cizilmemeli.',
    );
    expect(
      _badgeIn(_targetId, '1/4'),
      findsOneWidget,
      reason: 'Hedef satiri etkilenmemeli.',
    );
  });

  // --- DAVRANIS CEVIRIYE BAGLI DEGIL ----------------------------------------
  testWidgets('yon CEVIRILMIS etiketten degil, parametreden gelir', (
    tester,
  ) async {
    // Ingilizce arayuzde de sikayetci kendi actigi sikayetin oranini gorur.
    // `_CaseUserRow.role` cevirilmis metindir; rozet ona bakarak secilseydi
    // dil degisince sessizce yanlis sayiya donerdi.
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final adminRepo = InMemoryAdminRepository(
      superAdminUserIds: const {_adminId},
    );
    addTearDown(adminRepo.dispose);
    final moderationCase = _case();
    final moderationRepo = InMemoryAdminModerationRepository(
      seed: [moderationCase],
    )..details['report-a'] = _detail();
    moderationRepo.userInsights.addAll({
      _targetId: _insight(userId: _targetId, against: 7, againstUpheld: 5),
      _reporterId: _insight(userId: _reporterId, filed: 9, filedUpheld: 1),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminModerationRepositoryProvider.overrideWithValue(moderationRepo),
          adminRepositoryProvider.overrideWithValue(adminRepo),
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
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AdminCaseDetailPage(
            moderationCase: moderationCase,
            mirrorTicket: null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      _badgeIn(_reporterId, '1/9'),
      findsOneWidget,
      reason: 'Dil degisti, yon degismemeli.',
    );
    expect(_badgeIn(_targetId, '5/7'), findsOneWidget);
  });
}
