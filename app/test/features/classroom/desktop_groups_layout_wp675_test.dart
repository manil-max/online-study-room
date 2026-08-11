// WP-675 — GRUPLAR / KAMP ATESI EKRANININ MASAUSTU DUZENI.
//
// Sahip v64 Windows surumunu reddetti: "dikey mobil uygulama icin tasarlanan
// arayuzler yatay pc ekraninda cok kotu duruyor, tamamen mobilin penceresi
// gibi olmus." Bu ekranda WP-671 kapisinin olctugu kusur (2026-08-10):
//
//   gruplar 1920 -> 12 ihlal, icerik 1706 px, en genis satir 1688 px
//   gruplar 2560 -> 12 ihlal, icerik 2346 px, en genis satir 2328 px
//   gruplar 2560 kart -> 2352 px kutu / 178 px icerik ("Grup hedefi")
//
// WP-671 kapisi (`test/features/desktop/desktop_stretch_contract_test.dart`)
// bu sayilari TAVANLARLA olcer. Bu dosya iki fazla sey yapar:
//
//   1. **Duzeni** olcer, tavani degil: uc blok gercekten YAN YANA mi, sahne
//      gercekten bloklardan genis mi. Tavan gecirmek icin her seyi tek sutuna
//      yigmak da yeterdi; sahibin sikayeti tam olarak oydu.
//   2. **Islev kaybi olmadigini** olcer: kamp atesinde varlik (presence)
//      gosterimi ve durtme, masaustu agacinda da calisiyor. Depoda ikisi de
//      gecmiste kirildi (WP-511 / WP-617), o yuzden duzen degisiminin altina
//      birer kanca birakiliyor.
//
// Butun olcumler CIZILEN kutulardan (`tester.getSize` / `getTopLeft`) okunur;
// hicbir iddia kaynakta bir sabit aramaz ("kullanicinin GORDUGU satiri test
// et" dersi).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/desktop/desktop_layout.dart';
import 'package:online_study_room/core/device_integrations/samsung_modes_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/chat_message.dart';
import 'package:online_study_room/data/models/nudge.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/providers/analytics_query_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/chat_providers.dart';
import 'package:online_study_room/data/providers/moderation_providers.dart';
import 'package:online_study_room/data/providers/nudge_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_nudge_repository.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/features/classroom/classroom_screen.dart';
import 'package:online_study_room/features/classroom/widgets/campfire_scene.dart';
import 'package:online_study_room/features/classroom/widgets/class_chat_card.dart';
import 'package:online_study_room/features/classroom/widgets/class_chat_screen.dart';
import 'package:online_study_room/features/classroom/widgets/class_detail_screen.dart';
import 'package:online_study_room/features/desktop/desktop_page_scaffold.dart';
import 'package:online_study_room/features/home/widgets/group_goal_card.dart';
import 'package:online_study_room/features/home/widgets/group_trend_card.dart';
import 'package:online_study_room/features/home/widgets/leaderboard_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:online_study_room/main.dart';

import '../../support/v8_test_setup.dart';

/// Gonderim denemesini SAYAN depo — "durtme hala calisiyor" iddiasi ekranda
/// bir SnackBar gormekle degil, sunucuya giden cagriyla kanitlanir.
class _CountingNudgeRepository extends InMemoryNudgeRepository {
  int sendCount = 0;

  @override
  Future<Nudge> sendNudge({
    required String groupId,
    required Profile sender,
    required Profile recipient,
    String? message,
  }) {
    sendCount += 1;
    return super.sendNudge(
      groupId: groupId,
      sender: sender,
      recipient: recipient,
      message: message,
    );
  }
}

/// Cizilen sahne + gercek uygulama.
class _Fixture {
  const _Fixture({required this.me, required this.peer, required this.nudges});

  final Profile me;
  final Profile? peer;
  final _CountingNudgeRepository nudges;
}

void main() {
  final tr = AppLocalizationsTr();

  /// 🔴 Bayrak test GOVDESI BITMEDEN geri alinmali; `tearDown` gec kalir ve
  /// "foundation debug variable was changed by the test" diye patlar. Ayni
  /// tuzak WP-671 kapisini bir kez yalanci kirmiziya dusurdu.
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

  /// Kamp atesi surekli animasyonludur; `pumpAndSettle` orada asla oturmaz.
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
  Future<_Fixture> openGroups(
    WidgetTester tester, {
    required Size window,
    bool withPeer = false,
    PresenceStatus peerStatus = PresenceStatus.onBreak,
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

    Profile? peer;
    if (withPeer) {
      peer = Profile(
        id: 'peer-1',
        displayName: 'Komsu',
        createdAt: DateTime(2026, 1, 1),
      );
      await groupRepository.joinGroup(
        inviteCode: group.inviteCode,
        member: peer,
      );
    }

    final nudges = _CountingNudgeRepository()..currentUserId = me.id;
    final fixedNow = DateTime(2026, 7, 26, 12);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          groupRepositoryProvider.overrideWithValue(groupRepository),
          sharedPreferencesProvider.overrideWithValue(preferences),
          nudgeRepositoryProvider.overrideWithValue(nudges),
          deviceIntegrationServiceProvider.overrideWithValue(
            V8TestDeviceIntegrationService(),
          ),
          androidWidgetServiceProvider.overrideWithValue(V8TestWidgetGateway()),
          // 🔴 WP-690 — bu override olmadan `LeaderboardCard` "Veriler
          // yuklenemedi" hata kabuguna dusuyordu ve bu dosyanin butun kutu
          // olcumleri BOS bir kabugu olcuyordu (yukaridaki gercek-govde
          // iddiasi eklendiginde 12 test birden kirmizi dustu). Sebep:
          // `groupAlphaScoresProvider` widget testinde bulunmayan gercek
          // analitik deposunu ariyor.
          groupAlphaScoresProvider.overrideWith((ref) async => const {}),
          if (peer != null)
            groupPresenceProvider.overrideWith(
              (ref) => Stream.value([
                Presence(
                  userId: peer!.id,
                  groupId: group.id,
                  status: peerStatus,
                  todaySeconds: 0,
                  startedAt: peerStatus == PresenceStatus.studying
                      ? fixedNow
                      : null,
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

    // 🔴 WP-690 — SAHTE YESIL KAPATILDI.
    //
    // Bu dosyanin butun olcumleri `find.byType(LeaderboardCard)` /
    // `GroupGoalCard` ile kutu ariyor. Ama o tipler kartin HATA KABUGUNDA da
    // agacta durur: `cardDataGate` ("Veriler yuklenemedi." + "Tekrar dene")
    // `LeaderboardCard.build` icinden erken doner, yani `find.byType` yine
    // eslesir ve `getRect` bir kutu dondurur. Sonuc: "kart 448 px, yan yana,
    // tavani asmiyor" iddialari kartin ICI BOSKEN de yesil yanar.
    //
    // Olculdu (WP-690): bu fixture'da `groupAlphaScoresProvider` gercek
    // analitik deposunu ariyor, bulamiyor ve kart tam da o hata kabuguna
    // dusuyordu — asagidaki iddia eklendiginde 12 test birden kirmizi dustu.
    // Duzeltme: provider override edildi (yukarida), boylece olculen sey
    // gercek kart govdesi.
    expect(
      find.descendant(
        of: find.byType(LeaderboardCard),
        matching: find.text(tr.homeSiralama),
      ),
      findsOneWidget,
      reason:
          'Siralama karti govdesini cizmemis (veri/hata kapisi). Bu halde '
          'asagidaki butun kutu olcumleri BOS bir kabugu olcer.',
    );
    expect(
      find.descendant(
        of: find.byType(GroupGoalCard),
        matching: find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.data != null &&
              RegExp(r'^%\d+$').hasMatch(w.data!),
        ),
      ),
      findsOneWidget,
      reason:
          'Grup hedefi kartinda halka yuzdesi yok; kart iskelet/hata '
          'kabugunda ve genislik olcumu anlamsiz. (Halka widget tipi yerine '
          'CIZILEN yuzde araniyor: `cardDataGate` iskeleti de bir donen '
          'gosterge cizebilir, ama yuzde cizmez.)',
    );

    return _Fixture(me: me, peer: peer, nudges: nudges);
  }

  double widthOf(Finder finder) => _sizeOf(finder).width;
  Rect rectOf(Finder finder) => _rectOf(finder);

  // ======================= MASAUSTU DUZENI ================================

  for (final window in const [Size(1920, 1080), Size(2560, 1440)]) {
    final w = window.width.toInt();

    testWidgets(
      '$w px: hedef + siralama + trend YAN YANA tek satirda',
      (tester) async => onPlatform(TargetPlatform.windows, () async {
        await openGroups(tester, window: window);

        final goal = rectOf(find.byType(GroupGoalCard));
        final board = rectOf(find.byType(LeaderboardCard));
        final trend = rectOf(find.byType(GroupTrendCard));

        // Sahibin sikayeti "tek sutun + devasa bosluk"tu: uc blok ayni satirda
        // olmali, alt alta degil.
        expect(
          goal.top,
          moreOrLessEquals(board.top, epsilon: 1),
          reason:
              'Hedef ve siralama ayni satirda degil '
              '(dy ${goal.top} vs ${board.top}); duzen hala tek sutun.',
        );
        expect(trend.top, moreOrLessEquals(board.top, epsilon: 1));
        expect(goal.right, lessThanOrEqualTo(board.left));
        expect(board.right, lessThanOrEqualTo(trend.left));

        // SPEC KURAL 2.2 (600 px) + kart ic dolgusu 32 = 632 px blok tavani.
        for (final entry in {
          'Grup hedefi': goal,
          'Siralama': board,
          'Grup gunluk trendi': trend,
        }.entries) {
          expect(
            entry.value.width,
            lessThanOrEqualTo(kGroupBlockMaxWidth),
            reason:
                '"${entry.key}" blogu ekranda ${entry.value.width} px; '
                'tavan $kGroupBlockMaxWidth px (WP-671 olcumunde 2352 px idi).',
          );
        }

        // Uc blogun toplam yayilimi SPEC §2.3 pano tavanini asmaz.
        expect(
          trend.right - goal.left,
          lessThanOrEqualTo(DesktopBreakpoints.maxContentWidth),
        );
      }),
    );

    testWidgets(
      '$w px: kamp atesi sahnesi DARALTILMADI (A4)',
      (tester) async => onPlatform(TargetPlatform.windows, () async {
        await openGroups(tester, window: window);

        final scene = widthOf(find.byType(CampfireScene));
        final block = widthOf(find.byType(GroupGoalCard));

        // SPEC §3 A4: sahne bandin tamamini alir. Bloklarin tavani ona
        // UYGULANMAZ — sahibin "bu iyi" dedigi tek sey buydu.
        expect(
          scene,
          greaterThan(block),
          reason:
              'Sahne ($scene px) bir bloktan ($block px) genis degil; '
              'A4 sahnesi kart tavanina hapsedilmis.',
        );
        expect(
          scene,
          greaterThanOrEqualTo(DesktopBreakpoints.large),
          reason:
              'Sahne $scene px; masaustunde en az `large` (1200) bant bekleniyor.',
        );
        // ...ama pano tavanini da asmaz (WP-671 OLCUM 1).
        expect(scene, lessThanOrEqualTo(DesktopBreakpoints.maxContentWidth));
      }),
    );

    testWidgets(
      '$w px: masaustu yuzeyi BAGLI (SPEC §6)',
      (tester) async => onPlatform(TargetPlatform.windows, () async {
        await openGroups(tester, window: window);
        // `import` etmek ya da izole testte monte etmek gecmez: cizilen
        // agacta aranir.
        expect(find.byType(DesktopContent, skipOffstage: true), findsWidgets);
      }),
    );
  }

  // ======================= MOBIL REGRESYONU ===============================

  testWidgets(
    '390x844 mobil: bloklar ALT ALTA ve tam genislikte kalir',
    (tester) async => onPlatform(TargetPlatform.android, () async {
      await openGroups(tester, window: const Size(390, 844));

      final goal = rectOf(find.byType(GroupGoalCard));
      final board = rectOf(find.byType(LeaderboardCard));

      expect(
        board.top,
        greaterThan(goal.bottom),
        reason:
            'Mobilde bloklar yan yana gelmis; SPEC §7 "mobil branch degismez" '
            'kurali kirildi.',
      );
      // Mobil dolgu 16+16: kart ekran genisligini tam kullanir, 632 tavani
      // mobile SIZMAZ.
      expect(goal.width, moreOrLessEquals(390 - 32, epsilon: 0.5));
      expect(
        widthOf(find.byType(CampfireScene)),
        moreOrLessEquals(390 - 32, epsilon: 0.5),
      );
      expect(
        find.byType(DesktopContent),
        findsNothing,
        reason: 'Masaustu bandi mobil agaca sizmis.',
      );
    }),
  );

  // ==================== ISLEV KAYBI YOK (masaustu) ========================

  testWidgets(
    'masaustu: kamp atesinde VARLIK gosterimi duruyor',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      final fixture = await openGroups(
        tester,
        window: const Size(1920, 1080),
        withPeer: true,
        peerStatus: PresenceStatus.studying,
      );

      // Rozet "kac kisi calisiyor"u soyler; etiket kimin oldugunu.
      expect(
        find.textContaining(tr.classroomCalisiyor),
        findsWidgets,
        reason:
            'Calisan uye rozeti sahnede yok; varlik gosterimi masaustu '
            'duzeninde kaybolmus.',
      );
      expect(find.text(fixture.peer!.displayName), findsWidgets);
      expect(
        find.byKey(ValueKey('b-${fixture.peer!.id}')),
        findsOneWidget,
        reason: 'Kampci govdesi cizilmemis; sahne uyeleri gostermiyor.',
      );
    }),
  );

  testWidgets(
    'masaustu: kamp atesinden DURTME hala sunucuya gidiyor',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      final fixture = await openGroups(
        tester,
        window: const Size(1920, 1080),
        withPeer: true,
      );

      await tester.tap(find.byKey(ValueKey('b-${fixture.peer!.id}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text(tr.classroomBugunkuToplam),
        findsOneWidget,
        reason: 'Kampci alt sayfasi acilmadi; sahnedeki dokunma yolu olmus.',
      );

      final button = find.widgetWithText(FilledButton, tr.classroomDurt);
      await tester.ensureVisible(button);
      await tester.pump();
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        fixture.nudges.sendCount,
        1,
        reason: 'Durtme gonderilmedi; masaustu duzeni eylemi kopardi.',
      );
    }),
  );

  testWidgets(
    'masaustu: baslik kisayollari (degistir/sohbet/ayarlar) duruyor',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      await openGroups(tester, window: const Size(1920, 1080));

      for (final tooltip in [
        tr.classroomGrupDegistir,
        tr.classroomSohbet,
        tr.classroomAyarlar,
      ]) {
        expect(
          find.byTooltip(tooltip),
          findsOneWidget,
          reason: '"$tooltip" kisayolu masaustu duzeninde kayboldu.',
        );
      }
    }),
  );
  // ============ ITILEN EKRANLAR: sohbet + grup ayarlari =====================
  //
  // Bu ikisi WP-671 kapisinin ISINDE DEGIL (kapi yalnizca sekmeleri gezer),
  // ama sahibin gordugu ekranlar. Kanca burada duruyor ki "kapida yok, o yuzden
  // olculmedi" bosluguna dusmesinler.

  Widget host(Widget child) => MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );

  Future<void> pumpDetail(WidgetTester tester, Size window) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window;
    addTearDown(tester.view.reset);
    final groups = InMemoryGroupRepository();
    final me = Profile(
      id: 'me-1',
      displayName: 'Ben',
      createdAt: DateTime(2026, 1, 1),
    );
    final group = await groups.createGroup(name: 'Odak Kampi', creator: me);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          groupRepositoryProvider.overrideWithValue(groups),
          authStateProvider.overrideWith((ref) => Stream.value(me)),
          groupPresenceProvider.overrideWith(
            (ref) => Stream.value(const <Presence>[]),
          ),
        ],
        child: host(ClassDetailScreen(group: group)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpChat(WidgetTester tester, Size window) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = window;
    addTearDown(tester.view.reset);
    final me = Profile(
      id: 'me-1',
      displayName: 'Ben',
      createdAt: DateTime(2026, 1, 1),
    );
    final group = StudyGroup(
      id: 'g1',
      name: 'Odak Kampi',
      inviteCode: 'KAMP42',
      createdBy: me.id,
      createdAt: DateTime(2026, 1, 1),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(me)),
          blockedUserIdsProvider.overrideWith((ref) async => const <String>{}),
          classMessagesProvider(
            group.id,
          ).overrideWith((ref) => Stream.value(const <ChatMessage>[])),
        ],
        child: host(ClassChatScreen(group: group)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    '2560 px: grup ayarlari sutunu form genisliginde durur',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      await pumpDetail(tester, const Size(2560, 1440));
      // Her satir bir `ListTile`: baslik solda, `trailing` dugmesi sagda. Sutun
      // sinirlanmazsa aradaki goz sicramasi pencere kadar buyur.
      expect(
        widthOf(find.byType(ListView)),
        lessThanOrEqualTo(DesktopBreakpoints.maxFormWidth),
      );
    }),
  );

  testWidgets(
    '390 px mobil: grup ayarlari tam genislikte kalir',
    (tester) async => onPlatform(TargetPlatform.android, () async {
      await pumpDetail(tester, const Size(390, 844));
      expect(
        widthOf(find.byType(ListView)),
        moreOrLessEquals(390, epsilon: 0.5),
      );
    }),
  );

  testWidgets(
    '2560 px: sohbet sutunu form genisliginde durur',
    (tester) async => onPlatform(TargetPlatform.windows, () async {
      await pumpChat(tester, const Size(2560, 1440));
      // Balonlar zaten 320'de tavanli; kusur biri sola biri saga yaslandiginda
      // aralarinda kalan ~1700 px'lik bosluktu.
      expect(
        widthOf(find.byType(ClassChatCard)),
        lessThanOrEqualTo(DesktopBreakpoints.maxFormWidth),
      );
    }),
  );

  testWidgets(
    '390 px mobil: sohbet tam genislikte kalir',
    (tester) async => onPlatform(TargetPlatform.android, () async {
      await pumpChat(tester, const Size(390, 844));
      expect(
        widthOf(find.byType(ClassChatCard)),
        moreOrLessEquals(390, epsilon: 0.5),
      );
    }),
  );
}

Size _sizeOf(Finder finder) => _rectOf(finder).size;

Rect _rectOf(Finder finder) {
  final element = finder.evaluate().single;
  final box = element.renderObject! as RenderBox;
  final origin = box.localToGlobal(Offset.zero);
  return origin & box.size;
}
