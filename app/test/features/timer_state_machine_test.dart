import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_study_repository.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';

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

void main() {
  // studyTimerProvider.build() bir AppLifecycleListener kurar; bu da
  // WidgetsBinding.instance ister. Plain test()'lerde binding init edilmezse
  // provider kurulurken patlar (persistence testleri bu yüzden kırılıyordu).
  TestWidgetsFlutterBinding.ensureInitialized();

  group('timerPhaseTargetSeconds', () {
    test('kronometrede hedef yok (null)', () {
      expect(
        timerPhaseTargetSeconds(
          mode: TimerMode.stopwatch,
          phase: TimerPhase.work,
          countdownMinutes: 25,
          workMinutes: 25,
          breakMinutes: 5,
        ),
        isNull,
      );
    });

    test('geri sayım = countdownMinutes * 60', () {
      expect(
        timerPhaseTargetSeconds(
          mode: TimerMode.countdown,
          phase: TimerPhase.work,
          countdownMinutes: 30,
          workMinutes: 25,
          breakMinutes: 5,
        ),
        30 * 60,
      );
    });

    test('pomodoro çalışma/mola doğru hedefi verir', () {
      expect(
        timerPhaseTargetSeconds(
          mode: TimerMode.pomodoro,
          phase: TimerPhase.work,
          countdownMinutes: 25,
          workMinutes: 50,
          breakMinutes: 10,
        ),
        50 * 60,
      );
      expect(
        timerPhaseTargetSeconds(
          mode: TimerMode.pomodoro,
          phase: TimerPhase.rest,
          countdownMinutes: 25,
          workMinutes: 50,
          breakMinutes: 10,
        ),
        10 * 60,
      );
    });
  });

  group('nextPhaseTransition', () {
    test('geri sayım biter ve çalışmayı kaydeder', () {
      final t = nextPhaseTransition(
        mode: TimerMode.countdown,
        phase: TimerPhase.work,
        cycle: 1,
        cycles: 1,
      );
      expect(t.finished, isTrue);
      expect(t.recordWork, isTrue);
      expect(t.event, TimerEvent.countdownDone);
    });

    test('pomodoro çalışma (son değil) → molaya geçer, çalışmayı kaydeder', () {
      final t = nextPhaseTransition(
        mode: TimerMode.pomodoro,
        phase: TimerPhase.work,
        cycle: 1,
        cycles: 4,
      );
      expect(t.finished, isFalse);
      expect(t.recordWork, isTrue);
      expect(t.nextPhase, TimerPhase.rest);
      expect(t.nextCycle, 1); // döngü molada artmaz
      expect(t.event, TimerEvent.workDone);
    });

    test('pomodoro mola → sıradaki çalışma döngüsü, kayıt yok', () {
      final t = nextPhaseTransition(
        mode: TimerMode.pomodoro,
        phase: TimerPhase.rest,
        cycle: 1,
        cycles: 4,
      );
      expect(t.finished, isFalse);
      expect(t.recordWork, isFalse);
      expect(t.nextPhase, TimerPhase.work);
      expect(t.nextCycle, 2);
      expect(t.event, TimerEvent.breakDone);
    });

    test('pomodoro son çalışma döngüsü → biter (allDone), kaydeder', () {
      final t = nextPhaseTransition(
        mode: TimerMode.pomodoro,
        phase: TimerPhase.work,
        cycle: 4,
        cycles: 4,
      );
      expect(t.finished, isTrue);
      expect(t.recordWork, isTrue);
      expect(t.event, TimerEvent.allDone);
    });

    test(
      'tam pomodoro dizisi: N döngü → N çalışma kaydı + doğru faz sırası',
      () {
        const cycles = 3;
        var phase = TimerPhase.work;
        var cycle = 1;
        var workRecords = 0;
        final events = <TimerEvent>[];

        // Her faz hedefe ulaştığında geçişi uygula; bitene dek yürüt.
        for (var guard = 0; guard < 50; guard++) {
          final t = nextPhaseTransition(
            mode: TimerMode.pomodoro,
            phase: phase,
            cycle: cycle,
            cycles: cycles,
          );
          if (t.recordWork) workRecords++;
          events.add(t.event);
          if (t.finished) break;
          phase = t.nextPhase;
          cycle = t.nextCycle;
        }

        // 3 döngü = 3 çalışma kaydı.
        expect(workRecords, cycles);
        // Olay sırası: work,break,work,break,work(all done)
        expect(events, [
          TimerEvent.workDone,
          TimerEvent.breakDone,
          TimerEvent.workDone,
          TimerEvent.breakDone,
          TimerEvent.allDone,
        ]);
      },
    );
  });

  group('StudyTimerNotifier persistence', () {
    test(
      'start persists active timer and a new container restores it',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            timerNotificationServiceProvider.overrideWithValue(
              const _NoopTimerNotificationService(),
            ),
            androidWidgetServiceProvider.overrideWithValue(
              const _NoopAndroidWidgetService(),
            ),
          ],
        );
        addTearDown(container.dispose);

        container.read(studyTimerProvider.notifier).start();
        final running = container.read(studyTimerProvider);

        expect(running.isRunning, isTrue);
        expect(prefs.getString('timer_active_started_at'), isNotNull);

        final restoredContainer = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            timerNotificationServiceProvider.overrideWithValue(
              const _NoopTimerNotificationService(),
            ),
            androidWidgetServiceProvider.overrideWithValue(
              const _NoopAndroidWidgetService(),
            ),
          ],
        );
        addTearDown(restoredContainer.dispose);

        final restored = restoredContainer.read(studyTimerProvider);
        expect(restored.isRunning, isTrue);
        expect(restored.startedAt, isNotNull);
        expect(restored.mode, running.mode);
      },
    );

    test('stop clears active timer persistence', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          timerNotificationServiceProvider.overrideWithValue(
            const _NoopTimerNotificationService(),
          ),
          androidWidgetServiceProvider.overrideWithValue(
            const _NoopAndroidWidgetService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(studyTimerProvider.notifier).start();
      await container.read(studyTimerProvider.notifier).stop();

      expect(container.read(studyTimerProvider).isRunning, isFalse);
      expect(prefs.getString('timer_active_started_at'), isNull);
    });

    test('WP-104: app-içi stop oturumu kaydeder (süre kaybı yok)', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final auth = InMemoryAuthRepository();
      await auth.signUp(
        email: 'stop-qa@ornek.com',
        password: '123456',
        displayName: 'Stop QA',
      );
      final studyRepo = InMemoryStudyRepository();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(auth),
          groupRepositoryProvider.overrideWithValue(InMemoryGroupRepository()),
          studyRepositoryProvider.overrideWithValue(studyRepo),
          timerNotificationServiceProvider.overrideWithValue(
            const _NoopTimerNotificationService(),
          ),
          androidWidgetServiceProvider.overrideWithValue(
            const _NoopAndroidWidgetService(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final authSub = container.listen(
        authStateProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(authSub.close);
      for (var i = 0; i < 100 && !container.read(authStateProvider).hasValue; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      final profile = container.read(authStateProvider).value;
      expect(profile, isNotNull);

      final notifier = container.read(studyTimerProvider.notifier);
      notifier.start();
      final startedAt = container.read(studyTimerProvider).startedAt!;
      // Sabit bitiş: duration>0 garantisi (ms yarışına bağlı kalma).
      final endAt = startedAt.add(const Duration(seconds: 42));
      await notifier.stop(at: endAt);

      expect(container.read(studyTimerProvider).isRunning, isFalse);
      final sessions = await studyRepo.watchUserSessions(profile!.id).first;
      expect(sessions, isNotEmpty, reason: 'WP-104: stop oturumu yazmalı');
      expect(sessions.single.userId, profile.id);
      expect(sessions.single.durationSeconds, 42);
      expect(sessions.single.start, startedAt);
      expect(sessions.single.end, endAt);
    });

    test(
      'soğuk açılışta bekleyen "stop" komutu aktif sayacı durdurur',
      () async {
        // Uygulama kapalıyken bildirimdeki Durdur'a basıldı: aktif sayaç + komut
        // prefs'te duruyor. Açılışta (onResume tetiklenmese bile) durmalı.
        SharedPreferences.setMockInitialValues({
          'timer_active_started_at': DateTime.now()
              .subtract(const Duration(minutes: 3))
              .toIso8601String(),
          'timer_active_mode': TimerMode.stopwatch.name,
          'timer_active_phase': TimerPhase.work.name,
          'timer_active_cycle': 1,
          'timer_external_command': 'stop',
        });
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            timerNotificationServiceProvider.overrideWithValue(
              const _NoopTimerNotificationService(),
            ),
            androidWidgetServiceProvider.overrideWithValue(
              const _NoopAndroidWidgetService(),
            ),
          ],
        );
        addTearDown(container.dispose);

        // İlk okuma çalışan sayacı restore eder.
        expect(container.read(studyTimerProvider).isRunning, isTrue);

        // build() microtask'ı bekleyen komutu işleyene kadar bekle.
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(container.read(studyTimerProvider).isRunning, isFalse);
        expect(prefs.getString('timer_external_command'), isNull);
      },
    );

    test(
      'soğuk açılışta bekleyen "start" komutu sayacı başlatır',
      () async {
        SharedPreferences.setMockInitialValues({
          'timer_mode': TimerMode.stopwatch.name,
          'timer_external_command': 'start',
        });
        final prefs = await SharedPreferences.getInstance();
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            timerNotificationServiceProvider.overrideWithValue(
              const _NoopTimerNotificationService(),
            ),
            androidWidgetServiceProvider.overrideWithValue(
              const _NoopAndroidWidgetService(),
            ),
          ],
        );
        addTearDown(container.dispose);

        expect(container.read(studyTimerProvider).isRunning, isFalse);

        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(container.read(studyTimerProvider).isRunning, isTrue);
        expect(prefs.getString('timer_external_command'), isNull);
      },
    );
  });
}
