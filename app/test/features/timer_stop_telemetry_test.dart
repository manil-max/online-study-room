/// WP-507: durdurma zincirinden telemetri ağ turunu çıkarır.
///
/// Saha bulgusu (`docs/qa/V59-FIELD-FEEDBACK.md` madde 10): "bazen sayacı
/// kapatırken 3 sn bekliyor". Zincirdeki son halka `recordVerifiedSessionRollout`
/// çağrısıydı — saf telemetri olmasına rağmen `await` ediliyordu.
///
/// Buradaki iddia **davranış korumalıdır**: telemetri hiç dönmese de, hata verse
/// de sayaç durur ve oturum yazılır. `stop()` gövdesindeki `await` SIRASI bu
/// testin konusu değildir (WP-250/241/243/246/233/104 orada kapatıldı).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_group.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/group_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_group_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_study_repository.dart';
import 'package:online_study_room/features/android_widgets/android_widget_service.dart';
import 'package:online_study_room/features/classroom/widgets/study_timer_card.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../support/async_wait.dart';

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

/// Telemetri turunu testin denetimine alır: [called] çağrının gerçekten
/// yapıldığını, [release] ise ağın ne zaman (ya da hiç) döneceğini belirler.
class _TelemetryControlledStudyRepository extends InMemoryStudyRepository {
  _TelemetryControlledStudyRepository({this.throwInstead = false});

  /// `true` ise telemetri turu ağ hatasıyla düşer (dönmemek yerine patlar).
  final bool throwInstead;

  final _called = Completer<void>();
  final _release = Completer<void>();

  Future<void> get called => _called.future;

  void release() {
    if (!_release.isCompleted) _release.complete();
  }

  @override
  Future<void> recordVerifiedSessionRollout({
    required String platform,
    required int clientBuild,
    required bool capability,
    LiveStartOrigin? origin,
    LiveRolloutOutcome? outcome,
  }) async {
    if (!_called.isCompleted) _called.complete();
    if (throwInstead) throw StateError('telemetry_network_down');
    // Uyanan mobil veri / yeniden kurulan Supabase bağlantısı: bu tur uzayabilir.
    await _release.future;
    return super.recordVerifiedSessionRollout(
      platform: platform,
      clientBuild: clientBuild,
      capability: capability,
      origin: origin,
      outcome: outcome,
    );
  }
}

/// Doğrulanmış (verified) bir koşu ortasında açılmış uygulamayı kurar:
/// sunucuda canlı bir run vardır ve prefs onun token'ını taşır, yani `stop()`
/// `_finalizeVerifiedRun` yolundan geçer.
Future<(ProviderContainer, Profile)> _buildRunningVerifiedContainer(
  _TelemetryControlledStudyRepository repo, {
  required DateTime startedAt,
}) async {
  final auth = InMemoryAuthRepository();
  final profile = await auth.signUp(
    email: 'wp507@ornek.com',
    password: '123456',
    displayName: 'Stop QA',
  );
  final run = await repo.startLiveRun(
    userId: profile.id,
    clientRequestId: 'wp507-request',
  );

  SharedPreferences.setMockInitialValues(<String, Object>{
    'timer_active_started_at': startedAt.toIso8601String(),
    'timer_active_started_at_ms': startedAt.millisecondsSinceEpoch,
    'timer_active_mode': TimerMode.stopwatch.name,
    'timer_active_phase': TimerPhase.work.name,
    'timer_active_cycle': 1,
    'timer_fg_mode': 'running',
    'timer_active_live_run_id': run.id,
    'timer_active_live_run_token': run.runToken,
  });
  final prefs = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(auth),
      groupRepositoryProvider.overrideWithValue(InMemoryGroupRepository()),
      studyRepositoryProvider.overrideWithValue(repo),
      timerNotificationServiceProvider.overrideWithValue(
        const _NoopTimerNotificationService(),
      ),
      androidWidgetServiceProvider.overrideWithValue(
        const _NoopAndroidWidgetService(),
      ),
    ],
  );
  addTearDown(container.dispose);

  final authSub = container.listen(authStateProvider, (_, _) {});
  addTearDown(authSub.close);
  // Riverpod 3: dinleyicisiz provider her `read`de yeniden kurulur; sayaç
  // canlı tutulmazsa durdurma sırasındaki state geçişleri gözlenemez.
  final timerSub = container.listen(studyTimerProvider, (_, _) {});
  addTearDown(timerSub.close);

  await waitUntil(
    () => container.read(authStateProvider).value != null,
    reason: 'auth hazır olmalı',
  );
  await waitUntil(
    () => container.read(studyTimerProvider).isRunning,
    reason: 'kayıtlı başlangıçtan sayaç çalışır duruma geçmeli',
  );
  expect(
    container.read(studyTimerProvider).liveRunToken,
    run.runToken,
    reason: 'verified koşu benimsenmeli — yoksa test yanlış yolu ölçer',
  );
  return (container, profile);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WP-507: durdurma telemetriyi beklemez', () {
    test('telemetri turu hiç dönmese bile sayaç durur ve oturum yazılır', () async {
      final repo = _TelemetryControlledStudyRepository();
      addTearDown(repo.release);
      final startedAt = DateTime.now().subtract(const Duration(minutes: 12));
      final (container, profile) = await _buildRunningVerifiedContainer(
        repo,
        startedAt: startedAt,
      );

      // Telemetri `await` edilseydi bu future hiç tamamlanmazdı: kullanıcının
      // gördüğü "Durdur'a bastım, sayaç bir süre öylece duruyor" tam olarak bu.
      await container
          .read(studyTimerProvider.notifier)
          .stop()
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => fail(
              'stop() telemetri turunu bekledi — rollout kaydı ateşle-unut olmalı',
            ),
          );

      expect(container.read(studyTimerProvider).isRunning, isFalse);
      expect(
        container.read(sharedPreferencesProvider).getString('timer_fg_mode'),
        'idle',
      );
      final sessions = await repo.watchUserSessions(profile.id).first;
      expect(
        sessions,
        hasLength(1),
        reason: 'finalize edilen koşu oturum olarak yazılmalı',
      );

      // Vazgeçilmiş değil, yalnız beklenmemiş: çağrı gerçekten yapılır.
      // (Bu iddia olmadan telemetriyi tamamen silmek de testi geçerdi.)
      await repo.called.timeout(
        const Duration(seconds: 5),
        onTimeout: () => fail('rollout telemetrisi hiç çağrılmadı'),
      );

      // Geciken tur sonradan dönerse durmuş sayacı diriltmemeli.
      repo.release();
      await pumpEventQueue(times: 5);
      expect(container.read(studyTimerProvider).isRunning, isFalse);
    });

    test('telemetri hata verse bile durdurma başarısız sayılmaz', () async {
      final repo = _TelemetryControlledStudyRepository(throwInstead: true);
      final startedAt = DateTime.now().subtract(const Duration(minutes: 7));
      final (container, profile) = await _buildRunningVerifiedContainer(
        repo,
        startedAt: startedAt,
      );

      await expectLater(
        container.read(studyTimerProvider.notifier).stop(),
        completes,
        reason: 'telemetri hatası kullanıcıya durdurma hatası olarak yansımaz',
      );
      await pumpEventQueue(times: 5);

      expect(container.read(studyTimerProvider).isRunning, isFalse);
      final sessions = await repo.watchUserSessions(profile.id).first;
      expect(sessions, hasLength(1));
    });
  });

  group('WP-507: Durdur butonu ilerlemeyi gösterir', () {
    testWidgets('durdurma sürerken spinner + "Durduruluyor…" görünür', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final running = StudyTimerState(
        isRunning: true,
        startedAt: DateTime.now().subtract(const Duration(minutes: 5)),
        phase: TimerPhase.work,
      );
      final fake = _FakeTimerNotifier(running);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            userSessionsProvider.overrideWith(
              (_) => Stream.value(const <StudySession>[]),
            ),
            userSubjectsProvider.overrideWith(
              (_) => Stream.value(const <Subject>[]),
            ),
            dailyGoalMinutesProvider.overrideWithValue(240),
            userGroupProvider.overrideWithValue(
              const AsyncData<StudyGroup?>(null),
            ),
            studyTimerProvider.overrideWith(() => fake),
          ],
          child: MaterialApp(
            locale: const Locale('tr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: SizedBox(width: 380, height: 900, child: StudyTimerCard()),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Durdur'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Durdur'a basıldı: notifier ilk `await`ten önce bunu yayınlar.
      fake.push(running.copyWith(isStopping: true));
      await tester.pump();

      // "Ölü buton" hissinin bittiği yer: yazı değişir ve spinner döner.
      expect(find.text('Durduruluyor…'), findsOneWidget);
      expect(find.text('Durdur'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}

/// Gerçek notifier'ın kanal/dinleyici kurulumunu atlayan sahte — state'i test
/// sürer, ölçülen şey kartın çizimidir.
class _FakeTimerNotifier extends StudyTimerNotifier {
  _FakeTimerNotifier(this._initial);

  final StudyTimerState _initial;

  @override
  StudyTimerState build() => _initial;

  void push(StudyTimerState next) => state = next;
}
