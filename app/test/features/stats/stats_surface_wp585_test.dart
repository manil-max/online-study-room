// WP-585: istatistik yuzeyindeki UC sessiz celiski.
//
//   (1) `statsDersBazindaDagilimSon` metni "(son 30 gun)" diyordu. WP-573'ten
//       sonra o kart HICBIR donemde 30 gun degil (sicak pencere 90 gun, uzun
//       donemde sunucudan tam veri). Kullanici "son 30 gun" okuyup 400 gunluk
//       toplami goruyordu. Kapsam ekranda ZATEN var (`· <donem>` + `· N gun`),
//       metne gomulu ikinci bir pencere iddiasi ucuncu bir gercek uretiyordu.
//
//   (2) `refreshAppData` WP-550'de yenilemenin TEK kaynagi yapildi ama analitik
//       yolu listede YOKTU. Bu dosya listeyi degil DAVRANISI olcer: sahte
//       depodaki cagri sayaci 1 -> 2 olmali.
//
//       🔴 Olcum bilerek IZOLE edilir: `userGroupProvider` sabit bir degerle
//       ezilir. Aksi halde grup analitigi `userGroupsProvider` uzerinden
//       DOLAYLI olarak da tazelenir ve test, `refreshAppData` icindeki satir
//       silinse bile YESIL kalirdi — yani hicbir sey olcmezdi. Sozlesme sudur:
//       tek kaynak analitigi KENDISI tazeler, komsu bir provider'in yan etkisi
//       sayesinde degil.
//
//   (3) `analyticsUserSessionsInRangeProvider` sunucu BOS liste dondugunde
//       sicak pencereye geri dusuyordu ve bu geri dusme SESSIZDI: ekran "veri
//       geldi" sanip kapsam etiketini ("· 90 gun") yazmiyordu. Kullanici 90
//       gunluk toplami 400 gunluk saniyordu. Geri dusme kaldirilmadi (sunucu
//       bos dondugunde ekrani sifirlamak ayri bir yalan olurdu) — SOYLENIYOR.
//
// 🔴 GECE YARISI FLAKE'INE KARSI (WP-565 dersi): buradaki iddialarin hicbiri
// gun sinirina bagli degildir. Beklenen sayilar sure toplamlaridir ve oturum
// gun anahtarlari `DateTime(y, m, d - i)` takvim aritmetigiyle kurulur (yaz
// saati kaymasi yok), hepsi bugunden GERIDE durur.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// `Override` tipi Riverpod 3'te ana pakette degil; yardimcilarin imzasi icin.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';
import 'package:online_study_room/core/stats/session_window.dart';
import 'package:online_study_room/core/stats/stats_period.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/core/utils/duration_format.dart';
import 'package:online_study_room/core/widgets/app_pull_to_refresh.dart';
import 'package:online_study_room/data/models/analytics_query_models.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/presence.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/models/user_study_summary.dart';
import 'package:online_study_room/data/providers/analytics_query_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/presence_providers.dart';
import 'package:online_study_room/data/providers/stats_period_provider.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/data/repositories/analytics_query_repository.dart';
import 'package:online_study_room/features/stats/analytics/analytics_period.dart';
import 'package:online_study_room/features/stats/widgets/personal_stats_view.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _userId = 'u1';

/// Gecmisin uzunlugu (gun). Sicak pencerenin ~4,4 kati.
const _historyDays = 400;
const _hotSecondsPerDay = 3600;
const _coldSecondsPerDay = 7200;

final _profile = Profile(
  id: _userId,
  displayName: 'Test',
  createdAt: DateTime(2026),
);

final _group = StudyGroup(
  id: 'g1',
  name: 'Odak Grubu',
  inviteCode: 'KAMP42',
  createdBy: _userId,
  createdAt: DateTime(2026),
);

const _subjects = <Subject>[
  Subject(
    id: 'matematik',
    userId: _userId,
    name: 'Matematik',
    color: 'chart-1',
  ),
  Subject(id: 'fizik', userId: _userId, name: 'Fizik', color: 'chart-2'),
];

DateTime _dayBefore(DateTime todayKey, int i) =>
    DateTime(todayKey.year, todayKey.month, todayKey.day - i);

StudySession _session(DateTime day, int index, bool hot) {
  final seconds = hot ? _hotSecondsPerDay : _coldSecondsPerDay;
  return StudySession(
    id: 's$index',
    userId: _userId,
    subjectId: hot ? 'fizik' : 'matematik',
    start: day.add(const Duration(hours: 10)),
    end: day.add(Duration(hours: 10, seconds: seconds)),
    durationSeconds: seconds,
    source: StudySource.manual,
    recordedDay: day,
  );
}

/// Sunucudaki tam gecmis (400 gun) ve istemcideki sicak pencere (90 gun).
({List<StudySession> all, List<StudySession> hot}) _history() {
  final todayKey = istanbulDay(DateTime.now());
  final all = <StudySession>[];
  final hot = <StudySession>[];
  for (var i = 0; i < _historyDays; i++) {
    final isHot = i < kUserSessionsHotWindowDays;
    final session = _session(_dayBefore(todayKey, i), i, isHot);
    all.add(session);
    if (isHot) hot.add(session);
  }
  return (all: all, hot: hot);
}

/// Sahte analitik deposu.
///
/// `InMemoryAnalyticsQueryRepository`'den TUREMEZ: provider'lar o tipi gorunce
/// demo-mod tohumlama dallarina girer ve grup katkisi `groupDailyStatsProvider`i
/// izlemeye baslar. O dal acikken (2)'nin izolasyonu bozulurdu.
class _FakeAnalyticsRepository implements AnalyticsQueryRepository {
  _FakeAnalyticsRepository({required this.all, this.serverEmpty = false});

  final List<StudySession> all;

  /// Sunucu erisilebilir ama BOS liste donuyor — (3)'un tam senaryosu.
  final bool serverEmpty;

  int dayTotalCalls = 0;
  int sessionRangeCalls = 0;
  int contributionCalls = 0;
  int alphaCalls = 0;

  @override
  Future<List<UserDayTotal>> getUserDayTotals({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    dayTotalCalls++;
    if (serverEmpty) return const [];
    final totals = dailyTotals(inRange(all, from, to));
    return [
      for (final e in totals.entries)
        if (e.value > 0) UserDayTotal(day: e.key, seconds: e.value),
    ];
  }

  @override
  Future<List<StudySession>> getUserSessionsInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    sessionRangeCalls++;
    if (serverEmpty) return const [];
    return inRange(all, from, to).toList();
  }

  @override
  Future<List<GroupContributionRow>> getGroupContribution({
    required String groupId,
    required DateTime from,
    required DateTime to,
  }) async {
    contributionCalls++;
    return const [GroupContributionRow(userId: _userId, seconds: 3600)];
  }

  @override
  Future<List<GroupLeaderboardPoint>> getGroupLeaderboardSeries({
    required String groupId,
    required DateTime from,
    required DateTime to,
  }) async => const [];

  @override
  Future<List<GroupAlphaScore>> getGroupAlphaScores({
    required String groupId,
  }) async {
    alphaCalls++;
    return const [GroupAlphaScore(userId: _userId, alphaWins: 1)];
  }
}

/// Ekranin gercek kablosu: `stats_screen.dart` sicak pencereyi prop olarak
/// gecer; test de ayni sekilde gecer ki kirpma ayni yerden dogsun.
class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 🔴 Riverpod 3 tuzagi (WP-560 dersi): dinleyicisiz `authStateProvider` her
    // `read`de yeniden kurulur ve `.value` null doner. `refreshAppData` o
    // durumda ILK SATIRDA sessizce cikar ve testin tamami yalanci olur.
    ref.watch(authStateProvider);
    final sessions =
        ref.watch(userSessionsProvider).value ?? const <StudySession>[];
    return PersonalStatsView(sessions: sessions);
  }
}

/// Grup analitigini CANLI tutar. Riverpod 3'te dinleyicisiz provider
/// `invalidate` edilse bile yeniden kurulmaz; bu widget olmadan (2)'nin grup
/// yarisi hicbir sey olcmezdi.
class _GroupAnalyticsKeepAlive extends ConsumerWidget {
  const _GroupAnalyticsKeepAlive();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = analyticsPeriodFromSelection(ref.watch(statsPeriodProvider));
    ref.watch(analyticsGroupContributionProvider(period));
    ref.watch(groupAlphaScoresProvider);
    return const SizedBox.shrink();
  }
}

List<Override> _overrides(
  SharedPreferences prefs,
  _FakeAnalyticsRepository repo,
  List<StudySession> hot,
) => [
  sharedPreferencesProvider.overrideWithValue(prefs),
  authStateProvider.overrideWith((ref) => Stream.value(_profile)),
  userSessionsProvider.overrideWith((ref) => Stream.value(hot)),
  userSubjectsProvider.overrideWith((ref) => Stream.value(_subjects)),
  userStudySummaryProvider.overrideWith((ref) async => UserStudySummary.empty),
  userGroupsProvider.overrideWith((ref) => Stream.value(<StudyGroup>[_group])),
  // 🔴 (2) izolasyonu: sabit deger. `refreshAppData` `userGroupsProvider`i
  // tazeler; bu ezme olmadan grup analitigi oradan DOLAYLI olarak da tazelenir
  // ve olcum, duzeltme geri alinsa bile yesil kalirdi.
  userGroupProvider.overrideWithValue(AsyncData<StudyGroup?>(_group)),
  groupMembersProvider.overrideWith((ref) => Stream.value(const <Profile>[])),
  groupDailyStatsProvider.overrideWith(
    (ref) => Stream.value(const <DailyStat>[]),
  ),
  groupPresenceProvider.overrideWith((ref) => Stream.value(const <Presence>[])),
  analyticsQueryRepositoryProvider.overrideWithValue(repo),
];

Future<ProviderContainer> _container(
  _FakeAnalyticsRepository repo,
  List<StudySession> hot, {
  StatsPeriod period = StatsPeriod.all,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: _overrides(prefs, repo, hot));
  addTearDown(container.dispose);
  container.read(statsPeriodProvider.notifier).setPeriod(period);
  return container;
}

/// Varsayilan 800x600 test penceresi bilerek KORUNUR. Daha dar bir pencerede
/// `_RangeCard`in tarih satiri tasar (bu WP'nin konusu degil) ve testler
/// alakasiz bir overflow ile kirmizi doner.
Future<void> _pumpApp(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('tr'),
        home: Scaffold(
          // `StackFit.expand`: tek konumlandirilmamis cocuk `Offstage` oldugu
          // icin varsayilan `loose` yiginin yuksekligini 0 yapiyor, liste de
          // 0 piksellik bir viewport'a duserek jesti oldururdu.
          body: Stack(
            fit: StackFit.expand,
            children: [
              AppPullToRefresh(child: _Host()),
              Offstage(child: _GroupAnalyticsKeepAlive()),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pump(const Duration(milliseconds: 10));
}

/// Gercek parmak jesti. Baslangic noktasi KOORDINAT'tir (WP-550 dersi):
/// `find.byType(RefreshIndicator)`e surukleme, sarmalayici govdeyi hic
/// sarmasa bile yesil gosterebilirdi.
Future<void> _pullDown(WidgetTester tester) async {
  await tester.dragFrom(const Offset(400, 200), const Offset(0, 320));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(seconds: 3));
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    240,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 80,
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final hotTotal = kUserSessionsHotWindowDays * _hotSecondsPerDay;
  final coldTotal =
      (_historyDays - kUserSessionsHotWindowDays) * _coldSecondsPerDay;
  final grandTotal = hotTotal + coldTotal;

  // ─────────────────────────────────────────────────────────────────────────
  // (1) Baslik kendi kendisiyle celismez
  // ─────────────────────────────────────────────────────────────────────────

  test('(1) katalog metni kendi icinde pencere IDDIA ETMEZ', () async {
    final tr = await AppLocalizations.delegate.load(const Locale('tr'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));

    expect(tr.statsDersBazindaDagilimSon, 'Ders bazında dağılım');
    expect(en.statsDersBazindaDagilimSon, 'Distribution by subject');
    // Kapsami ekran soyler (`· <donem>` ve gerekirse `· N gun`). Metne gomulu
    // sabit bir pencere, donem secicisiyle her zaman celisir.
    expect(tr.statsDersBazindaDagilimSon, isNot(contains('30')));
    expect(en.statsDersBazindaDagilimSon, isNot(contains('30')));
  });

  testWidgets('(1) "Tumu"de baslik TEK bir kapsam soyler', (tester) async {
    final data = _history();
    final repo = _FakeAnalyticsRepository(all: data.all);
    await _pumpApp(tester, await _container(repo, data.hot));

    // On kosul: kartlar gercekten donemin tamamini gosteriyor (yoksa baslik
    // dogru olsa bile iddia bos kalirdi). Kaydirmadan ONCE olculur: ListView
    // ekrandan cikan satiri soker ve `find.text` sifir dondururdu.
    expect(find.text(formatHuman(grandTotal)), findsOneWidget);

    await _scrollTo(tester, find.textContaining('Ders bazında dağılım'));

    expect(
      find.text('Ders bazında dağılım · Tümü'),
      findsOneWidget,
      reason: 'Baslik yalniz ekrandaki donem etiketini tasimali.',
    );
    expect(
      find.textContaining('son 30 gün'),
      findsNothing,
      reason: 'Kullanici "son 30 gun" okuyup 400 gunluk toplami goruyordu.',
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // (2) Yenilemenin TEK kaynagi analitigi de tazeler
  // ─────────────────────────────────────────────────────────────────────────

  testWidgets('(2) asagi cekme jesti analitik sunucu yolunu YENIDEN okur', (
    tester,
  ) async {
    final data = _history();
    final repo = _FakeAnalyticsRepository(all: data.all);
    await _pumpApp(tester, await _container(repo, data.hot));

    // On kosul: dort yol da acilista okundu — yoksa "arttI" iddiasi bos olur.
    expect(repo.sessionRangeCalls, greaterThan(0));
    expect(repo.dayTotalCalls, greaterThan(0));
    expect(repo.contributionCalls, greaterThan(0));
    expect(repo.alphaCalls, greaterThan(0));

    final sessionsBefore = repo.sessionRangeCalls;
    final dayTotalsBefore = repo.dayTotalCalls;
    final contributionBefore = repo.contributionCalls;
    final alphaBefore = repo.alphaCalls;

    await _pullDown(tester);

    // 🔴 Bu iki iddia IKI yoldan birden doyurulabilir: kisisel analitik
    // `userSessionsProvider`i izler ve o zaten listededir. Yani burasi "su
    // satir duruyor mu" degil, "yenilemeden sonra uzun donem verisi yeniden
    // okundu mu" SOZLESMESINI kilitler; iki telin birlikte kesilmesi kirmizi
    // verir. Satirin kendisini asagidaki grup iddialari kilitler.
    expect(
      repo.sessionRangeCalls,
      greaterThan(sessionsBefore),
      reason: 'Uzun donem oturumlari yenilemede yeniden okunmali (WP-573).',
    );
    expect(
      repo.dayTotalCalls,
      greaterThan(dayTotalsBefore),
      reason: 'Gun toplamlari yenilemede yeniden okunmali.',
    );
    // 🔴 Bu iki iddia IZOLE: `userGroupProvider` sabit ezildigi icin grup
    // analitigine giden TEK canli tel `refreshAppData`nin kendi satiridir.
    // Analitik satirlari silinince BURASI kirmizi doner.
    expect(
      repo.contributionCalls,
      greaterThan(contributionBefore),
      reason: 'Grup katkisi yalniz komsu provider sayesinde tazelenemez.',
    );
    expect(
      repo.alphaCalls,
      greaterThan(alphaBefore),
      reason: 'Alfa toplamlari yenilemenin tek kaynaginda listelenmeli.',
    );
  });

  // ─────────────────────────────────────────────────────────────────────────
  // (3) Sessiz geri dusme artik SESSIZ degil
  // ─────────────────────────────────────────────────────────────────────────

  testWidgets('(3) sunucu BOS donunce kapsam etiketi YAZILIR', (tester) async {
    final data = _history();
    final repo = _FakeAnalyticsRepository(all: data.all, serverEmpty: true);
    await _pumpApp(tester, await _container(repo, data.hot));

    // On kosul: sunucuya gercekten gidildi ve bos dondu.
    expect(repo.sessionRangeCalls, greaterThan(0));

    // Kartlar sicak pencereye dustu: "Toplam" 400 gunun degil 90 gunun toplami.
    expect(
      find.text(formatHuman(hotTotal)),
      findsOneWidget,
      reason: 'Bos sunucu yanitinda kartlar sicak pencereden besleniyor.',
    );
    expect(find.text(formatHuman(grandTotal)), findsNothing);

    // ...ve bunu SOYLUYOR. Eski hal: view `serverSessions != null` gordugu icin
    // "veri geldi" sanip tam donem basligi yaziyordu.
    await _scrollTo(tester, find.textContaining('Çalışma saatleri'));
    expect(
      find.text('Çalışma saatleri · Tümü · 90 gün'),
      findsOneWidget,
      reason: 'Eksik veriyi tam gostermek sessiz yalandir.',
    );

    await _scrollTo(tester, find.textContaining('Ders bazında dağılım'));
    expect(find.text('Ders bazında dağılım · Tümü · 90 gün'), findsOneWidget);
  });

  testWidgets('(3) sunucu DOLU donunce kapsam etiketi yazilmaz', (
    tester,
  ) async {
    // Dogru veriye yanlis uyari eklemek de bir yalandir: etiket kosullu kalmali.
    final data = _history();
    final repo = _FakeAnalyticsRepository(all: data.all);
    await _pumpApp(tester, await _container(repo, data.hot));

    await _scrollTo(tester, find.textContaining('Çalışma saatleri'));
    expect(find.text('Çalışma saatleri · Tümü'), findsOneWidget);
    expect(find.textContaining('Tümü · 90 gün'), findsNothing);
  });
}
