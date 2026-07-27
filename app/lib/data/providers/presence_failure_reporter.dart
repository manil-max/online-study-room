/// WP-364: presence yazma hatalarının **sessiz kalmamasını** sağlayan karar
/// birimi.
///
/// 🔴 Neden ayrı bir sınıf: WP-363'ün asıl maliyeti hatanın kendisi değil,
/// hiç kimsenin onu görmemesiydi. Yazma her 20 saniyede bir denendiği için
/// "her hatayı bildir" demek telemetriyi boğar ve gürültü yine körlüğe döner.
/// Karar mantığı burada saf tutulur ki provider kurmadan test edilebilsin.
///
/// Kural: **ilk** hata her zaman bildirilir; aynı hata tekrar ederse en fazla
/// [window] başına bir kez; hata **türü değişirse** hemen bildirilir (yeni bir
/// arıza sınıfı gürültü değil sinyaldir); başarılı bir yazım sayacı sıfırlar,
/// böylece arıza tekrar başlarsa yeniden bildirilir.
library;

class PresenceWriteFailureReport {
  const PresenceWriteFailureReport({
    required this.errorType,
    required this.consecutiveFailures,
  });

  final String errorType;
  final int consecutiveFailures;
}

class PresenceWriteFailureReporter {
  PresenceWriteFailureReporter({
    this.window = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Aynı arıza için iki bildirim arasındaki asgari süre.
  final Duration window;
  final DateTime Function() _clock;

  String? _lastErrorType;
  DateTime? _lastReportedAt;
  int _consecutiveFailures = 0;

  int get consecutiveFailures => _consecutiveFailures;

  /// Hata geldi. Bildirilmesi gerekiyorsa raporu döner, gerekmiyorsa `null`.
  PresenceWriteFailureReport? onFailure(Object error) {
    final errorType = error.runtimeType.toString();
    _consecutiveFailures++;

    final now = _clock();
    final typeChanged = errorType != _lastErrorType;
    final lastAt = _lastReportedAt;
    final windowPassed = lastAt == null || now.difference(lastAt) >= window;

    _lastErrorType = errorType;
    if (!typeChanged && !windowPassed) return null;

    _lastReportedAt = now;
    return PresenceWriteFailureReport(
      errorType: errorType,
      consecutiveFailures: _consecutiveFailures,
    );
  }

  /// Yazım başarılı oldu; arıza serisi kapandı.
  void onSuccess() {
    _consecutiveFailures = 0;
    _lastErrorType = null;
    _lastReportedAt = null;
  }
}
