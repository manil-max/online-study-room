import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/notifications/timer_notification_service.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/models/study_session.dart';
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

/// WP-273: RTT penceresini duvar saatiyle beklemek yerine iki açık kapıyla
/// kurar. Önce yerel cache emit olur, test yalnız bu noktada devam eder; ağın
/// tamamlanması da testin çağırdığı [releaseNetwork] ile belirlenir.
class _ControlledStudyRepository extends InMemoryStudyRepository {
  final _localWriteEmitted = Completer<void>();
  final _networkRelease = Completer<void>();

  @override
  Future<void> addSession(StudySession session) async {
    await super.addSession(session); // yerel emit
    if (!_localWriteEmitted.isCompleted) _localWriteEmitted.complete();
    await _networkRelease.future;
  }

  Future<void> get localWriteEmitted => _localWriteEmitted.future;

  void releaseNetwork() {
    if (!_networkRelease.isCompleted) _networkRelease.complete();
  }
}

/// WP-251: seçilen oturum id'lerinde ağ hatası taklidi (kısmi kuyruk hatası).
class _FlakyStudyRepository extends InMemoryStudyRepository {
  final Set<String> failIds = <String>{};

  @override
  Future<void> addSession(StudySession session) async {
    if (failIds.contains(session.id)) {
      throw StateError('network_down');
    }
    await super.addSession(session);
  }
}

/// Girişli auth + oturumları gözlenebilir bir in-memory study repo ile container
/// kurar. [initialPrefs] FGS'in arka planda yazdığı durumu taklit eder.
Future<(ProviderContainer, InMemoryStudyRepository, Profile)> _buildContainer(
  Map<String, Object> initialPrefs, {
  InMemoryStudyRepository? repository,
}) async {
  SharedPreferences.setMockInitialValues(initialPrefs);
  final prefs = await SharedPreferences.getInstance();

  final auth = InMemoryAuthRepository();
  await auth.signUp(
    email: 'reconcile@ornek.com',
    password: '123456',
    displayName: 'Reconcile QA',
  );
  final studyRepo = repository ?? InMemoryStudyRepository();

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

  // Auth stream'i emit edene kadar bekle ki reconcile (_recordSession)
  // kullanıcıyı hazır görsün. Aktif bir dinleyici olmadan StreamProvider
  // sürülmüyor; bu yüzden container.listen ile dinleyip `.value`'yu yokluyoruz.
  final authSub = container.listen(
    authStateProvider,
    (_, _) {},
    fireImmediately: true,
  );
  addTearDown(authSub.close);
  await pumpEventQueue(times: 20);
  final profile = container.read(authStateProvider).value;
  expect(profile, isNotNull, reason: 'auth hazır olmalı');
  return (container, studyRepo, profile!);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FGS arka plan uzlaştırma (WP-41 R2)', () {
    test(
      'app-kapalı Durdur (idle): kuyruğa yazılan aralık oturum olur + sayaç durur',
      () async {
        final start = DateTime.now().subtract(const Duration(minutes: 30));
        final end = DateTime.now().subtract(const Duration(minutes: 5));
        final (container, studyRepo, profile) = await _buildContainer({
          // Durdur öncesi çalışan oturumdan kalan aktif state (idle'da started_at
          // FGS tarafından silinmiş olur → app açılışında sayaç durur).
          'timer_active_mode': TimerMode.stopwatch.name,
          'timer_active_phase': TimerPhase.work.name,
          'timer_fg_mode': 'idle',
          'timer_pending_intervals':
              '[{"start":"${start.toIso8601String()}","end":"${end.toIso8601String()}","subject":""}]',
        });

        // build() sayacı durur restore eder (started_at yok).
        expect(container.read(studyTimerProvider).isRunning, isFalse);

        // build() microtask'ı reconcile'i çalıştırana kadar bekle.
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Aralık oturum olarak kaydedildi.
        final sessions = await studyRepo.watchUserSessions(profile.id).first;
        expect(sessions, hasLength(1));
        expect(
          sessions.single.durationSeconds,
          end.difference(start).inSeconds,
        );

        // Kuyruk temizlendi, sayaç durur.
        expect(container.read(studyTimerProvider).isRunning, isFalse);
        final prefs = container.read(sharedPreferencesProvider);
        expect(prefs.getString('timer_pending_intervals'), isNull);
      },
    );

    test(
      'app-kapalı Durdur→Başlat: eski oturum kaydedilir + yeni oturum çalışır',
      () async {
        final oldStart = DateTime.now().subtract(const Duration(minutes: 40));
        final oldEnd = DateTime.now().subtract(const Duration(minutes: 20));
        final newStart = DateTime.now().subtract(const Duration(minutes: 10));
        final (container, studyRepo, profile) = await _buildContainer({
          // Başlat sonrası: yeni oturum started_at + running mod; kuyrukta eski
          // (Durdur ile kapanan) aralık.
          'timer_active_started_at': newStart.toIso8601String(),
          'timer_active_mode': TimerMode.stopwatch.name,
          'timer_active_phase': TimerPhase.work.name,
          'timer_active_cycle': 1,
          'timer_fg_mode': 'running',
          'timer_pending_intervals':
              '[{"start":"${oldStart.toIso8601String()}","end":"${oldEnd.toIso8601String()}","subject":""}]',
        });

        // build() yeni oturumu (newStart) running restore eder.
        expect(container.read(studyTimerProvider).isRunning, isTrue);
        expect(container.read(studyTimerProvider).startedAt, newStart);

        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Eski aralık kaydedildi; yeni oturum hâlâ çalışıyor (kaydedilmedi).
        final sessions = await studyRepo.watchUserSessions(profile.id).first;
        expect(sessions, hasLength(1));
        expect(
          sessions.single.durationSeconds,
          oldEnd.difference(oldStart).inSeconds,
        );
        expect(container.read(studyTimerProvider).isRunning, isTrue);
        expect(container.read(studyTimerProvider).startedAt, newStart);
      },
    );

    test(
      'app-kapalı Mola: native break fazı ve yeni epoch uygulamaya yansır',
      () async {
        final breakStartedAt = DateTime.now().subtract(
          const Duration(minutes: 3),
        );
        final (container, _, _) = await _buildContainer({
          'timer_active_started_at': breakStartedAt.toIso8601String(),
          'timer_active_mode': TimerMode.stopwatch.name,
          'timer_active_phase': TimerPhase.rest.name,
          'timer_active_cycle': 2,
          'timer_fg_mode': 'running',
        });

        final timer = container.read(studyTimerProvider);
        expect(timer.isRunning, isTrue);
        expect(timer.startedAt, breakStartedAt);
        expect(timer.phase, TimerPhase.rest);
        expect(timer.cycle, 2);
      },
    );

    test(
      '10 app-kapalı Durdur/Başlat (5 tam çift) → 5 oturum kaydeder',
      () async {
        // 5 tamamlanmış aralık (Durdur), son Başlat ile 6. oturum çalışıyor.
        final base = DateTime.now().subtract(const Duration(hours: 3));
        final intervals = <String>[];
        for (var i = 0; i < 5; i++) {
          final s = base.add(Duration(minutes: i * 20));
          final e = s.add(const Duration(minutes: 10));
          intervals.add(
            '{"start":"${s.toIso8601String()}","end":"${e.toIso8601String()}","subject":""}',
          );
        }
        final running = base.add(const Duration(minutes: 100));
        final (container, studyRepo, profile) = await _buildContainer({
          'timer_active_started_at': running.toIso8601String(),
          'timer_active_mode': TimerMode.stopwatch.name,
          'timer_active_phase': TimerPhase.work.name,
          'timer_active_cycle': 1,
          'timer_fg_mode': 'running',
          'timer_pending_intervals': '[${intervals.join(',')}]',
        });

        // Notifier'ı kur → build() microtask'ı reconcile'i tetikler.
        expect(container.read(studyTimerProvider).isRunning, isTrue);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        final sessions = await studyRepo.watchUserSessions(profile.id).first;
        expect(sessions, hasLength(5));
        for (final s in sessions) {
          expect(s.durationSeconds, 10 * 60);
        }
        // 6. oturum hâlâ çalışıyor (kuyrukta değildi).
        expect(container.read(studyTimerProvider).isRunning, isTrue);
      },
    );
  });

  group('WP-233: uygulama önplandayken bildirimden başlatma', () {
    test(
      'adopte edilmemiş native sayaç uygulama içi Durdur ile gerçekten durur',
      () async {
        // Uygulama açık ve sayaç durur durumda kuruldu. UI'ın notifier'ı canlı
        // tuttuğunu taklit et: Riverpod 3'te dinleyicisiz provider dispose olur
        // ve her read'de build() prefs'i yeniden okuyup durumu kendiliğinden
        // adopte eder — gerçek uygulamada olmayan bir davranış.
        final (container, studyRepo, profile) = await _buildContainer({});
        final timerSub = container.listen(studyTimerProvider, (_, _) {});
        addTearDown(timerSub.close);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(container.read(studyTimerProvider).isRunning, isFalse);

        // Kullanıcı bildirim panelinden Başlat'a bastı: native SSOT'a yazdı ama
        // uygulama zaten önplanda olduğu için resume/adopt hiç tetiklenmedi.
        final nativeStart = DateTime.now().subtract(const Duration(minutes: 25));
        final prefs = container.read(sharedPreferencesProvider);
        await prefs.setInt(
          'timer_active_started_at_ms',
          nativeStart.millisecondsSinceEpoch,
        );
        await prefs.setString(
          'timer_active_started_at',
          nativeStart.toIso8601String(),
        );
        await prefs.setString('timer_active_mode', TimerMode.stopwatch.name);
        await prefs.setString('timer_active_phase', TimerPhase.work.name);
        await prefs.setInt('timer_active_cycle', 1);
        await prefs.setString('timer_fg_mode', 'running');
        await prefs.setString('timer_active_start_origin', 'native_notification');

        // Dart state hâlâ "durur" — regresyondan önce Durdur sessizce dönüyordu.
        expect(container.read(studyTimerProvider).isRunning, isFalse);

        await container.read(studyTimerProvider.notifier).stop();

        // Durdur artık native durumu uzlaştırıp oturumu gerçekten yazmalı.
        final sessions = await studyRepo.watchUserSessions(profile.id).first;
        expect(
          sessions,
          hasLength(1),
          reason: 'bildirimden başlatılan çalışma oturum olarak kaydedilmeli',
        );
        expect(
          sessions.single.durationSeconds,
          closeTo(25 * 60, 5),
          reason: 'süre native başlangıç saatinden hesaplanmalı',
        );
        expect(container.read(studyTimerProvider).isRunning, isFalse);
        expect(prefs.getString('timer_fg_mode'), 'idle');
      },
    );
  });

  group('WP-245: native boş-token mayını (D1)', () {
    test(
      'native "" token ile başlatılan sayaç uygulama içi Durdur ile GERÇEKTEN '
      'durur ve oturum yazılır (finalize("") kilidi yok)',
      () async {
        // Native FGS, verified koşusu olmayan HER başlatmayı prefs'e boş string
        // token ile yazar (StudyTimerService `.orEmpty()`). Cihaz gerçeği budur;
        // testler bugüne kadar bu anahtarı hiç yazmadığı için mayını kaçırdı.
        final nativeStart = DateTime.now().subtract(const Duration(minutes: 18));
        final (container, studyRepo, profile) = await _buildContainer({
          'timer_active_started_at': nativeStart.toIso8601String(),
          'timer_active_started_at_ms': nativeStart.millisecondsSinceEpoch,
          'timer_active_mode': TimerMode.stopwatch.name,
          'timer_active_phase': TimerPhase.work.name,
          'timer_active_cycle': 1,
          'timer_fg_mode': 'running',
          'timer_active_start_origin': 'native_notification',
          // MAYIN: native her zaman "" yazar; null DEĞİL.
          'timer_active_live_run_id': '',
          'timer_active_live_run_token': '',
        });
        final timerSub = container.listen(studyTimerProvider, (_, _) {});
        addTearDown(timerSub.close);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Sayaç çalışır benimsendi; "" token verified sanılmamalı.
        final adopted = container.read(studyTimerProvider);
        expect(adopted.isRunning, isTrue);
        expect(
          adopted.liveRunToken,
          isNull,
          reason: '"" gerçek token değildir → verified yolu tetiklenmemeli',
        );
        expect(adopted.verification, TimerVerification.statisticsOnly);

        // Fix'ten önce: finalize("") → StateError → _finish() hiç çalışmaz →
        // sayaç durmaz + oturum yazılmazdı. Şimdi düzgün durmalı.
        await container.read(studyTimerProvider.notifier).stop();

        expect(
          container.read(studyTimerProvider).isRunning,
          isFalse,
          reason: 'boş-token mayını nötrlendi → Durdur gerçekten durdurmalı',
        );
        final sessions = await studyRepo.watchUserSessions(profile.id).first;
        expect(sessions, hasLength(1), reason: 'oturum yazılmalı');
        expect(sessions.single.durationSeconds, closeTo(18 * 60, 5));
        expect(
          container.read(sharedPreferencesProvider).getString('timer_fg_mode'),
          'idle',
        );
      },
    );
  });

  group('WP-246: stop() reentrancy (D2 — çift/çoklu sayım)', () {
    test(
      'ardı ardına Durdur basışı tek oturum kaydeder (aynı aralık tekrar yok)',
      () async {
        // Geçmişte başlamış çalışan sayaç (kayıt/RTT penceresi olsun diye).
        final start = DateTime.now().subtract(const Duration(minutes: 15));
        final (container, studyRepo, profile) = await _buildContainer({
          'timer_active_started_at': start.toIso8601String(),
          'timer_active_started_at_ms': start.millisecondsSinceEpoch,
          'timer_active_mode': TimerMode.stopwatch.name,
          'timer_active_phase': TimerPhase.work.name,
          'timer_active_cycle': 1,
          'timer_fg_mode': 'running',
        });
        final timerSub = container.listen(studyTimerProvider, (_, _) {});
        addTearDown(timerSub.close);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(container.read(studyTimerProvider).isRunning, isTrue);

        // Kullanıcı Durdur'a ard arda 4 kez basar; state ilk stop'un `await`'i
        // bitene kadar `running` kaldığı için kilitsizken hepsi kayıt üretirdi.
        final notifier = container.read(studyTimerProvider.notifier);
        await Future.wait([
          notifier.stop(),
          notifier.stop(),
          notifier.stop(),
          notifier.stop(),
        ]);

        final sessions = await studyRepo.watchUserSessions(profile.id).first;
        expect(
          sessions,
          hasLength(1),
          reason: 'reentrancy kilidi → tek oturum, çift sayım yok',
        );
        expect(container.read(studyTimerProvider).isRunning, isFalse);
      },
    );
  });

  group('WP-247: µs/ms hassasiyeti echo no-op (D3)', () {
    Future<void> fireReconcile2() async {
      const channel = MethodChannel('com.manilmax.online_study_room/timer');
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(const MethodCall('reconcile')),
            (_) {},
          );
    }

    test(
      'ms-eşit echo adoption tetiklemez (startedAt mikrosaniyesi korunur)',
      () async {
        // Dart µs hassasiyetli başlangıç; native ms'e yuvarlar. State µs tutar.
        final baseMs = DateTime.now()
            .subtract(const Duration(minutes: 10))
            .millisecondsSinceEpoch;
        final startMicro = DateTime.fromMicrosecondsSinceEpoch(
          baseMs * 1000 + 500,
        );
        final (container, _, _) = await _buildContainer({
          'timer_active_started_at': startMicro.toIso8601String(),
          'timer_active_started_at_ms': baseMs,
          'timer_active_mode': TimerMode.stopwatch.name,
          'timer_active_phase': TimerPhase.work.name,
          'timer_active_cycle': 1,
          'timer_fg_mode': 'running',
        });
        final timerSub = container.listen(studyTimerProvider, (_, _) {});
        addTearDown(timerSub.close);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(container.read(studyTimerProvider).startedAt, startMicro);

        // Native'in yazdığı ms-yuvarlanmış (µs'siz) echo gelir.
        final prefs = container.read(sharedPreferencesProvider);
        await prefs.setString(
          'timer_active_started_at',
          DateTime.fromMillisecondsSinceEpoch(baseMs).toIso8601String(),
        );
        await prefs.setInt('timer_active_started_at_ms', baseMs);
        await fireReconcile2();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // ms eşit → adoption yok → startedAt (µs dahil) DEĞİŞMEZ. Ham != ile
        // adoption tetiklenip µs kırpılıyordu.
        expect(
          container.read(studyTimerProvider).startedAt,
          startMicro,
          reason: 'ms-eşit echo no-op olmalı, startedAt korunmalı',
        );
      },
    );
  });

  group('WP-243: içerik-temelli durdurma yarışı (echo bastırma)', () {
    // Native→Dart `reconcile` broadcast'ini tetikler (gerçek native yayınının
    // uygulama önplandayken yaptığı çağrının aynısı).
    Future<void> fireReconcile() async {
      const channel = MethodChannel('com.manilmax.online_study_room/timer');
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(const MethodCall('reconcile')),
            (_) {},
          );
    }

    test(
      'bildirimden başlatılan sayaç uygulama içi Durdur sonrası GEÇ echo ile '
      'geri gelmez',
      () async {
        // Bildirimden başlatılmış çalışan sayaç (native SSOT prefs'te).
        final nativeStart = DateTime.now().subtract(const Duration(minutes: 12));
        final (container, studyRepo, profile) = await _buildContainer({
          'timer_active_started_at': nativeStart.toIso8601String(),
          'timer_active_started_at_ms': nativeStart.millisecondsSinceEpoch,
          'timer_active_mode': TimerMode.stopwatch.name,
          'timer_active_phase': TimerPhase.work.name,
          'timer_active_cycle': 1,
          'timer_fg_mode': 'running',
          'timer_active_start_origin': 'native_notification',
        });
        final timerSub = container.listen(studyTimerProvider, (_, _) {});
        addTearDown(timerSub.close);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(container.read(studyTimerProvider).isRunning, isTrue);

        // Kullanıcı uygulama içinden Durdur'a bastı → oturum yazılır, durur.
        await container.read(studyTimerProvider.notifier).stop();
        expect(container.read(studyTimerProvider).isRunning, isFalse);
        final afterStop = await studyRepo.watchUserSessions(profile.id).first;
        expect(afterStop, hasLength(1));

        // GEÇ echo: native `writeIdle` diske düşmeden önceki bir `reconcile`
        // broadcast'i gelir; prefs hâlâ AYNI startedAt-ms ile `running` okur.
        final prefs = container.read(sharedPreferencesProvider);
        await prefs.setString(
          'timer_active_started_at',
          nativeStart.toIso8601String(),
        );
        await prefs.setInt(
          'timer_active_started_at_ms',
          nativeStart.millisecondsSinceEpoch,
        );
        await prefs.setString('timer_fg_mode', 'running');
        await fireReconcile();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Durdurma geri ALINMAMALI (fix'ten önce echo sayacı diriltiyordu) ve
        // ikinci bir oturum YAZILMAMALI.
        expect(
          container.read(studyTimerProvider).isRunning,
          isFalse,
          reason: 'geç echo durdurulmuş sayacı yeniden benimsememeli',
        );
        final afterEcho = await studyRepo.watchUserSessions(profile.id).first;
        expect(afterEcho, hasLength(1), reason: 'çift oturum yazılmamalı');
      },
    );

    test(
      'Durdur sonrası GERÇEKTEN yeni bir native başlatma (farklı ms) benimsenir',
      () async {
        // Bildirimden başlatılmış çalışan sayaç.
        final firstStart = DateTime.now().subtract(const Duration(minutes: 12));
        final (container, _, _) = await _buildContainer({
          'timer_active_started_at': firstStart.toIso8601String(),
          'timer_active_started_at_ms': firstStart.millisecondsSinceEpoch,
          'timer_active_mode': TimerMode.stopwatch.name,
          'timer_active_phase': TimerPhase.work.name,
          'timer_active_cycle': 1,
          'timer_fg_mode': 'running',
          'timer_active_start_origin': 'native_notification',
        });
        final timerSub = container.listen(studyTimerProvider, (_, _) {});
        addTearDown(timerSub.close);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(container.read(studyTimerProvider).isRunning, isTrue);

        await container.read(studyTimerProvider.notifier).stop();
        expect(container.read(studyTimerProvider).isRunning, isFalse);

        // Kullanıcı bildirimden YENİDEN Başlat'a bastı: yeni epoch (farklı ms).
        final secondStart = DateTime.now().subtract(const Duration(minutes: 1));
        final prefs = container.read(sharedPreferencesProvider);
        await prefs.setString(
          'timer_active_started_at',
          secondStart.toIso8601String(),
        );
        await prefs.setInt(
          'timer_active_started_at_ms',
          secondStart.millisecondsSinceEpoch,
        );
        await prefs.setString('timer_fg_mode', 'running');
        await fireReconcile();
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Yeni ms echo değil → benimsenmeli (aşırı bastırma yok).
        expect(
          container.read(studyTimerProvider).isRunning,
          isTrue,
          reason: 'farklı ms gerçek yeni başlatmadır, benimsenmeli',
        );
        expect(container.read(studyTimerProvider).startedAt, secondStart);
      },
    );
  });

  group('WP-250: durdurma çift-sayımı (settling modeli)', () {
    test(
      'DB yazımı (RTT) sürerken ekran toplamı ne zıplar ne düşer',
      () async {
        final start = DateTime.now().subtract(const Duration(minutes: 20));
        final slowRepo = _ControlledStudyRepository();
        final (container, studyRepo, profile) = await _buildContainer({
          'timer_active_started_at': start.toIso8601String(),
          'timer_active_started_at_ms': start.millisecondsSinceEpoch,
          'timer_active_mode': TimerMode.stopwatch.name,
          'timer_active_phase': TimerPhase.work.name,
          'timer_active_cycle': 1,
          'timer_fg_mode': 'running',
        }, repository: slowRepo);

        // Riverpod 3: dinleyicisiz provider her read'de yeniden kurulur →
        // stream'i canlı tutmak için ikisini de dinle (yoksa test anlamsızlaşır).
        final timerSub = container.listen(studyTimerProvider, (_, _) {});
        addTearDown(timerSub.close);
        final sessionsSub = container.listen(
          userSessionsProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sessionsSub.close);
        await pumpEventQueue(times: 20);
        expect(container.read(studyTimerProvider).isRunning, isTrue);

        // Ekranın gösterdiği sayıyı, UI ile BİREBİR aynı kuralla hesapla.
        int displayed() {
          final t = container.read(studyTimerProvider);
          final elapsed = (t.isRunning && !t.isStopping && t.startedAt != null)
              ? DateTime.now().difference(t.startedAt!).inSeconds
              : 0;
          return resolveTodayDisplayTotal(
            recordedToday: container.read(todayRecordedSecondsProvider),
            liveWorkSeconds: t.phase == TimerPhase.work ? elapsed : 0,
            settlingSeconds: t.settlingSeconds,
            settlingBaseline: t.settlingBaseline,
            settlingDay: t.settlingDay,
            today: DateTime.now(),
          );
        }

        final before = displayed(); // ≈ 1200 sn
        expect(before, greaterThan(1100));

        final stopFuture = container.read(studyTimerProvider.notifier).stop();

        // RTT penceresi: yerel cache emit oldu, `_finish()` HENÜZ çalışmadı.
        // Düzeltme olmadan burada toplam ~2x olur (oturum boyu kadar şişme).
        await slowRepo.localWriteEmitted;
        expect(
          container.read(studyTimerProvider).isStopping,
          isTrue,
          reason: 'durdurma başlar başlamaz canlı akış kesilmeli',
        );
        expect(
          displayed(),
          closeTo(before, 2),
          reason: 'RTT penceresinde toplam şişmemeli (asıl bug)',
        );

        slowRepo.releaseNetwork();
        await stopFuture;
        await pumpEventQueue(times: 20);
        expect(
          displayed(),
          closeTo(before, 2),
          reason: 'durdurma bittikten sonra da aynı sayı',
        );

        final sessions = await studyRepo.watchUserSessions(profile.id).first;
        expect(sessions, hasLength(1));
      },
    );

    test(
      'app-kapalı Durdur sonrası uyanma: ölü zaman toplama eklenmez',
      () async {
        // Kullanıcı 30 dk çalıştı, 25 dk önce bildirimden Durdur'a bastı,
        // uygulamayı ŞİMDİ açıyor. Kuyrukta gerçek aralık var; state ise
        // (arka planda uyuyan isolate gibi) hâlâ "çalışıyor".
        final start = DateTime.now().subtract(const Duration(minutes: 55));
        final end = DateTime.now().subtract(const Duration(minutes: 25));
        final (container, _, _) = await _buildContainer({
          'timer_active_started_at': start.toIso8601String(),
          'timer_active_started_at_ms': start.millisecondsSinceEpoch,
          'timer_active_mode': TimerMode.stopwatch.name,
          'timer_active_phase': TimerPhase.work.name,
          'timer_active_cycle': 1,
          'timer_fg_mode': 'running',
        });
        final timerSub = container.listen(studyTimerProvider, (_, _) {});
        addTearDown(timerSub.close);
        final sessionsSub = container.listen(
          userSessionsProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sessionsSub.close);
        await Future<void>.delayed(const Duration(milliseconds: 20));

        // Native Durdur'u taklit et: start anahtarları silinir, kuyruğa aralık.
        final prefs = container.read(sharedPreferencesProvider);
        await prefs.remove('timer_active_started_at');
        await prefs.remove('timer_active_started_at_ms');
        await prefs.setString('timer_fg_mode', 'idle');
        await prefs.setString(
          'timer_pending_intervals',
          '[{"start":"${start.toIso8601String()}",'
              '"end":"${end.toIso8601String()}","subject":""}]',
        );

        await container.read(studyTimerProvider.notifier).stop();
        await Future<void>.delayed(const Duration(milliseconds: 40));

        final t = container.read(studyTimerProvider);
        expect(t.isRunning, isFalse);
        final total = resolveTodayDisplayTotal(
          recordedToday: container.read(todayRecordedSecondsProvider),
          liveWorkSeconds: 0,
          settlingSeconds: t.settlingSeconds,
          settlingBaseline: t.settlingBaseline,
          settlingDay: t.settlingDay,
          today: DateTime.now(),
        );
        // Gerçekten çalışılan 30 dk kaydedilir; aradaki 25 dk ölü zaman
        // toplama EKLENMEZ (eski hata: ~55 dk gösterip gün boyu kilitlerdi).
        expect(total, closeTo(30 * 60, 5));
      },
    );
  });

  group('WP-251: kuyruk kısmi başarısızlığı (çift yazım / kayıp yok)', () {
    Future<void> fireReconcile4() async {
      const channel = MethodChannel('com.manilmax.online_study_room/timer');
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
            channel.name,
            channel.codec.encodeMethodCall(const MethodCall('reconcile')),
            (_) {},
          );
    }

    test(
      '2. aralık hata alsa da 1. tekrar yazılmaz, 2. sonra tamamlanır',
      () async {
        const idA = '11111111-1111-4111-8111-111111111111';
        const idB = '22222222-2222-4222-8222-222222222222';
        final s1 = DateTime.now().subtract(const Duration(hours: 3));
        final e1 = s1.add(const Duration(minutes: 20));
        final s2 = DateTime.now().subtract(const Duration(hours: 2));
        final e2 = s2.add(const Duration(minutes: 30));

        final flaky = _FlakyStudyRepository()..failIds.add(idB);
        final (container, studyRepo, profile) = await _buildContainer({
          'timer_fg_mode': 'idle',
          'timer_pending_intervals':
              '[{"id":"$idA","start":"${s1.toIso8601String()}",'
              '"end":"${e1.toIso8601String()}","subject":""},'
              '{"id":"$idB","start":"${s2.toIso8601String()}",'
              '"end":"${e2.toIso8601String()}","subject":""}]',
        }, repository: flaky);
        final timerSub = container.listen(studyTimerProvider, (_, _) {});
        addTearDown(timerSub.close);
        await Future<void>.delayed(const Duration(milliseconds: 40));

        // 1. tur: yalnız A yazıldı, B kuyrukta kaldı.
        var sessions = await studyRepo.watchUserSessions(profile.id).first;
        expect(sessions.map((s) => s.id), [idA]);
        final prefs = container.read(sharedPreferencesProvider);
        expect(
          prefs.getString('timer_pending_intervals'),
          contains(idB),
          reason: 'başarısız kayıt kuyrukta kalmalı',
        );
        expect(
          prefs.getString('timer_pending_intervals'),
          isNot(contains(idA)),
          reason: 'başarılı kayıt kuyruktan düşmeli (replay kaynağı buydu)',
        );

        // 2. tur: ağ düzeldi.
        flaky.failIds.clear();
        await fireReconcile4();
        await Future<void>.delayed(const Duration(milliseconds: 40));

        sessions = await studyRepo.watchUserSessions(profile.id).first;
        expect(
          sessions.map((s) => s.id).toSet(),
          {idA, idB},
          reason: 'iki oturum da yazılmalı',
        );
        expect(sessions, hasLength(2), reason: 'A ikinci kez yazılmamalı');
        expect(prefs.getString('timer_pending_intervals'), isNull);
      },
    );

    test('kuyruktaki id, oturum id olarak kullanılır (idempotency anahtarı)', () async {
      const nativeId = '33333333-3333-4333-8333-333333333333';
      final s = DateTime.now().subtract(const Duration(hours: 1));
      final e = s.add(const Duration(minutes: 10));
      final (container, studyRepo, profile) = await _buildContainer({
        'timer_fg_mode': 'idle',
        'timer_pending_intervals':
            '[{"id":"$nativeId","start":"${s.toIso8601String()}",'
            '"end":"${e.toIso8601String()}","subject":""}]',
      });
      final timerSub = container.listen(studyTimerProvider, (_, _) {});
      addTearDown(timerSub.close);
      await Future<void>.delayed(const Duration(milliseconds: 40));

      final sessions = await studyRepo.watchUserSessions(profile.id).first;
      expect(
        sessions.single.id,
        nativeId,
        reason: 'native UUID study_sessions.id olmalı — upsert(onConflict:id) '
            'ancak böyle tekrar yazımı aynı satıra düşürür',
      );
    });
  });
}
