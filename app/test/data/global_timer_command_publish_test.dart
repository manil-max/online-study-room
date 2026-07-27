import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/background/timer_v2_command_outbox.dart';
import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/global_timer.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/global_timer_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-368 (V51-2) regresyon testi.
///
/// Düzeltilen hata: başlatma komutu sunucuya **hiç** gitmiyordu. Kuyruğu
/// boşaltan `flushShadow()` tek yerden çağrılıyordu — `_syncBackgroundTimerState`,
/// yani soğuk açılış ve uygulamanın öne gelmesi. Başlatmanın ardından çağıran
/// yoktu. Sonuç: A cihazında başlatılan koşu sunucuya yazılmıyor, B cihazı
/// açıldığında snapshot boş dönüyor (`00.00.00`) ve B kendi sayacını
/// başlatabiliyordu.
///
/// İkinci arıza: `bindActiveAccount` ile native başlatma ikisi de `unawaited`
/// olduğu için yarışıyordu; bind yetişmezse zarf boş `account_id` ile yazılıp
/// kalıcı karantinaya düşüyor ve o komut bir daha asla gönderilmiyordu.
///
/// Not: soğuk açılışta `build()` zaten bir kez `_syncBackgroundTimerState`
/// koşturur; testler o ilk turu tükettikten **sonra** ölçmeye başlar, böylece
/// ölçülen tek şey başlat/durdur'un kendi yayınıdır.
class _RecordingCoordinator extends GlobalTimerCoordinator {
  _RecordingCoordinator(super.ref, this._prefs);

  final SharedPreferences _prefs;

  /// Her yayında, yayın **anındaki** hesap bağı. `null` = bind yetişmemiş.
  final List<String?> boundAccountAtFlush = <String?>[];
  int foregroundReconcileCount = 0;

  @override
  Future<void> flushShadow() async {
    boundAccountAtFlush.add(
      _prefs.getString(TimerV2CommandEnvelope.accountIdKey),
    );
  }

  @override
  Future<GlobalTimerForegroundDirective?> reconcileForeground({
    required bool localRunning,
    required bool localIsMirror,
    required String? localMirrorRunId,
  }) async {
    foregroundReconcileCount++;
    return null;
  }
}

class _ThrowingCoordinator extends GlobalTimerCoordinator {
  _ThrowingCoordinator(super.ref);

  /// Soğuk açılış turunda patlatma; ölçülen şey başlat yolundaki dayanıklılık.
  bool armed = false;

  @override
  Future<void> flushShadow() async {
    if (armed) throw StateError('network down');
  }

  @override
  Future<GlobalTimerForegroundDirective?> reconcileForeground({
    required bool localRunning,
    required bool localIsMirror,
    required String? localMirrorRunId,
  }) async => null;
}

class _NoopTimerNotificationService implements TimerNotificationGateway {
  const _NoopTimerNotificationService();

  @override
  Stream<TimerNotificationAction> get commands => const Stream.empty();

  @override
  Future<void> cancel() async {}

  @override
  Future<void> requestPermissionIfNeeded() async {}

  @override
  Future<void> showRunning(TimerNotificationSnapshot snapshot) async {}
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

Profile _profile(String id) =>
    Profile(id: id, displayName: id, createdAt: DateTime(2026));

/// Zincir (bind → native yazım → yayın) gerçek async adımlar içerir; sabit
/// sayıda mikrotask turu beklemek kararsızdır. Koşul gerçekleşene kadar bekle.
Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

/// Bekleyen işler bittikten sonra "başka bir yayın daha gelmiyor" iddiasını
/// ölçebilmek için kısa bir sessizlik penceresi.
Future<void> _quietWindow() =>
    Future<void>.delayed(const Duration(milliseconds: 120));

void main() {
  // studyTimerProvider.build() bir AppLifecycleListener kurar → binding şart.
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> buildContainer(
    GlobalTimerCoordinator Function(Ref ref, SharedPreferences prefs)
    coordinator,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authStateProvider.overrideWith((ref) => Stream.value(_profile('u-1'))),
        timerNotificationServiceProvider.overrideWithValue(
          const _NoopTimerNotificationService(),
        ),
        androidWidgetServiceProvider.overrideWithValue(
          const _NoopAndroidWidgetService(),
        ),
        globalTimerCoordinatorProvider.overrideWith(
          (ref) => coordinator(ref, prefs),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Riverpod 3: dinleyicisiz provider her read'de yeniden kurulur; sayaç
    // durumunu tek örnekte tutmak için ikisini de canlı tut.
    container.listen(authStateProvider, (_, _) {});
    container.listen(studyTimerProvider, (_, _) {});
    await container.read(authStateProvider.future);
    // Soğuk açılış turunu tüket: ölçüm bundan sonra başlar.
    await _quietWindow();
    return container;
  }

  Future<({ProviderContainer container, _RecordingCoordinator coordinator})>
  buildRecordingHarness() async {
    late _RecordingCoordinator recorder;
    final container = await buildContainer((ref, prefs) {
      recorder = _RecordingCoordinator(ref, prefs);
      return recorder;
    });
    recorder.boundAccountAtFlush.clear();
    return (container: container, coordinator: recorder);
  }

  group('WP-368 global timer komut yayını', () {
    test('başlatma komutu resume beklemeden yayınlanır', () async {
      final harness = await buildRecordingHarness();

      harness.container.read(studyTimerProvider.notifier).start();
      await _waitUntil(
        () => harness.coordinator.boundAccountAtFlush.isNotEmpty,
      );
      await _quietWindow();

      expect(
        harness.coordinator.boundAccountAtFlush.length,
        1,
        reason:
            'start tam bir kez yayın tetiklemeli; eskiden hiç tetiklemiyordu',
      );
    });

    test('yayın anında hesap bağı yazılmış olur (karantina yarışı)', () async {
      final harness = await buildRecordingHarness();

      harness.container.read(studyTimerProvider.notifier).start();
      await _waitUntil(
        () => harness.coordinator.boundAccountAtFlush.isNotEmpty,
      );

      expect(
        harness.coordinator.boundAccountAtFlush.single,
        'u-1',
        reason:
            'bind native yazımdan önce tamamlanmalı; yoksa zarf boş account_id '
            'ile yazılıp kalıcı karantinaya düşer',
      );
    });

    test('durdurma da yayın tetikler', () async {
      final harness = await buildRecordingHarness();
      final notifier = harness.container.read(studyTimerProvider.notifier);

      notifier.start();
      await _waitUntil(
        () => harness.coordinator.boundAccountAtFlush.isNotEmpty,
      );
      final afterStart = harness.coordinator.boundAccountAtFlush.length;

      await notifier.stop();
      await _waitUntil(
        () => harness.coordinator.boundAccountAtFlush.length > afterStart,
      );

      expect(
        harness.coordinator.boundAccountAtFlush.length,
        greaterThan(afterStart),
        reason:
            'durdurma yayınlanmazsa diğer cihazdaki aynalanmış sayaç çalışmaya '
            'devam eder',
      );
    });

    test('yayın hatası sayacı durdurmaz', () async {
      late _ThrowingCoordinator thrower;
      final container = await buildContainer((ref, _) {
        thrower = _ThrowingCoordinator(ref);
        return thrower;
      });
      thrower.armed = true;

      container.read(studyTimerProvider.notifier).start();
      await _quietWindow();

      expect(container.read(studyTimerProvider).isRunning, isTrue);
    });

    test('açık cihaz snapshot reconcile için yalnız FCM beklemez', () async {
      final harness = await buildRecordingHarness();
      final before = harness.coordinator.foregroundReconcileCount;

      await Future<void>.delayed(
        kGlobalTimerForegroundReconcileInterval +
            const Duration(milliseconds: 750),
      );

      expect(
        harness.coordinator.foregroundReconcileCount,
        greaterThan(before),
        reason:
            'FCM kaybolsa bile açık cihaz, düşük frekanslı auth snapshot turuyla '
            'uzak timer state\'ini yeniden kontrol etmeli',
      );
    });

    /// WP-371: tur "foreground" turudur. Sayaç çalışırken native foreground
    /// servis süreci canlı tuttuğu için, arka planda durmazsa ekran kapalıyken
    /// de 5 sn'de bir ağ turu döner (pil + kota). O pencerede senkronu FCM taşır.
    test('arka plana düşen uygulama snapshot turunu durdurur', () async {
      final harness = await buildRecordingHarness();
      final binding = TestWidgetsFlutterBinding.ensureInitialized();

      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await _quietWindow();
      final afterPause = harness.coordinator.foregroundReconcileCount;

      await Future<void>.delayed(
        kGlobalTimerForegroundReconcileInterval +
            const Duration(milliseconds: 750),
      );
      expect(
        harness.coordinator.foregroundReconcileCount,
        afterPause,
        reason: 'arka plandayken hiçbir snapshot turu atmamalı',
      );

      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      // Resume'un kendi tek seferlik uzlaştırması sayılmasın; ölçüm ondan
      // sonra başlar ki iddia gerçekten periyodik turun döndüğünü kanıtlasın.
      await _waitUntil(
        () => harness.coordinator.foregroundReconcileCount > afterPause,
      );
      await _quietWindow();
      final afterResume = harness.coordinator.foregroundReconcileCount;

      await Future<void>.delayed(
        kGlobalTimerForegroundReconcileInterval +
            const Duration(milliseconds: 750),
      );
      expect(
        harness.coordinator.foregroundReconcileCount,
        greaterThan(afterResume),
        reason: 'öne dönen uygulamada periyodik tur yeniden başlamalı',
      );
    });
  });
}
