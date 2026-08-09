// WP-622 — "Çalışmaya dön" pomodoro turunu ilerletiyor mu? (DENETIM-sayac
// RİSK-5) — zincirin **Dart yakası**.
//
// 🔴 Hata native tarafta doğuyordu: `StudyTimerService.handleEndBreak` tur
// numarasını prefs'ten okuyup **aynen** geri yazıyordu. Kararın kendisi artık
// `TimerStateStore.endBreakPlan` içinde ve cihazsız JVM testiyle ölçülüyor
// (`android/app/src/test/.../EndBreakCycleWp622Test.kt`).
//
// Bu dosya zincirin öbür ucunu ölçer, çünkü native düzeltme tek başına
// kullanıcıya ULAŞMAZ:
//   1. Dart, native SSOT'un yazdığı turu gerçekten benimsemeli — yoksa ekran
//      kendi bayat turunda kalır ve native düzeltme sessizce ölür.
//   2. Uygulama İÇİNDEKİ normal faz geçişi bozulmamalı (iki yönlü iddia):
//      mola kendi kendine bitince de tur ilerlemeli ve yeni tur native köprüye
//      itilmeli (WP-613 köprüsü).
//
// Zaman enjekte edilir; hiçbir iddia duvar saatine bakmaz.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';

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

/// Native `StudyTimerService` köprüsünün sahtesi: Dart→native giden komutları
/// kaydeder (WP-613'teki casusun aynısı).
class _TimerBridgeSpy {
  static const MethodChannel channel = MethodChannel(
    'com.manilmax.online_study_room/timer',
  );

  final starts = <Map<Object?, Object?>>[];

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'startTimer') {
            starts.add(call.arguments as Map<Object?, Object?>);
          }
          return null;
        });
  }

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  }
}

/// Native servisin `notifyStateChanged()` sonrası Dart'ta tetiklediği gerçek
/// giriş noktası: `reconcile` method channel çağrısı (`study_providers.dart`
/// `_timerChannel.setMethodCallHandler`). Test özel bir kapı açmaz.
Future<void> _nativeCallsReconcile() async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        _TimerBridgeSpy.channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('reconcile'),
        ),
        (_) {},
      );
}

/// Molada duran 4 turluk bir pomodoro koşusu (soğuk açılış geri yüklemesi).
Map<String, Object> _restingPomodoro({
  required DateTime breakStartedAt,
  required int cycle,
  int breakMinutes = 5,
}) => <String, Object>{
  'timer_mode': 'pomodoro',
  'timer_work_min': 25,
  'timer_break_min': breakMinutes,
  'timer_cycles': 4,
  'timer_active_mode': 'pomodoro',
  'timer_active_phase': 'rest',
  'timer_active_cycle': cycle,
  'timer_active_started_at': breakStartedAt.toIso8601String(),
  'timer_active_started_at_ms': breakStartedAt.millisecondsSinceEpoch,
  'timer_fg_mode': 'running',
};

Future<(ProviderContainer, SharedPreferences)> _container(
  _FakeClock clock,
  Map<String, Object> prefsSeed,
) async {
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
  // await'ler arasında hayatta kalmalı.
  container.listen(studyTimerProvider, (_, _) {});
  return (container, prefs);
}

void main() {
  // studyTimerProvider.build() bir AppLifecycleListener kurar → binding şart.
  TestWidgetsFlutterBinding.ensureInitialized();

  late _TimerBridgeSpy bridge;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    bridge = _TimerBridgeSpy()..install();
  });
  tearDown(() {
    bridge.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  test(
    'bildirimden bitirilen molada ekran native SSOT\'un ilerlettiği turu benimser',
    () async {
      final clock = _FakeClock(DateTime.utc(2026, 8, 9, 21, 0));
      final breakStartedAt = DateTime.utc(2026, 8, 9, 20, 58);
      final (container, prefs) = await _container(
        clock,
        _restingPomodoro(breakStartedAt: breakStartedAt, cycle: 2),
      );

      // Ön koşul: ekran gerçekten molada ve 2. turda.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final resting = container.read(studyTimerProvider);
      expect(resting.phase, TimerPhase.rest, reason: 'test boş çalışmasın');
      expect(resting.cycle, 2);

      // Kullanıcı kalıcı bildirimdeki "Çalışmaya dön"e bastı. Native servis
      // SSOT'a bir SONRAKİ turun çalışma fazını yazar (WP-622 sonrası
      // `TimerStateStore.endBreakPlan`: cycle 2 → 3) ve Dart'ı uyandırır.
      final workStartedAt = DateTime.utc(2026, 8, 9, 21, 0);
      await prefs.setString('timer_active_phase', 'work');
      await prefs.setInt('timer_active_cycle', 3);
      await prefs.setString(
        'timer_active_started_at',
        workStartedAt.toIso8601String(),
      );
      await prefs.setInt(
        'timer_active_started_at_ms',
        workStartedAt.millisecondsSinceEpoch,
      );
      await _nativeCallsReconcile();

      final after = container.read(studyTimerProvider);
      expect(after.phase, TimerPhase.work);
      expect(
        after.cycle,
        3,
        reason:
            'Native turu ilerletse bile ekran kendi bayat turunda kalırsa '
            'düzeltme kullanıcıya HİÇ ulaşmaz; sayaç "Tur 2/4"te donar.',
      );
      expect(after.isRunning, isTrue);
      expect(after.startedAt, workStartedAt);
    },
  );

  test(
    'KARŞI İDDİA: uygulama içinde kendi biten mola da turu ilerletir ve '
    'yeni turu native köprüye iter',
    () async {
      // Native tarafta "turu artır" derken uygulama içi geçişi bozmak kolaydı;
      // bu iddia o sabotajı düşürür. Mola hedefini çoktan aşmış bir koşu
      // ekilir, ilk saniyelik tetik gerçek `_onTick` → `_completePhase`
      // yolundan geçer.
      final clock = _FakeClock(DateTime.utc(2026, 8, 9, 21, 0));
      final breakStartedAt = DateTime.now().subtract(
        const Duration(minutes: 30),
      );
      final (container, prefs) = await _container(
        clock,
        _restingPomodoro(
          breakStartedAt: breakStartedAt,
          cycle: 2,
          breakMinutes: 5,
        ),
      );

      expect(container.read(studyTimerProvider).phase, TimerPhase.rest);

      // Soğuk açılış zinciri: uzlaşma → auth penceresi → _startTick → 1 sn.
      await Future<void>.delayed(const Duration(milliseconds: 2500));

      final after = container.read(studyTimerProvider);
      expect(after.phase, TimerPhase.work);
      expect(after.cycle, 3, reason: 'rest → work geçişi turu artırır');
      expect(after.lastEvent, TimerEvent.breakDone);

      // WP-613 köprüsü: yeni faz VE yeni tur native servise gitmeli, yoksa
      // bildirim/widget eski turu göstermeye devam eder.
      expect(bridge.starts, isNotEmpty);
      final last = bridge.starts.last;
      expect(last['phase'], 'work');
      expect(last['cycle'], 3);
      expect(last['targetSeconds'], 25 * 60);

      // SSOT da ilerlemiş olmalı: uygulama öldürülürse geri yükleme buradan.
      expect(prefs.getInt('timer_active_cycle'), 3);
    },
  );
}
