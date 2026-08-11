// WP-707 · istatistik widget'indaki SERI satiri.
//
// OLCULEN kusur (bu dosya yazildiginda kirmizidi): `stats_streak` anahtarini
// `lib/` icinde HICBIR yer yazmiyordu.
//   * `_syncStatsWidgets` yalniz `AndroidWidgetSnapshot.goals` +
//     `.leaderboard` yaziyor; `goalsGroup` kumesi `statsStreak`i disarida
//     birakiyor.
//   * `AndroidWidgetSnapshot.stats(...)` kurucusunun `lib/` icinde tek bir
//     cagri yeri yoktu (olu kod).
// Sonuc: satir yalniz TALL boyutta acilir (`statsStreakVisible`) ve orada HER
// ZAMAN native `widget_streak_zero` yedegini ("Hedef serisi: 0 gun") cizerdi.
// Serisi 40 gun olan kullanici widget'i buyutunce SIFIR gorurdu.
//
// Depodaki tekrarlayan kusurun ayni sinifi: *bitmis backend + baglanmamis UI*.
//
// 🔴 Olcum kaynak taramasi DEGILDIR. Gercek `StudyTimerNotifier` kurulur,
// gercek `_syncStatsWidgets` turu kosar ve gateway'e DUSEN anlik goruntuler
// birlestirilir — yani widget prefs dosyasinin tur sonundaki hali okunur.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/l10n/system_localizations.dart';
import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/goal_streak.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/goal_streak_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/goal_streak_repository.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Gateway sahtesi: tur sonunda prefs dosyasinda ne kalir?
///
/// `saveSnapshot` her anahtari ayri ayri yazar ve ayni anahtara ikinci yazim
/// birinciyi ezer — `Map.addAll` bunun birebir esidir (WP-696 deseni).
class _WidgetSpy implements AndroidWidgetGateway {
  final Map<String, Object> prefs = <String, Object>{};
  final List<AndroidWidgetSnapshot> snapshots = <AndroidWidgetSnapshot>[];
  final List<String> refreshed = <String>[];

  @override
  Future<void> saveSnapshot(AndroidWidgetSnapshot snapshot) async {
    snapshots.add(snapshot);
    prefs.addAll(snapshot.toWidgetData());
  }

  @override
  Future<void> refresh({Iterable<StudyHomeWidget>? widgets}) async {
    refreshed.addAll(
      (widgets ?? StudyHomeWidget.values).map((widget) => widget.androidName),
    );
  }

  @override
  Future<void> seedPlaceholder() async {}
}

class _NoopTimerNotifications implements TimerNotificationGateway {
  const _NoopTimerNotifications();

  @override
  Stream<TimerNotificationAction> get commands => const Stream.empty();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> requestPermissionIfNeeded() async {}
}

/// Sunucudaki kanonik seri projeksiyonunun sahtesi.
///
/// Ekrandaki `GoalStreakBadge` de ayni kaynagi okur; widget baska bir motordan
/// (`currentStreak()`) beslenirse iki yuzey sessizce ayrisir — WP-481'in
/// kapattigi kusur budur.
class _FakeGoalStreakRepository implements GoalStreakRepository {
  _FakeGoalStreakRepository(this.days);

  final int days;
  int readCalls = 0;

  GoalStreakProjection _projection(GoalStreakScope scope) =>
      GoalStreakProjection(
        scope: scope,
        asOfDay: DateTime.utc(2026, 8, 11),
        currentStreak: days,
        completionCount: days,
        lastCompletedDay: DateTime.utc(2026, 8, 11),
        state: GoalStreakState.completedToday,
        sourceVersion: 'test',
      );

  @override
  Future<GoalStreakProjection> readProjection(
    GoalStreakScope scope, {
    DateTime? asOfDay,
  }) async {
    readCalls++;
    return _projection(scope);
  }

  @override
  Stream<GoalStreakProjection> watchProjection(
    GoalStreakScope scope, {
    DateTime? asOfDay,
  }) => Stream.value(_projection(scope));
}

const _userId = 'u-707';

Profile _profile() => Profile(
  id: _userId,
  displayName: 'Seri Sahibi',
  createdAt: DateTime.utc(2026),
  dailyGoalMinutes: 60,
);

/// Bugun hedefi tutturan tek bir oturum: gunluk hedef yuzdesi de gercek cikar.
List<StudySession> _sessions() {
  final end = DateTime.now();
  return [
    StudySession(
      id: 's-1',
      userId: _userId,
      start: end.subtract(const Duration(minutes: 45)),
      end: end,
      durationSeconds: 45 * 60,
      source: StudySource.live,
    ),
  ];
}

Future<void> _waitUntil(bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 6));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  // studyTimerProvider.build() bir AppLifecycleListener kurar → binding sart.
  TestWidgetsFlutterBinding.ensureInitialized();

  // 🔴 Beklenen dize `loadSystemLocalizations()` ile uretilir — boru hattinin
  // KENDI kullandigi cozunurluk. Testi sabit `tr` ile kurmak, kosum hostunun
  // dili farkli oldugunda gercek kusuru degil dil farkini olcerdi.
  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await loadSystemLocalizations();
  });

  setUp(() {
    // `_syncStatsWidgets` Android disinda ILK SATIRDA doner; platform
    // enjekte edilmezse bu dosyanin tamami bedavaya yesil gecerdi.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  /// Gercek sayac notifier'ini kurar ve bir `_syncStatsWidgets` turu bekler.
  ///
  /// Tetikleyici uydurma degil: notifier `userSessionsProvider`i dinler ve
  /// 250 ms'lik debounce ile turu baslatir (`study_providers.dart:889`).
  Future<_WidgetSpy> runOneStatsSync({int streakDays = 7}) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final spy = _WidgetSpy();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith((ref) => Stream.value(_profile())),
        userSessionsProvider.overrideWith((ref) => Stream.value(_sessions())),
        groupDailyStatsProvider.overrideWith(
          (ref) => Stream.value(const <DailyStat>[]),
        ),
        groupMembersProvider.overrideWith(
          (ref) => Stream.value(<Profile>[_profile()]),
        ),
        timerNotificationServiceProvider.overrideWithValue(
          const _NoopTimerNotifications(),
        ),
        androidWidgetServiceProvider.overrideWithValue(spy),
        goalStreakRepositoryProvider.overrideWithValue(
          _FakeGoalStreakRepository(streakDays),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Riverpod 3: dinleyicisiz provider her read'de yeniden kurulur; notifier
    // await'ler arasinda hayatta kalmali.
    container.listen(studyTimerProvider, (_, _) {});
    // Turun BITISINI bekle, ortasini degil: `refresh(_kStatsWidgets)` cagrisi
    // `_syncStatsWidgets`in son satiridir. `dailyGoalPercent`i beklemek turun
    // ortasinda uyanir ve seri yaziminin yarisinda olcum yapardi.
    await _waitUntil(
      () => spy.refreshed.contains(StudyHomeWidget.stats.androidName),
    );
    return spy;
  }

  group('WP-707 · seri satiri gercek veriye bagli mi', () {
    test('kanonik seri 7 gun iken widget 7 YAZAR (sifir degil)', () async {
      final spy = await runOneStatsSync(streakDays: 7);

      expect(
        spy.snapshots,
        isNotEmpty,
        reason: 'test bos kosmasin: bir istatistik turu gerceklesmeli',
      );
      final written = spy.prefs[AndroidWidgetKeys.statsStreak];

      expect(
        written,
        isNotNull,
        reason:
            'stats_streak hicbir snapshot tarafindan yazilmiyor; sirasi gelince '
            'StudyStatsWidgetProvider native `widget_streak_zero` yedegini '
            'cizer ve kullanici serisi ne olursa olsun SIFIR gorur',
      );
      expect(
        written,
        '${l10n.coreGunlukHedefSerisi}: ${l10n.statsStreakGun('7')}',
      );
      expect(
        written,
        isNot(l10n.androidWidgetsHedefSerisi0Gun),
        reason: 'yedek/placeholder dizesi gercek veri yerine gecemez',
      );
    });

    test('seri 0 iken de GERCEK 0 yazilir (satir sessiz kalmaz)', () async {
      final spy = await runOneStatsSync(streakDays: 0);

      expect(
        spy.prefs[AndroidWidgetKeys.statsStreak],
        '${l10n.coreGunlukHedefSerisi}: ${l10n.statsStreakGun('0')}',
        reason:
            'gercek sifir da yazilmali: aksi halde dunku 7 ekranda asili kalir',
      );
    });

    test(
      'seri satiri gunluk hedef satirlarini EZMEZ (WP-696 nobeti)',
      () async {
        final spy = await runOneStatsSync(streakDays: 7);

        // Seri anlik goruntusu 17 anahtarin hepsini yazsaydi, `goals` turunun
        // gercek yuzdesini placeholder ile ezerdi.
        expect(spy.prefs[AndroidWidgetKeys.dailyGoalPercent], isNot('0%'));
        expect(
          spy.prefs[AndroidWidgetKeys.dailyGoalDetail],
          isNot('${l10n.clockMDk('0')} / ${l10n.clockMDk('0')}'),
        );
      },
    );

    test('seri anlik goruntusu YALNIZ kendi anahtarini tasir', () {
      final snapshot = AndroidWidgetSnapshot.streak(
        l10n: l10n,
        streak: 'Seri: 7 gun',
      );

      expect(snapshot.toWidgetData(), {
        AndroidWidgetKeys.statsStreak: 'Seri: 7 gun',
      });
    });
  });

  group('WP-707 · seri KAYNAGI kanonik projeksiyon', () {
    test('widget serisi sunucu projeksiyonundan okunur', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final spy = _WidgetSpy();
      final repository = _FakeGoalStreakRepository(3);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith((ref) => Stream.value(_profile())),
          userSessionsProvider.overrideWith((ref) => Stream.value(_sessions())),
          groupDailyStatsProvider.overrideWith(
            (ref) => Stream.value(const <DailyStat>[]),
          ),
          groupMembersProvider.overrideWith(
            (ref) => Stream.value(<Profile>[_profile()]),
          ),
          timerNotificationServiceProvider.overrideWithValue(
            const _NoopTimerNotifications(),
          ),
          androidWidgetServiceProvider.overrideWithValue(spy),
          goalStreakRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);
      container.listen(studyTimerProvider, (_, _) {});
      await _waitUntil(
        () => spy.refreshed.contains(StudyHomeWidget.stats.androidName),
      );

      expect(
        repository.readCalls,
        greaterThan(0),
        reason:
            'widget serisi `currentStreak()` gibi ikinci bir istemci motorundan '
            'besleniyorsa ekrandaki rozetle sessizce ayrisir (WP-481)',
      );
    });
  });
}
