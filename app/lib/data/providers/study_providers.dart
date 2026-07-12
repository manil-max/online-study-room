import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Presence;
import 'package:uuid/uuid.dart';

import 'package:flutter/widgets.dart';

import '../../core/config/supabase_config.dart';
import '../../core/background/timer_foreground_service.dart';
import '../../core/notifications/timer_external_command_store.dart';
import '../../core/notifications/timer_notification_service.dart';
import '../../core/observability/observability_service.dart';
import '../../core/prefs/app_prefs.dart';
import '../../core/stats/canonical_stats_projection.dart';
import '../../core/stats/study_stats.dart';
import '../../core/utils/duration_format.dart';
import '../../features/android_widgets/android_widget_service.dart';
import '../models/daily_stat.dart';
import '../models/presence.dart';
import '../models/profile.dart';
import '../models/study_session.dart';
import '../repositories/study_repository.dart';
import '../repositories/offline/offline_first_study_repository.dart';
import '../repositories/in_memory/in_memory_study_repository.dart';
import '../repositories/supabase/supabase_study_repository.dart';
import 'offline_providers.dart';
import 'auth_providers.dart';
import 'group_providers.dart';
import 'presence_providers.dart';

SupabaseClient? _supabaseClientOrNull() {
  if (!SupabaseConfig.isConfigured) return null;
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
}

/// Aktif StudyRepository. Remote katman Supabase veya bellek-içi olabilir;
/// ikisinin üstüne offline-first cache sarılır.
final studyRepositoryProvider = Provider<StudyRepository>((ref) {
  final cache = ref.watch(offlineCacheStoreProvider);
  final client = _supabaseClientOrNull();
  if (client != null) {
    return OfflineFirstStudyRepository(
      remote: SupabaseStudyRepository(client),
      cache: cache,
    );
  }
  final remote = InMemoryStudyRepository();
  ref.onDispose(remote.dispose);
  return OfflineFirstStudyRepository(remote: remote, cache: cache);
});

/// Giriş yapan kullanıcının oturumları (yeni → eski).
final userSessionsProvider = StreamProvider<List<StudySession>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(studyRepositoryProvider).watchUserSessions(user.id);
});

/// Kullanıcının sınıfının **per-user-per-gün** toplamları (grup geneli
/// istatistik/sıralama/seri için). Ham oturumlar artık akıtılmaz; veri sunucuda
/// toplanır (F1). Leaderboard, grup serisi ve trend bundan hesaplanır.
final groupDailyStatsProvider = StreamProvider<List<DailyStat>>((ref) {
  final group = ref.watch(userGroupProvider).value;
  if (group == null) return Stream.value(const []);
  return ref.watch(studyRepositoryProvider).watchGroupDailyStats(group.id);
});

/// Kullanıcının bugün KAYDEDİLMİŞ toplam süresi (saniye). Devam eden oturum hariç
/// (canlı kısım UI'da anlık eklenir).
final todayRecordedSecondsProvider = Provider<int>((ref) {
  final sessions = ref.watch(userSessionsProvider).value ?? const [];
  final now = DateTime.now();
  return sessions
      .where((s) => isSameDay(s.day, now))
      .fold<int>(0, (sum, s) => sum + s.durationSeconds);
});

/// Kullanıcının günlük hedefi (dakika). Profil yoksa varsayılan (§3.7).
final dailyGoalMinutesProvider = Provider<int>((ref) {
  return ref.watch(authStateProvider).value?.dailyGoalMinutes ??
      kDefaultDailyGoalMinutes;
});

/// Günlük hedefe bağlı güncel seri (üst üste hedef tutturulan gün, §3.7).
final currentStreakProvider = Provider<int>((ref) {
  final sessions = ref.watch(userSessionsProvider).value ?? const [];
  final goalSeconds = ref.watch(dailyGoalMinutesProvider) * 60;
  return currentStreak(sessions, goalSeconds);
});

/// UI ve widget için aynı session kümesinden türetilen canonical özet.
final canonicalStatsProjectionProvider = Provider<CanonicalStatsProjection>((
  ref,
) {
  final sessions =
      ref.watch(userSessionsProvider).value ?? const <StudySession>[];
  return CanonicalStatsProjection.fromSessions(sessions);
});

/// Sınıftaki her üyenin bugün KAYDEDİLMİŞ toplam süresi (userId -> saniye).
/// Canlı sınıf ekranında "bugünkü toplam" buradan okunur; devam eden oturumun
/// anlık kısmı UI'da presence üzerinden eklenir.
final groupTodaySecondsProvider = Provider<Map<String, int>>((ref) {
  final stats = ref.watch(groupDailyStatsProvider).value ?? const [];
  return todaySecondsByUser(stats);
});

/// Sayaç modu (§2H). Kronometre yukarı sayar; geri sayım ve pomodoro hedef
/// süreye ulaşınca otomatik biter/geçiş yapar.
enum TimerMode { stopwatch, countdown, pomodoro }

/// Pomodoro fazı. Kronometre/geri sayım her zaman `work` sayılır.
enum TimerPhase { work, rest }

/// Bir faz tamamlandığında UI'ın (ses/titreşim/uyarı) tepki vermesi için sinyal.
enum TimerEvent { countdownDone, workDone, breakDone, allDone }

/// Sınırlar (dakika). UI ve mantık ortak kullanır.
const int kMinTimerMinutes = 1;
const int kMaxTimerMinutes = 180;
const int kMinPomodoroCycles = 1;
const int kMaxPomodoroCycles = 12;

/// Bir çalışma/mola fazının hedef süresi (saniye); kronometrede hedef yoktur → null.
/// Saf fonksiyon (testli).
int? timerPhaseTargetSeconds({
  required TimerMode mode,
  required TimerPhase phase,
  required int countdownMinutes,
  required int workMinutes,
  required int breakMinutes,
}) {
  switch (mode) {
    case TimerMode.stopwatch:
      return null;
    case TimerMode.countdown:
      return countdownMinutes * 60;
    case TimerMode.pomodoro:
      return (phase == TimerPhase.work ? workMinutes : breakMinutes) * 60;
  }
}

/// Bir faz hedefe ulaştığında ne olacağının saf kararı (testli). Timer/UI'dan
/// bağımsız: kayıt gerekli mi, sayaç bitti mi, sıradaki faz/döngü ne.
class PhaseTransition {
  const PhaseTransition({
    required this.finished,
    required this.recordWork,
    required this.nextPhase,
    required this.nextCycle,
    required this.event,
  });

  /// Sayaç tamamen bitti mi (geri sayım sonu / son pomodoro döngüsü).
  final bool finished;

  /// Biten çalışma aralığı `study_sessions`'a yazılacak mı (mola → false).
  final bool recordWork;

  /// Bitmediyse sıradaki faz ve döngü numarası.
  final TimerPhase nextPhase;
  final int nextCycle;
  final TimerEvent event;
}

/// Çalışan bir faz hedefe ulaştığında sıradaki geçişi hesaplar (saf, testli).
/// - countdown: biter, çalışma kaydedilir.
/// - pomodoro work: son döngüyse biter (kaydet); değilse molaya geçer (kaydet).
/// - pomodoro rest: sıradaki çalışma döngüsüne geçer (kayıt yok).
PhaseTransition nextPhaseTransition({
  required TimerMode mode,
  required TimerPhase phase,
  required int cycle,
  required int cycles,
}) {
  if (mode == TimerMode.countdown) {
    return const PhaseTransition(
      finished: true,
      recordWork: true,
      nextPhase: TimerPhase.work,
      nextCycle: 1,
      event: TimerEvent.countdownDone,
    );
  }
  if (mode == TimerMode.pomodoro && phase == TimerPhase.work) {
    final lastCycle = cycle >= cycles;
    return PhaseTransition(
      finished: lastCycle,
      recordWork: true,
      nextPhase: lastCycle ? TimerPhase.work : TimerPhase.rest,
      nextCycle: lastCycle ? 1 : cycle,
      event: lastCycle ? TimerEvent.allDone : TimerEvent.workDone,
    );
  }
  if (mode == TimerMode.pomodoro && phase == TimerPhase.rest) {
    return PhaseTransition(
      finished: false,
      recordWork: false,
      nextPhase: TimerPhase.work,
      nextCycle: cycle + 1,
      event: TimerEvent.breakDone,
    );
  }
  // Kronometre (hedefsiz) — teoride çağrılmaz; güvenli varsayılan.
  return const PhaseTransition(
    finished: true,
    recordWork: true,
    nextPhase: TimerPhase.work,
    nextCycle: 1,
    event: TimerEvent.countdownDone,
  );
}

/// Çalışma sayacının durumu (§3.5 + §2H mod/faz).
class StudyTimerState {
  const StudyTimerState({
    this.mode = TimerMode.stopwatch,
    this.isRunning = false,
    this.startedAt,
    this.subjectId,
    this.phase = TimerPhase.work,
    this.cycle = 1,
    this.countdownMinutes = 25,
    this.workMinutes = 25,
    this.breakMinutes = 5,
    this.cycles = 4,
    this.eventSeq = 0,
    this.lastEvent,
    this.accumulatedSeconds = 0,
    this.commandSeq = 0,
    this.lastUpdatedAt,
  });

  final TimerMode mode;
  final bool isRunning;

  /// Çalışırken mevcut FAZ segmentinin başlangıcı (anlık süre buradan hesaplanır).
  final DateTime? startedAt;

  /// Seçili ders (opsiyonel — null ise "derssiz"). Bkz. project.md §3.7.
  final String? subjectId;

  /// Pomodoro fazı (çalışma/mola). Diğer modlarda her zaman `work`.
  final TimerPhase phase;

  /// Pomodoro'da kaçıncı döngüdeyiz (1..cycles).
  final int cycle;

  /// Geri sayım hedefi (dakika).
  final int countdownMinutes;

  /// Pomodoro çalışma/mola süreleri (dakika) ve toplam döngü sayısı.
  final int workMinutes;
  final int breakMinutes;
  final int cycles;

  /// Her faz tamamlanışında artan sayaç + son olay (UI ses/titreşim/uyarı için).
  final int eventSeq;
  final TimerEvent? lastEvent;
  final int accumulatedSeconds;
  final int commandSeq;
  final DateTime? lastUpdatedAt;

  /// Mevcut fazın hedef süresi (saniye); kronometrede null.
  int? get phaseTargetSeconds => timerPhaseTargetSeconds(
    mode: mode,
    phase: phase,
    countdownMinutes: countdownMinutes,
    workMinutes: workMinutes,
    breakMinutes: breakMinutes,
  );

  StudyTimerState copyWith({
    TimerMode? mode,
    bool? isRunning,
    DateTime? startedAt,
    bool clearStartedAt = false,
    String? subjectId,
    bool clearSubject = false,
    TimerPhase? phase,
    int? cycle,
    int? countdownMinutes,
    int? workMinutes,
    int? breakMinutes,
    int? cycles,
    int? eventSeq,
    TimerEvent? lastEvent,
    int? accumulatedSeconds,
    int? commandSeq,
    DateTime? lastUpdatedAt,
  }) {
    return StudyTimerState(
      mode: mode ?? this.mode,
      isRunning: isRunning ?? this.isRunning,
      startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
      subjectId: clearSubject ? null : (subjectId ?? this.subjectId),
      phase: phase ?? this.phase,
      cycle: cycle ?? this.cycle,
      countdownMinutes: countdownMinutes ?? this.countdownMinutes,
      workMinutes: workMinutes ?? this.workMinutes,
      breakMinutes: breakMinutes ?? this.breakMinutes,
      cycles: cycles ?? this.cycles,
      eventSeq: eventSeq ?? this.eventSeq,
      lastEvent: lastEvent ?? this.lastEvent,
      accumulatedSeconds: accumulatedSeconds ?? this.accumulatedSeconds,
      commandSeq: commandSeq ?? this.commandSeq,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
    );
  }
}

/// Çalışma sayacını yönetir: başlat / durdur + geri sayım/pomodoro otomatik
/// faz geçişleri; her tamamlanan **çalışma** aralığını `study_sessions`'a yazar.
/// Mola fazında presence `onBreak` olur (kamp ateşi sahnesi mola→karanlık, 2G).
/// Not: süre arka planda kesintisiz sayılır (bkz. project.md §3.5).
class StudyTimerNotifier extends Notifier<StudyTimerState> {
  static const _uuid = Uuid();
  static const _kMode = 'timer_mode';
  static const _kCountdown = 'timer_countdown_min';
  static const _kWork = 'timer_work_min';
  static const _kBreak = 'timer_break_min';
  static const _kCycles = 'timer_cycles';
  static const _kActiveStartedAt = 'timer_active_started_at';
  static const _kActiveMode = 'timer_active_mode';
  static const _kActivePhase = 'timer_active_phase';
  static const _kActiveCycle = 'timer_active_cycle';
  static const _kActiveSubject = 'timer_active_subject';
  static const _kActiveAccumulated = 'timer_active_accumulated_seconds';
  static const _kActiveCommandSeq = 'timer_active_command_seq';
  static const _kActiveUpdatedAt = 'timer_active_updated_at';

  Timer? _tick;
  Timer? _widgetRefreshDebounce;
  StreamSubscription<TimerNotificationAction>? _notificationCommands;
  AppLifecycleListener? _lifecycleListener;
  bool _disposed = false;

  @override
  StudyTimerState build() {
    _notificationCommands = ref
        .read(timerNotificationServiceProvider)
        .commands
        .listen((action) {
          if (action == TimerNotificationAction.stop) {
            unawaited(stop());
          }
        });
    _lifecycleListener = AppLifecycleListener(
      onResume: () => unawaited(_onAppResumed()),
    );
    ref.onDispose(() {
      _disposed = true;
      _tick?.cancel();
      _widgetRefreshDebounce?.cancel();
      _notificationCommands?.cancel();
      _lifecycleListener?.dispose();
    });
    // Stats/leaderboard widget'ları saniyelik timer tick'iyle değil, kaynak
    // veriler değiştiğinde güncellenir. Bir oturum yazılması, senkron akışı,
    // gruba giriş/çıkış ve grup toplamlarının gelmesi aynı kısa pencereye
    // düşebileceği için native widget güncellemelerini tek olaya birleştiririz.
    ref.listen(userSessionsProvider, (_, next) {
      if (next.hasValue) _scheduleStatsWidgetRefresh();
    });
    ref.listen(groupDailyStatsProvider, (_, next) {
      if (next.hasValue) _scheduleStatsWidgetRefresh();
    });
    ref.listen(groupMembersProvider, (_, next) {
      if (next.hasValue) _scheduleStatsWidgetRefresh();
    });
    ref.listen(userGroupProvider, (_, next) {
      if (next.hasValue) _scheduleStatsWidgetRefresh();
    });
    final prefs = ref.read(sharedPreferencesProvider);
    final modeName = prefs.getString(_kMode);
    final mode = TimerMode.values.firstWhere(
      (m) => m.name == modeName,
      orElse: () => TimerMode.stopwatch,
    );
    final activeMode = TimerMode.values.firstWhere(
      (m) => m.name == prefs.getString(_kActiveMode),
      orElse: () => mode,
    );
    final activePhase = TimerPhase.values.firstWhere(
      (p) => p.name == prefs.getString(_kActivePhase),
      orElse: () => TimerPhase.work,
    );
    final activeStartedAt = DateTime.tryParse(
      prefs.getString(_kActiveStartedAt) ?? '',
    );
    final activeSubject = prefs.getString(_kActiveSubject);
    final initial = StudyTimerState(
      mode: activeStartedAt == null ? mode : activeMode,
      isRunning: activeStartedAt != null,
      startedAt: activeStartedAt,
      subjectId: activeSubject == '' ? null : activeSubject,
      phase: activeStartedAt == null ? TimerPhase.work : activePhase,
      cycle: activeStartedAt == null
          ? 1
          : (prefs.getInt(_kActiveCycle) ?? 1)
                .clamp(kMinPomodoroCycles, kMaxPomodoroCycles)
                .toInt(),
      countdownMinutes: prefs.getInt(_kCountdown) ?? 25,
      workMinutes: prefs.getInt(_kWork) ?? 25,
      breakMinutes: prefs.getInt(_kBreak) ?? 5,
      cycles: prefs.getInt(_kCycles) ?? 4,
      accumulatedSeconds: prefs.getInt(_kActiveAccumulated) ?? 0,
      commandSeq: prefs.getInt(_kActiveCommandSeq) ?? 0,
      lastUpdatedAt: DateTime.tryParse(
        prefs.getString(_kActiveUpdatedAt) ?? '',
      ),
    );
    ObservabilityService.instance.timerRestore(
      hadActiveTimer: activeStartedAt != null,
    );
    Future.microtask(() async {
      // Bildirim/widget'tan gelen Durdur/Başlat komutu eskiden yalnız onResume'da
      // işleniyordu; onResume ise SOĞUK açılışta tetiklenmez → uygulama kapalıyken
      // basılan Durdur, kullanıcı uygulamayı açsa bile işlenmezdi. Komutu init
      // anında da işle ki açılışta hemen onurlandırılsın. (Uygulama tamamen
      // kapalıyken gerçek zamanlı işleme için foreground service gerekir; o ayrı
      // iş paketi — bkz. background-timer-actions-unreliable.)
      await _processPendingExternalCommand();
      if (_disposed || !state.isRunning) return;
      _publishPresence(
        status: state.phase == TimerPhase.work
            ? PresenceStatus.studying
            : PresenceStatus.onBreak,
        startedAt: state.startedAt,
      );
      _startTick();
      unawaited(_syncTimerSurfaces());
    });
    return initial;
  }

  Future<void> _onAppResumed() => _processPendingExternalCommand();

  /// Bildirim/widget aksiyonunun [SharedPreferences]'e yazdığı bekleyen
  /// Durdur/Başlat komutunu işler. Hem uygulama öne gelince (onResume) hem de
  /// soğuk açılışta ([build] içindeki microtask) çağrılır; komut tek seferliktir
  /// (işlenince temizlenir).
  Future<void> _processPendingExternalCommand() async {
    final store = ref.read(timerExternalCommandStoreProvider);
    await store.reload();
    if (_disposed) return;
    final pending = store.pendingCommand;
    if (pending == null || pending.sequence < state.commandSeq) return;
    // Komutu önce tüket: stop() kayıt/senkron beklerken aynı komut tekrar
    // işlenmez ve soğuk açılış kuyruğu deterministik kalır.
    await store.clearCommand();

    state = state.copyWith(commandSeq: pending.sequence);
    if (pending.command == 'start' && !state.isRunning) {
      start();
    } else if (pending.command == 'stop' && state.isRunning) {
      await stop();
    }
  }

  /// Aktif dersi seçer (yalnızca sayaç dururken; null → derssiz).
  void selectSubject(String? subjectId) {
    if (state.isRunning) return;
    state = state.copyWith(
      subjectId: subjectId,
      clearSubject: subjectId == null,
    );
  }

  /// Modu değiştirir (yalnız dururken). Faz/döngü sıfırlanır, seçim kalıcılaşır.
  void setMode(TimerMode mode) {
    if (state.isRunning) return;
    state = state.copyWith(mode: mode, phase: TimerPhase.work, cycle: 1);
    ref.read(sharedPreferencesProvider).setString(_kMode, mode.name);
  }

  /// Geri sayım süresini ayarlar (dakika; yalnız dururken).
  void setCountdownMinutes(int minutes) {
    if (state.isRunning) return;
    final m = minutes.clamp(kMinTimerMinutes, kMaxTimerMinutes);
    state = state.copyWith(countdownMinutes: m);
    ref.read(sharedPreferencesProvider).setInt(_kCountdown, m);
  }

  /// Pomodoro ayarlarını değiştirir (dakika + döngü; yalnız dururken).
  void setPomodoro({int? workMinutes, int? breakMinutes, int? cycles}) {
    if (state.isRunning) return;
    final w = (workMinutes ?? state.workMinutes).clamp(
      kMinTimerMinutes,
      kMaxTimerMinutes,
    );
    final b = (breakMinutes ?? state.breakMinutes).clamp(
      kMinTimerMinutes,
      kMaxTimerMinutes,
    );
    final c = (cycles ?? state.cycles).clamp(
      kMinPomodoroCycles,
      kMaxPomodoroCycles,
    );
    state = state.copyWith(workMinutes: w, breakMinutes: b, cycles: c);
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setInt(_kWork, w);
    prefs.setInt(_kBreak, b);
    prefs.setInt(_kCycles, c);
  }

  /// Çalışmaya başla (mevcut moda göre ilk fazı kurar).
  void start() {
    if (state.isRunning) return;
    final now = DateTime.now();
    state = state.copyWith(
      isRunning: true,
      startedAt: now,
      phase: TimerPhase.work,
      cycle: 1,
      accumulatedSeconds: 0,
      lastUpdatedAt: now,
    );
    _persistActiveTimer();
    unawaited(
      TimerForegroundService.start(
        startedAt: now,
        mode: state.mode.name,
        phase: state.phase.name,
        cycle: state.cycle,
        subjectId: state.subjectId,
      ),
    );
    _publishPresence(status: PresenceStatus.studying, startedAt: now);
    _startTick();
    unawaited(_showTimerSurfaces(requestPermission: true));
  }

  /// Kullanıcı elle durdurur: çalışma fazındaysa geçen süreyi kaydet, çevrimdışına çek.
  Future<void> stop() async {
    if (!state.isRunning) return;
    final startedAt = state.startedAt;
    final subjectId = state.subjectId;
    final wasWork = state.phase == TimerPhase.work;
    _finish();
    if (wasWork && startedAt != null) {
      await _recordSession(startedAt, DateTime.now(), subjectId);
    }
  }

  void _startTick() {
    _tick?.cancel();
    // Kronometrede otomatik geçiş yok; timer yalnız geri sayım/pomodoro için.
    if (state.phaseTargetSeconds == null) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  void _onTick() {
    final target = state.phaseTargetSeconds;
    final startedAt = state.startedAt;
    if (!state.isRunning || target == null || startedAt == null) return;
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    if (elapsed >= target) {
      // Geç tetiklense bile hedef süreyi (target) kaydet → overshoot sayılmaz.
      _completePhase(target);
    }
  }

  /// Mevcut faz hedefe ulaştı: saf karara göre kaydet/geçiş yap.
  Future<void> _completePhase(int targetSeconds) async {
    final startedAt = state.startedAt;
    final subjectId = state.subjectId;
    if (startedAt == null) return;
    final phaseEnd = startedAt.add(Duration(seconds: targetSeconds));

    final t = nextPhaseTransition(
      mode: state.mode,
      phase: state.phase,
      cycle: state.cycle,
      cycles: state.cycles,
    );

    if (t.finished) {
      _finish(lastEvent: t.event);
    } else {
      final now = DateTime.now();
      state = state.copyWith(
        phase: t.nextPhase,
        cycle: t.nextCycle,
        startedAt: now,
        eventSeq: state.eventSeq + 1,
        lastEvent: t.event,
      );
      _publishPresence(
        status: t.nextPhase == TimerPhase.work
            ? PresenceStatus.studying
            : PresenceStatus.onBreak,
        startedAt: now,
      );
      _persistActiveTimer();
      _startTick();
      unawaited(_syncTimerSurfaces());
    }

    // Çalışma fazı hedefe ulaştıysa süreyi kaydet (mola kaydedilmez).
    if (t.recordWork) {
      await _recordSession(startedAt, phaseEnd, subjectId);
    }
  }

  /// Sayacı durdurur (kayıt yapmadan): timer'ı iptal et, çevrimdışına çek.
  void _finish({TimerEvent? lastEvent}) {
    _tick?.cancel();
    _tick = null;
    state = state.copyWith(
      isRunning: false,
      clearStartedAt: true,
      phase: TimerPhase.work,
      cycle: 1,
      eventSeq: lastEvent != null ? state.eventSeq + 1 : state.eventSeq,
      lastEvent: lastEvent,
    );
    _clearActiveTimer();
    unawaited(TimerForegroundService.stop());
    _publishPresence(status: PresenceStatus.offline, startedAt: null);
    unawaited(ref.read(timerNotificationServiceProvider).cancel());
    unawaited(_syncTimerWidget());
  }

  /// Tamamlanan bir aralığı `study_sessions`'a yazar.
  Future<void> _recordSession(
    DateTime start,
    DateTime end,
    String? subjectId,
  ) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final duration = end.difference(start).inSeconds;
    if (duration <= 0) return;

    await ref
        .read(studyRepositoryProvider)
        .addSession(
          StudySession(
            id: _uuid.v4(),
            userId: user.id,
            subjectId: subjectId,
            start: start,
            end: end,
            durationSeconds: duration,
            source: StudySource.live,
          ),
        );
  }

  /// Kullanıcının canlı durumunu presence deposuna yazar (hata olursa sayacı bozmaz).
  void _publishPresence({
    required PresenceStatus status,
    required DateTime? startedAt,
  }) {
    final user = ref.read(authStateProvider).value;
    final group = ref.read(userGroupProvider).value;
    if (user == null || group == null) return;

    final presence = Presence(
      userId: user.id,
      groupId: group.id,
      status: status,
      startedAt: startedAt,
      todaySeconds: ref.read(todayRecordedSecondsProvider),
    );
    // Yangına-at-unut: presence yazımı başarısız olsa bile çalışma akışı sürmeli.
    ref
        .read(presenceRepositoryProvider)
        .setPresence(presence)
        .catchError((_) {});
  }

  void _persistActiveTimer() {
    if (!state.isRunning || state.startedAt == null) return;
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(_kActiveStartedAt, state.startedAt!.toIso8601String());
    prefs.setString(_kActiveMode, state.mode.name);
    prefs.setString(_kActivePhase, state.phase.name);
    prefs.setInt(_kActiveCycle, state.cycle);
    prefs.setString(_kActiveSubject, state.subjectId ?? '');
    prefs.setInt(_kActiveAccumulated, state.accumulatedSeconds);
    prefs.setInt(_kActiveCommandSeq, state.commandSeq);
    prefs.setString(
      _kActiveUpdatedAt,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  void _clearActiveTimer() {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.remove(_kActiveStartedAt);
    prefs.remove(_kActiveMode);
    prefs.remove(_kActivePhase);
    prefs.remove(_kActiveCycle);
    prefs.remove(_kActiveSubject);
    prefs.remove(_kActiveAccumulated);
    prefs.remove(_kActiveCommandSeq);
    prefs.remove(_kActiveUpdatedAt);
  }

  Future<void> _showTimerSurfaces({bool requestPermission = false}) async {
    if (requestPermission) {
      await ref
          .read(timerNotificationServiceProvider)
          .requestPermissionIfNeeded();
    }
    await _syncTimerSurfaces();
  }

  Future<void> _syncTimerSurfaces() async {
    await Future.wait([
      _syncTimerNotification(),
      _syncTimerWidget(),
      _syncStatsWidgets(),
    ]);
  }

  void _scheduleStatsWidgetRefresh() {
    if (_disposed) return;
    _widgetRefreshDebounce?.cancel();
    _widgetRefreshDebounce = Timer(const Duration(milliseconds: 250), () {
      if (!_disposed) unawaited(_syncStatsWidgets());
    });
  }

  Future<void> _syncStatsWidgets() async {
    final widgetService = ref.read(androidWidgetServiceProvider);
    final projection = ref.read(canonicalStatsProjectionProvider);
    await widgetService.saveSnapshot(
      AndroidWidgetSnapshot.stats(
        today: 'Bugün: ${formatHuman(projection.todaySeconds)}',
        week: 'Hafta: ${formatHuman(projection.weekSeconds)}',
        streak:
            'Seri: ${projection.streakForGoal(ref.read(dailyGoalMinutesProvider) * 60)} gün',
      ),
    );
    final members = ref.read(groupMembersProvider).value ?? const <Profile>[];
    final todayTotals = CanonicalGroupStatsProjection.fromDailyStats(
      ref.read(groupDailyStatsProvider).value ?? const <DailyStat>[],
    ).secondsByUser;
    final names = {for (final member in members) member.id: member.displayName};
    final rows = todayTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    await widgetService.saveSnapshot(
      AndroidWidgetSnapshot.leaderboard(
        rows: rows.take(3).map((entry) {
          final name = names[entry.key] ?? 'Grup üyesi';
          return '$name · ${formatHuman(entry.value)}';
        }).toList(),
      ),
    );
    await widgetService.refresh(
      widgets: const [StudyHomeWidget.stats, StudyHomeWidget.leaderboard],
    );
  }

  Future<void> _syncTimerNotification() async {
    if (!state.isRunning || state.startedAt == null) {
      await ref.read(timerNotificationServiceProvider).cancel();
      return;
    }
    await ref
        .read(timerNotificationServiceProvider)
        .showRunning(_notificationSnapshot(DateTime.now()));
  }

  Future<void> _syncTimerWidget() async {
    final widgetService = ref.read(androidWidgetServiceProvider);
    if (!state.isRunning || state.startedAt == null) {
      await widgetService.saveSnapshot(
        AndroidWidgetSnapshot.timer(
          elapsed: '00:00:00',
          status: 'Çalışma hazır',
          action: 'Başlat',
        ),
      );
      await widgetService.refresh(widgets: const [StudyHomeWidget.timer]);
      return;
    }

    final now = DateTime.now();
    final startedAt = state.startedAt!;
    final elapsed = now.difference(startedAt).inSeconds;
    final target = state.phaseTargetSeconds;
    final remaining = target == null
        ? null
        : (target - elapsed).clamp(0, target).toInt();
    await widgetService.saveSnapshot(
      AndroidWidgetSnapshot.timer(
        elapsed: formatHms(remaining ?? elapsed),
        status: state.phase == TimerPhase.rest ? 'Mola' : 'Çalışıyor',
        action: 'Durdur',
      ),
    );
    await widgetService.refresh(widgets: const [StudyHomeWidget.timer]);
  }

  TimerNotificationSnapshot _notificationSnapshot(DateTime now) {
    final startedAt = state.startedAt!;
    final elapsed = now.difference(startedAt).inSeconds;
    final target = state.phaseTargetSeconds;
    final remaining = target == null
        ? null
        : (target - elapsed).clamp(0, target).toInt();
    final phaseLabel = switch (state.mode) {
      TimerMode.stopwatch => 'Çalışma',
      TimerMode.countdown => 'Geri sayım',
      TimerMode.pomodoro =>
        state.phase == TimerPhase.work
            ? 'Çalışma ${state.cycle}/${state.cycles}'
            : 'Mola',
    };
    final title = state.phase == TimerPhase.rest
        ? 'Odak Kampı molada'
        : 'Odak Kampı çalışıyor';
    return TimerNotificationSnapshot(
      title: title,
      modeLabel: switch (state.mode) {
        TimerMode.stopwatch => 'Kronometre',
        TimerMode.countdown => 'Geri sayım',
        TimerMode.pomodoro => 'Pomodoro',
      },
      phaseLabel: phaseLabel,
      startedAt: startedAt,
      elapsedSeconds: elapsed,
      remainingSeconds: remaining,
      isCountingDown: target != null,
      isRunning: state.isRunning,
      progress: target == null ? null : elapsed.clamp(0, target).toInt(),
      progressMax: target,
    );
  }
}

final studyTimerProvider =
    NotifierProvider<StudyTimerNotifier, StudyTimerState>(
      StudyTimerNotifier.new,
    );
