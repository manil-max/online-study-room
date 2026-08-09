// WP-573: "Tumu"/"Yil" doneminde kisisel istatistik SESSIZCE 90 gune kirpiliyordu.
//
// `PersonalStatsView` ders kirilimini, saat dagilimini, oturum dagilimini,
// haftalik ritmi ve "Toplam"i `widget.sessions`ten ciziyordu. O liste sunucudan
// **90 gunluk sicak pencere** olarak gelir
// (`supabase_study_repository.dart` `_fetchHotWindowSessions`,
// `session_window.dart` `kUserSessionsHotWindowDays`). Yani 400 gunluk gecmisi
// olan kullanici "Tumu"yu sectiginde son 90 gunun toplamini goruyordu.
//
// 🔴 Bu bir "eksik ozellik" degil, **baglanmamis** ozellikti:
// `analyticsUserSessionsInRangeProvider` tam bu is icin yazilmisti ve `lib/`
// icinde tek bir cagirani yoktu. Bu repoda tekrar eden desen: bitmis backend +
// baglanmamis UI = ozellik YOK.
//
// 🔴 GECE YARISI FLAKE'INE KARSI: buradaki iddialarin hicbiri gun sinirina
// bagli degildir. Beklenen sayilar **sure toplamlaridir** (90x1sa, 310x2sa);
// oturumlarin gun anahtarlari `DateTime(y, m, d - i)` ile takvim aritmetigiyle
// kurulur (yaz saati kaymasi yok) ve hepsi bugunden GERIDE durur, yani kosum
// 23:59'da da 00:01'de de ayni sayilari uretir. Donem matematigi ise ayri bir
// testte **sabitlenmis saatle** (`fixedNow`) olculur.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';
import 'package:online_study_room/core/stats/session_window.dart';
import 'package:online_study_room/core/stats/stats_period.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/core/utils/duration_format.dart';
import 'package:online_study_room/core/widgets/error_retry_view.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/analytics_query_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/stats_period_provider.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_analytics_query_repository.dart';
import 'package:online_study_room/features/stats/widgets/personal_stats_view.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _userId = 'u1';

/// Gecmisin uzunlugu (gun). Sicak pencerenin ~4,4 kati.
const _historyDays = 400;

/// Sicak penceredeki her gun 1 sa, oncesindeki her gun 2 sa.
const _hotSecondsPerDay = 3600;
const _coldSecondsPerDay = 7200;

final _profile = Profile(
  id: _userId,
  displayName: 'Test',
  createdAt: DateTime(2026),
);

const _subjects = <Subject>[
  Subject(id: 'matematik', userId: _userId, name: 'Matematik', color: 'chart-1'),
  Subject(id: 'fizik', userId: _userId, name: 'Fizik', color: 'chart-2'),
];

/// [i] gun once. `subtract(Duration(days:))` degil takvim aritmetigi: yaz saati
/// uygulayan bir kosum makinesinde `subtract` gun anahtarini 23:00'a kaydirir.
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
    // Gun anahtari sunucu damgasindan gelir (bkz. `StudySession.day`).
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

/// Sahte depo: `sessionSource` verildigi icin provider'in demo-mod
/// `seedSessions` cagrisi (bkz. `analytics_query_providers.dart`) veriyi
/// **ezemez** - aksi halde sunucu yolu sessizce sicak pencereye donerdi.
({InMemoryAnalyticsQueryRepository repo, List<int> calls}) _repository(
  List<StudySession> all, {
  bool fail = false,
}) {
  final calls = <int>[];
  final repo = InMemoryAnalyticsQueryRepository(
    sessionSource: (userId) async {
      calls.add(1);
      if (fail) throw StateError('sunucu yok');
      return all;
    },
  );
  return (repo: repo, calls: calls);
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('tr'),
      home: Scaffold(body: _Host()),
    ),
  );
}

class _Host extends ConsumerWidget {
  const _Host();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ekranin gercek kablosu: `stats_screen.dart` `_PersonalTab` sicak pencereyi
    // prop olarak gecer. Test de ayni sekilde gecer ki kirpma ayni yerden dogsun.
    final sessions = ref.watch(userSessionsProvider).value ?? const [];
    return PersonalStatsView(sessions: sessions);
  }
}

Future<ProviderContainer> _container({
  required InMemoryAnalyticsQueryRepository repo,
  required List<StudySession> hot,
  StatsPeriod period = StatsPeriod.all,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authStateProvider.overrideWith((ref) => Stream.value(_profile)),
      userSessionsProvider.overrideWith((ref) => Stream.value(hot)),
      userSubjectsProvider.overrideWith((ref) => Stream.value(_subjects)),
      analyticsQueryRepositoryProvider.overrideWithValue(repo),
    ],
  );
  addTearDown(container.dispose);
  container.read(statsPeriodProvider.notifier).setPeriod(period);
  return container;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 10));
  await tester.pump(const Duration(milliseconds: 10));
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

  test('on kosul (sabit saat): "Tumu" sicak pencerenin gerisine uzanir', () {
    // 🔴 Kurulum dogrulamasi: senaryo gercekten hatanin penceresinde mi?
    // Saat burada ENJEKTE edilir; `DateTime.now()` okunmaz.
    final fixedNow = DateTime(2026, 8, 9, 12);
    final (from, to) = const StatsPeriodSelection(
      period: StatsPeriod.all,
    ).range(now: fixedNow);

    expect(
      from.isBefore(sessionHotWindowStart(now: fixedNow)),
      isTrue,
      reason: '"Tumu" sicak pencerenin gerisine uzanmiyorsa hata zaten olusmaz.',
    );
    expect(
      dayOf(to).difference(dayOf(from)).inDays,
      greaterThan(_historyDays),
      reason: 'Donem 400 gunluk gecmisin tamamini kapsamali.',
    );
    // Gecmisin cogunlugu bilerek sicak pencerenin DISINDA.
    expect(coldTotal, greaterThan(hotTotal));
  });

  testWidgets('"Tumu"de Toplam karti 400 gunun toplamini gosterir', (
    tester,
  ) async {
    final data = _history();
    final fake = _repository(data.all);
    final container = await _container(repo: fake.repo, hot: data.hot);

    await tester.pumpWidget(_app(container));
    await _settle(tester);

    // Eski davranis burada `formatHuman(hotTotal)` (= 90 gunun toplami)
    // yaziyordu; sunucudaki 310 gun hic goruntulenmiyordu.
    expect(
      find.text(formatHuman(grandTotal)),
      findsOneWidget,
      reason: 'Toplam, donemin tamamini (400 gun) toplamali.',
    );
    // Sunucu verisi geldiginde kapsam etiketi YAZILMAZ; dogru veriye yanlis
    // uyari eklemek de bir yalandir.
    expect(find.textContaining('Tümü · 90 gün'), findsNothing);
  });

  testWidgets('"Tumu"de ders kirilimi 400 gunun tamamini toplar', (
    tester,
  ) async {
    final data = _history();
    final fake = _repository(data.all);
    final container = await _container(repo: fake.repo, hot: data.hot);

    await tester.pumpWidget(_app(container));
    await _settle(tester);

    // Kartin bicim secicisi gorunur olana kadar kaydir (kart tek parca kurulur,
    // yani ayni anda efsane satirlari da agacta olur).
    await _scrollTo(tester, find.text('Süre'));

    // Yalniz sicak pencerenin DISINDA calisilmis ders: eski kodun ders
    // kiriliminda bu satir hic olusmuyordu.
    expect(find.text('Matematik'), findsOneWidget);
    expect(find.text('Fizik'), findsOneWidget);

    // Yuzde yerine sureyi goster: kirilimin toplami olculebilir olsun.
    await tester.tap(find.text('Süre'));
    await tester.pumpAndSettle();

    expect(
      find.text(formatHuman(coldTotal)),
      findsOneWidget,
      reason: 'Sicak pencere disindaki 310 gun (620 sa) kirilimda olmali.',
    );
    expect(find.text(formatHuman(hotTotal)), findsOneWidget);
  });

  testWidgets('sunucu yolu duserse sessizce 90 gune DUSULMEZ', (tester) async {
    final data = _history();
    final fake = _repository(data.all, fail: true);
    final container = await _container(repo: fake.repo, hot: data.hot);

    await tester.pumpWidget(_app(container));
    await _settle(tester);

    // 1) Cikis var: WP-560 ortak hata govdesi (yalniz mesaj degil, tekrar-dene).
    expect(find.byType(ErrorRetryView), findsOneWidget);

    // 2) Tekrar-dene gercekten veriyi yeniden okur (sozle degil sayacla olculur).
    final before = fake.calls.length;
    await tester.tap(find.byKey(kErrorRetryButtonKey));
    await _settle(tester);
    expect(
      fake.calls.length,
      greaterThan(before),
      reason: 'Tekrar-dene dugmesi depoyu yeniden cagirmali.',
    );

    // 3) Kapsam soylenir: kart basliklari 90 gunle sinirli olduklarini yazar.
    await _scrollTo(tester, find.textContaining('Çalışma saatleri'));
    expect(
      find.text('Çalışma saatleri · Tümü · 90 gün'),
      findsOneWidget,
      reason: 'Sunucu yoksa kartin kapsami baslikta yazmali.',
    );
  });

  testWidgets('donem sicak pencerenin icindeyse sunucuya HIC gidilmez', (
    tester,
  ) async {
    final data = _history();
    // Depo bilerek bozuk: "Hafta"da dokunulursa hata yuzeyi acilir ve gorulur.
    final fake = _repository(data.all, fail: true);
    final container = await _container(
      repo: fake.repo,
      hot: data.hot,
      period: StatsPeriod.week,
    );

    await tester.pumpWidget(_app(container));
    await _settle(tester);

    expect(
      find.byType(ErrorRetryView),
      findsNothing,
      reason: 'Kisa donemde gereksiz RPC dogurulmamali.',
    );
  });
}
