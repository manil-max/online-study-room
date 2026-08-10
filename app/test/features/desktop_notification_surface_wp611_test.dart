// WP-611 — masaüstünde sessizce patlayan bildirim yolları.
//
// Denetim bulgusu (KANAMA-1 / KANAMA-2):
//   1. `alarm_notification_service.dart` masaüstünde `_plugin.initialize`'ı
//      atlıyor ama `_initialized = true` yazıyordu; sonra aynı kurulmamış
//      eklentiye `zonedSchedule` / `cancel` / `show` çağrısı yapılıyordu.
//      Windows implementasyonu plugin registrant'ta kayıtlı olduğu için
//      `?.` kurtarmıyor: çağrı istisna atıyor, `alarm_providers.dart`
//      try/catch'siz olduğu için `invalidateSelf()` hiç koşmuyordu. Sonuç:
//      alarm diske yazılıyor, listede belirmiyor, hiç çalmıyordu.
//   2. `reminder_notification_service.dart` koşulsuz Android-only init
//      yapıyordu; Windows'ta FLN `ArgumentError` atıyor ve anahtarın
//      `onChanged`i tercih satırına HİÇ gelmiyordu.
//
// 🔴 İDDİA İKİ YÖNLÜ. Yalnız "masaüstünde patlamıyor" ölçmek yetmez; asıl
// risk Android kolunu sessizce kapatmaktır. Her servis iddiası bu yüzden
// çiftli: masaüstünde çağrı yüzeyine HİÇ dokunulmaz, Android'de eskisi gibi
// gerçek `flutter_local_notifications` yoluna girilir (test ortamında eklenti
// kurulu olmadığı için oradan `Error` düşer — gözlenebilir olan da budur).
//
// Platform gerçek işletim sisteminden değil `debugDefaultTargetPlatformOverride`
// ile enjekte edilir; kapı `defaultTargetPlatform` üzerinden okunur.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/notifications/alarm_notification_service.dart';
import 'package:online_study_room/core/notifications/notification_preferences.dart';
import 'package:online_study_room/core/notifications/reminder_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/time_engine/exact_alarm_permission.dart';
import 'package:online_study_room/data/models/alarm_rule.dart';
import 'package:online_study_room/data/models/timer_preset.dart';
import 'package:online_study_room/data/providers/alarm_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_alarm_repository.dart';
import 'package:online_study_room/features/clock/alarms_screen.dart';
import 'package:online_study_room/features/clock/timers_screen.dart';
import 'package:online_study_room/features/notifications/notification_center_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

const _alarm = AlarmRule(id: 'a-wp611', hour: 7, minute: 30, days: [1, 2, 3]);

final _timer = TimerInstance(
  id: 't-wp611',
  presetId: 'p1',
  label: 'WP-611',
  durationSeconds: 600,
  remainingSeconds: 600,
  status: TimerStateStatus.running,
  lastUpdatedAt: DateTime.fromMillisecondsSinceEpoch(1800000000000),
  endsAtEpochMs: 1800000600000,
);

/// FLN planlama yolunun **yürünüp yürünmediğini** ölçen sonda.
///
/// `AlarmNotificationService._mode()` yalnız FLN dalında çağrılır; masaüstü
/// kapısı bu satıra gelmeden dönmelidir.
class _ProbeExactPermission extends ExactAlarmPermission {
  int scheduleModeCalls = 0;

  @override
  Future<AndroidScheduleMode> scheduleMode() async {
    scheduleModeCalls++;
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }
}

class _MockAlarmService implements AlarmNotificationService {
  _MockAlarmService({this.throwOnSchedule = false});

  /// Planlamanın patladığı hâli taklit eder (masaüstündeki eski davranış).
  final bool throwOnSchedule;

  @override
  Future<ExactAlarmStatus> exactAlarmStatus() async => ExactAlarmStatus.granted;

  @override
  Future<void> rescheduleAll(
    List<AlarmRule> alarms, {
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    if (throwOnSchedule) throw StateError('plugin not initialized');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      invocation.isMethod ? Future<void>.value() : null;
}

/// Platformu enjekte eder ve **test gövdesi bitmeden** geri alır.
///
/// `testWidgets` gövde biter bitmez foundation debug değişkenlerinin
/// varsayılana döndüğünü doğrular; `tearDown` çok geç kalır. Ağaç ayrıca
/// sökülür: `TimerInstancesNotifier` periyodik ticker açar ve
/// `ref.onDispose` ancak ProviderScope sökülünce koşar.
Future<void> _withPlatform(
  WidgetTester tester,
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  }
}

Widget _app(Widget child, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  group('alarm servisi çağrı yüzeyi', () {
    test(
      'masaüstünde plan/iptal/göster istisna atmaz ve FLN yolunu yürümez',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        final probe = _ProbeExactPermission();
        final service = AlarmNotificationService(exactPermission: probe);

        // Düzeltme öncesi bu beş çağrının HEPSİ atıyordu (gerçek Windows'ta
        // StateError "must be initialized before use", testte LateError).
        await service.scheduleAlarm(_alarm);
        await service.cancelAlarm(_alarm.id);
        await service.scheduleTimer(_timer);
        await service.cancelTimer(_timer.id);
        await service.showImmediate('t', 'b');

        expect(
          probe.scheduleModeCalls,
          0,
          reason: 'masaüstünde FLN planlama dalına hiç girilmemeli',
        );
      },
    );

    test('Android kolu hâlâ gerçek eklenti yoluna giriyor', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final service = AlarmNotificationService(
        exactPermission: _ProbeExactPermission(),
      );

      // 🔴 Bu iddia düzeltmenin Android'i kapatmadığını ölçer: eklenti test
      // ortamında kurulu olmadığı için çağrı `Error` ile düşer. Sessizce
      // tamamlanırsa kapı Android'i de yutmuş demektir.
      await expectLater(service.scheduleAlarm(_alarm), throwsA(isA<Error>()));
      await expectLater(service.cancelAlarm(_alarm.id), throwsA(isA<Error>()));
      await expectLater(service.showImmediate('t', 'b'), throwsA(isA<Error>()));
    });
  });

  group('alarm listesi tazeleme', () {
    // 🔴 Denetimin ikinci yarısı: `saveAlarm` planlamayı `invalidateSelf()`ten
    // ÖNCE `await` ediyordu ve try/catch yoktu. Planlama patlayınca alarm
    // diske yazılmış olmasına rağmen listede belirmiyordu — kullanıcı kendi
    // işleminin kaydedildiğinden bile emin olamıyordu. İstisna hâlâ
    // yutulmuyor; ölçülen şey listenin yine de tazelenmesi.
    test('planlama patlasa bile kaydedilen alarm listeye düşer', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          alarmRepositoryProvider.overrideWithValue(InMemoryAlarmRepository()),
          alarmNotificationServiceProvider.overrideWithValue(
            _MockAlarmService(throwOnSchedule: true),
          ),
        ],
      );
      addTearDown(container.dispose);
      // Riverpod 3: dinleyicisiz provider her read'de yeniden build olur ve
      // "tazelendi mi" iddiasını sessizce etkisizleştirir.
      container.listen(alarmsProvider, (_, _) {});
      await container.read(alarmsProvider.future);

      await expectLater(
        container.read(alarmsProvider.notifier).saveAlarm(_alarm),
        throwsA(isA<StateError>()),
      );

      final list = await container.read(alarmsProvider.future);
      expect(list.map((a) => a.id), contains(_alarm.id));
    });
  });

  group('hatırlatıcı servisi', () {
    const prefs = NotificationPreferences(
      nudgeNotificationsEnabled: true,
      announcementsEnabled: true,
      updatesEnabled: true,
      quietHoursEnabled: false,
      quietStartMinutes: 0,
      quietEndMinutes: 0,
      smartStreakReminderEnabled: true,
      smartWeeklySummaryEnabled: true,
    );

    test(
      'masaüstünde izin çağrısı atmaz ve "verildi" yalanı söylemez',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.windows;
        final service = ReminderNotificationService.forTest(
          FlutterLocalNotificationsPlugin(),
        );

        expect(service.isSupported, isFalse);
        // Düzeltme öncesi: ArgumentError("Windows settings must be set...").
        expect(await service.requestPermissionIfNeeded(), isFalse);
        await service.syncSmartReminders(prefs);
      },
    );

    test('Android kolu hâlâ gerçek eklenti yoluna giriyor', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final service = ReminderNotificationService.forTest(
        FlutterLocalNotificationsPlugin(),
      );

      expect(service.isSupported, isTrue);
      await expectLater(
        service.requestPermissionIfNeeded(),
        throwsA(isA<Error>()),
      );
    });
  });

  group('Bildirim Merkezi yüzeyi', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        _app(const NotificationCenterScreen(), [
          sharedPreferencesProvider.overrideWithValue(prefs),
        ]),
      );
      await tester.pump();
    }

    testWidgets(
      'masaüstünde akıllı hatırlatıcı satırları devre dışı ve gerekçeli',
      (tester) async {
        await _withPlatform(tester, TargetPlatform.windows, () async {
          await pump(tester);

          const streakKey = Key('notification_smart_streak_switch');
          const weeklyKey = Key('notification_smart_weekly_switch');
          final l10n = AppLocalizations.of(
            tester.element(find.byKey(streakKey)),
          );

          // 🔴 Sessiz yutma yasağı: anahtar açılıp hiçbir şey olmaması yerine
          // satır devre dışı ve nedeni yazılı.
          expect(
            tester.widget<SwitchListTile>(find.byKey(streakKey)).onChanged,
            isNull,
          );
          expect(
            tester.widget<SwitchListTile>(find.byKey(weeklyKey)).onChanged,
            isNull,
          );
          // 🔴 WP-685: 2 -> 4. Sayi bir esik degil ENVANTER: masaustunde
          // kapatilan HER satirin gerekcesi yazili olmali. WP-611 iki
          // hatirlaticiyi kapatmisti; WP-685 durtme ve guncelleme
          // anahtarlarinin da masaustunde teslim edilemedigini olctu ve
          // ayni gerekceye bagladi. Testin niyeti degismedi, kapsami buyudu.
          expect(
            find.text(l10n.notificationsHatirlaticiMasaustundeYok),
            findsNWidgets(4),
          );

          // "Bozuk düğme" yerine gerekçe: izin düğmesi yok, açıklama var.
          final note = tester.widget<Text>(
            find.byKey(const Key('notification_permission_note')),
          );
          expect(note.data, l10n.notificationsIzinMasaustundeGecersiz);
          expect(
            find.text(l10n.notificationsBildirimIzniniKontrolEt),
            findsNothing,
          );

          // Devre dışı satıra dokunmak tercihi yazmaz.
          await tester.tap(find.byKey(streakKey));
          await tester.pump();
          expect(prefs.getBool('notification_smart_streak_enabled'), isNull);
        });
      },
    );

    testWidgets('Android kolunda satırlar açık kalır', (tester) async {
      await _withPlatform(tester, TargetPlatform.android, () async {
        await pump(tester);

        const streakKey = Key('notification_smart_streak_switch');
        final l10n = AppLocalizations.of(tester.element(find.byKey(streakKey)));

        expect(
          tester.widget<SwitchListTile>(find.byKey(streakKey)).onChanged,
          isNotNull,
        );
        expect(
          tester
              .widget<SwitchListTile>(
                find.byKey(const Key('notification_smart_weekly_switch')),
              )
              .onChanged,
          isNotNull,
        );
        expect(find.text(l10n.smartStreakReminderBody), findsOneWidget);
        expect(
          find.text(l10n.notificationsHatirlaticiMasaustundeYok),
          findsNothing,
        );
        final note = tester.widget<Text>(
          find.byKey(const Key('notification_permission_note')),
        );
        expect(note.data, l10n.notificationsBildirimlerCihazIznineBaglidir);
        expect(
          find.text(l10n.notificationsBildirimIzniniKontrolEt),
          findsOneWidget,
        );
      });
    });
  });

  group('Saat sekmesi', () {
    late SharedPreferences prefs;
    late InMemoryAlarmRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      repo = InMemoryAlarmRepository();
    });

    List<Override> overrides() => [
      sharedPreferencesProvider.overrideWithValue(prefs),
      alarmRepositoryProvider.overrideWithValue(repo),
      alarmNotificationServiceProvider.overrideWithValue(_MockAlarmService()),
    ];

    testWidgets('alarm sekmesi masaüstünde çalmadığını söyler', (tester) async {
      await _withPlatform(tester, TargetPlatform.windows, () async {
        await tester.pumpWidget(
          _app(const AlarmsScreen(embedded: true), overrides()),
        );
        await tester.pump();

        const bannerKey = Key('alarms_desktop_limit_banner');
        expect(find.byKey(bannerKey), findsOneWidget);
        final l10n = AppLocalizations.of(tester.element(find.byKey(bannerKey)));
        expect(find.text(l10n.clockAlarmMasaustundeCalmaz), findsOneWidget);
      });
    });

    testWidgets('Android alarm sekmesinde şerit yok', (tester) async {
      await _withPlatform(tester, TargetPlatform.android, () async {
        await tester.pumpWidget(
          _app(const AlarmsScreen(embedded: true), overrides()),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('alarms_desktop_limit_banner')),
          findsNothing,
        );
      });
    });

    testWidgets('sayaç sekmesi masaüstünde bildirim vermediğini söyler', (
      tester,
    ) async {
      await _withPlatform(tester, TargetPlatform.windows, () async {
        await tester.pumpWidget(
          // Gömülü kol kendi Scaffold'unu kurmaz (kabuk ClockScreen'dedir);
          // ActionChip bir Material atası ister.
          _app(const Scaffold(body: TimersScreen(embedded: true)), overrides()),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('timers_desktop_limit_banner')),
          findsOneWidget,
        );
      });
    });

    testWidgets('Android sayaç sekmesinde şerit yok', (tester) async {
      await _withPlatform(tester, TargetPlatform.android, () async {
        await tester.pumpWidget(
          _app(const Scaffold(body: TimersScreen(embedded: true)), overrides()),
        );
        await tester.pump();

        expect(
          find.byKey(const Key('timers_desktop_limit_banner')),
          findsNothing,
        );
      });
    });
  });
}
