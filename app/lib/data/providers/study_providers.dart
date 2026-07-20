import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Presence;
import 'package:uuid/uuid.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../core/config/supabase_config.dart';
import '../../core/background/timer_foreground_service.dart';
import '../../core/l10n/system_localizations.dart';
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
import '../models/user_study_summary.dart';
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

/// Giriş yapan kullanıcının **sıcak pencere** oturumları (son 90 gün, yeni → eski).
/// Ömür boyu / yıl toplamları için [userStudySummaryProvider].
final userSessionsProvider = StreamProvider<List<StudySession>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return Stream.value(const []);
  return ref.watch(studyRepositoryProvider).watchUserSessions(user.id);
});

/// Hafif özet: lifetime / bu yıl / 90g saniye (RPC veya bellek-içi).
final userStudySummaryProvider = FutureProvider<UserStudySummary>((ref) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return UserStudySummary.empty;
  // Yeni oturum kaydı sonrası özeti yenile.
  ref.watch(userSessionsProvider);
  return ref.watch(studyRepositoryProvider).fetchUserStudySummary(user.id);
});

/// Kullanıcının sınıfının **per-user-per-gün** toplamları (grup geneli
/// istatistik/sıralama/seri için). Ham oturumlar artık akıtılmaz; veri sunucuda
/// toplanır (F1). Leaderboard, grup serisi ve trend bundan hesaplanır.
final groupDailyStatsProvider = StreamProvider<List<DailyStat>>((ref) {
  final group = ref.watch(userGroupProvider).value;
  if (group == null) return Stream.value(const []);
  return ref.watch(studyRepositoryProvider).watchGroupDailyStats(group.id);
});

/// OPT N3: oturum listesinden tek sefer `gün → saniye` haritası.
/// Streak / bugün / grafikler bunu paylaşır (çoklu O(n) taramayı keser).
final dailyTotalsProvider = Provider<Map<DateTime, int>>((ref) {
  final sessions = ref.watch(userSessionsProvider).value ?? const [];
  return dailyTotals(sessions);
});

/// Kullanıcının bugün KAYDEDİLMİŞ toplam süresi (saniye). Devam eden oturum hariç
/// (canlı kısım UI'da anlık eklenir).
final todayRecordedSecondsProvider = Provider<int>((ref) {
  final totals = ref.watch(dailyTotalsProvider);
  final today = dayOf(DateTime.now());
  return totals[today] ?? 0;
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
  final totals = ref.watch(dailyTotalsProvider);
  return currentStreak(sessions, goalSeconds, totals: totals);
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

enum TimerVerification {
  idle,
  pending,
  verified,
  statisticsOnly,
  updateRequired,
}

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
    this.liveRunId,
    this.liveRunToken,
    this.verification = TimerVerification.idle,
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
  final String? liveRunId;
  final String? liveRunToken;
  final TimerVerification verification;

  bool get isVerifiedRun => liveRunId != null && liveRunToken != null;

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
    String? liveRunId,
    String? liveRunToken,
    bool clearLiveRun = false,
    TimerVerification? verification,
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
      liveRunId: clearLiveRun ? null : (liveRunId ?? this.liveRunId),
      liveRunToken: clearLiveRun ? null : (liveRunToken ?? this.liveRunToken),
      verification: verification ?? this.verification,
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
  // Widget'ın native Chronometer'ı için güvenilir epoch-millis anahtarı.
  static const _kActiveStartedAtMs = 'timer_active_started_at_ms';
  static const _kActiveLiveRunId = 'timer_active_live_run_id';
  static const _kActiveLiveRunToken = 'timer_active_live_run_token';
  static const _kActiveStartOrigin = 'timer_active_start_origin';

  /// Native `StudyTimerService` ile çift yönlü method channel: Dart→native
  /// (start/stop), native→Dart (`reconcile`).
  static const MethodChannel _timerChannel = MethodChannel(
    'com.manilmax.online_study_room/timer',
  );

  Timer? _tick;
  Timer? _widgetRefreshDebounce;

  /// WP-167: soğuk açılış auth-retry gecikmesi; dispose'ta iptal edilmezse
  /// widget testlerinde FakeTimer sızıntısı oluşur.
  Timer? _authRetryTimer;
  Completer<void>? _authRetryCompleter;
  StreamSubscription<TimerNotificationAction>? _notificationCommands;
  AppLifecycleListener? _lifecycleListener;
  bool _disposed = false;
  Future<void>? _verifiedStartFuture;

  /// WP-241: sayaç reconcile yarışı koruması.
  /// [_localTimerMutationAt]: Dart'ın kendi start/stop'unu en son yaptığı an.
  /// Bu pencere içinde native'in ürettiği `reconcile` broadcast'i state'i
  /// EZMEZ (Dart zaten native'i sürdü, durum tutarlı). [_reconcileInFlight]:
  /// eşzamanlı reconcile çağrılarını tek bir çalışmaya birleştirir (sıra-dışı
  /// çalışıp state'i bozmasınlar).
  DateTime? _localTimerMutationAt;
  Future<void>? _reconcileInFlight;

  /// Dart-origin start/stop sonrası native reconcile'ın state'i ezmemesi için
  /// bastırma penceresi. Ard arda işlemi kapsayacak kadar uzun, gerçek
  /// bildirim/widget işlemini geciktirmeyecek kadar kısa.
  static const _localMutationGuard = Duration(milliseconds: 1500);

  // Süre kaynağı ürün açısından fark yaratmaz: manuel giriş, uygulama içi
  // sayaç ve native sayaç aynı XP/başarım yolunu kullanır. Eski live-run
  // altyapısı geçmiş kayıtları okuyabilmek için DB'de kalır; yeni sayaçlar
  // artık ona başvurmaz.
  bool get _verifiedServerAvailable => false;

  /// Auth henüz yoksa 400ms bekler; dispose olursa Timer iptal + await serbest.
  Future<void> _awaitAuthRetryWindow() {
    _cancelAuthRetryWindow();
    final completer = Completer<void>();
    _authRetryCompleter = completer;
    _authRetryTimer = Timer(const Duration(milliseconds: 400), () {
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  void _cancelAuthRetryWindow() {
    _authRetryTimer?.cancel();
    _authRetryTimer = null;
    final pending = _authRetryCompleter;
    _authRetryCompleter = null;
    if (pending != null && !pending.isCompleted) {
      pending.complete();
    }
  }

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
    // Native foreground servis (widget/bildirim Başlat-Durdur) uygulama AÇIKKEN de
    // anında yansısın diye native taraf `reconcile` çağırır; biz bu method channel
    // çağrısında arka plan durumunu uzlaştırırız. Uygulama kapalıyken tetiklenmez;
    // aralıklar app açılışında kuyruğu işlenir.
    try {
      _timerChannel.setMethodCallHandler((call) async {
        if (call.method == 'reconcile') {
          await _syncBackgroundTimerState();
        }
      });
    } catch (_) {
      // Platform kanalı olmayan test/web hostu.
    }
    ref.onDispose(() {
      _disposed = true;
      _tick?.cancel();
      _widgetRefreshDebounce?.cancel();
      _cancelAuthRetryWindow();
      _notificationCommands?.cancel();
      _lifecycleListener?.dispose();
      try {
        _timerChannel.setMethodCallHandler(null);
      } catch (_) {}
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
    ref.listen(userGroupProvider, (prev, next) {
      if (next.hasValue) _scheduleStatsWidgetRefresh();
      // Widget/bildirim start sırasında group henüz yüklenmemiş olabilir;
      // _publishPresence sessizce no-op olur. Grup hazır olunca bir kez
      // yeniden yaz (H3 — kamp ateşi / şu an çalışanlar).
      final group = next.asData?.value;
      if (group != null && state.isRunning && state.startedAt != null) {
        _publishPresence(
          status: state.phase == TimerPhase.work
              ? PresenceStatus.studying
              : PresenceStatus.onBreak,
          startedAt: state.startedAt,
        );
      }
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
      liveRunId: prefs.getString(_kActiveLiveRunId),
      liveRunToken: prefs.getString(_kActiveLiveRunToken),
      verification: prefs.getString(_kActiveLiveRunToken) == null
          ? (activeStartedAt == null
                ? TimerVerification.idle
                : TimerVerification.statisticsOnly)
          : TimerVerification.verified,
    );
    ObservabilityService.instance.timerRestore(
      hadActiveTimer: activeStartedAt != null,
    );
    Future.microtask(() async {
      // WP-136: soğuk açılışta store'dan türet (resume bekleme).
      await _syncBackgroundTimerState();
      if (_disposed) return;
      // Auth geç gelebilir → pending kuyruk için kısa yeniden deneme.
      // WP-167: Future.delayed dispose'ta iptal edilmiyordu → FakeTimer sızıntısı.
      if (ref.read(authStateProvider).value == null) {
        await _awaitAuthRetryWindow();
        if (!_disposed) await _syncBackgroundTimerState();
      }
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

  Future<void> _onAppResumed() => _syncBackgroundTimerState();

  /// Arka plandaki (FGS) durum ile ana isolate'i uzlaştırır: önce app-kapalı
  /// Durdur/Başlat toggle'ının etkilerini ([_reconcileBackgroundTimer]), sonra
  /// widget'ın tek-atımlık başlat/durdur komutunu ([_processPendingExternalCommand])
  /// işler. Hem soğuk açılışta hem onResume/onTaskData'da çağrılır.
  Future<void> _syncBackgroundTimerState() async {
    if (_disposed) return;
    // WP-241: Dart kendi start/stop'unu yeni yaptıysa, native durumu Dart'la
    // zaten tutarlı (Dart native'i sürdü). O işlemin tetiklediği native
    // `reconcile` broadcast'i buraya düşünce state'i yeniden türetip ezmesin —
    // ard arda başlat/durdur'da sayaç donması ve çift sayımın kök nedeni buydu.
    // Gerçek bildirim/widget işlemi bu pencereyi set etmez → normal işlenir.
    final mutatedAt = _localTimerMutationAt;
    if (mutatedAt != null &&
        DateTime.now().difference(mutatedAt) < _localMutationGuard) {
      return;
    }
    await _reconcileBackgroundTimer();
    if (_disposed) return;
    await _processPendingExternalCommand();
  }

  /// WP-241: eşzamanlı reconcile çağrılarını tek çalışmaya birleştirir.
  /// Native ard arda birden çok broadcast gönderince, iç içe geçen `await`'ler
  /// state'i sıra-dışı ezmesin diye çağıranlar aynı future'ı bekler.
  Future<void> _reconcileBackgroundTimer() {
    if (_disposed) return Future<void>.value();
    final existing = _reconcileInFlight;
    if (existing != null) return existing;
    final future = _reconcileBackgroundTimerImpl().whenComplete(() {
      _reconcileInFlight = null;
    });
    _reconcileInFlight = future;
    return future;
  }

  /// FGS bildiriminden gelen app-kapalı Durdur↔Başlat toggle'ını uzlaştırır:
  /// (1) Durdur ile üretilmiş tamamlanmış çalışma aralıklarını oturum olarak
  /// kaydeder; (2) FGS moduna göre sayacın çalışır/durur durumunu düzeltir.
  /// Server-authoritative kayıt korunur — arka plan yalnız aralık verisini
  /// kuyruğa yazar, gerçek oturum yazımı burada (kimlik doğrulamalı) yapılır.
  Future<void> _reconcileBackgroundTimerImpl() async {
    if (_disposed) return;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.reload();
    if (_disposed) return;

    // 1. App-kapalı Durdur'ların ürettiği tamamlanmış aralıkları oturum yaz.
    // Kimlik henüz hazır değilse kuyruğu KORU (clear yarışı yok — WP-136).
    final raw = prefs.getString(TimerForegroundService.pendingIntervalsKey);
    if (raw != null && ref.read(authStateProvider).value != null) {
      var recordedOk = true;
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final entry in decoded) {
            if (_disposed) return;
            if (entry is! Map) continue;
            final runToken = entry['runToken']?.toString();
            final action = entry['action']?.toString();
            if (runToken != null && runToken.isNotEmpty && action != null) {
              try {
                final repo = ref.read(studyRepositoryProvider);
                switch (action) {
                  case 'pause':
                    await repo.pauseLiveRun(runToken);
                  case 'resume':
                    await repo.resumeLiveRun(runToken);
                  case 'finalize':
                    await _finalizeVerifiedRun(runToken);
                  default:
                    throw const FormatException('unknown verified command');
                }
              } catch (_) {
                recordedOk = false;
              }
              continue;
            }
            final start = DateTime.tryParse(entry['start']?.toString() ?? '');
            final end = DateTime.tryParse(entry['end']?.toString() ?? '');
            final subjectRaw = entry['subject']?.toString();
            final subject = (subjectRaw == null || subjectRaw.isEmpty)
                ? null
                : subjectRaw;
            if (start != null && end != null && end.isAfter(start)) {
              try {
                await _recordSession(start, end, subject);
                final origin = entry['origin']?.toString();
                final build = await _clientBuildNumber();
                await ref
                    .read(studyRepositoryProvider)
                    .recordVerifiedSessionRollout(
                      platform: _rolloutPlatform,
                      clientBuild: build,
                      capability: true,
                      origin: origin == 'native_widget'
                          ? LiveStartOrigin.nativeWidget
                          : LiveStartOrigin.nativeNotification,
                      outcome: LiveRolloutOutcome.unverifiedFallback,
                    );
              } catch (_) {
                recordedOk = false;
              }
            }
          }
        }
      } catch (_) {
        // Bozuk kuyruk yok sayılır (aşağıda temizlenir).
        recordedOk = true;
      }
      // WP-136: yalnız başarılı (veya bozuk) kuyruk temizlenir; partial fail korunur.
      if (recordedOk) {
        await prefs.remove(TimerForegroundService.pendingIntervalsKey);
      }
    }
    if (_disposed) return;
    // Pending yazımı sonrası store'u yeniden oku (SSOT).
    await prefs.reload();
    if (_disposed) return;

    // 2. SSOT: started_at(_ms) + fg_mode → Dart state türet.
    // WP-135 sonrası native yazımlar commit; yine de keys önceliklidir.
    final hasActiveStart =
        (prefs.getString(_kActiveStartedAt)?.isNotEmpty ?? false) ||
        (prefs.getInt(_kActiveStartedAtMs) ?? 0) > 0;
    final fgModeRaw = prefs.getString(TimerForegroundService.fgModeKey);
    final fgMode = fgModeRaw ?? (hasActiveStart ? 'running' : 'idle');

    if (fgMode == 'idle' || !hasActiveStart) {
      if (state.isRunning && !hasActiveStart) {
        // Gerçek app-kapalı Durdur: native started_at sildi, Dart hâlâ running.
        _finish();
      } else if (state.isRunning && hasActiveStart && fgMode == 'idle') {
        // Nadir tutarsızlık: start keys var ama fg idle — native'i yeniden it.
        final started = state.startedAt;
        if (started != null) {
          unawaited(
            TimerForegroundService.start(
              startedAt: started,
              mode: state.mode.name,
              phase: state.phase.name,
              cycle: state.cycle,
              subjectId: state.subjectId,
              liveRunId: state.liveRunId,
              liveRunToken: state.liveRunToken,
              startOrigin: prefs.getString(_kActiveStartOrigin) ?? 'dart_app',
            ),
          );
        }
      }
      return;
    }

    // running + hasActiveStart: store'dan UI/presence/widget hizala.
    final ms = prefs.getInt(_kActiveStartedAtMs) ?? 0;
    final fgStart =
        DateTime.tryParse(prefs.getString(_kActiveStartedAt) ?? '') ??
        (ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms) : null);
    final fgPhase = TimerPhase.values.firstWhere(
      (phase) => phase.name == prefs.getString(_kActivePhase),
      orElse: () => TimerPhase.work,
    );
    final fgCycle = (prefs.getInt(_kActiveCycle) ?? 1)
        .clamp(kMinPomodoroCycles, kMaxPomodoroCycles)
        .toInt();
    final fgModeName = prefs.getString(_kActiveMode);
    final fgLiveRunId = prefs.getString(_kActiveLiveRunId);
    final fgLiveRunToken = prefs.getString(_kActiveLiveRunToken);
    final fgTimerMode = TimerMode.values.firstWhere(
      (m) => m.name == fgModeName,
      orElse: () => state.mode,
    );
    final stateNeedsNativeUpdate =
        !state.isRunning ||
        state.startedAt != fgStart ||
        state.phase != fgPhase ||
        state.cycle != fgCycle ||
        state.mode != fgTimerMode;
    if (fgStart != null && stateNeedsNativeUpdate) {
      state = state.copyWith(
        isRunning: true,
        startedAt: fgStart,
        phase: fgPhase,
        cycle: fgCycle,
        mode: fgTimerMode,
        accumulatedSeconds: 0,
        lastUpdatedAt: DateTime.now(),
        liveRunId: fgLiveRunId,
        liveRunToken: fgLiveRunToken,
        clearLiveRun: fgLiveRunToken == null,
        verification: fgLiveRunToken == null
            ? TimerVerification.statisticsOnly
            : TimerVerification.verified,
      );
      _persistActiveTimer();
      _publishPresence(
        status: fgPhase == TimerPhase.work
            ? PresenceStatus.studying
            : PresenceStatus.onBreak,
        startedAt: fgStart,
      );
      _startTick();
      unawaited(_syncTimerSurfaces());
    }
  }

  /// Bildirim/widget aksiyonunun [SharedPreferences]'e yazdığı bekleyen
  /// Durdur/Başlat komutunu işler. Hem uygulama öne gelince (onResume) hem de
  /// soğuk açılışta ([build] içindeki microtask) çağrılır; komut tek seferliktir
  /// (işlenince temizlenir).
  Future<void> _processPendingExternalCommand() async {
    if (_disposed) return;
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
      // App-kapalı basılan Durdur'da gerçek durdurma anını (pending.at) kullan.
      await stop(at: pending.at);
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
    // WP-241: Dart-origin mutation; native'in bunun ardından göndereceği
    // reconcile broadcast'i state'i ezmesin.
    _localTimerMutationAt = now;
    state = state.copyWith(
      isRunning: true,
      startedAt: now,
      phase: TimerPhase.work,
      cycle: 1,
      accumulatedSeconds: 0,
      lastUpdatedAt: now,
      clearLiveRun: true,
      verification: TimerVerification.idle,
    );
    _persistActiveTimer();
    // Native broadcast / apply yarışında reconcile'ın idle sanmaması için
    // fg_mode'u Dart tarafında da hemen running yaz.
    ref
        .read(sharedPreferencesProvider)
        .setString(TimerForegroundService.fgModeKey, 'running');
    unawaited(
      TimerForegroundService.start(
        startedAt: now,
        mode: state.mode.name,
        phase: state.phase.name,
        cycle: state.cycle,
        subjectId: state.subjectId,
        startOrigin: 'dart_app',
      ),
    );
    _publishPresence(status: PresenceStatus.studying, startedAt: now);
    _startTick();
    unawaited(_showTimerSurfaces(requestPermission: true));
    if (_verifiedServerAvailable) {
      final requestId = _uuid.v4();
      _verifiedStartFuture = _startVerifiedRun(requestId);
    } else {
      _verifiedStartFuture = null;
    }
  }

  Future<int> _clientBuildNumber() async {
    try {
      return int.tryParse((await PackageInfo.fromPlatform()).buildNumber) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  String get _rolloutPlatform {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.windows => 'windows',
      _ => 'other',
    };
  }

  Future<void> _startVerifiedRun(String requestId) async {
    final user = ref.read(authStateProvider).value;
    if (user == null || !state.isRunning) return;
    final repo = ref.read(studyRepositoryProvider);
    final build = await _clientBuildNumber();
    try {
      final config = await repo.fetchVerifiedSessionConfig();
      if (config.minimumVerifiedXpBuild case final minimum?
          when build < minimum) {
        if (state.isRunning) {
          state = state.copyWith(
            verification: TimerVerification.updateRequired,
          );
          _persistActiveTimer();
        }
        await repo.recordVerifiedSessionRollout(
          platform: _rolloutPlatform,
          clientBuild: build,
          capability: true,
          origin: LiveStartOrigin.dartApp,
          outcome: LiveRolloutOutcome.unverifiedFallback,
        );
        return;
      }
      final groupId = ref.read(userGroupProvider).value?.id;
      LiveStudyRun run;
      try {
        run = await repo.startLiveRun(
          userId: user.id,
          clientRequestId: requestId,
          groupId: groupId,
          subjectId: state.subjectId,
          clientBuild: build,
        );
      } catch (_) {
        // Ağ cevabı kaybı: aynı idempotency anahtarıyla bir kez daha sor.
        run = await repo.startLiveRun(
          userId: user.id,
          clientRequestId: requestId,
          groupId: groupId,
          subjectId: state.subjectId,
          clientBuild: build,
        );
      }
      if (!state.isRunning || _disposed) return;
      state = state.copyWith(
        liveRunId: run.id,
        liveRunToken: run.runToken,
        verification: TimerVerification.verified,
      );
      _persistActiveTimer();
      await TimerForegroundService.start(
        startedAt: state.startedAt!,
        mode: state.mode.name,
        phase: state.phase.name,
        cycle: state.cycle,
        subjectId: state.subjectId,
        liveRunId: run.id,
        liveRunToken: run.runToken,
        startOrigin: 'dart_app',
      );
      await repo.recordVerifiedSessionRollout(
        platform: _rolloutPlatform,
        clientBuild: build,
        capability: true,
        origin: LiveStartOrigin.dartApp,
      );
    } catch (_) {
      if (state.isRunning && !_disposed) {
        state = state.copyWith(verification: TimerVerification.statisticsOnly);
        _persistActiveTimer();
      }
      await repo
          .recordVerifiedSessionRollout(
            platform: _rolloutPlatform,
            clientBuild: build,
            capability: true,
            origin: LiveStartOrigin.dartApp,
            outcome: LiveRolloutOutcome.unverifiedFallback,
          )
          .catchError((_) {});
    }
  }

  /// Kullanıcı elle durdurur: çalışma fazındaysa geçen süreyi kaydet, çevrimdışına çek.
  ///
  /// [at]: durdurma gerçekten ne zaman istendi. Bildirim/widget "Durdur"u app
  /// kapalıyken basıldıysa o an buradan gelir; yoksa (uygulama içi Durdur) şimdi.
  /// Böylece app-kapalı durdurmada, uygulamanın açıldığı ana kadar geçen süre
  /// yanlışlıkla oturuma eklenmez.
  Future<void> stop({DateTime? at}) async {
    if (!state.isRunning) {
      // WP-233: uygulama ÖNPLANDAYKEN bildirimden Başlat'a basılırsa resume
      // olayı hiç tetiklenmez, dolayısıyla native SSOT bu isolate'e adopte
      // edilmez ve state.isRunning false kalır. Eskiden burada sessizce
      // dönerdik → kullanıcı sayacı uygulama içinden durduramıyordu.
      // Pes etmeden önce native durumla bir kez uzlaş.
      await _reconcileBackgroundTimer();
      if (_disposed || !state.isRunning) return;
    }
    final startedAt = state.startedAt;
    final subjectId = state.subjectId;
    final wasWork = state.phase == TimerPhase.work;
    final end = (at != null && startedAt != null && at.isAfter(startedAt))
        ? at
        : DateTime.now();

    await _verifiedStartFuture;

    // WP-104: oturum kaydını native FGS teardown (_finish → STOP_SILENT) öncesine
    // al. Süreç erken ölürse bile offline-first cache/outbox oturumu tutar;
    // STOP_SILENT kuyruğa interval yazmadığı için çift kayıt üretmez.
    if (wasWork && startedAt != null) {
      if (state.liveRunToken case final token?) {
        await _finalizeVerifiedRun(token);
      } else {
        await _recordSession(startedAt, end, subjectId);
      }
    }
    _finish();
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
    await _verifiedStartFuture;
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

    if (state.liveRunToken case final token?) {
      try {
        if (t.finished) {
          await _finalizeVerifiedRun(token);
        } else if (t.nextPhase == TimerPhase.rest) {
          await ref.read(studyRepositoryProvider).pauseLiveRun(token);
        } else {
          await ref.read(studyRepositoryProvider).resumeLiveRun(token);
        }
      } catch (_) {
        state = state.copyWith(verification: TimerVerification.statisticsOnly);
      }
    }

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
    if (t.recordWork && !state.isVerifiedRun) {
      await _recordSession(startedAt, phaseEnd, subjectId);
    }
  }

  Future<void> _finalizeVerifiedRun(String token) async {
    final repo = ref.read(studyRepositoryProvider);
    final build = await _clientBuildNumber();
    try {
      await repo.finalizeLiveRun(token);
      await repo.recordVerifiedSessionRollout(
        platform: _rolloutPlatform,
        clientBuild: build,
        capability: true,
        outcome: LiveRolloutOutcome.verifiedFinalize,
      );
      ref.invalidate(userSessionsProvider);
    } catch (_) {
      await repo
          .recordVerifiedSessionRollout(
            platform: _rolloutPlatform,
            clientBuild: build,
            capability: true,
            outcome: LiveRolloutOutcome.finalizeFailure,
          )
          .catchError((_) {});
      rethrow;
    }
  }

  /// Sayacı durdurur (kayıt yapmadan): timer'ı iptal et, çevrimdışına çek.
  void _finish({TimerEvent? lastEvent}) {
    _tick?.cancel();
    _tick = null;
    // WP-241: Dart-origin durdurma; ardından gelen native STOP broadcast'inin
    // reconcile'ı state'i tekrar "çalışıyor"a çevirmesin (durdurma yarışı).
    _localTimerMutationAt = DateTime.now();
    state = state.copyWith(
      isRunning: false,
      clearStartedAt: true,
      phase: TimerPhase.work,
      cycle: 1,
      eventSeq: lastEvent != null ? state.eventSeq + 1 : state.eventSeq,
      lastEvent: lastEvent,
      clearLiveRun: true,
      verification: TimerVerification.idle,
    );
    _clearActiveTimer();
    ref
        .read(sharedPreferencesProvider)
        .setString(TimerForegroundService.fgModeKey, 'idle');
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
      // WP-104: yerel satırda updatedAt zorunlu (cache bayatlama eşiği).
      updatedAt: DateTime.now(),
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
    prefs.setInt(_kActiveStartedAtMs, state.startedAt!.millisecondsSinceEpoch);
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
    if (state.liveRunId != null) {
      prefs.setString(_kActiveLiveRunId, state.liveRunId!);
    } else {
      prefs.remove(_kActiveLiveRunId);
    }
    if (state.liveRunToken != null) {
      prefs.setString(_kActiveLiveRunToken, state.liveRunToken!);
    } else {
      prefs.remove(_kActiveLiveRunToken);
    }
    prefs.setString(_kActiveStartOrigin, 'dart_app');
  }

  void _clearActiveTimer() {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.remove(_kActiveStartedAt);
    prefs.remove(_kActiveStartedAtMs);
    prefs.remove(_kActiveMode);
    prefs.remove(_kActivePhase);
    prefs.remove(_kActiveCycle);
    prefs.remove(_kActiveSubject);
    prefs.remove(_kActiveAccumulated);
    prefs.remove(_kActiveCommandSeq);
    prefs.remove(_kActiveUpdatedAt);
    prefs.remove(_kActiveLiveRunId);
    prefs.remove(_kActiveLiveRunToken);
    prefs.remove(_kActiveStartOrigin);
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
    if (_disposed) return;
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
    if (_disposed) return;
    // Android home_widget yoksa (Windows/web) projeksiyon + kanal maliyeti sıfır.
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final l10n = await loadSystemLocalizations();
    final widgetService = ref.read(androidWidgetServiceProvider);
    final projection = ref.read(canonicalStatsProjectionProvider);
    final dailyGoalSeconds = ref.read(dailyGoalMinutesProvider) * 60;
    final dailyPercent = _goalPercent(
      projection.todaySeconds,
      dailyGoalSeconds,
    );
    final user = ref.read(authStateProvider).value;
    final group = ref.read(userGroupProvider).value;
    final members = ref.read(groupMembersProvider).value ?? const <Profile>[];
    final todayTotals = CanonicalGroupStatsProjection.fromDailyStats(
      ref.read(groupDailyStatsProvider).value ?? const <DailyStat>[],
    ).secondsByUser;
    final names = {for (final member in members) member.id: member.displayName};
    final rows = todayTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final groupGoalSeconds = (group?.dailyGoalMinutes ?? 0) * 60;
    final groupTodaySeconds = todayTotals.values.fold<int>(0, (a, b) => a + b);
    final groupPercent = _goalPercent(groupTodaySeconds, groupGoalSeconds);
    await widgetService.saveSnapshot(
      AndroidWidgetSnapshot.goals(
        l10n: l10n,
        dailyPercent: '$dailyPercent%',
        dailyDetail:
            '${_formatWidgetDuration(projection.todaySeconds, l10n)} / '
            '${_formatWidgetDuration(dailyGoalSeconds, l10n)}',
        groupPercent: group == null ? '0%' : '$groupPercent%',
        groupDetail: group == null
            ? l10n.commonBirGrubaKatil
            : groupGoalSeconds == 0
            ? l10n.commonGrupHedefiBelirlenmedi
            : '${_formatWidgetDuration(groupTodaySeconds, l10n)} / '
                  '${_formatWidgetDuration(groupGoalSeconds, l10n)}',
      ),
    );
    final ownRank = user == null
        ? l10n.commonSiralamaOlusuncaBuradaGorunur
        : _rankLabel(rows, user.id, l10n);
    await widgetService.saveSnapshot(
      AndroidWidgetSnapshot.leaderboard(
        l10n: l10n,
        rows: rows.take(3).map((entry) {
          final name = names[entry.key] ?? l10n.commonGrupUyesi;
          return '$name · ${_formatWidgetDuration(entry.value, l10n)}';
        }).toList(),
        myRank: ownRank,
      ),
    );
    await widgetService.refresh(
      widgets: const [
        StudyHomeWidget.stats,
        StudyHomeWidget.groupGoal,
        StudyHomeWidget.leaderboard,
      ],
    );
  }

  int _goalPercent(int currentSeconds, int goalSeconds) {
    if (goalSeconds <= 0) return 0;
    return ((currentSeconds / goalSeconds) * 100).floor();
  }

  String _rankLabel(
    List<MapEntry<String, int>> rows,
    String userId,
    AppLocalizations l10n,
  ) {
    final index = rows.indexWhere((entry) => entry.key == userId);
    return index < 0
        ? l10n.commonSiralamaOlusuncaBuradaGorunur
        : '#${index + 1}';
  }

  String _formatWidgetDuration(int totalSeconds, AppLocalizations l10n) {
    final seconds = totalSeconds.clamp(0, 1 << 31);
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) {
      return '${l10n.commonHourCount(hours)} '
          '${l10n.commonMinuteCount(minutes)}';
    }
    return l10n.commonMinuteCount(minutes);
  }

  Future<void> _syncTimerNotification() async {
    // Sayaç bildirimi artık foreground service'in TEK bildirimidir (canlı akan
    // süre + Durdur butonu; TimerForegroundService/_TimerTask yönetir, app
    // kapalıyken bile). Burada yalnız eski flutter_local_notifications
    // bildirimini (varsa) temizleriz ki çift bildirim çıkmasın.
    if (!state.isRunning || state.startedAt == null) {
      await ref.read(timerNotificationServiceProvider).cancel();
    }
  }

  Future<void> _syncTimerWidget() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final l10n = await loadSystemLocalizations();
    final widgetService = ref.read(androidWidgetServiceProvider);
    if (!state.isRunning || state.startedAt == null) {
      await widgetService.saveSnapshot(
        AndroidWidgetSnapshot.timer(
          l10n: l10n,
          elapsed: '00:00:00',
          status: l10n.commonCalismaHazir,
          action: l10n.desktopBaslat,
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
        l10n: l10n,
        elapsed: formatHms(remaining ?? elapsed),
        status: state.phase == TimerPhase.rest
            ? l10n.desktopMola
            : l10n.commonCalsyor,
        action: l10n.profileDurdur,
      ),
    );
    await widgetService.refresh(widgets: const [StudyHomeWidget.timer]);
  }
}

final studyTimerProvider =
    NotifierProvider<StudyTimerNotifier, StudyTimerState>(
      StudyTimerNotifier.new,
    );
