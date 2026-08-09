import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/device_integrations/samsung_modes_service.dart';
import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/core/observability/timer_diagnostic_journal.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/device_integration_listener.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';

/// WP-599: "sayacı gerçekten kardeşim mi başlattı?"
///
/// 🔴 Ölçülen açık (`docs/analiz/WP-595-sayac-xp-teshis.md`): cihaz
/// entegrasyonu (Samsung Modes & Routines / ana ekran kısayolu) `start()`'ı
/// doğrudan çağırıyordu ve günlüğe kullanıcının parmağıyla **birebir aynı**
/// satır düşüyordu: `start_requested / user_action / app`. Yani gece 03:00'te
/// bir rutinin açtığı sayaç, kullanıcının açtığı sayaçtan ayırt edilemezdi.
///
/// İddialar **iki yönlüdür**: düğme "kullanıcı" damgası taşımalı, cihaz
/// aksiyonu taşımaMAlı. Tek yönlü ölçüm "her şeye aynı damgayı bas" hâlini
/// yeşil geçirirdi — bugünkü hata zaten tam olarak budur.
///
/// Hiçbir iddia duvar saatine bakmaz; sayacın saati enjekte edilir
/// ([studyTimerClockProvider]).
class _FakeClock {
  _FakeClock(this.now);

  DateTime now;

  DateTime call() => now;
}

class _NoopTimerNotificationService implements TimerNotificationGateway {
  const _NoopTimerNotificationService();

  @override
  Stream<TimerNotificationAction> get commands => const Stream.empty();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> requestPermissionIfNeeded() async {}
}

class _NoopAndroidWidgetService implements AndroidWidgetGateway {
  const _NoopAndroidWidgetService();

  @override
  Future<void> refresh({Iterable<StudyHomeWidget>? widgets}) async {}

  @override
  Future<void> saveSnapshot(AndroidWidgetSnapshot snapshot) async {}

  @override
  Future<void> seedPlaceholder() async {}
}

/// Gerçek servis MethodChannel kurar; `enabled: false` ile kanal hiç açılmaz.
class _FakeDeviceIntegrationService extends DeviceIntegrationService {
  _FakeDeviceIntegrationService({this.initialAction}) : super(enabled: false);

  /// Soğuk başlangıçta `getInitialAction()`'ın döndüreceği intent.
  final String? initialAction;

  @override
  Future<String?> getInitialAction() async => initialAction;
}

const _startTimer = 'com.manilmax.online_study_room.START_TIMER';
const _stopTimer = 'com.manilmax.online_study_room.STOP_TIMER';
const _startPomodoro = 'com.manilmax.online_study_room.START_POMODORO';
const _takeBreak = 'com.manilmax.online_study_room.TAKE_BREAK';

Future<void> _settle() async {
  // Günlük yazımı `unawaited(record())` ile arka planda gider.
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

Future<(ProviderContainer, _FakeDeviceIntegrationService)> _container({
  String? initialAction,
}) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final device = _FakeDeviceIntegrationService(initialAction: initialAction);
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      studyTimerClockProvider.overrideWithValue(
        _FakeClock(DateTime.utc(2026, 8, 8, 19, 0)).call,
      ),
      timerNotificationServiceProvider.overrideWithValue(
        const _NoopTimerNotificationService(),
      ),
      androidWidgetServiceProvider.overrideWithValue(
        const _NoopAndroidWidgetService(),
      ),
      deviceIntegrationServiceProvider.overrideWithValue(device),
    ],
  );
  addTearDown(container.dispose);
  // Riverpod 3: dinleyicisiz provider her read'de yeniden kurulur; notifier
  // örneği await'ler arasında hayatta kalmalı.
  container.listen(studyTimerProvider, (_, _) {});
  return (container, device);
}

TimerJournalEntry _single(ProviderContainer container, String event) {
  final rows = container
      .read(timerDiagnosticJournalProvider)
      .entries()
      .where((entry) => entry.event == event)
      .toList();
  expect(rows, hasLength(1), reason: '$event satiri tam olarak bir kez olmali');
  return rows.single;
}

void main() {
  // studyTimerProvider.build() bir AppLifecycleListener kurar → binding şart.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Cihaz entegrasyonu dinleyicisi yalnız Android'de kurulur.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('gunluk baslatmanin kaynagini soyler', () {
    test('EKRAN DUGMESI: kullanici damgasi TASIR', () async {
      final (container, _) = await _container();
      container.read(studyTimerProvider.notifier).start();
      await _settle();

      final row = _single(container, TimerJournalEvents.startRequested);
      expect(row.trigger, TimerJournalTriggers.userButton);
      expect(row.reason, TimerJournalReasons.userAction);
      expect(TimerJournalTriggers.isUserButton(row.trigger), isTrue);
    });

    test('CIHAZ AKSIYONU (uygulama acikken): kullanici damgasi TASIMAZ', () async {
      final (container, device) = await _container();
      container.read(deviceIntegrationListenerProvider);
      await _settle();

      device.onActionReceived!(_startTimer);
      await _settle();

      final row = _single(container, TimerJournalEvents.startRequested);
      expect(
        TimerJournalTriggers.isUserButton(row.trigger),
        isFalse,
        reason:
            'ASIL ACIK: Samsung Routine baslatmasi parmakla ayni satiri yaziyordu',
      );
      expect(row.trigger, 'device_start_timer_warm');
      expect(row.reason, TimerJournalReasons.deviceIntegration);
      expect(
        container.read(studyTimerProvider).isRunning,
        isTrue,
        reason:
            'davranis degismedi: rutin sayaci hala baslatir, sadece iz birakir',
      );
    });

    test('SOGUK BASLANGIC ile UYGULAMA ACIKKEN ayirt edilir', () async {
      final (container, _) = await _container(initialAction: _startPomodoro);
      container.read(deviceIntegrationListenerProvider);
      await _settle();

      final row = _single(container, TimerJournalEvents.startRequested);
      expect(
        row.trigger,
        'device_start_pomodoro_cold',
        reason: '"uygulamayi hic acmadim" anlatisini yalniz cold dogrular',
      );
      expect(TimerJournalTriggers.isUserButton(row.trigger), isFalse);
    });
  });

  group('gunluk DURDURMANIN kaynagini da soyler', () {
    test('EKRAN DUGMESI ile durdurma kullanici damgasi TASIR', () async {
      final (container, _) = await _container();
      final notifier = container.read(studyTimerProvider.notifier);
      notifier.start();
      await notifier.stop();
      await _settle();

      final row = _single(container, TimerJournalEvents.stopRequested);
      expect(row.trigger, TimerJournalTriggers.userButton);
      expect(row.reason, TimerJournalReasons.userAction);
    });

    test('CIHAZ AKSIYONU ile durdurma kullanici damgasi TASIMAZ', () async {
      final (container, device) = await _container();
      container.read(deviceIntegrationListenerProvider);
      await _settle();
      container.read(studyTimerProvider.notifier).start();
      await _settle();

      device.onActionReceived!(_stopTimer);
      await _settle();

      final row = _single(container, TimerJournalEvents.stopRequested);
      expect(
        TimerJournalTriggers.isUserButton(row.trigger),
        isFalse,
        reason: '"durdurdugumu saniyordum" vakasinin simetrigi',
      );
      expect(row.trigger, 'device_stop_timer_warm');
      expect(row.reason, TimerJournalReasons.deviceIntegration);
    });

    test('TAKE_BREAK durdurmasi da kendi adiyla gorunur', () async {
      final (container, device) = await _container();
      container.read(deviceIntegrationListenerProvider);
      await _settle();
      container.read(studyTimerProvider.notifier).start();
      await _settle();

      device.onActionReceived!(_takeBreak);
      await _settle();

      expect(
        _single(container, TimerJournalEvents.stopRequested).trigger,
        'device_take_break_warm',
        reason:
            'hangi rutinin durdurdugu bilinmeden "kim durdurdu" cevaplanamaz',
      );
    });
  });

  group('sozluk ve geriye donuk okunabilirlik', () {
    test('WP-599 ONCESI satir "bilinmiyor" okunur, "kullanici" OKUNMAZ', () {
      final legacy = TimerJournalEntry.tryParse(const {
        'at': '2026-08-08T19:40:28.000Z',
        'event': 'start_requested',
        'reason': 'user_action',
        'outcome': 'applied',
        'origin': 'app',
      });

      expect(legacy, isNotNull);
      expect(legacy!.trigger, TimerJournalTriggers.unknown);
      expect(
        TimerJournalTriggers.isUserButton(legacy.trigger),
        isFalse,
        reason:
            'eski satirlari parmaga yazmak, kapatmaya calistigimiz acigi '
            'gecmise dogru kaliciliastirirdi',
      );
      expect(legacy.toJson()['trigger'], TimerJournalTriggers.unknown);
    });

    test('tetikleyici slug kapisindan gecer (48 karakter / [a-z0-9_])', () {
      for (final action in const [
        'start_timer',
        'stop_timer',
        'start_pomodoro',
        'start_stopwatch',
        'take_break',
      ]) {
        for (final cold in const [true, false]) {
          final slug = TimerJournalTriggers.deviceIntegration(
            action: action,
            coldStart: cold,
          );
          expect(slug, isNot(TimerJournalTriggers.unknown));
          expect(slug, TimerJournalSlug.normalize(slug));
          expect(slug.startsWith(TimerJournalTriggers.devicePrefix), isTrue);
          expect(slug.endsWith(cold ? '_cold' : '_warm'), isTrue);
        }
      }
    });

    test('intent adi -> slug eslemesi tum sayac aksiyonlarini kapsar', () {
      for (final action in const [
        _startTimer,
        _stopTimer,
        _startPomodoro,
        _takeBreak,
        'com.manilmax.online_study_room.START_STOPWATCH',
      ]) {
        expect(
          deviceIntegrationTrigger(action, coldStart: false),
          isNot(contains(TimerJournalSlug.unknown)),
          reason: '$action gunluge "unknown" olarak dusuyor',
        );
      }
    });

    test('her tetikleyicinin tek bir kanonik reason karsiligi var', () {
      expect(
        TimerJournalTriggers.reasonFor(TimerJournalTriggers.userButton),
        TimerJournalReasons.userAction,
      );
      expect(
        TimerJournalTriggers.reasonFor(
          TimerJournalTriggers.externalCommandQueue,
        ),
        TimerJournalReasons.externalCommandQueue,
      );
      expect(
        TimerJournalTriggers.reasonFor(
          deviceIntegrationTrigger(_startTimer, coldStart: true),
        ),
        TimerJournalReasons.deviceIntegration,
      );
      expect(
        TimerJournalTriggers.reasonFor(TimerJournalTriggers.unknown),
        TimerJournalSlug.unknown,
        reason: 'kaynagini bildirmeyen cagri "kullanici" sayilamaz',
      );
    });
  });
}
