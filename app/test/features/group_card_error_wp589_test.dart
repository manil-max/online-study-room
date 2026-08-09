// WP-589: grup kartlarinda hata YANLIS BILGI olarak gosteriliyordu.
//
// Salt-okunur denetim (WP-581) iki KARDES kusur buldu; ikisi de Play kapali
// testine giren surumde duruyordu:
//
//   1. `groupCardGate` hata dalinda CIKIS yoktu (duz metin). Kardesi
//      `cardDataGate` ayni cikisi WP-560'ta almisti; bu kapi almamisti. Kapi
//      DORT karta birden iner: siralama, grup hedefi, grup trendi, su an
//      calisanlar.
//   2. `class_stats_view` uye-katki karti HATA dalinda BOS dalin cumlesini
//      kullaniyordu (`statsBuDonemdeHenuzCalisma`). Sunucuya ulasilamayinca
//      kullaniciya "bu donemde henuz calisma yok" deniyordu — grubu hakkinda
//      YANLIS bilgi. Yasak `group_card_shell.dart` icinde zaten YAZILIYDI,
//      uygulanmamisti.
//
// Iddia sozel degil DAVRANISSAL. Uc sey olculur:
//
//   (a) Hata durumunda GORUNUR bir eylem var (`kErrorRetryButtonKey`).
//   (b) Eyleme basinca veri kaynagi GERCEKTEN yeniden okunuyor: sahte
//       kaynaktaki cagri sayaci 1 -> 2. Bu madde olmadan "dugme var ama
//       hicbir sey yapmiyor" testten gecerdi, o da hatanin kendisinden
//       kotudur.
//   (c) Yukleme / bos / hata UC AYRI cikti. Ikinci kusurun tamami buydu:
//       hata ile bos AYNI cumleyi paylasiyordu.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/widgets/error_retry_view.dart';
import 'package:online_study_room/data/models/analytics_query_models.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/user_study_summary.dart';
import 'package:online_study_room/data/providers/analytics_query_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/home/widgets/active_members_card.dart';
import 'package:online_study_room/features/home/widgets/group_card_shell.dart';
import 'package:online_study_room/features/home/widgets/group_goal_card.dart';
import 'package:online_study_room/features/home/widgets/group_trend_card.dart';
import 'package:online_study_room/features/home/widgets/leaderboard_card.dart';
import 'package:online_study_room/features/stats/widgets/class_stats_view.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _me = Profile(
  id: 'me-1',
  displayName: 'Sahip',
  createdAt: DateTime(2026, 1, 1),
);

final _group = StudyGroup(
  id: 'g-1',
  name: 'Odak Grubu',
  inviteCode: 'KAMP42',
  createdBy: 'me-1',
  createdAt: DateTime(2026, 1, 1),
);

/// Hic emisyon yapmayan akis: cihazda ag turunun beklendigi kare.
Stream<T> _pending<T>() => StreamController<T>().stream;

Future<AppLocalizations> _tr() =>
    AppLocalizations.delegate.load(const Locale('tr'));

Widget _app(Widget home, {required List<Override> overrides}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  ),
);

/// Birkac kare pompalar.
///
/// Tek `pump` YETMEZ: `userGroupProvider` turetilmis bir `Provider`dir ve
/// altindaki `userGroupsProvider` akisi ilk kareyi `AsyncLoading` olarak verir;
/// hata bir sonraki microtask turunda gelir. Olculdu: tek karede kapi hala
/// iskelet cizerken iddia yalanci KIRMIZI duruyordu. `pumpAndSettle` de
/// kullanilamaz — `GroupGoalCard` sonsuz `Timer.periodic` kurar, hic oturmaz.
Future<void> _pumpFrames(WidgetTester tester, [int frames = 5]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump();
  }
}

/// Widget agacini sokup provider'lari (ve periyodik ticker'lari) kapatir.
///
/// `GroupGoalCard` initState'te 1 sn'lik `Timer.periodic` kurar; agac
/// sokulmezse test "A Timer is still pending" ile duser.
Future<void> _teardownTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

// ---------------------------------------------------------------------------
// 1. groupCardGate — grup gerektiren DORT kartin ortak kapisi
// ---------------------------------------------------------------------------

/// Sahte grup akisi: her kurulumda sayac artar, ilk turda hata verir.
class _GroupSource {
  int calls = 0;

  Stream<List<StudyGroup>> build() {
    calls++;
    // Ilk tur patlar, ikinci tur veri verir: tekrar-dene GERCEKTEN duzeltiyor
    // mu, yoksa yalniz yeniden mi kosuyor — ikisi ayri iddia.
    if (calls == 1) {
      return Stream<List<StudyGroup>>.error('ag yok', StackTrace.current);
    }
    return Stream.value(<StudyGroup>[_group]);
  }
}

/// `groupCardGate`i dogrudan kosan kabuk.
///
/// Kart fabrikalarinin tamami yerine kapinin KENDISI olculur: uc durumun
/// ciktisi burada dogar ve dort kart onu paylasir.
class _GateHarness extends ConsumerWidget {
  const _GateHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Riverpod 3 tuzagi: `authStateProvider` dinleyicisiz kalirsa her `read`de
    // yeniden kurulur ve `.value` null doner. `refreshAppData` o durumda ILK
    // SATIRDA sessizce cikar. Uretimde kabuk zaten watch eder.
    ref.watch(authStateProvider);
    final groupAsync = ref.watch(userGroupProvider);
    final gate = groupCardGate(context, groupAsync, title: 'Grup Siralamasi');
    return Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          height: 320,
          child: gate ?? const Text('KART GOVDESI'),
        ),
      ),
    );
  }
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  List<Override> gateOverrides({
    _GroupSource? source,
    Stream<List<StudyGroup>> Function()? groups,
  }) => [
    // `userGroupProvider` -> `activeGroupIdProvider` -> prefs zinciri gercek
    // kalsin: olculen sey tam olarak uretimdeki kapinin gordugu durum.
    sharedPreferencesProvider.overrideWithValue(prefs),
    authStateProvider.overrideWith((ref) => Stream.value(_me)),
    userGroupsProvider.overrideWith(
      (ref) => groups != null ? groups() : source!.build(),
    ),
    // `refreshAppData` asagidaki kaynaklari `ref.refresh` ile ZORLA okur;
    // override edilmezlerse varsayilan depo Supabase olur.
    userSessionsProvider.overrideWith(
      (ref) => Stream.value(const <StudySession>[]),
    ),
    userStudySummaryProvider.overrideWith((ref) async => UserStudySummary.empty),
    groupMembersProvider.overrideWith((ref) => Stream.value(const <Profile>[])),
    groupDailyStatsProvider.overrideWith(
      (ref) => Stream.value(const <DailyStat>[]),
    ),
    groupPresenceProvider.overrideWith(
      (ref) => Stream.value(const <Presence>[]),
    ),
  ];

  group('groupCardGate (grup kartlarinin ortak kapisi)', () {
    testWidgets('hata: gorunur bir eylem var', (tester) async {
      await tester.pumpWidget(
        _app(
          const _GateHarness(),
          overrides: gateOverrides(source: _GroupSource()),
        ),
      );
      await _pumpFrames(tester);

      final l10n = await _tr();
      expect(find.text(l10n.homeGrupBilgisiYuklenemedi), findsOneWidget);
      expect(
        find.byKey(kErrorRetryButtonKey),
        findsOneWidget,
        reason: 'hata metni tek basina cikis degildir',
      );
      expect(find.text(l10n.commonTekrarDene), findsOneWidget);
      await _teardownTree(tester);
    });

    testWidgets('tekrar-dene grup akisini yeniden okuyor (1 -> 2)', (
      tester,
    ) async {
      final source = _GroupSource();
      await tester.pumpWidget(
        _app(const _GateHarness(), overrides: gateOverrides(source: source)),
      );
      await _pumpFrames(tester);

      expect(source.calls, 1);
      await tester.tap(find.byKey(kErrorRetryButtonKey));
      await _pumpFrames(tester);

      expect(
        source.calls,
        2,
        reason: 'dugme var ama grup akisi yeniden okunmuyor',
      );
      // Ikinci tur veri veriyor: kapi cekiliyor, kart kendi govdesini ciziyor.
      expect(find.text('KART GOVDESI'), findsOneWidget);
      expect(find.byKey(kErrorRetryButtonKey), findsNothing);
      await _teardownTree(tester);
    });

    testWidgets('yukleme / grupsuz / hata uc ayri cikti', (tester) async {
      final l10n = await _tr();

      // Yukleme: iskelet; hata metni yok, eylem yok (WP-495B kazanimi).
      await tester.pumpWidget(
        _app(
          const _GateHarness(),
          overrides: gateOverrides(groups: () => _pending<List<StudyGroup>>()),
        ),
      );
      await _pumpFrames(tester);
      expect(
        find.byKey(kGroupCardSkeletonKey),
        findsOneWidget,
        reason: 'WP-495B regresyonu: yuklenirken yer tutucu cizilmeli',
      );
      expect(find.text(l10n.homeGrupBilgisiYuklenemedi), findsNothing);
      expect(find.byKey(kErrorRetryButtonKey), findsNothing);
      await _teardownTree(tester);

      // Grubu yok: davet kabugu. Bu BOS durumdur, hata degil — kendi cumlesi.
      await tester.pumpWidget(
        _app(
          const _GateHarness(),
          overrides: gateOverrides(
            groups: () => Stream.value(const <StudyGroup>[]),
          ),
        ),
      );
      await _pumpFrames(tester);
      expect(find.text(l10n.homeBirGrubaKatilincaBurada), findsOneWidget);
      expect(find.byKey(kGroupCardSkeletonKey), findsNothing);
      expect(find.byKey(kErrorRetryButtonKey), findsNothing);
      expect(find.text(l10n.homeGrupBilgisiYuklenemedi), findsNothing);
      await _teardownTree(tester);

      // Hata: iskelet YOK (sonsuz iskelet tuzagi), davet cumlesi de YOK
      // ("grubun yok" demek yanlis bilgi olurdu); metin + eylem VAR.
      await tester.pumpWidget(
        _app(
          const _GateHarness(),
          overrides: gateOverrides(source: _GroupSource()),
        ),
      );
      await _pumpFrames(tester);
      expect(find.byKey(kGroupCardSkeletonKey), findsNothing);
      expect(find.text(l10n.homeBirGrubaKatilincaBurada), findsNothing);
      expect(find.text(l10n.homeGrupBilgisiYuklenemedi), findsOneWidget);
      expect(find.byKey(kErrorRetryButtonKey), findsOneWidget);
      await _teardownTree(tester);
    });

    testWidgets('duzeltme DORT karta birden iniyor', (tester) async {
      // Kapi ortak oldugu icin dort kartin hepsi ayni cikisi almalidir. Kart
      // listesi burada YAZILI: biri kapiyi atlayip kendi hata dalini yazarsa
      // bu iddia duser.
      final cards = <String, Widget>{
        'leaderboard_card': const LeaderboardCard(),
        'group_goal_card': const GroupGoalCard(),
        'group_trend_card': const GroupTrendCard(),
        'active_members_card': const ActiveMembersCard(),
      };
      final l10n = await _tr();

      for (final entry in cards.entries) {
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: Center(
                child: SizedBox(width: 360, height: 320, child: entry.value),
              ),
            ),
            overrides: gateOverrides(source: _GroupSource()),
          ),
        );
        await _pumpFrames(tester);

        expect(
          find.text(l10n.homeGrupBilgisiYuklenemedi),
          findsOneWidget,
          reason: '${entry.key}: hata kendi cumlesini tasimali',
        );
        expect(
          find.byKey(kErrorRetryButtonKey),
          findsOneWidget,
          reason: '${entry.key}: hata dalinda cikis yok',
        );
        await _teardownTree(tester);
      }
    });
  });

  // -------------------------------------------------------------------------
  // 2. class_stats_view — uye katki karti: hata ile bos AYRI cumle
  // -------------------------------------------------------------------------

  group('class_stats_view (uye katki karti)', () {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final members = [
      Profile(id: 'u1', displayName: 'Ada', createdAt: DateTime(2026, 1, 1)),
      Profile(id: 'u2', displayName: 'Bora', createdAt: DateTime(2026, 1, 1)),
    ];
    // Siralama ve liderlik grafigi DOLU olsun: `statsBuDonemdeHenuzCalisma`
    // ekranda baska hicbir yerde dogmasin, boylece "hata dali bos dalin
    // cumlesini kullaniyor mu" iddiasi tek sayiyla olculur.
    final stats = [
      DailyStat(userId: 'u1', day: today, seconds: 3600),
      DailyStat(userId: 'u2', day: today, seconds: 1800),
      DailyStat(userId: 'u1', day: yesterday, seconds: 2400),
    ];

    Widget view() => Scaffold(
      body: ClassStatsView(
        stats: stats,
        members: members,
        currentUserId: 'u1',
        groupName: 'Odak Grubu',
        groupGoalMinutes: 120,
      ),
    );

    Future<void> pumpTall(
      WidgetTester tester, {
      required List<Override> overrides,
    }) async {
      tester.view.physicalSize = const Size(2400, 9000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(_app(view(), overrides: overrides));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
    }

    testWidgets('hata bos dalin cumlesini KULLANMIYOR + eylem var', (
      tester,
    ) async {
      var calls = 0;
      await pumpTall(
        tester,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          analyticsGroupContributionProvider.overrideWith((ref, period) async {
            calls++;
            throw StateError('ag yok');
          }),
        ],
      );

      final l10n = await _tr();
      expect(find.text(l10n.statsUyeKatkisiYuklenemedi), findsOneWidget);
      expect(
        find.byKey(kErrorRetryButtonKey),
        findsOneWidget,
        reason: 'hata metni tek basina cikis degildir',
      );
      expect(
        find.text(l10n.statsBuDonemdeHenuzCalisma),
        findsNothing,
        reason:
            'YANLIS BILGI: ag hatasi "bu donemde henuz calisma yok" diye '
            'yazilamaz',
      );
      expect(calls, 1);
      await _teardownTree(tester);
    });

    testWidgets('tekrar-dene katki kaynagini yeniden okuyor (1 -> 2)', (
      tester,
    ) async {
      var calls = 0;
      await pumpTall(
        tester,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          analyticsGroupContributionProvider.overrideWith((ref, period) async {
            calls++;
            if (calls == 1) throw StateError('ag yok');
            return const <GroupContributionRow>[
              GroupContributionRow(userId: 'u1', seconds: 3600),
              GroupContributionRow(userId: 'u2', seconds: 1800),
            ];
          }),
        ],
      );

      final l10n = await _tr();
      expect(calls, 1);
      await tester.tap(find.byKey(kErrorRetryButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(calls, 2, reason: 'dugme var ama katki kaynagi yeniden okunmuyor');
      expect(find.text(l10n.statsUyeKatkisiYuklenemedi), findsNothing);
      expect(find.byKey(kErrorRetryButtonKey), findsNothing);
      // Ikinci tur veri veriyor: legend isimleri ciziliyor.
      expect(find.text('Ada'), findsWidgets);
      await _teardownTree(tester);
    });

    testWidgets('bos dal kendi cumlesini KORUYOR (hata cumlesi degil)', (
      tester,
    ) async {
      await pumpTall(
        tester,
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          analyticsGroupContributionProvider.overrideWith(
            (ref, period) async => const <GroupContributionRow>[],
          ),
        ],
      );

      final l10n = await _tr();
      expect(find.text(l10n.statsBuDonemdeHenuzCalisma), findsOneWidget);
      expect(find.text(l10n.statsUyeKatkisiYuklenemedi), findsNothing);
      expect(
        find.byKey(kErrorRetryButtonKey),
        findsNothing,
        reason: 'bos durum bir hata degildir; tekrar-dene teklif edilmez',
      );
      await _teardownTree(tester);
    });
  });
}
