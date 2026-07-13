import 'epoch_clock.dart';

/// Epoch tabanlı kronometre durumu (saf model — UI yok).
///
/// Çalışırken geçen süre = `accumulatedMs + (now - segmentStartedAtMs)`.
/// Pause, segment birikimini `accumulatedMs`'e yazar ve segmenti kapatır.
class EpochStopwatchState {
  const EpochStopwatchState({
    this.segmentStartedAtMs,
    this.accumulatedMs = 0,
    this.running = false,
    this.laps = const [],
  });

  /// Çalışan segmentin duvar saati başlangıcı; pause/idle iken null.
  final int? segmentStartedAtMs;

  /// Önceki tamamlanmış segmentlerin toplamı (ms).
  final int accumulatedMs;

  final bool running;

  /// Tur bitiş anlarındaki **toplam elapsed ms** listesi (artan).
  final List<int> laps;

  static const idle = EpochStopwatchState();

  int elapsedMs(int nowMs) {
    final live = running && segmentStartedAtMs != null
        ? (nowMs - segmentStartedAtMs!).clamp(0, 1 << 62)
        : 0;
    return accumulatedMs + live;
  }

  Duration elapsed(int nowMs) => Duration(milliseconds: elapsedMs(nowMs));

  EpochStopwatchState start(int nowMs) {
    if (running) return this;
    return EpochStopwatchState(
      segmentStartedAtMs: nowMs,
      accumulatedMs: accumulatedMs,
      running: true,
      laps: laps,
    );
  }

  EpochStopwatchState pause(int nowMs) {
    if (!running) return this;
    final total = elapsedMs(nowMs);
    return EpochStopwatchState(
      segmentStartedAtMs: null,
      accumulatedMs: total,
      running: false,
      laps: laps,
    );
  }

  EpochStopwatchState resume(int nowMs) => start(nowMs);

  EpochStopwatchState toggle(int nowMs) =>
      running ? pause(nowMs) : start(nowMs);

  EpochStopwatchState reset() => EpochStopwatchState.idle;

  /// Tur kaydı: o anki toplam elapsed.
  EpochStopwatchState lap(int nowMs) {
    final e = elapsedMs(nowMs);
    if (e <= 0) return this;
    if (laps.isNotEmpty && laps.last == e) return this;
    return EpochStopwatchState(
      segmentStartedAtMs: segmentStartedAtMs,
      accumulatedMs: accumulatedMs,
      running: running,
      laps: [...laps, e],
    );
  }

  Map<String, dynamic> toMap() => {
        'segmentStartedAtMs': segmentStartedAtMs,
        'accumulatedMs': accumulatedMs,
        'running': running,
        'laps': laps,
      };

  factory EpochStopwatchState.fromMap(Map<String, dynamic> map) {
    return EpochStopwatchState(
      segmentStartedAtMs: (map['segmentStartedAtMs'] as num?)?.toInt(),
      accumulatedMs: (map['accumulatedMs'] as num?)?.toInt() ?? 0,
      running: map['running'] as bool? ?? false,
      laps: (map['laps'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
    );
  }
}

/// Kronometre motoru — [EpochClock] enjekte edilir.
class EpochStopwatchEngine {
  EpochStopwatchEngine({EpochClock? clock, EpochStopwatchState? initial})
      : _clock = clock ?? const SystemEpochClock(),
        state = initial ?? EpochStopwatchState.idle;

  final EpochClock _clock;
  EpochStopwatchState state;

  int get nowMs => _clock.nowMs();
  int get elapsedMs => state.elapsedMs(nowMs);
  bool get isRunning => state.running;

  void start() => state = state.start(nowMs);
  void pause() => state = state.pause(nowMs);
  void toggle() => state = state.toggle(nowMs);
  void reset() => state = state.reset();
  void lap() => state = state.lap(nowMs);
}
