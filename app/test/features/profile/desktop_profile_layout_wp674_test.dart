// WP-674 — PROFIL + BASARIMLAR MASAUSTU DUZENI.
//
// Sahip v64 Windows surumunu reddetti: "dikey mobil uygulama icin tasarlanan
// arayuzler yatay pc ekraninda cok kotu duruyor". Bu dosyanin olctugu uc kusur
// (hepsi duzeltme oncesi GERCEK olcum, uydurma degil):
//
//   basarimlar @2560 : en genis etiket-deger satiri 2488 px ("Toplam" -> "0sn",
//                      arasi 2348 px bosluk); en genis kart 2520 px, icindeki
//                      en genis metin 260 px -> 2260 px olu alan.
//   basarimlar @1920 : icerik araligi 1872 px, en genis satir 1848 px.
//   profil    @1920/2560 : icerik 646 px'lik TEK okuma sutunu, iki yani bos;
//                      cizilen agacta hicbir masaustu yuzey widget'i yok.
//
// 🔴 Iddialarin hepsi CIZILEN KUTUDAN okunur (`getRect`/`getSize`). Kaynakta
// `maxWidth: 496` yazmasi kanit degildir — depoda kayitli ders: "dogruluk
// kaynagi dogruyken ekran bos olabilir" (0126 uretim regresyonu kapi boyunca
// yesil kaldi).
//
// NEYI KORUMAZ: guzellik, renk/kontrast, katlanin alti, golden. Bunlar ayri
// kapilardir. Burada olculen sey MESAFE ve TAVAN.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/desktop/desktop_layout.dart';
import 'package:online_study_room/core/device_integrations/samsung_modes_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/achievement.dart';
import 'package:online_study_room/data/models/gamification_profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/features/profile/widgets/achievement_showcase.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/profile/widgets/gamification_card.dart';
import 'package:online_study_room/features/profile/widgets/profile_stats_panel.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:online_study_room/main.dart';

import '../../support/v8_test_setup.dart';

/// SPEC §2.3 "Form / ayar satiri" = `DesktopSurface.readingWidth`.
/// Tek bir kart yuzeyi icin depodaki en musamahakar tavan.
const double kMaxCardWidth = DesktopBreakpoints.maxFormWidth; // 760

/// SPEC KURAL 2.2 HEDEFI (Bringhurst 66ch). Kapi (`desktop_stretch_contract`)
/// yalniz 600 px'lik SERT tavani olcer; burada hedefin kendisi kilitlenir ki
/// bir sonraki ajan 599 px'e kadar gevseyemesin.
const double kLabelValueTarget =
    DesktopBreakpoints.labelValueTargetWidth; // 496

void main() {
  final tr = AppLocalizationsTr();

  /// 🔴 `debugDefaultTargetPlatformOverride` test GOVDESI BITMEDEN geri
  /// alinmali; `tearDown` cok gec kalir ve "foundation debug variable was
  /// changed by the test" hatasi asil iddianin yerine gecer.
  Future<void> onWindows(Future<void> Function() body) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  Future<void> settle(WidgetTester tester) async {
    try {
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 3),
      );
    } catch (_) {
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 120));
      }
    }
  }

  /// Gercek uygulamayi verilen pencerede cizer ve Profil sekmesini acar.
  Future<void> openProfileTab(WidgetTester tester, Size window) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window;
    addTearDown(tester.view.reset);

    final preferences = await v8SharedPreferences();
    final auth = await signedInV8AuthRepository(prefs: preferences);
    final groupRepository = InMemoryGroupRepository();
    final profile = (await auth.authStateChanges().first)!;
    await groupRepository.createGroup(name: 'Odak Kampi', creator: profile);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          groupRepositoryProvider.overrideWithValue(groupRepository),
          sharedPreferencesProvider.overrideWithValue(preferences),
          deviceIntegrationServiceProvider.overrideWithValue(
            V8TestDeviceIntegrationService(),
          ),
          androidWidgetServiceProvider.overrideWithValue(V8TestWidgetGateway()),
        ],
        child: const OnlineStudyRoomApp(),
      ),
    );
    await settle(tester);
    await tester.tap(find.text(tr.profileProfil).first);
    await settle(tester);
  }

  /// Profil sekmesinden Basarimlar (tam ekran rota) ekranina gecer.
  Future<void> openAchievements(WidgetTester tester, Size window) async {
    await openProfileTab(tester, window);
    final entry = find.text(tr.profileRozetlerinSerilerinVeIlerlemen);
    expect(
      entry,
      findsWidgets,
      reason: 'Profilden basarimlara giris satiri yok; ekran olculemez.',
    );
    await tester.tap(entry.first);
    await settle(tester);
  }

  /// Ekranda GORUNEN butun `Card` kutulari (offstage olanlar haric).
  List<Rect> visibleCards(WidgetTester tester) => [
    for (final element in find.byType(Card, skipOffstage: true).evaluate())
      tester.getRect(find.byElementPredicate((e) => e == element)),
  ];

  group('basarimlar ekrani — masaustu', () {
    for (final window in const [Size(1920, 1080), Size(2560, 1440)]) {
      final w = window.width.toInt();

      testWidgets(
        '@${w}x${window.height.toInt()} kart tavani 760 px',
        (tester) async => onWindows(() async {
          await openAchievements(tester, window);

          // ÖNCE: @1920 en genis kart 1880 px, @2560 2520 px.
          final cards = visibleCards(tester)
            ..sort((a, b) => b.width.compareTo(a.width));
          expect(cards, isNotEmpty, reason: 'hic kart cizilmemis');
          expect(
            cards.first.width,
            lessThanOrEqualTo(kMaxCardWidth),
            reason:
                'SPEC §2.3: bir kart yuzeyi 760 px\'i asamaz. En genis kart '
                '${cards.first.width.toStringAsFixed(0)} px cizildi — pencereye '
                'gore boyutlanmis, icerigine gore degil.',
          );
        }),
      );

      testWidgets(
        '@${w}x${window.height.toInt()} etiket-deger satiri hedef 496 px',
        (tester) async => onWindows(() async {
          await openAchievements(tester, window);

          // ÖNCE: "En verimli gun" -> "—" satiri @1920 1848 px, @2560 2488 px.
          final label = find.text(tr.statsEnVerimliGun);
          final value = find.byKey(const Key('profile-stat-peak-day'));
          expect(label, findsOneWidget);
          expect(value, findsOneWidget);

          final span = tester.getRect(value).right - tester.getRect(label).left;
          expect(
            span,
            lessThanOrEqualTo(kLabelValueTarget),
            reason:
                'SPEC KURAL 2.2: etiketin solu ile degerin sagi arasi hedef '
                '496 px (sert tavan 600). Olculen ${span.toStringAsFixed(0)} px '
                '— goz satir basina donemez.',
          );
        }),
      );

      testWidgets(
        '@${w}x${window.height.toInt()} iki pane yan yana + katalog cok sutunlu',
        (tester) async => onWindows(() async {
          await openAchievements(tester, window);

          // Sol ray: tac seridi. Sag pane: katalog basligi.
          final crown = tester.getRect(
            find.byKey(const ValueKey('crown-header-tiers-gate')),
          );
          final catalog = tester.getRect(
            find.text(tr.profileBasariKatalogu).first,
          );
          expect(
            catalog.left,
            greaterThanOrEqualTo(crown.right),
            reason:
                'SPEC §1.2 `large` (1200): geniş pencerede kimlik rayı ile '
                'katalog YAN YANA durmali. Tac ${crown.left.toStringAsFixed(0)}'
                '..${crown.right.toStringAsFixed(0)}, katalog '
                '${catalog.left.toStringAsFixed(0)} px\'te basliyor — '
                'ust uste, yani hala tek sutun.',
          );
          expect(
            crown.width,
            lessThanOrEqualTo(kLabelValueTarget),
            reason:
                'Sol ray SPEC KURAL 2.2 olcusunde (496 px) kalmali; sahibin '
                '"tac ortada, iki yaninda devasa bosluk" sikayeti tam olarak '
                'bu seridin pencere genisligine yayilmasiydi.',
          );

          // Katalog ızgarası: en az iki dosseme AYNI satirda.
          final tiles = visibleCards(
            tester,
          ).where((rect) => rect.left >= catalog.left - 1).toList();
          expect(
            tiles.length,
            greaterThanOrEqualTo(2),
            reason: 'katalog dossemesi bulunamadi',
          );
          final sameRow = tiles.where(
            (other) =>
                other != tiles.first &&
                (other.top - tiles.first.top).abs() < 1 &&
                (other.left - tiles.first.left).abs() > 1,
          );
          expect(
            sameRow,
            isNotEmpty,
            reason:
                'SPEC §5: rozet izgarasi cok sutunlu olmali. Butun dossemeler '
                'ayri satirda — tek sutunluk mobil liste hala duruyor.',
          );
        }),
      );
    }
  });

  group('profil sekmesi — masaustu', () {
    testWidgets(
      '@1920 kimlik ve ayar sutunlari YAN YANA, ikisi de <= 760 px',
      (tester) async => onWindows(() async {
        await openProfileTab(tester, const Size(1920, 1080));

        // ÖNCE: tek 760 px'lik okuma sutunu; iki yani bos (icerik araligi 646 px).
        final gamification = tester.getRect(find.byType(GamificationCard));
        final actionsRow = tester.getRect(
          find.text(tr.profileCalismaKayitlarim).first,
        );
        expect(
          actionsRow.left,
          greaterThanOrEqualTo(gamification.right),
          reason:
              'SPEC §5: profil A3 (okuma) degil A2 (pano). `large` esiginde XP '
              'karti ile ayar/kayit sutunu yan yana durmali. XP karti '
              '${gamification.left.toStringAsFixed(0)}..'
              '${gamification.right.toStringAsFixed(0)}, "Calisma kayitlarim" '
              '${actionsRow.left.toStringAsFixed(0)} px.',
        );
        expect(
          gamification.width,
          lessThanOrEqualTo(kLabelValueTarget),
          reason: 'sol ray SPEC KURAL 2.2 olcusu (496 px)',
        );
        for (final card in visibleCards(tester)) {
          expect(
            card.width,
            lessThanOrEqualTo(kMaxCardWidth),
            reason: 'SPEC §2.3: kart tavani 760 px',
          );
        }
      }),
    );
  });

  group('ProfileStatsPanel — SPEC §8 iddia 3 (izole)', () {
    testWidgets(
      '1600 px genislikte bile etiket-deger satiri 496 pikselde durur',
      (tester) async => onWindows(() async {
        // 🔴 Bu iddia EKRANDAN BAĞIMSIZ olmali. Vitrin duzeni panele 496
        // px'lik bir ray verdigi surece paneldeki tavan OLCULEMEZ; kapi yesil
        // yanar ama kok neden (`profile_stats_panel.dart` icindeki TAVANSIZ
        // `Expanded`) yerinde durur ve panel baska bir yuzeye tasindigi anda
        // kusur geri gelir. SPEC §8 iddia 3 tam olarak bunu ister:
        // "ProfileStatsPanel 1600 px genislikte monte edilir".
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1600, 1200);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              userSessionsProvider.overrideWith(
                (ref) => Stream.value(const []),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('tr'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: ProfileStatsPanel(userId: 'me', isSelf: true),
                ),
              ),
            ),
          ),
        );
        await tester.pump();

        final label = find.text(tr.statsAktifGun);
        final value = find.byKey(const Key('profile-stat-active-days'));
        expect(label, findsOneWidget);
        expect(value, findsOneWidget);
        final span = tester.getRect(value).right - tester.getRect(label).left;
        expect(
          span,
          lessThanOrEqualTo(kLabelValueTarget),
          reason:
              'SPEC §2.2: `Expanded` TAVANSIZ oldugu surece satir kabi ne kadar '
              'genisse o kadar acilir. 1600 piksellik kapta olculen '
              '${span.toStringAsFixed(0)} px.',
        );
      }),
    );
  });

  group('islev kaybi yok', () {
    GamificationProfile gamification(String userId) => GamificationProfile(
      userId: userId,
      streakFreezes: 0,
      xp: 0,
      crownRank: 'wood_novice',
      selectedBadges: const [],
      createdAt: DateTime(2026, 8, 10),
      updatedAt: DateTime(2026, 8, 10),
    );

    Widget wrap(Widget child) => ProviderScope(
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

    testWidgets(
      'GENIS masaustunde de gizli basarim baskasinin profilinde ????? kalir',
      (tester) async => onWindows(() async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(2560, 1440);
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          wrap(
            AchievementShowcase(
              gamification: gamification('other'),
              userAchievements: [
                UserAchievement(
                  id: 'other-marathon_total',
                  userId: 'other',
                  achievementId: 'marathon_total',
                  tier: 2,
                  progress: 2,
                  unlockedAt: DateTime(2026, 8, 10),
                  createdAt: DateTime(2026, 8, 10),
                  updatedAt: DateTime(2026, 8, 10),
                ),
              ],
              metricProgress: const [],
              isSelf: false,
              showCatalog: true,
            ),
          ),
        );
        await tester.pump();

        // WP-660'in gizlilik iddiasi: iki sutunlu duzen onu delmez.
        expect(
          find.text('?????'),
          findsWidgets,
          reason:
              'Kilitli gizli basarim baskasinin profilinde adiyla gorunemez '
              '(WP-660). Iki sutuna gecis bunu delmemeli.',
        );
        expect(find.text('Gece Kuşu'), findsNothing);
        expect(find.text('404 Dakika'), findsNothing);
        // Rozet vitrini, unvan satiri ve kademe ilerlemesi de kaybolmadi.
        expect(find.text('2/6 kademe'), findsOneWidget);
        expect(find.textContaining(tr.profileVitrin), findsWidgets);
      }),
    );

    testWidgets('mobil 390x844: tek sutun, katalog dossemeleri UST USTE', (
      tester,
    ) async {
      // Platform override YOK: mobil dal (`isDesktopWindow == false`).
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        wrap(
          AchievementShowcase(
            gamification: gamification('me'),
            userAchievements: const [],
            metricProgress: const [],
            isSelf: true,
            showCatalog: true,
            statsPanel: const SizedBox(
              key: Key('wp674-stats-slot'),
              height: 40,
            ),
          ),
        ),
      );
      await tester.pump();

      final crown = tester.getRect(
        find.byKey(const ValueKey('crown-header-tiers-gate')),
      );
      final slot = tester.getRect(const Key('wp674-stats-slot').toFinder());
      expect(
        slot.bottom,
        lessThanOrEqualTo(crown.top),
        reason:
            'SPEC §7: mobil sira degismez — istatistik paneli tac seridinin '
            'USTUNDE kalir.',
      );
      expect(
        crown.width,
        greaterThan(300),
        reason:
            'mobilde tac seridi tam genislikte kalmali; masaustu 496 px rayi '
            'mobile sizmamali',
      );

      // Katalog: mobilde her dosseme kendi satirinda (tek sutun).
      final tiles = visibleCards(tester);
      expect(tiles.length, greaterThanOrEqualTo(2));
      for (final tile in tiles.skip(1)) {
        expect(
          (tile.left - tiles.first.left).abs(),
          lessThan(1),
          reason:
              'SPEC §7: mobil izgara TEK sutundur. Iki dosseme farkli `dx`\'te '
              'cizildi — masaustu izgarasi mobil dala sizmis.',
        );
      }
    });
  });
}

extension on Key {
  Finder toFinder() => find.byKey(this);
}
