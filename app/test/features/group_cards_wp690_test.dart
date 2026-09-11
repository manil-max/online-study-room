// WP-690 — GRUPLAR SEKMESINDE TEKRAR EDEN SATIR + BOS SAG TARAF.
//
// Sahip telefonda Gruplar sekmesinde iki duzen kusuru gordu:
//
//   1. "Siralama" kartinin en ustunde, hemen ustundeki "Grup hedefi" kartiyla
//      AYNI bilgiyi tekrarlayan bir satir var (bayrak + "Grup hedefi" + seri
//      rozeti + yuzde + ilerleme cubugu). Sahip: "ranking kismida group goal
//      olmasina gerek yok, hemen ustunde var zaten, gereksiz yere uzatiyor
//      karti."
//   2. "Grup hedefi" kartinin SAG TARAFI bos; seri rozeti ortada ve kucuk.
//      Sahip: "sag taraf bos kalmis, oraya seriyi koysak daha guzel olur, hem
//      daha buyuk koyma sansi olur."
//
// 🔴 Bu dosya once OLCER (hunter SKILL §1: "sorun bulamadim" bir sonuc
// degildir). Butun sayilar CIZILEN kutulardan (`tester.getRect`/`getSize`)
// okunur; hicbir iddia kaynakta bir sabit aramaz.
//
// 🔴 SAHTE YESIL TUZAGI: `cardLabelValueRow` (`home/widgets/card_scaffold.dart`
// :19) icerigi `Align` + `ConstrainedBox` icine sarar. `Align` KABI doldurur —
// onu olcersen tavani degil hucreyi olcersin. Bu yuzden rozet `GoalStreakFlame`
// dugumunden okunur (o dugum `Container` cizer, kap degildir).
//
// 🔴 IKINCI SAHTE YESIL TUZAGI — bu dosyayi yazarken YASANDI: `LeaderboardCard`
// widget testinde `groupAlphaScoresProvider` gercek analitik deposunu ariyor,
// bulamiyor ve `cardDataGate` karti "Veriler yuklenemedi" hata kabuguna
// dusuruyor. Ilk kosuda "siralama kartinda Grup hedefi satiri = 0" cikti, yani
// kusur "duzelmis" sanilacakti; olculen sey kart degil HATA EKRANIYDI.
// Override eklenince satir 1 oldu. Bu yuzden asagidaki her sozlesme once kartin
// GERCEK govdesinin cizildigini dogrular ("Siralama" basligi + bir uye satiri).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/device_integrations/samsung_modes_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/analytics_query_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/features/classroom/widgets/campfire_scene.dart';
import 'package:online_study_room/features/home/widgets/group_goal_card.dart';
import 'package:online_study_room/features/home/widgets/leaderboard_card.dart';
import 'package:online_study_room/features/stats/widgets/goal_streak_flame.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:online_study_room/main.dart';

import '../support/v8_test_setup.dart';

/// 🔴 WP-690 — DUZELTME LIDER KARARIYLA IKI PARCA.
///
/// Kusurlarin kodu `classroom/**` icinde degil, `home/widgets/` ve
/// `stats/widgets/` icinde; ustelik ayni iki widget Ana Sayfa panosunda da
/// cizilir (`home/dashboard_card.dart:540-541`). Bu yuzden duzeltme GLOBAL
/// degil KOSULLU yapildi:
///
///   * `LeaderboardCard.showGoalRow` — varsayilan `true` (Ana Sayfa panosu
///     DEGISMEDI), `classroom_screen.dart` `false` geciyor.
///   * `GoalStreakFlameSize.large` — yeni kademe; "kucuk" olan `compact`
///     DEGILDI, Gruplar sekmesindeki rozet zaten `regular`di (olculdu: ikon
///     20 px), o yuzden yeni kademe sart oldu.
///
/// Asagidaki `PANO` testi "Ana Sayfa degismedi" iddiasini olcer — kosullu
/// duzeltmenin sessizce global olmadigini yakalayan tek kanca odur.

void main() {
  final tr = AppLocalizationsTr();

  /// 🔴 Bayrak test GOVDESI BITMEDEN geri alinmali; `tearDown` gec kalir ve
  /// "foundation debug variable was changed by the test" diye patlar.
  Future<void> onPlatform(
    TargetPlatform? platform,
    Future<void> Function() body,
  ) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await body();
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }

  /// Kamp atesi surekli animasyonlu + `GroupGoalCard` saniyelik `Timer`
  /// kuruyor; `pumpAndSettle` burada asla oturmaz.
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

  /// Gercek uygulamayi verilen pencerede cizer ve Gruplar sekmesine gider.
  ///
  /// Istatistik `groupDailyStatsProvider` uzerinden verilir — iki kartin da
  /// GERCEKTEN okudugu yol budur (`group_goal_card.dart:78`,
  /// `leaderboard_card.dart:85`). Depoyu mock'lamak yerine ekranin okudugu
  /// provider besleniyor (hunter SKILL §3).
  Future<void> openGroups(
    WidgetTester tester, {
    required Size window,
    int myTodaySeconds = 0,
    int peerTodaySeconds = 0,
    bool peerStudying = false,
  }) async {
    tester.binding.platformDispatcher.localesTestValue = const [Locale('tr')];
    addTearDown(tester.binding.platformDispatcher.clearLocalesTestValue);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window;
    addTearDown(tester.view.reset);

    final preferences = await v8SharedPreferences();
    final auth = await signedInV8AuthRepository(prefs: preferences);
    final groupRepository = InMemoryGroupRepository();
    final me = (await auth.authStateChanges().first)!;
    final group = await groupRepository.createGroup(
      name: 'Odak Kampi',
      creator: me,
    );
    final peer = Profile(
      id: 'peer-1',
      displayName: 'Komsu',
      createdAt: DateTime(2026, 1, 1),
    );
    await groupRepository.joinGroup(inviteCode: group.inviteCode, member: peer);

    // `todaySecondsByUser` ve `groupDayTotals` ikisi de `dayOf(now)` gunune
    // bakar; gunu testin kostugu andan uretiyoruz.
    final today = dayOf(DateTime.now());
    final stats = <DailyStat>[
      DailyStat(userId: me.id, day: today, seconds: myTodaySeconds),
      DailyStat(userId: peer.id, day: today, seconds: peerTodaySeconds),
    ];

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
          groupDailyStatsProvider.overrideWith((ref) => Stream.value(stats)),
          // Bkz. dosya basindaki IKINCI SAHTE YESIL TUZAGI notu: bu override
          // olmadan olculen sey kart degil "Veriler yuklenemedi" ekrani olur.
          groupAlphaScoresProvider.overrideWith((ref) async => const {}),
          groupPresenceProvider.overrideWith(
            (ref) => Stream.value([
              Presence(
                userId: peer.id,
                groupId: group.id,
                status: peerStudying
                    ? PresenceStatus.studying
                    : PresenceStatus.onBreak,
                todaySeconds: peerTodaySeconds,
                startedAt: peerStudying ? DateTime.now() : null,
              ),
            ]),
          ),
        ],
        child: const OnlineStudyRoomApp(),
      ),
    );
    await settle(tester);

    await tester.tap(find.text(tr.desktopGruplar).first);
    await settle(tester);

    expect(
      find.byType(CampfireScene),
      findsOneWidget,
      reason:
          'Gruplar sekmesi cizilmedi; hicbir sey olculemez. Once kabugun '
          'ayakta oldugundan emin ol.',
    );
  }

  /// Kartin GERCEK govdesi cizildi mi (hata/iskelet kabugu degil)?
  void assertBoardBodyIsReal() {
    expect(
      find.descendant(
        of: find.byType(LeaderboardCard),
        matching: find.text(tr.homeSiralama),
      ),
      findsOneWidget,
      reason:
          'Siralama karti govdesini cizmemis (muhtemelen veri kapisi). Bu '
          'halde "grup hedefi satiri yok" iddiasi SAHTE YESIL olur.',
    );
    expect(
      find.descendant(
        of: find.byType(LeaderboardCard),
        matching: find.text('Komsu'),
      ),
      findsOneWidget,
      reason: 'Siralama satirlari cizilmemis; olculecek kart yok.',
    );
  }

  /// Rozetin GORUNEN kutusu. `GoalStreakFlame` `Container` cizer — `Align`
  /// gibi kabi doldurmaz, yani tavan degil isaretin kendisi olculur.
  Rect badgeRectIn(WidgetTester tester, Finder cardFinder) {
    final flame = find.descendant(
      of: find.descendant(
        of: cardFinder,
        matching: find.byType(GoalStreakBadge),
      ),
      matching: find.byType(GoalStreakFlame),
    );
    expect(flame, findsOneWidget, reason: 'Kartta seri rozeti yok.');
    return tester.getRect(flame);
  }

  double badgeIconSizeIn(WidgetTester tester, Finder cardFinder) {
    final icon = find.descendant(
      of: find.descendant(
        of: cardFinder,
        matching: find.byType(GoalStreakBadge),
      ),
      matching: find.byType(Icon),
    );
    expect(icon, findsOneWidget);
    return tester.getSize(icon).height;
  }

  /// Bir kartta cizilen "%NN" metni (yoksa `null`).
  String? percentIn(Finder cardFinder) {
    final found = find
        .descendant(
          of: cardFinder,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Text &&
                w.data != null &&
                RegExp(r'^%\d+$').hasMatch(w.data!),
          ),
        )
        .evaluate();
    if (found.isEmpty) return null;
    return (found.first.widget as Text).data;
  }

  // ======================= 0. OLCUM (baseline) =============================
  //
  // Iddia degil OLCUM: bugunku sayilari yazdirir, boylece raporda "ONCE"
  // degeri tahmin degil cikti olur. Kusur duzelince de yesil kalir.

  for (final window in const [Size(390, 844), Size(1920, 1080)]) {
    final w = window.width.toInt();
    final platform = w == 390 ? TargetPlatform.android : TargetPlatform.windows;

    testWidgets(
      'OLCUM $w: iki kartin kutusu + rozetin kutusu',
      (tester) async => onPlatform(platform, () async {
        await openGroups(
          tester,
          window: window,
          myTodaySeconds: 2 * 3600 + 22 * 60,
          peerTodaySeconds: 3600,
        );
        assertBoardBodyIsReal();

        final goal = tester.getRect(find.byType(GroupGoalCard));
        final board = tester.getRect(find.byType(LeaderboardCard));
        final badge = badgeRectIn(tester, find.byType(GroupGoalCard));
        final dupRows = find
            .descendant(
              of: find.byType(LeaderboardCard),
              matching: find.text(tr.homeGrupHedefi),
            )
            .evaluate()
            .length;

        final timeText = find.descendant(
          of: find.byType(GroupGoalCard),
          matching: find.text('3sa 22dk / 6sa'),
        );
        final label = find.descendant(
          of: find.byType(GroupGoalCard),
          matching: find.text(tr.homeGrupHedefi),
        );
        // ignore: avoid_print
        print(
          'WP690-PARCA@$w | sureMetni ${tester.getRect(timeText)} '
          '| etiket ${tester.getRect(label.at(1))} '
          '| baslik ${tester.getRect(label.first)} '
          '| rozet $badge',
        );
        // ignore: avoid_print
        print(
          'WP690-OLCUM@$w | hedefKarti ${goal.width}x${goal.height} '
          '| siralamaKarti ${board.width}x${board.height} '
          '| rozet ${badge.width}x${badge.height} sol=${badge.left} '
          '| rozetIkon ${badgeIconSizeIn(tester, find.byType(GroupGoalCard))} '
          '| kartMerkeziX ${goal.center.dx} rozetMerkeziX ${badge.center.dx} '
          '| rozetSagi..kartSagi ${goal.right - badge.right} px '
          '| siralamadaGrupHedefiSatiri $dupRows '
          '| hedefYuzdesi ${percentIn(find.byType(GroupGoalCard))} '
          '| siralamaYuzdesi ${percentIn(find.byType(LeaderboardCard))}',
        );
      }),
    );
  }

  // ============ 1. TEKRAR MI? Iki yuzde AYNI kaynaktan mi geliyor? =========
  //
  // Sahibin ekran goruntusunde ustte %23, altta %22 yaziyordu — "ayni sayi
  // degil" gorunumu, kaldirmanin bilgi kaybi olup olmadigi sorusunu doguruyor.
  // Asagidaki iki test cevabi EKRANDAN verir, kaynak okuyarak degil.

  testWidgets(
    'TEKRAR KANITI: ayni istatistikte iki kart AYNI yuzdeyi cizer',
    (tester) async => onPlatform(TargetPlatform.android, () async {
      await openGroups(
        tester,
        window: const Size(390, 844),
        myTodaySeconds: 2 * 3600 + 22 * 60,
        peerTodaySeconds: 3600,
      );
      assertBoardBodyIsReal();

      final goalPct = percentIn(find.byType(GroupGoalCard));
      final boardPct = percentIn(find.byType(LeaderboardCard));
      expect(goalPct, isNotNull);

      // Siralama karti hedef satirini hala ciziyorsa, sayi ustteki halkanin
      // sayisiyla BIREBIR ayni olmali — degilse kaldirmak bilgi KAYBI olurdu ve
      // bu test onu yakalar. Satir kaldirildiktan sonra `null` olur, iddia
      // dusmez.
      if (boardPct != null) {
        expect(
          boardPct,
          goalPct,
          reason:
              'Iki kart FARKLI sayi gosteriyor ($goalPct vs $boardPct); '
              'siralamadaki satir tekrar degil AYRI bir olcum demektir. '
              'Kaldirmadan once lider karar vermeli.',
        );
      }
    }),
  );

  testWidgets(
    'TEKRAR KANITI: aradaki tek fark canli tik (_virtualOffset), olcum degil',
    (tester) async => onPlatform(TargetPlatform.android, () async {
      // Grup gunluk hedefi 6 sa = 21600 sn; %1 = 216 sn. Tek calisan uyeyle
      // `GroupGoalCard._tick` saniyede +1 ekler (group_goal_card.dart:50-61);
      // `LeaderboardCard` ham `todaySecondsByUser` toplamini kullanir
      // (leaderboard_card.dart:157-163) ve hic ilerlemez.
      await openGroups(
        tester,
        window: const Size(390, 844),
        myTodaySeconds: 2 * 3600 + 22 * 60,
        peerTodaySeconds: 3600,
        peerStudying: true,
      );
      assertBoardBodyIsReal();

      final goalBefore = percentIn(find.byType(GroupGoalCard));
      final boardBefore = percentIn(find.byType(LeaderboardCard));

      for (var i = 0; i < 240; i++) {
        await tester.pump(const Duration(seconds: 1));
      }

      final goalAfter = percentIn(find.byType(GroupGoalCard));
      final boardAfter = percentIn(find.byType(LeaderboardCard));
      // ignore: avoid_print
      print(
        'WP690-SAPMA | hedef $goalBefore -> $goalAfter '
        '| siralama $boardBefore -> $boardAfter',
      );

      expect(
        goalAfter,
        isNot(goalBefore),
        reason:
            'Hedef karti canli tiklamiyor; o zaman ekrandaki %23/%22 farkinin '
            'baska bir sebebi var ve tekrar iddiasi cokuyor.',
      );
      if (boardAfter != null) {
        expect(
          boardAfter,
          boardBefore,
          reason:
              'Siralama karti da ilerledi; iki kartin farki canli tik degil.',
        );
      }
    }),
  );

  // ============ 2. SOZLESME — siralama karti grup hedefini TEKRAR ETMEZ ====

  for (final window in const [Size(390, 844), Size(1920, 1080)]) {
    final w = window.width.toInt();
    final platform = w == 390 ? TargetPlatform.android : TargetPlatform.windows;

    testWidgets(
      '$w px: siralama kartinda "Grup hedefi" satiri YOK',
      (tester) async => onPlatform(platform, () async {
        await openGroups(
          tester,
          window: window,
          myTodaySeconds: 2 * 3600 + 22 * 60,
          peerTodaySeconds: 3600,
        );
        assertBoardBodyIsReal();

        // Ust kartta duruyor olmali (islev kaybi yok).
        expect(
          find.descendant(
            of: find.byType(GroupGoalCard),
            matching: find.text(tr.homeGrupHedefi),
          ),
          findsWidgets,
          reason: '"Grup hedefi" basligi UST karttan da silinmis.',
        );

        expect(
          find.descendant(
            of: find.byType(LeaderboardCard),
            matching: find.text(tr.homeGrupHedefi),
          ),
          findsNothing,
          reason:
              'Siralama karti hemen ustundeki karti tekrar ediyor '
              '(leaderboard_card.dart:228-286). Sahip: "gereksiz yere '
              'uzatiyor karti."',
        );
        expect(
          find.descendant(
            of: find.byType(LeaderboardCard),
            matching: find.byType(GoalStreakBadge),
          ),
          findsNothing,
          reason: 'Ayni seri rozeti ekranda iki kez.',
        );
        expect(
          find.descendant(
            of: find.byType(LeaderboardCard),
            matching: find.byType(LinearProgressIndicator),
          ),
          findsNothing,
          reason:
              'Grup hedefi ilerleme cubugu siralama kartinda; ustteki halka '
              'ayni orani zaten ciziyor.',
        );

        // ISLEV KAYBI YOK: uye satirlarindaki sure duruyor.
        expect(
          find.descendant(
            of: find.byType(LeaderboardCard),
            matching: find.text('1sa'),
          ),
          findsOneWidget,
          reason:
              'Uye suresi kaybolmus — satir kaldirmak degil, karti bosaltmak '
              'olmus.',
        );
      }),
    );
  }

  // ==== 2b. ANA SAYFA PANOSU DEGISMEDI (kosullu duzeltmenin kancasi) =======
  //
  // 🔴 Bu testin varlik sebebi: KUSUR 1'in duzeltmesi `LeaderboardCard`
  // widget'inda yapildi ve ayni widget Ana Sayfa panosunda da cizilir
  // (`home/dashboard_card.dart:541`, varsayilan duzende leaderboard VAR —
  // `dashboard_providers.dart:38`). Global kaldirilsaydi, "Grup hedefi"
  // kartini panosuna hic eklememis bir kullanici o bilgiyi tamamen kaybederdi.
  // Bu iddia olmadan duzeltme sessizce global olabilir ve hicbir kapi gormez.

  testWidgets(
    'PANO: Ana Sayfa siralama kartinda grup hedefi satiri DURUYOR',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      await openGroups(
        tester,
        window: const Size(1920, 1080),
        myTodaySeconds: 2 * 3600 + 22 * 60,
        peerTodaySeconds: 3600,
      );

      // Gruplar sekmesindeki ornek: satir KAPALI.
      final inGroups = tester.widgetList<LeaderboardCard>(
        find.byType(LeaderboardCard),
      );
      expect(inGroups, isNotEmpty);
      for (final card in inGroups) {
        expect(
          card.showGoalRow,
          isFalse,
          reason: 'Gruplar sekmesindeki kart hala hedef satirini istiyor.',
        );
      }

      await tester.tap(find.text(tr.desktopAnaSayfa).first);
      await settle(tester);

      // Ana Sayfa panosundaki ornek: satir ACIK (varsayilan davranis).
      final inHome = tester.widgetList<LeaderboardCard>(
        find.byType(LeaderboardCard),
      );
      expect(
        inHome,
        isNotEmpty,
        reason:
            'Ana Sayfa panosunda siralama karti hic cizilmemis; varsayilan '
            'duzende olmasi gerekiyordu (dashboard_providers.dart:38). Bu '
            'halde "pano degismedi" iddiasi SAHTE YESIL olur.',
      );
      for (final card in inHome) {
        expect(
          card.showGoalRow,
          isTrue,
          reason:
              'Ana Sayfa panosundaki kart da hedef satirini kaybetmis — '
              'kosullu olmasi gereken duzeltme GLOBAL olmus.',
        );
      }

      // Cagri yeri sozlesmesi yetmez; satirin GERCEKTEN cizildigini de gor.
      // (Pano hucresi kisaysa `showGroupGoal` yine kapanabilir — bu durumda
      // sebep WP-662 yukseklik kurali, WP-690 degil; ayirt edebilmek icin
      // ciktiyi yazdiriyoruz.)
      final drawn = find
          .descendant(
            of: find.byType(LeaderboardCard),
            matching: find.text(tr.homeGrupHedefi),
          )
          .evaluate()
          .length;
      // ignore: avoid_print
      print('WP690-PANO | anaSayfada cizilen grup hedefi satiri: $drawn');
      expect(
        drawn,
        greaterThan(0),
        reason:
            'Ana Sayfa panosunda satir cizilmiyor; kart genisligi/yuksekligi '
            'degil WP-690 degisikligi sizmis olabilir.',
      );
    }),
  );

  // ============ 3. SOZLESME — hedef kartinin sagi degerlendirilmis =========

  for (final window in const [Size(390, 844), Size(1920, 1080)]) {
    final w = window.width.toInt();
    final platform = w == 390 ? TargetPlatform.android : TargetPlatform.windows;

    testWidgets(
      '$w px: seri rozeti kartin SAG yarisinda ve BUYUK',
      (tester) async => onPlatform(platform, () async {
        await openGroups(
          tester,
          window: window,
          myTodaySeconds: 2 * 3600 + 22 * 60,
          peerTodaySeconds: 3600,
        );

        final card = tester.getRect(find.byType(GroupGoalCard));
        final badge = badgeRectIn(tester, find.byType(GroupGoalCard));

        expect(
          badge.center.dx,
          greaterThan(card.center.dx),
          reason:
              'Rozet merkezi ${badge.center.dx}, kart merkezi '
              '${card.center.dx} — rozet hala SOL yarida, sag taraf bos.',
        );
        expect(
          card.right - badge.right,
          lessThanOrEqualTo(24.0),
          reason:
              'Rozetin sagi ile kart kenari arasinda '
              '${card.right - badge.right} px olu alan; bosluk '
              'degerlendirilmemis.',
        );
        // "Daha buyuk koyma sansi": ONCE ikon 20 px'di (regular kademe).
        // Sag bosluk degerlendirildiyse rozet bundan BUYUK olmali.
        expect(
          badgeIconSizeIn(tester, find.byType(GroupGoalCard)),
          greaterThan(20.0),
          reason:
              'Rozet ikonu hala 20 px (regular); sahip "daha buyuk koyma '
              'sansi olur" dedi.',
        );
        // Tasma yok: rozet kartin icinde kalir (masaustunde kart 448 px).
        expect(badge.right, lessThanOrEqualTo(card.right));
        expect(badge.left, greaterThanOrEqualTo(card.left));

        // 🔴 BEDEL KANCASI — rozet buyuyunce yanindaki kolon daralir. Ilk
        // denemede olculdu: "3sa 22dk / 6sa" 136 px kolona UC SATIR sardi
        // (kutu 136x60) ve kart 152 -> 164 px UZADI. Iki taraftan da
        // korunuyor: satir TEK kalacak (yuksekligi tek satir tavanini
        // asmayacak) ama olcek de okunmaz kadar kucultmeyecek.
        final timeRect = tester.getRect(
          find.descendant(
            of: find.byType(GroupGoalCard),
            matching: find.text('3sa 22dk / 6sa'),
          ),
        );
        expect(
          timeRect.height,
          lessThanOrEqualTo(24.0),
          reason:
              'Sure metni ${timeRect.width}x${timeRect.height} — tek satirdan '
              'uzun, yani rozet kolonu ezip metni sardirmis.',
        );
        expect(
          timeRect.height,
          greaterThanOrEqualTo(12.0),
          reason:
              'Sure metni ${timeRect.height} px boyuna kucultulmus; rozet '
              'kolondan cok yer aliyor, okunmaz.',
        );

        // Kart YUKSEKLIGI kontrolden cikmasin (lider sarti; ONCE 152 / 184).
        expect(
          card.height,
          lessThanOrEqualTo(w == 390 ? 152.0 : 184.0),
          reason:
              'Hedef karti ${card.height} px — rozet buyurken kart da uzamis.',
        );

        // ISLEV KAYBI YOK: sure/hedef satiri duruyor.
        expect(
          find.descendant(
            of: find.byType(GroupGoalCard),
            matching: find.text('3sa 22dk / 6sa'),
          ),
          findsOneWidget,
          reason: 'Sure/hedef satiri kaybolmus.',
        );
      }),
    );
  }
}
