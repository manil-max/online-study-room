// WP-613 — sayacın faz geçişi: native köprü (KANAMA-2) + kaza penceresi
// (RİSK-3).
//
// 🔴 KANAMA-2: kalıcı bildirim koşunun İLK saniyesinde donuyordu. Native panel
// yalnız `handleStart`/`handleStop` komutlarında kurulur ve etiketi/kronometre
// zeminini o an prefs'ten okur; faz geçişinde Dart'tan hiçbir komut gitmiyordu.
// Sonuç: pomodoro molasında bildirim hâlâ "Odaklanıyorsun" diyor, süreyi ilk
// çalışma başlangıcından sayıyor ve `rest` fazında doğan "Çalışmaya dön"
// düğmesi üretimde HİÇ çıkmıyordu.
//
// 🔴 Ölçmeyen kapı: `test/core/verified_timer_bridge_contract_test.dart`
// `ACTION_END_BREAK`'i `.kt` dosyasında METİN olarak arıyordu. Metin vardı,
// düğme yoktu. Bu dosya metne bakmaz: **komut gidiyor mu** diye ölçer — sahte
// bir platform kanalı kurulur ve `startTimer` turları sayılır/okunur.
//
// 🔴 RİSK-3: geri sayım kendi kendine bittiğinde de WP-598 penceresi açılıyor,
// hemen ardından Başlat'a basan kullanıcıya "Az önce durdurdun" deniyordu.
// Kullanıcı durdurmamıştı. İddia iki yönlüdür: kullanıcı durdurunca pencere
// AÇILMALI, doğal bitişte AÇILMAMALI.
//
// Koşu, sayacın SOĞUK AÇILIŞ geri yüklemesiyle kurulur: hedefi çoktan aşmış
// bir aktif koşu prefs'e ekilir, ilk saniyelik tetik fazı tamamlar. Böylece
// gerçek `_onTick` → `_completePhase` yolu ölçülür, özel bir test kapısı değil.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';

/// WP-598 penceresi enjekte edilen saatle ölçülür; hiçbir iddia duvar saatine
/// bakmaz.
class _FakeClock {
  _FakeClock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration d) => now = now.add(d);
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

/// Native `StudyTimerService` köprüsünün sahtesi: hangi komutun hangi
/// argümanlarla gittiğini kaydeder.
class _TimerBridgeSpy {
  static const MethodChannel _channel = MethodChannel(
    'com.manilmax.online_study_room/timer',
  );

  final starts = <Map<Object?, Object?>>[];
  int stopCalls = 0;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          switch (call.method) {
            case 'startTimer':
              starts.add(call.arguments as Map<Object?, Object?>);
            case 'stopTimer':
              stopCalls++;
          }
          return null;
        });
  }

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  }
}

/// Hedefini çoktan aşmış bir aktif koşu (soğuk açılış geri yüklemesi için).
Map<String, Object> _expiredRun({
  required String mode,
  required int minutes,
  int breakMinutes = 3,
  int cycles = 4,
}) {
  final startedAt = DateTime.now().subtract(const Duration(minutes: 30));
  return <String, Object>{
    'timer_mode': mode,
    'timer_countdown_min': minutes,
    'timer_work_min': minutes,
    'timer_break_min': breakMinutes,
    'timer_cycles': cycles,
    'timer_active_mode': mode,
    'timer_active_phase': 'work',
    'timer_active_cycle': 1,
    'timer_active_started_at': startedAt.toIso8601String(),
    'timer_active_started_at_ms': startedAt.millisecondsSinceEpoch,
    'timer_fg_mode': 'running',
  };
}

Future<ProviderContainer> _container(
  _FakeClock clock, {
  Map<String, Object> prefsSeed = const <String, Object>{},
}) async {
  SharedPreferences.setMockInitialValues(prefsSeed);
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      studyTimerClockProvider.overrideWithValue(clock.call),
      timerNotificationServiceProvider.overrideWithValue(
        const _NoopTimerNotificationService(),
      ),
      androidWidgetServiceProvider.overrideWithValue(
        const _NoopAndroidWidgetService(),
      ),
    ],
  );
  addTearDown(container.dispose);
  // Riverpod 3: dinleyicisiz provider her read'de yeniden kurulur; koşu
  // await'ler arasında hayatta kalmalı (yoksa tetik hiç çalışmaz).
  container.listen(studyTimerProvider, (_, _) {});
  return container;
}

/// Soğuk açılış zinciri: microtask → uzlaşma → 400 ms auth penceresi → ikinci
/// uzlaşma → `_startTick()` → 1 sn sonra ilk tetik.
Future<void> _awaitFirstTick() =>
    Future<void>.delayed(const Duration(milliseconds: 2500));

void main() {
  // studyTimerProvider.build() bir AppLifecycleListener kurar → binding şart.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _TimerBridgeSpy bridge;

  setUp(() {
    // `TimerForegroundService` yalnız Android'de kanala çıkar.
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    bridge = _TimerBridgeSpy()..install();
  });
  tearDown(() {
    bridge.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  group('KANAMA-2 — faz geçişi native köprüye ULAŞIR', () {
    test('molaya geçişte bildirim YENİDEN kurulur, üstelik yeni faz ile',
        () async {
      final clock = _FakeClock(DateTime.utc(2026, 8, 9, 21, 0));
      final container = await _container(
        clock,
        prefsSeed: _expiredRun(mode: 'pomodoro', minutes: 1, breakMinutes: 3),
      );
      final restoredStart = container.read(studyTimerProvider).startedAt;
      expect(
        restoredStart,
        isNotNull,
        reason: 'test boş çalışmasın: koşu gerçekten geri yüklenmeli',
      );

      await _awaitFirstTick();

      final timer = container.read(studyTimerProvider);
      expect(
        timer.phase,
        TimerPhase.rest,
        reason: 'faz geçişi gerçekten oldu mu (ölçümün ön koşulu)',
      );

      expect(
        bridge.starts,
        isNotEmpty,
        reason:
            'ASIL BUG: faz geçişinde native servise HİÇBİR komut gitmiyordu; '
            'bildirim koşunun ilk saniyesinde donuyordu',
      );
      final last = bridge.starts.last;
      expect(
        last['phase'],
        'rest',
        reason:
            'bildirim molada olduğumuzu söylemeli; "Çalışmaya dön" düğmesi de '
            'yalnız rest fazında doğar (StudyTimerService.endBreakActionPending)',
      );
      expect(last['mode'], 'pomodoro');
      expect(
        last['targetSeconds'],
        3 * 60,
        reason: 'bildirimdeki hedef mola süresi olmalı, çalışma süresi değil',
      );
      expect(
        last['startedAtMs'],
        isNot(restoredStart!.millisecondsSinceEpoch),
        reason:
            'KRONOMETRE ZEMİNİ: süre ilk çalışma başlangıcından değil, molanın '
            'başladığı andan sayılmalı',
      );
      expect(
        (last['startedAtMs']! as int) >
            restoredStart.millisecondsSinceEpoch,
        isTrue,
      );
    });

    test('KARŞI İDDİA: koşu bittiğinde başlat komutu DEĞİL durdurma gider',
        () async {
      // "Her tetikte native start gönder" sabotajı bu iddiayla düşer: koşunun
      // bittiği yerde bildirim yeniden kurulmamalı, kaldırılmalı.
      final clock = _FakeClock(DateTime.utc(2026, 8, 9, 21, 0));
      final container = await _container(
        clock,
        prefsSeed: _expiredRun(mode: 'countdown', minutes: 1),
      );

      await _awaitFirstTick();

      expect(container.read(studyTimerProvider).isRunning, isFalse);
      expect(bridge.starts, isEmpty);
      expect(bridge.stopCalls, greaterThan(0));
    });
  });

  group('RİSK-3 — kaza penceresini yalnız DURDURMA açar', () {
    test('geri sayım KENDİ bittiğinde pencere açılmaz, Başlat geçer', () async {
      final clock = _FakeClock(DateTime.utc(2026, 8, 9, 21, 0));
      final container = await _container(
        clock,
        prefsSeed: _expiredRun(mode: 'countdown', minutes: 1),
      );

      await _awaitFirstTick();

      final finished = container.read(studyTimerProvider);
      expect(finished.isRunning, isFalse);
      expect(
        finished.lastEvent,
        TimerEvent.countdownDone,
        reason: 'koşu DOĞAL yoldan bitmiş olmalı (kullanıcı durdurmadı)',
      );

      // "Bitti" uyarısını gören kullanıcı hemen bir tur daha istiyor.
      clock.advance(const Duration(seconds: 3));
      container.read(studyTimerProvider.notifier).start();

      expect(
        container.read(studyTimerProvider).isRunning,
        isTrue,
        reason:
            'ASIL BUG: sayaç başlamıyor ve kullanıcıya "Az önce durdurdun" '
            'deniyordu — oysa kullanıcı durdurmamıştı',
      );
      expect(
        container.read(accidentalRestartNoticeProvider),
        isFalse,
        reason: 'yanlış sebep söylemek, sessiz kalmaktan iyi değildir',
      );
    });

    test('KARŞI İDDİA: kullanıcı DURDURUNCA pencere hâlâ açılır', () async {
      // WP-598'in koruduğu 11 saatlik sahte oturum tam buradan geçmişti;
      // düzeltme o kapıyı açık bırakamaz.
      final clock = _FakeClock(DateTime.utc(2026, 8, 9, 21, 0));
      final container = await _container(clock);
      final notifier = container.read(studyTimerProvider.notifier);

      notifier.start();
      await notifier.stop();

      clock.advance(const Duration(seconds: 3));
      notifier.start();

      expect(container.read(studyTimerProvider).isRunning, isFalse);
      expect(container.read(accidentalRestartNoticeProvider), isTrue);
    });
  });
}
