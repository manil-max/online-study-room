// 🔴 WP-550 — "aşağı çekerek yenile" KABLO testi.
//
// Ölçüm (düzeltme öncesi): `AppPullToRefresh` yazılmış, belgelenmiş ve kendi
// birim testi de varmış — ama `lib/` içinde **hiçbir yerde monte edilmemişti**.
// `grep -rn "AppPullToRefresh" app/lib` yalnız tanımın kendisini buluyordu.
// Yani telefon kullanıcısında dört ana sekmenin hiçbirinde aşağı çekerek
// yenileme yoktu; sınıfın kendi yorumu ise "tüm route'ları saran" diyordu.
// `app_pull_to_refresh_test.dart` bunu göremezdi: orada sarmalayıcı testin
// kendi kurduğu bir `ListView`ı sarıyor, üretim ekranlarını hiç okumuyordu.
//
// Bu dosyanın iddiası **davranış**, varlık değil. "Ağaçta bir `RefreshIndicator`
// var" iddiası mutasyona dayanıklı DEĞİLDİR: sarmalayıcı ekranın yanına da
// konabilir, gövdeyi hiç sarmayabilir, ya da içinde kaydırıcı olmayan bir
// gövdeyi sarıp jesti ölü bırakabilir. Burada gerçek bir sürükleme jesti atılır
// ve yenileme kümesindeki **her** provider'ın yeniden build edildiği sayılır.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` tipi ana pakette değil (Riverpod 3): yardımcıların imzası için.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/widgets/app_pull_to_refresh.dart';
import 'package:online_study_room/data/models/achievement.dart';
import 'package:online_study_room/data/models/achievement_ledger.dart';
import 'package:online_study_room/data/models/achievement_reward.dart';
import 'package:online_study_room/data/models/announcement.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/gamification_profile.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/models/user_study_summary.dart';
import 'package:online_study_room/data/providers/achievement_provider.dart';
import 'package:online_study_room/data/providers/achievement_reward_provider.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/gamification_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/notification_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/core/navigation/home_shell.dart';
import 'package:online_study_room/features/classroom/classroom_screen.dart';
import 'package:online_study_room/features/desktop/desktop_home_shell.dart';
import 'package:online_study_room/features/home/home_screen.dart';
import 'package:online_study_room/features/profile/profile_screen.dart';
import 'package:online_study_room/features/stats/stats_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _me = Profile(
  id: 'me-1',
  displayName: 'Sahip',
  createdAt: DateTime(2026, 1, 1),
);

/// `refreshAppData` tek kaynağının tazelemesi gereken küme.
///
/// 🔴 Bu sabit ikinci bir "liste" DEĞİLDİR — üretimde tek liste `refreshAppData`
/// içindedir; burası onun **beklentisidir**. Listeden bir provider düşerse
/// ölçülen küme küçülür ve test kırmızıya döner (sabotaj (b)).
const _expectedRefreshSet = <String>{
  'userSubjects',
  'myAnnouncements',
  'readAnnouncementIds',
  'achievementDictionary',
  'gamificationProfile',
  'userAchievements',
  'pendingRewardSummary',
  'userSessions',
  'userStudySummary',
  'userGroups',
  'groupMembers',
  'groupDailyStats',
  'groupPresence',
};

/// Provider başına build sayacı. Sayaç = ölçüm; "widget var" iddiası değil.
class _Probe {
  final Map<String, int> counts = <String, int>{};

  void bump(String name) => counts[name] = (counts[name] ?? 0) + 1;

  Map<String, int> snapshot() => Map<String, int>.of(counts);

  /// [before] anına göre YENİDEN build edilmiş provider'lar.
  Set<String> rebuiltSince(Map<String, int> before) => {
    for (final entry in counts.entries)
      if ((before[entry.key] ?? 0) < entry.value) entry.key,
  };
}

/// [groupsFails] açıkken grup akışı hata verir — ekranların hata dalları ölçülür.
/// Aynı provider için ikinci bir override EKLENMEZ: Riverpod aynı listede
/// yinelenen override'ı sessizce yutar ve test yanlış dalı ölçerdi.
List<Override> _overrides(
  _Probe probe,
  SharedPreferences prefs, {
  bool groupsFails = false,
}) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  authStateProvider.overrideWith((ref) => Stream.value(_me)),

  // — arka planda invalidate edilenler —
  userSubjectsProvider.overrideWith((ref) {
    probe.bump('userSubjects');
    return Stream.value(const <Subject>[]);
  }),
  myAnnouncementsProvider.overrideWith((ref) async {
    probe.bump('myAnnouncements');
    return const <Announcement>[];
  }),
  readAnnouncementIdsProvider.overrideWith((ref) async {
    probe.bump('readAnnouncementIds');
    return <String>{};
  }),
  achievementDictionaryProvider.overrideWith((ref) async {
    probe.bump('achievementDictionary');
    return const <AchievementDictEntry>[];
  }),
  gamificationProfileProvider.overrideWith((ref, userId) {
    probe.bump('gamificationProfile');
    return const Stream<GamificationProfile>.empty();
  }),
  userAchievementsProvider.overrideWith((ref, userId) {
    probe.bump('userAchievements');
    return Stream.value(const <UserAchievement>[]);
  }),
  pendingAchievementRewardSummaryProvider.overrideWith((ref) async {
    probe.bump('pendingRewardSummary');
    return AchievementRewardSummary.empty;
  }),

  // — kritik: spinner bunları kısa timeout ile bekler —
  userSessionsProvider.overrideWith((ref) {
    probe.bump('userSessions');
    return Stream.value(const <StudySession>[]);
  }),
  userStudySummaryProvider.overrideWith((ref) async {
    probe.bump('userStudySummary');
    return UserStudySummary.empty;
  }),
  userGroupsProvider.overrideWith((ref) {
    probe.bump('userGroups');
    return groupsFails
        ? Stream<List<StudyGroup>>.error(StateError('ağ yok'))
        : Stream.value(const <StudyGroup>[]);
  }),
  groupMembersProvider.overrideWith((ref) {
    probe.bump('groupMembers');
    return Stream.value(const <Profile>[]);
  }),
  groupDailyStatsProvider.overrideWith((ref) {
    probe.bump('groupDailyStats');
    return Stream.value(const <DailyStat>[]);
  }),
  groupPresenceProvider.overrideWith((ref) {
    probe.bump('groupPresence');
    return Stream.value(const <Presence>[]);
  }),
];

/// Arka planda `invalidate` edilen provider'lar ancak **canlı** ise yeniden
/// build edilir. Dinleyicisiz provider her okumada yeniden kurulur ve regresyon
/// testini sessizce etkisizleştirir (Riverpod 3 auto-dispose tuzağı), bu yüzden
/// kümenin tamamı burada izlenir.
class _KeepAlive extends ConsumerWidget {
  const _KeepAlive();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🔴 `refreshAppData` ilk iş olarak `authStateProvider`ı okur ve kullanıcı
    // yoksa hiçbir şey yapmadan döner. Dinleyicisi olmayan bir provider her
    // `read`de sıfırdan kurulur (`AsyncLoading` → `value == null`), yani bu satır
    // olmadan testin tamamı sessizce "yenileme hiç çağrılmadı" ölçerdi.
    ref.watch(authStateProvider);
    ref.watch(userSubjectsProvider);
    ref.watch(myAnnouncementsProvider);
    ref.watch(readAnnouncementIdsProvider);
    ref.watch(achievementDictionaryProvider);
    ref.watch(gamificationProfileProvider(_me.id));
    ref.watch(userAchievementsProvider(_me.id));
    ref.watch(pendingAchievementRewardSummaryProvider);
    ref.watch(userSessionsProvider);
    ref.watch(userStudySummaryProvider);
    ref.watch(userGroupsProvider);
    ref.watch(groupMembersProvider);
    ref.watch(groupDailyStatsProvider);
    ref.watch(groupPresenceProvider);
    return const SizedBox.shrink();
  }
}

Widget _app(
  Widget home,
  _Probe probe,
  SharedPreferences prefs, {
  bool groupsFails = false,
}) => ProviderScope(
  overrides: _overrides(probe, prefs, groupsFails: groupsFails),
  child: MaterialApp(
    locale: const Locale('tr'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Stack(
      children: [
        Positioned.fill(child: home),
        const Offstage(child: _KeepAlive()),
      ],
    ),
  ),
);

/// Boş pano: `dashboard_layout_v2_32` anahtarı boş listeye ayarlanınca düzen
/// boşalır (`DashboardLayoutNotifier.build`). Sütun sayısı WP-186'dan beri
/// herkeste sabit 32'dir (`DashboardGridDensityX.columns`).
Map<String, Object> _emptyDashboardPrefs() => {
  'dashboard_layout_v2_32': <String>[],
};

/// 🔴 Ana Sayfa turu (`AppTours.home`, `tour_prefs.dart` anahtar biçimi)
/// görülmemişse `TourHost` ekranın üstüne modal bir balon serer ve **jesti
/// yutar**. Tur bayrağı olmadan Ana Sayfa ölçümü sarmalayıcıyı değil turu
/// ölçerdi. Diğer sekmelerin turları `navIndexProvider` 0'da tetiklenmez.
const _homeTourSeenKey = 'tour.home.v2.${'me-1'}';

Future<SharedPreferences> _prefs([Map<String, Object>? values]) async {
  SharedPreferences.setMockInitialValues({_homeTourSeenKey: true, ...?values});
  return SharedPreferences.getInstance();
}

/// Ekranı kurar ve akışların ilk değerini oturtur.
Future<void> _pumpScreen(
  WidgetTester tester,
  Widget home,
  _Probe probe,
  SharedPreferences prefs, {
  bool groupsFails = false,
}) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(_app(home, probe, prefs, groupsFails: groupsFails));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Gerçek jest: parmakla aşağı çekme.
///
/// Sürükleme başlangıç noktası **koordinattır**, `find.byType(RefreshIndicator)`
/// DEĞİL. Sarmalayıcıyı ada göre bulup ona sürüklemek, sarmalayıcı gövdeyi hiç
/// sarmasa bile testi yeşil gösterebilirdi.
Future<void> _pullDown(WidgetTester tester, {double y = 420}) async {
  await tester.dragFrom(Offset(200, y), const Offset(0, 320));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  group('WP-550 — dört ana sekmede aşağı çekerek yenileme', () {
    testWidgets('Ana Sayfa: jest tüm yenileme kümesini tazeler', (
      tester,
    ) async {
      final probe = _Probe();
      final prefs = await _prefs();
      await _pumpScreen(tester, const HomeScreen(), probe, prefs);

      final before = probe.snapshot();
      await _pullDown(tester);

      expect(probe.rebuiltSince(before), _expectedRefreshSet);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Sınıflar: jest tüm yenileme kümesini tazeler', (tester) async {
      final probe = _Probe();
      final prefs = await _prefs();
      await _pumpScreen(tester, const ClassroomScreen(), probe, prefs);

      final before = probe.snapshot();
      await _pullDown(tester);

      expect(probe.rebuiltSince(before), _expectedRefreshSet);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('İstatistik: jest tüm yenileme kümesini tazeler', (
      tester,
    ) async {
      final probe = _Probe();
      final prefs = await _prefs();
      await _pumpScreen(tester, const StatsScreen(), probe, prefs);

      final before = probe.snapshot();
      await _pullDown(tester);

      expect(probe.rebuiltSince(before), _expectedRefreshSet);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Profil: jest tüm yenileme kümesini tazeler', (tester) async {
      final probe = _Probe();
      final prefs = await _prefs();
      await _pumpScreen(tester, const ProfileScreen(), probe, prefs);

      final before = probe.snapshot();
      await _pullDown(tester);

      expect(probe.rebuiltSince(before), _expectedRefreshSet);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('WP-550 — içerik viewport\'tan kısayken de çalışır', () {
    testWidgets('boş pano: ekranda taşan içerik yokken bile jest yenilemeyi '
        'tetikler', (tester) async {
      final probe = _Probe();
      final prefs = await _prefs(_emptyDashboardPrefs());
      await _pumpScreen(tester, const HomeScreen(), probe, prefs);

      // Ön koşul: gerçekten kısa içerik — taşma olsaydı test hiçbir şey ölçmezdi.
      expect(find.byType(RefreshableBody), findsOneWidget);

      final before = probe.snapshot();
      await _pullDown(tester);

      expect(probe.rebuiltSince(before), _expectedRefreshSet);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Sınıflar boş durumu: kısa gövdede jest yaşar', (tester) async {
      final probe = _Probe();
      final prefs = await _prefs();
      await _pumpScreen(tester, const ClassroomScreen(), probe, prefs);

      // Grubu olmayan kullanıcı: ekranda yalnız üç düğme var, hiçbir şey taşmaz.
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      expect(find.text(l10n.classroomHenuzBirGruptaDegilsin), findsOneWidget);

      final before = probe.snapshot();
      await _pullDown(tester, y: 300);

      expect(probe.rebuiltSince(before), _expectedRefreshSet);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('WP-550 — hata kollarında çıkış var', () {
    testWidgets('Sınıflar hata dalı: "Yenile" düğmesi kaynağı tekrar çeker', (
      tester,
    ) async {
      final probe = _Probe();
      final prefs = await _prefs();
      await _pumpScreen(
        tester,
        const ClassroomScreen(),
        probe,
        prefs,
        groupsFails: true,
      );

      // 🔴 Düzeltme öncesi burası çıkışsız bir duvardı: yalnız "Beklenmeyen bir
      // hata oluştu" yazıyordu, kullanıcının tek çaresi uygulamayı öldürmekti.
      final retry = find.byKey(const Key('classroom-error-retry'));
      expect(retry, findsOneWidget);

      final before = probe.snapshot();
      await tester.tap(retry);
      await tester.pump();

      expect(probe.rebuiltSince(before), contains('userGroups'));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('İstatistik grup sekmesi hata dalı: "Yenile" düğmesi var', (
      tester,
    ) async {
      final probe = _Probe();
      final prefs = await _prefs();
      await _pumpScreen(
        tester,
        const StatsScreen(),
        probe,
        prefs,
        groupsFails: true,
      );

      // Grup sekmesine geç.
      final l10n = await AppLocalizations.delegate.load(const Locale('tr'));
      await tester.tap(find.text(l10n.statsGrup));
      await tester.pumpAndSettle();

      final retry = find.byKey(const Key('stats-group-error-retry'));
      expect(retry, findsOneWidget);

      final before = probe.snapshot();
      await tester.tap(retry);
      await tester.pump();

      expect(probe.rebuiltSince(before), contains('userGroups'));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('WP-550 — masaüstü ve mobil kol aynı kümeyi tazeler', () {
    testWidgets('iki kol da `refreshAppData` çağırır; kümeler birebir aynı', (
      tester,
    ) async {
      // — mobil kol: gerçek sürükleme jesti —
      final mobileProbe = _Probe();
      final mobilePrefs = await _prefs();
      await _pumpScreen(
        tester,
        const ProfileScreen(),
        mobileProbe,
        mobilePrefs,
      );
      final mobileBefore = mobileProbe.snapshot();
      await _pullDown(tester);
      final mobileSet = mobileProbe.rebuiltSince(mobileBefore);
      await tester.pumpWidget(const SizedBox());

      // — masaüstü kol: `home_shell.dart`ın `DesktopHomeShell`e GERÇEKTEN
      // verdiği geri çağrı ağaçtan okunur. Testin kendi yazdığı bir
      // `refreshAppData(ref)` çağrısı burada işe yaramazdı — o totolojidir ve
      // masaüstünün kendi eksik listesine dönmesini hiç göremezdi.
      final desktopProbe = _Probe();
      final desktopPrefs = await _prefs();
      Set<String> desktopSet;
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await tester.pumpWidget(
          _app(const HomeShell(), desktopProbe, desktopPrefs),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final shell = tester.widget<DesktopHomeShell>(
          find.byType(DesktopHomeShell),
        );
        final desktopBefore = desktopProbe.snapshot();
        shell.onRefresh();
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
        desktopSet = desktopProbe.rebuiltSince(desktopBefore);
      } finally {
        await tester.pumpWidget(const SizedBox());
        debugDefaultTargetPlatformOverride = null;
      }

      expect(mobileSet, _expectedRefreshSet);
      expect(desktopSet, mobileSet);
    });
  });
}
