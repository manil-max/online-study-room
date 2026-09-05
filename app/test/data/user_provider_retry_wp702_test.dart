// WP-702 — 38 SANIYELIK DONEN CARK **KULLANICI** TARAFINDA DA DURUYOR.
//
// WP-692 ayni tuzagi yalniz `admin_providers.dart`'ta kapatti. Olculen kalinti:
// kullaniciya gorunen 13 okuma saglayicisi hala korumasizdi
// (`moderation_providers.dart` 4, `analytics_query_providers.dart` 5,
// `admin_moderation_providers.dart` 4).
//
// Kusurun kaynagi (riverpod-3.3.2):
//   * `provider_container.dart:940` `ProviderContainer.defaultRetry` yalniz
//     `Error` ve `ProviderException` icin durur. `ModerationException` ve ham
//     `PostgrestException` **`Exception`**tir → 10 kez yeniden denenir
//     (200+400+800+1600+3200+6400*5 = **38.4 sn**).
//   * `element.dart:781-787` — o sure boyunca durum `AsyncLoading(retrying:
//     true)`, yani ekranda **donen cark**; kayip hic yazilmaz.
//   * `element.dart:80` — `onLoading` completer'i tamamlamaz; `.future`
//     bekleyen her cagri 38 saniye askida kalir.
//
// 🔴 Bu dosya SURE olcmez, **cagri sayisi + durum gecisi** olcer. Gercek
// bekleme yok: `testWidgets` FakeAsync altinda kosar.
//
// 🔴 Kapatma TOPTAN DEGIL: gercekten gecici bir ag hatasinda yeniden deneme
// YARARLIDIR ve acik birakilmistir — WP-702/5 bunu AYRI olcer. Politika geri
// alinirsa (sabotaj) 1-4 kirmiziya doner ama 5 YESIL kalir; kalmiyorsa test
// kalici/gecici ayrimini olcmuyor demektir.

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/net/read_retry_policy.dart';
import 'package:online_study_room/data/models/analytics_query_models.dart';
import 'package:online_study_room/data/models/moderation_appeal.dart';
import 'package:online_study_room/data/models/moderation_case.dart';
import 'package:online_study_room/data/models/moderation_sanction.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/providers/admin_moderation_providers.dart';
import 'package:online_study_room/data/providers/analytics_query_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/moderation_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/admin_moderation_repository.dart';
import 'package:online_study_room/data/repositories/admin_repository.dart';
import 'package:online_study_room/data/repositories/analytics_query_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_moderation_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_moderation_repository.dart';
import 'package:online_study_room/features/stats/analytics/analytics_period.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

// ---------------------------------------------------------------------------
// Gercek hata ornekleri. Hicbiri uydurma degil — her biri deponun ilgili
// `catch` dalindan cikan bicimi tasir.
// ---------------------------------------------------------------------------

/// Sunucunun **kalici** reddi: RLS.
/// `supabase_moderation_repository.dart:85` `on PostgrestException` →
/// `ModerationException(e.message)`.
const _modDenied = ModerationException(
  'permission denied for table moderation_sanctions',
);

/// Ayni kalici sinif, kuyruk tarafi
/// (`supabase_admin_moderation_repository.dart:53`): yonetici degilsin.
const _queueDenied = ModerationException(
  'permission denied for function admin_ugc_report_groups',
);

/// **Ham** PostgREST hatasi. `supabase_analytics_query_repository.dart` HIC
/// sarmalamaz; `listBlockedUserIds` (`supabase_moderation_repository.dart:138`)
/// de sarmalamaz — bu tip saglayiciya oldugu gibi ulasir.
const _rawDenied = PostgrestException(
  message: 'permission denied for table study_sessions',
  code: '42501',
);

/// Oturum dusmus: PostgREST 401. Yine kalici — tekrar denemek yenilemez.
const _jwtExpired = PostgrestException(message: 'JWT expired', code: 'PGRST301');

/// **Gecici**: ag dusmesi. Depo katmani bunu sarmalamaz, ham gecer.
final _transientRaw = const SocketException(
  "Failed host lookup: 'abc.supabase.co'",
);

/// **Gecici**, sarmalanmis bicim: `admin-user-actions` cagrisinin genis
/// `catch`i ag hatasini da ayni tipe sarabilir.
const _transientWrapped = ModerationException(
  'Servis hatasi: ClientException with SocketException: Connection reset by peer',
);

Profile _profile(String id) =>
    Profile(id: id, displayName: id, createdAt: DateTime(2026));

final _group = StudyGroup(
  id: 'g1',
  name: 'Kamp',
  inviteCode: 'ABC123',
  createdBy: 'u1',
  createdAt: DateTime(2026),
);

/// "Tum zamanlar" donemi: araligi `DateTime(2000) → simdi`
/// (`stats_period.dart:100`), yani 90 gunluk sicak-pencere kisayolu HER
/// TAKVIM GUNUNDE atlanir ve cagri gercekten depoya iner. `year` kullanmak
/// testi ocak ayinda sessizce etkisiz birakirdi.
const _period = AnalyticsPeriod(AnalyticsPeriodKind.all);

// ---------------------------------------------------------------------------
// Sayan sahte depolar. Her biri **yalniz** verilen metotta duser; digerleri
// bos/basarili doner ki olculen saglayici izole kalsin.
// ---------------------------------------------------------------------------

mixin _CallCounter {
  final Map<String, int> calls = <String, int>{};
  String get failingMethod;
  Object get error;

  int callsTo(String method) => calls[method] ?? 0;

  T _guard<T>(String method, T Function() ok) {
    calls[method] = callsTo(method) + 1;
    if (method == failingMethod) throw error;
    return ok();
  }
}

class _FailingModerationRepository extends InMemoryModerationRepository
    with _CallCounter {
  _FailingModerationRepository(this.failingMethod, this.error);

  @override
  final String failingMethod;
  @override
  final Object error;

  @override
  Future<List<String>> listBlockedUserIds() async =>
      _guard('listBlockedUserIds', () => const <String>[]);

  @override
  Future<List<Profile>> fetchBlockedProfiles() async =>
      _guard('fetchBlockedProfiles', () => const <Profile>[]);

  @override
  Future<List<ModerationSanction>> fetchMySanctions() async =>
      _guard('fetchMySanctions', () => const <ModerationSanction>[]);

  @override
  Future<List<ModerationAppeal>> fetchMyAppeals() async =>
      _guard('fetchMyAppeals', () => const <ModerationAppeal>[]);
}

class _FailingAdminModerationRepository
    extends InMemoryAdminModerationRepository
    with _CallCounter {
  _FailingAdminModerationRepository(this.failingMethod, this.error);

  @override
  final String failingMethod;
  @override
  final Object error;

  @override
  Future<List<ModerationCase>> fetchQueue() async =>
      _guard('fetchQueue', () => const <ModerationCase>[]);

  @override
  Future<ModerationCaseDetail> fetchDetail(String reportId) async => _guard(
    'fetchDetail',
    () => const ModerationCaseDetail(
      snapshot: '',
      details: null,
      contextMessages: [],
      reportCount: 0,
    ),
  );

  @override
  Future<List<ModerationSanction>> fetchSanctions(String targetUserId) async =>
      _guard('fetchSanctions', () => const <ModerationSanction>[]);

  @override
  Future<List<ModerationAppeal>> fetchAppeals() async =>
      _guard('fetchAppeals', () => const <ModerationAppeal>[]);
}

class _FailingAnalyticsRepository
    with _CallCounter
    implements AnalyticsQueryRepository {
  _FailingAnalyticsRepository(this.failingMethod, this.error);

  @override
  final String failingMethod;
  @override
  final Object error;

  @override
  Future<List<UserDayTotal>> getUserDayTotals({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async => _guard('getUserDayTotals', () => const <UserDayTotal>[]);

  @override
  Future<List<StudySession>> getUserSessionsInRange({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async => _guard('getUserSessionsInRange', () => const <StudySession>[]);

  @override
  Future<List<GroupContributionRow>> getGroupContribution({
    required String groupId,
    required DateTime from,
    required DateTime to,
  }) async =>
      _guard('getGroupContribution', () => const <GroupContributionRow>[]);

  @override
  Future<List<GroupLeaderboardPoint>> getGroupLeaderboardSeries({
    required String groupId,
    required DateTime from,
    required DateTime to,
  }) async => _guard(
    'getGroupLeaderboardSeries',
    () => const <GroupLeaderboardPoint>[],
  );

  @override
  Future<List<GroupAlphaScore>> getGroupAlphaScores({
    required String groupId,
  }) async => _guard('getGroupAlphaScores', () => const <GroupAlphaScore>[]);
}

// ---------------------------------------------------------------------------
// Ortak yardimcilar
// ---------------------------------------------------------------------------

/// Sahte saati **10 yeniden denemenin tamamindan** (38.4 sn) fazla ilerletir.
Future<void> _elapseBeyondEveryRetry(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(seconds: 120));
  await tester.pump();
}

/// 🔴 Riverpod 3 tuzagi (hafizada kayitli ders): dinleyicisi olmayan saglayici
/// her `read`de yeniden kurulur ve regresyon testini SESSIZCE etkisizlestirir.
/// Bagimliligi hem `listen` eder hem de ilk degerini bekler — boylece olculen
/// saglayici tek kez, sabit bir bagimlilik durumu uzerinde kurulur.
Future<void> _prime<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
  Future<T> future,
) async {
  final sub = container.listen<AsyncValue<T>>(provider, (_, _) {});
  addTearDown(sub.close);
  await future;
}

Future<ProviderContainer> _container(
  WidgetTester tester,
  List<Override> overrides,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  final container = ProviderContainer(
    overrides: [
      authStateProvider.overrideWith((ref) => Stream.value(_profile('u1'))),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await _prime(
    container,
    authStateProvider,
    container.read(authStateProvider.future),
  );
  return container;
}

/// Saglayicinin gordugu TUM durumlari kaydeder (dinleyici de acik kalir).
List<AsyncValue<Object?>> _record<T>(
  ProviderContainer container,
  ProviderListenable<AsyncValue<T>> provider,
) {
  final states = <AsyncValue<Object?>>[];
  final sub = container.listen<AsyncValue<T>>(
    provider,
    (_, next) => states.add(next),
    fireImmediately: true,
  );
  addTearDown(sub.close);
  return states;
}

/// Kalici hata icin ortak iddia uclusu.
void _expectPermanentSurfaced({
  required String name,
  required int callCount,
  required List<AsyncValue<Object?>> states,
  required AsyncValue<Object?> finalState,
}) {
  expect(
    callCount,
    1,
    reason:
        '$name: sunucunun kesin reddi tekrar denemekle DUZELMEZ; her deneme '
        'kullanicinin gordugu carki 38 saniyeye kadar uzatir',
  );
  expect(
    states.any((s) => s.isLoading && s.retrying),
    isFalse,
    reason:
        '$name: `AsyncLoading(retrying: true)` = kullanicinin gordugu DONEN '
        'CARK; kalici hatada bu durum hic olusmamali',
  );
  expect(
    finalState,
    isA<AsyncError<Object?>>(),
    reason: '$name: kayip DERHAL yuzeye cikmali',
  );
}

typedef _Case = ({
  String name,
  String method,
  Object error,
  ProviderListenable<AsyncValue<Object?>> provider,
});

void main() {
  // ------------------------------------------------------------------
  // WP-702/1 — `moderation_providers.dart` (dogrudan KULLANICI yuzeyi:
  // engellenenler ekrani + "hakkimdaki yaptirim" karti).
  // ------------------------------------------------------------------
  group('WP-702/1 moderation_providers kalici hatada carka donmez', () {
    final cases = <_Case>[
      (
        name: 'blockedUserIdsProvider',
        method: 'listBlockedUserIds',
        error: _rawDenied,
        provider: blockedUserIdsProvider,
      ),
      (
        name: 'mySanctionsProvider',
        method: 'fetchMySanctions',
        error: _modDenied,
        provider: mySanctionsProvider,
      ),
      (
        name: 'myAppealsProvider',
        method: 'fetchMyAppeals',
        error: _modDenied,
        provider: myAppealsProvider,
      ),
    ];

    for (final c in cases) {
      testWidgets('${c.name}: depo 1 kez cagrilir, durum AsyncError', (
        tester,
      ) async {
        final repo = _FailingModerationRepository(c.method, c.error);
        final container = await _container(tester, [
          moderationRepositoryProvider.overrideWithValue(repo),
        ]);
        final states = _record(container, c.provider);

        await _elapseBeyondEveryRetry(tester);

        _expectPermanentSurfaced(
          name: c.name,
          callCount: repo.callsTo(c.method),
          states: states,
          finalState: container.read(c.provider),
        );
      });
    }

    testWidgets('blockedProfilesProvider: depo 1 kez cagrilir', (tester) async {
      final repo = _FailingModerationRepository(
        'fetchBlockedProfiles',
        _rawDenied,
      );
      final container = await _container(tester, [
        moderationRepositoryProvider.overrideWithValue(repo),
      ]);
      // Bu saglayici `blockedUserIdsProvider`i izler; onun durum gecisi de
      // yeniden kurma uretirdi. Once oturtulur ki sayac YALNIZ retry'i olcsun.
      await _prime(
        container,
        blockedUserIdsProvider,
        container.read(blockedUserIdsProvider.future),
      );
      final states = _record(container, blockedProfilesProvider);

      await _elapseBeyondEveryRetry(tester);

      _expectPermanentSurfaced(
        name: 'blockedProfilesProvider',
        callCount: repo.callsTo('fetchBlockedProfiles'),
        states: states,
        finalState: container.read(blockedProfilesProvider),
      );
    });
  });

  // ------------------------------------------------------------------
  // WP-702/2 — `analytics_query_providers.dart` (istatistik sekmesinin
  // tamami). Bu depo hicbir hatayi sarmalamaz: tip HAM `PostgrestException`.
  // ------------------------------------------------------------------
  group('WP-702/2 analytics_query_providers kalici hatada carka donmez', () {
    final cases = <_Case>[
      (
        name: 'analyticsUserDayTotalsProvider',
        method: 'getUserDayTotals',
        error: _rawDenied,
        provider: analyticsUserDayTotalsProvider(_period),
      ),
      (
        name: 'analyticsUserSessionsInRangeProvider',
        method: 'getUserSessionsInRange',
        error: _jwtExpired,
        provider: analyticsUserSessionsInRangeProvider(_period),
      ),
      (
        name: 'analyticsGroupContributionProvider',
        method: 'getGroupContribution',
        error: _rawDenied,
        provider: analyticsGroupContributionProvider(_period),
      ),
      (
        name: 'analyticsGroupLeaderboardSeriesProvider',
        method: 'getGroupLeaderboardSeries',
        error: _rawDenied,
        provider: analyticsGroupLeaderboardSeriesProvider(_period),
      ),
      (
        name: 'groupAlphaScoresProvider',
        method: 'getGroupAlphaScores',
        error: _rawDenied,
        provider: groupAlphaScoresProvider,
      ),
    ];

    for (final c in cases) {
      testWidgets('${c.name}: depo 1 kez cagrilir, durum AsyncError', (
        tester,
      ) async {
        final repo = _FailingAnalyticsRepository(c.method, c.error);
        final container = await _container(tester, [
          analyticsQueryRepositoryProvider.overrideWithValue(repo),
          userGroupProvider.overrideWithValue(AsyncValue.data(_group)),
          userSessionsProvider.overrideWith(
            (ref) => Stream.value(const <StudySession>[]),
          ),
        ]);
        // Sicak pencere akisi da once oturtulur (durum gecisi = yeniden kurma).
        await _prime(
          container,
          userSessionsProvider,
          container.read(userSessionsProvider.future),
        );
        final states = _record(container, c.provider);

        await _elapseBeyondEveryRetry(tester);

        _expectPermanentSurfaced(
          name: c.name,
          callCount: repo.callsTo(c.method),
          states: states,
          finalState: container.read(c.provider),
        );
      });
    }
  });

  // ------------------------------------------------------------------
  // WP-702/3 — `admin_moderation_providers.dart` (moderasyon kuyrugu).
  // ------------------------------------------------------------------
  group('WP-702/3 admin_moderation_providers kalici hatada carka donmez', () {
    final cases = <_Case>[
      (
        name: 'moderationQueueProvider',
        method: 'fetchQueue',
        error: _queueDenied,
        provider: moderationQueueProvider,
      ),
      (
        name: 'moderationCaseDetailProvider',
        method: 'fetchDetail',
        error: _queueDenied,
        provider: moderationCaseDetailProvider('r1'),
      ),
      (
        name: 'moderationSanctionsProvider',
        method: 'fetchSanctions',
        error: _rawDenied,
        provider: moderationSanctionsProvider('u2'),
      ),
      (
        name: 'moderationAppealsProvider',
        method: 'fetchAppeals',
        error: _queueDenied,
        provider: moderationAppealsProvider,
      ),
    ];

    for (final c in cases) {
      testWidgets('${c.name}: depo 1 kez cagrilir, durum AsyncError', (
        tester,
      ) async {
        final repo = _FailingAdminModerationRepository(c.method, c.error);
        final container = await _container(tester, [
          adminModerationRepositoryProvider.overrideWithValue(repo),
        ]);
        final states = _record(container, c.provider);

        await _elapseBeyondEveryRetry(tester);

        _expectPermanentSurfaced(
          name: c.name,
          callCount: repo.callsTo(c.method),
          states: states,
          finalState: container.read(c.provider),
        );
      });
    }
  });

  // ------------------------------------------------------------------
  // WP-702/4 — `.future` bekleyen kod KILITLENMEZ.
  // ------------------------------------------------------------------
  group('WP-702/4 `.future` askida kalmaz', () {
    testWidgets('kalici hatada `.future` derhal firlatir', (tester) async {
      final repo = _FailingModerationRepository('fetchMySanctions', _modDenied);
      final container = await _container(tester, [
        moderationRepositoryProvider.overrideWithValue(repo),
      ]);
      _record(container, mySanctionsProvider);

      var settled = false;
      Object? thrown;
      unawaited(
        container
            .read(mySanctionsProvider.future)
            .then(
              (_) => settled = true,
              onError: (Object e) {
                thrown = e;
                settled = true;
              },
            ),
      );

      // SADECE mikro gorevler + bir kare: ilk yeniden deneme gecikmesinin
      // (200 ms) COK altinda. Retry zamanlayicisi kasten atesenmez.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(
        settled,
        isTrue,
        reason:
            '`element.dart:80` — `onLoading` completer\'i tamamlamaz; retry '
            'doneminde `.future` askida kalir ve onu bekleyen her cagri '
            '(ve bagli saglayici) 38 saniye kilitlenir',
      );
      expect(thrown, isNotNull);
    });
  });

  // ------------------------------------------------------------------
  // WP-702/5 — 🔴 KAPATMA SECILI: gecici hatada yeniden deneme DURUYOR.
  // Sabotajda (politika geri alinirsa) bu grup YESIL kalmali; kalmiyorsa
  // testin kalici/gecici ayrimi sahtedir.
  // ------------------------------------------------------------------
  group('WP-702/5 gecici hata hala yeniden denenir', () {
    testWidgets('ham SocketException: analytics depo tekrar cagrilir', (
      tester,
    ) async {
      final repo = _FailingAnalyticsRepository(
        'getUserDayTotals',
        _transientRaw,
      );
      final container = await _container(tester, [
        analyticsQueryRepositoryProvider.overrideWithValue(repo),
        userGroupProvider.overrideWithValue(AsyncValue.data(_group)),
        userSessionsProvider.overrideWith(
          (ref) => Stream.value(const <StudySession>[]),
        ),
      ]);
      await _prime(
        container,
        userSessionsProvider,
        container.read(userSessionsProvider.future),
      );
      final states = _record(
        container,
        analyticsUserDayTotalsProvider(_period),
      );

      await _elapseBeyondEveryRetry(tester);

      expect(
        repo.callsTo('getUserDayTotals'),
        greaterThan(1),
        reason:
            'gecici ag hatasi tekrar denemekle DUZELIR; toptan kapatma bu '
            'kazanci da silerdi',
      );
      expect(
        states.any((s) => s.isLoading && s.retrying),
        isTrue,
        reason: 'gecici hatada `retrying` beklenen davranistir',
      );
    });

    testWidgets('sarmalanmis ag hatasi: moderasyon depo tekrar cagrilir', (
      tester,
    ) async {
      final repo = _FailingModerationRepository(
        'fetchMySanctions',
        _transientWrapped,
      );
      final container = await _container(tester, [
        moderationRepositoryProvider.overrideWithValue(repo),
      ]);
      final states = _record(container, mySanctionsProvider);

      await _elapseBeyondEveryRetry(tester);

      expect(
        repo.callsTo('fetchMySanctions'),
        greaterThan(1),
        reason:
            'ayni tip hem kalici reddi hem gecici ag hatasini sarar; ayrim '
            'SAGLAYICI basina degil HATA basina yapilmali',
      );
      expect(states.any((s) => s.isLoading && s.retrying), isTrue);
    });
  });

  // ------------------------------------------------------------------
  // WP-702/6 — politikanin kendisi (saf birim).
  // ------------------------------------------------------------------
  group('WP-702/6 politika', () {
    test('kalici hatalar: null (yeniden deneme YOK)', () {
      expect(readRetryPolicy(0, _modDenied), isNull);
      expect(readRetryPolicy(0, _queueDenied), isNull);
      expect(readRetryPolicy(0, _rawDenied), isNull);
      expect(readRetryPolicy(0, _jwtExpired), isNull);
      expect(
        readRetryPolicy(0, const ModerationException('İtiraz metni çok kısa.')),
        isNull,
        reason: 'dogrulama hatasi tekrar denemekle duzelmez',
      );
      expect(
        readRetryPolicy(0, const AdminException('admin_required')),
        isNull,
        reason: 'WP-692 sozlesmesi ayni kaynakta korunur',
      );
    });

    test('gecici hatalar: yeniden denenir', () {
      expect(readRetryPolicy(0, _transientRaw), isNotNull);
      expect(readRetryPolicy(0, _transientWrapped), isNotNull);
      expect(
        readRetryPolicy(0, TimeoutException('after 0:00:10')),
        isNotNull,
        reason:
            'REST cagrilarina `TimeoutHttpClient` ust siniri kondu '
            '(`core/net/timeout_http_client.dart`); asilan istek bu tiple doner',
      );
      expect(
        readRetryPolicy(
          0,
          const ModerationException(
            'Beklenmeyen hata: Connection closed before full header was received',
          ),
        ),
        isNotNull,
      );
    });

    test('Riverpod\'un kendi sinirlari korunur', () {
      expect(
        readRetryPolicy(10, _transientRaw),
        isNull,
        reason: '`defaultRetry` 10 denemeden sonra durur; politika EZMEZ',
      );
      expect(
        readRetryPolicy(0, StateError('bug')),
        isNull,
        reason: '`Error` zaten hic denenmez (`provider_container.dart:948`)',
      );
    });
  });

  // ------------------------------------------------------------------
  // WP-702/7 — envanter kapisi: politikasiz yeni okuma saglayicisi eklenemez.
  // ------------------------------------------------------------------
  group('WP-702/7 envanter', () {
    const files = <String, int>{
      'lib/data/providers/moderation_providers.dart': 4,
      'lib/data/providers/analytics_query_providers.dart': 5,
      // WP-777: +1 = `adminUserInsightProvider` (politikasi var, ustteki
      // esitlik iddiasi onu dogruladi). Sayi TRIPWIRE'dir: yeni bir okuma
      // saglayicisi eklendiginde bilerek kirmizi dusup buraya bakilmasini
      // saglar.
      // WP-796: +1 = `adminCaseTimelineProvider`.
      'lib/data/providers/admin_moderation_providers.dart': 6,
    };

    for (final entry in files.entries) {
      test('${entry.key}: her FutureProvider politikayi tasir', () {
        final source = File(entry.key).readAsStringSync();
        // 🔴 Yalniz KOSAN satirlar olculur; aciklama satirlari sayimi sahte
        // yesile cekerdi.
        final code = source
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');

        final declared = RegExp(r'FutureProvider[<.]').allMatches(code).length;
        final guarded = RegExp(
          r'retry:\s*readRetryPolicy',
        ).allMatches(code).length;

        expect(
          guarded,
          declared,
          reason:
              '${entry.key}: politikasiz kalan saglayici kalici hatada yine '
              '38 saniye cark cevirir (bildirilen: $declared, korunan: $guarded)',
        );
        expect(declared, entry.value);
      });
    }
  });
}
