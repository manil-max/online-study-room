/// Epoch tabanlı geri sayım (çoklu timer motoru).
///
/// Çalışırken bitiş anı [endsAtMs] mutlak epoch'tur.
/// UI her karede `max(0, endsAtMs - nowMs)` okur — tick kaybı süreyi bozmaz.
class EpochCountdownState {
  const EpochCountdownState({
    required this.durationMs,
    this.endsAtMs,
    this.remainingMsWhenPaused,
    this.running = false,
  });

  /// Toplam süre (ms).
  final int durationMs;

  /// Çalışıyorsa mutlak bitiş epoch ms.
  final int? endsAtMs;

  /// Duraklatılmışsa kalan ms.
  final int? remainingMsWhenPaused;

  final bool running;

  factory EpochCountdownState.initial(int durationMs) => EpochCountdownState(
        durationMs: durationMs,
        remainingMsWhenPaused: durationMs,
        running: false,
      );

  int remainingMs(int nowMs) {
    if (running && endsAtMs != null) {
      return (endsAtMs! - nowMs).clamp(0, durationMs);
    }
    return (remainingMsWhenPaused ?? durationMs).clamp(0, durationMs);
  }

  bool isDone(int nowMs) => remainingMs(nowMs) <= 0 && durationMs > 0;

  double progress(int nowMs) {
    if (durationMs <= 0) return 1;
    final left = remainingMs(nowMs);
    return (1 - left / durationMs).clamp(0.0, 1.0);
  }

  EpochCountdownState start(int nowMs) {
    final base = remainingMsWhenPaused ?? durationMs;
    if (base <= 0) {
      return EpochCountdownState(
        durationMs: durationMs,
        endsAtMs: null,
        remainingMsWhenPaused: 0,
        running: false,
      );
    }
    return EpochCountdownState(
      durationMs: durationMs,
      endsAtMs: nowMs + base,
      remainingMsWhenPaused: null,
      running: true,
    );
  }

  EpochCountdownState pause(int nowMs) {
    if (!running) return this;
    final left = remainingMs(nowMs);
    return EpochCountdownState(
      durationMs: durationMs,
      endsAtMs: null,
      remainingMsWhenPaused: left,
      running: false,
    );
  }

  EpochCountdownState reset() => EpochCountdownState.initial(durationMs);

  /// +N saniye ekle (çalışırken endsAt uzar).
  EpochCountdownState addSeconds(int seconds, int nowMs) {
    final add = seconds * 1000;
    final newDuration = durationMs + add;
    if (running && endsAtMs != null) {
      return EpochCountdownState(
        durationMs: newDuration,
        endsAtMs: endsAtMs! + add,
        remainingMsWhenPaused: null,
        running: true,
      );
    }
    final left = (remainingMsWhenPaused ?? durationMs) + add;
    return EpochCountdownState(
      durationMs: newDuration,
      endsAtMs: null,
      remainingMsWhenPaused: left,
      running: false,
    );
  }

  Map<String, dynamic> toMap() => {
        'durationMs': durationMs,
        'endsAtMs': endsAtMs,
        'remainingMsWhenPaused': remainingMsWhenPaused,
        'running': running,
      };

  factory EpochCountdownState.fromMap(Map<String, dynamic> map) {
    return EpochCountdownState(
      durationMs: (map['durationMs'] as num).toInt(),
      endsAtMs: (map['endsAtMs'] as num?)?.toInt(),
      remainingMsWhenPaused: (map['remainingMsWhenPaused'] as num?)?.toInt(),
      running: map['running'] as bool? ?? false,
    );
  }
}
