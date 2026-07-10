import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/providers/study_providers.dart';

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

void main() {
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
        ],
      );
      addTearDown(container.dispose);

      container.read(studyTimerProvider.notifier).start();
      await container.read(studyTimerProvider.notifier).stop();

      expect(container.read(studyTimerProvider).isRunning, isFalse);
      expect(prefs.getString('timer_active_started_at'), isNull);
    });
  });
}
