// WP-707 · yayina alinan dort widget GERCEKTEN veri ciziyor mu?
//
// 🔴 Olcunun neden bu kadar dolayli oldugu: WP-696'da iki widget yayina
// alinsaydi kullanici SONSUZA KADAR %0 gorecekti ve kapi yesildi. "Snapshot
// yaziliyor" ile "widget o degeri ciziyor" ayni sey degil. Bu dosya ikisinin
// arasindaki her halkayi olcer:
//
//   1. Gercek `StudyTimerNotifier` bir `_syncStatsWidgets` turu kosar.
//   2. Gercek `AndroidWidgetService` kullanilir; `home_widget` PLATFORM
//      KANALI kesilir ve karsiya gecen `saveWidgetData` cagrilari toplanir.
//      (WP-558 kapisi burada: yayinda `widgetData` okuyan saglayici yoksa
//      servis tek anahtar bile yazmaz. Dort widget yayina alinmadan once bu
//      kapi KAPALIYDI — manifest acilsa bile widget'lar bos kalirdi.)
//   3. Her saglayicinin Kotlin `onUpdate` govdesinden OKUDUGU anahtar listesi
//      cikarilir (elle sayilmaz; sayim bayatlar).
//   4. Kotlin'in okudugu her anahtarin kanalda bir degeri olmali VE bu deger
//      `AndroidWidgetSnapshot.placeholder` degerinden FARKLI olmali.
//
// (4) olmadan test "anahtar yazildi" der ve WP-696'nin kalici %0'ini yine
// kacirirdi.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/l10n/system_localizations.dart';
import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/stats/istanbul_calendar.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/goal_streak.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/goal_streak_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/goal_streak_repository.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/features/android_widgets/published_home_widgets.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const String _kotlinDir =
    'android/app/src/main/kotlin/com/manilmax/online_study_room/widgets';

/// WP-752: alti saglayici alti ayri dosyada; anahtar TABLOSU paylasilan
/// zeminde. Tek dosya okuyan eski hali bolme sonrasi sessizce bos donerdi.
const List<String> _providerFiles = <String>[
  'TimerWidget.kt',
  'StatsWidget.kt',
  'LeaderboardWidget.kt',
  'GroupGoalWidget.kt',
  'ClockWidget.kt',
  'AlarmWidget.kt',
];

/// `const val Ad = "deger"` tablosu (yorum satirlari elenir — WP-640 tuzagi).
Map<String, String> _kotlinKeyTable() {
  final file = File('$_kotlinDir/WidgetCommon.kt');
  expect(file.existsSync(), isTrue, reason: '${file.path} yok');
  final pattern = RegExp(r'^\s*const val (\w+) = "([^"]+)"');
  final table = <String, String>{};
  for (final line in file.readAsLinesSync()) {
    if (line.trimLeft().startsWith('//')) continue;
    final match = pattern.firstMatch(line);
    if (match != null) table[match.group(1)!] = match.group(2)!;
  }
  expect(table, isNotEmpty, reason: 'regex hicbir sey yakalamadi');
  return table;
}

/// Bir saglayici sinifinin govdesi (bir sonraki ust duzey `class`a kadar).
/// Sinif hangi dosyada olursa olsun bulunur.
String _kotlinClassBody(String className) {
  for (final name in _providerFiles) {
    final file = File('$_kotlinDir/$name');
    expect(file.existsSync(), isTrue, reason: '${file.path} yok');
    final source = file.readAsStringSync().replaceAll('\r\n', '\n');
    final start = source.indexOf('class $className ');
    if (start < 0) continue;
    final next = source.indexOf('\nclass ', start + 1);
    return next == -1 ? source.substring(start) : source.substring(start, next);
  }
  fail('$className hicbir saglayici dosyasinda yok');
}

/// Saglayicinin `widgetData`dan GERCEKTEN okudugu anahtarlar.
Set<String> _keysReadBy(String className) {
  final table = _kotlinKeyTable();
  final body = _kotlinClassBody(className);
  return {
    for (final match in RegExp(r'StudyWidgetKeys\.(\w+)').allMatches(body))
      if (table.containsKey(match.group(1))) table[match.group(1)]!,
  };
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

class _FakeGoalStreakRepository implements GoalStreakRepository {
  _FakeGoalStreakRepository(this.days);

  final int days;

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
  }) async => _projection(scope);

  @override
  Stream<GoalStreakProjection> watchProjection(
    GoalStreakScope scope, {
    DateTime? asOfDay,
  }) => Stream.value(_projection(scope));
}

/// Gercek `home_widget` platform kanalinin kesicisi.
class _ChannelSpy {
  static const MethodChannel _channel = MethodChannel('home_widget');

  final Map<String, Object?> saved = <String, Object?>{};
  final List<String> updated = <String>[];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          final args = call.arguments as Map<Object?, Object?>;
          switch (call.method) {
            case 'saveWidgetData':
              saved[args['id']! as String] = args['data'];
            case 'updateWidget':
              updated.add(args['android'] as String? ?? '?');
          }
          return true;
        });
  }

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}

const _userId = 'u-707';
const _mateId = 'u-mate';
const _thirdId = 'u-third';

Profile _profile(String id, String name) => Profile(
  id: id,
  displayName: name,
  createdAt: DateTime.utc(2026),
  dailyGoalMinutes: 60,
);

StudyGroup _group() => StudyGroup(
  id: 'g-707',
  name: 'Odak Kampi',
  inviteCode: 'WP707',
  createdBy: _userId,
  createdAt: DateTime.utc(2026),
  dailyGoalMinutes: 600,
);

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

List<DailyStat> _groupStats() {
  final today = calendarDay(istanbulNow());
  return [
    DailyStat(userId: _userId, day: today, seconds: 45 * 60),
    DailyStat(userId: _mateId, day: today, seconds: 90 * 60),
    DailyStat(userId: _thirdId, day: today, seconds: 20 * 60),
  ];
}

Future<void> _waitUntil(bool Function() ready) async {
  final deadline = DateTime.now().add(const Duration(seconds: 6));
  while (!ready() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;
  late _ChannelSpy channel;

  setUpAll(() async {
    l10n = await loadSystemLocalizations();
  });

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    channel = _ChannelSpy()..install();
  });
  tearDown(() {
    channel.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  /// Gercek servis + gercek notifier ile tek istatistik turu.
  Future<void> runOneStatsSync() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith(
          (ref) => Stream.value(_profile(_userId, 'Ben')),
        ),
        userSessionsProvider.overrideWith((ref) => Stream.value(_sessions())),
        userGroupProvider.overrideWithValue(AsyncValue.data(_group())),
        groupDailyStatsProvider.overrideWith(
          (ref) => Stream.value(_groupStats()),
        ),
        groupMembersProvider.overrideWith(
          (ref) => Stream.value(<Profile>[
            _profile(_userId, 'Ben'),
            _profile(_mateId, 'Ayse'),
            _profile(_thirdId, 'Zeynep'),
          ]),
        ),
        timerNotificationServiceProvider.overrideWithValue(
          const _NoopTimerNotifications(),
        ),
        goalStreakRepositoryProvider.overrideWithValue(
          _FakeGoalStreakRepository(5),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(studyTimerProvider, (_, _) {});
    await _waitUntil(
      () => channel.updated.contains(StudyHomeWidget.stats.androidName),
    );
  }

  group('WP-707 · veri boru hatti yayin bayragiyla ACILDI', () {
    test('yayinda widgetData okuyan bir tuketici var (WP-558 kapisi acik)', () {
      // Bu bayrak `false` iken `AndroidWidgetService.saveSnapshot` ILK
      // SATIRDA doner: manifest acilsa bile uc istatistik widgeti sonsuza
      // kadar native yedek metinleri cizerdi.
      expect(StudyHomeWidget.anyPublishedConsumesWidgetData, isTrue);
    });

    test('yayindaki her saglayicinin tazeleme yolu var', () {
      final orphans = publishedHomeWidgets
          .where((provider) => !hasHomeWidgetRefreshPath(provider))
          .toList();
      expect(
        orphans,
        isEmpty,
        reason: '$orphans bir kez cizilir, bir daha asla',
      );
    });
  });

  group('WP-707 · Kotlin`in okudugu her anahtarda GERCEK deger var', () {
    /// Kotlin govdesinden turetilen anahtar listesi + placeholder kiyasi.
    Future<void> expectRealData(String className) async {
      final keys = _keysReadBy(className);
      expect(keys, isNotEmpty, reason: '$className hicbir anahtar okumuyor?');
      final placeholder = AndroidWidgetSnapshot.placeholder(
        l10n,
      ).toWidgetData();

      for (final key in keys) {
        expect(
          channel.saved.containsKey(key),
          isTrue,
          reason:
              '$className `$key` okuyor ama boru hatti onu HIC yazmiyor; '
              'saglayici native yedek dizesini cizer (WP-707 seri satirinin '
              'kusuru buydu)',
        );
        expect(
          channel.saved[key],
          isNot(placeholder[key]),
          reason:
              '$className `$key` icin hala placeholder degeri goruyor: '
              'kullanici widget\'i eklediginde gercek verisini degil '
              'sifir/bos hali gorur',
        );
      }
    }

    test('StudyStatsWidgetProvider (gunluk hedef + seri)', () async {
      await runOneStatsSync();
      await expectRealData('StudyStatsWidgetProvider');

      // Somut deger: 45 dk / 60 dk hedef -> %75, seri 5 gun.
      expect(channel.saved[AndroidWidgetKeys.dailyGoalPercent], '75%');
      expect(
        channel.saved[AndroidWidgetKeys.statsStreak],
        '${l10n.coreGunlukHedefSerisi}: ${l10n.statsStreakGun('5')}',
      );
    });

    test('GroupGoalWidgetProvider (grup hedefi)', () async {
      await runOneStatsSync();
      await expectRealData('GroupGoalWidgetProvider');

      // 45 + 90 + 20 = 155 dk, grup hedefi 600 dk -> %25.
      expect(channel.saved[AndroidWidgetKeys.groupGoalPercent], '25%');
    });

    test('GroupLeaderboardWidgetProvider (kamp siralamasi)', () async {
      await runOneStatsSync();
      await expectRealData('GroupLeaderboardWidgetProvider');

      // Siralama gercek isimlerle ve buyukten kucuge.
      expect(
        channel.saved[AndroidWidgetKeys.leaderboardRow1],
        startsWith('Ayse'),
      );
      expect(
        channel.saved[AndroidWidgetKeys.leaderboardRow2],
        startsWith('Ben'),
      );
      expect(
        channel.saved[AndroidWidgetKeys.leaderboardRow3],
        startsWith('Zeynep'),
      );
      // Kisa boyutta cizilen tek satir KULLANICININ sirasidir.
      expect(channel.saved[AndroidWidgetKeys.leaderboardMyRank], '#2');
    });

    test('yayindaki uc saglayiciya yeniden cizim yayini GIDER', () async {
      await runOneStatsSync();

      for (final widget in const [
        StudyHomeWidget.stats,
        StudyHomeWidget.groupGoal,
        StudyHomeWidget.leaderboard,
      ]) {
        expect(
          channel.updated,
          contains(widget.androidName),
          reason:
              '${widget.androidName} veri aldi ama yeniden cizim yayini '
              'almadi: ekranda eski kare kalir',
        );
      }
    });
  });

  group('WP-707 · ClockWidgetProvider veriyi Flutter\'dan ALMAZ', () {
    test('hicbir widgetData anahtari okumaz', () {
      expect(
        _keysReadBy('ClockWidgetProvider'),
        isEmpty,
        reason:
            'saat bir anahtar okumaya baslamis: artik Flutter yayini gerekir, '
            'kSelfUpdatingHomeWidgets uyeligi bayatladi',
      );
    });

    test('canli saat native `TextClock` ile akar', () {
      final layout = File(
        'android/app/src/main/res/layout/odak_clock_widget.xml',
      ).readAsStringSync();
      expect(
        layout.contains('TextClock'),
        isTrue,
        reason:
            'TextClock yoksa saat yalniz `onUpdate` aninda cizilir ve '
            'dakikada bir donmez — kullanici duran bir saat gorur',
      );
    });

    test('tazeleme yolu kendi kendine akan kumeden gelir', () {
      expect(kSelfUpdatingHomeWidgets, contains(HomeWidgetProvider.clock));
      expect(
        StudyHomeWidget.values.any(
          (widget) => widget.catalogProvider == HomeWidgetProvider.clock,
        ),
        isFalse,
        reason: 'saate Flutter yayini gonderilmesine gerek yok',
      );
    });
  });
}
