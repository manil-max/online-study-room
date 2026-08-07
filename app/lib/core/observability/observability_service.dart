import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'observability_config.dart';
import 'timer_diagnostic_journal.dart';

/// Derleme ortamı açık olsa bile kullanıcı bu yerel tercih ile telemetriyi
/// kapatabilir. Ayar ekranı eklendiğinde aynı anahtar tüketilir.
class TelemetryPreference {
  const TelemetryPreference._();

  static const key = 'observability.telemetry_enabled';

  static bool isEnabled(SharedPreferences preferences) =>
      preferences.getBool(key) ?? true;

  static Future<bool> setEnabled(SharedPreferences preferences, bool enabled) =>
      preferences.setBool(key, enabled);
}

class ObservabilityBreadcrumb {
  const ObservabilityBreadcrumb({
    required this.message,
    required this.data,
    this.category = 'app.sync',
  });

  final String category;
  final String message;
  final Map<String, Object> data;
}

/// Kullanıcı eylemlerinde hangi ürün alanının sonuç ürettiğini belirtir.
///
/// Bu kapalı sözlük özellikle ham grup/kullanıcı kimliği, geri bildirim metni
/// veya moderasyon içeriğinin tanısal kayda girmesini engeller.
enum ObservabilityOperation {
  timer,
  feedback,
  groupLeave,
  moderation,
  application;

  String get slug => switch (this) {
    ObservabilityOperation.timer => 'timer',
    ObservabilityOperation.feedback => 'feedback',
    ObservabilityOperation.groupLeave => 'group_leave',
    ObservabilityOperation.moderation => 'moderation',
    ObservabilityOperation.application => 'application',
  };
}

/// Kullanıcıya gösterilen sonuçla tanısal kaydın aynı sonucu taşımasını sağlar.
enum ObservabilityOutcome {
  succeeded,
  failed,
  cancelled,
  offline,
  timedOut;

  String get slug => switch (this) {
    ObservabilityOutcome.succeeded => 'succeeded',
    ObservabilityOutcome.failed => 'failed',
    ObservabilityOutcome.cancelled => 'cancelled',
    ObservabilityOutcome.offline => 'offline',
    ObservabilityOutcome.timedOut => 'timed_out',
  };
}

/// Sağlayıcı yapılandırılmamış ya da çevrimdışıyken bellekte kalan güvenli olay.
/// Bu günlük diske yazılmaz; uygulama kapanınca silinir.
class ObservabilityLocalEvent {
  ObservabilityLocalEvent({
    required this.name,
    required Map<String, Object> data,
    required this.recordedAt,
  }) : data = Map.unmodifiable(data);

  final String name;
  final Map<String, Object> data;
  final DateTime recordedAt;
}

abstract interface class ObservabilityTransport {
  Future<void> initialize(ObservabilityConfig config);

  void addBreadcrumb(ObservabilityBreadcrumb breadcrumb);

  Future<void> captureException(Object exception, StackTrace stackTrace);
}

class SentryObservabilityTransport implements ObservabilityTransport {
  @override
  Future<void> initialize(ObservabilityConfig config) {
    return SentryFlutter.init((options) {
      options.dsn = config.dsn;
      options.environment = config.environment;
      options.release = config.release;
      options.sendDefaultPii = false;
      options.tracesSampleRate = 0;
      // Otomatik breadcrumb'lar URL veya kullanıcı girdisi taşıyabilir. Sadece
      // aşağıdaki kontrollü, sayısal/boolean uygulama olaylarını saklarız.
      options.beforeBreadcrumb = (Breadcrumb? breadcrumb, Hint? hint) {
        return breadcrumb?.category == 'app.sync' ? breadcrumb : null;
      };
    });
  }

  @override
  void addBreadcrumb(ObservabilityBreadcrumb breadcrumb) {
    Sentry.addBreadcrumb(
      Breadcrumb(
        category: breadcrumb.category,
        message: breadcrumb.message,
        data: breadcrumb.data,
        level: SentryLevel.info,
      ),
    );
  }

  @override
  Future<void> captureException(Object exception, StackTrace stackTrace) {
    return Sentry.captureException(exception, stackTrace: stackTrace);
  }
}

/// Sentry bağımlılığını ürün akışlarından ayıran, PII güvenli olay kapısı.
///
/// Bu sınıf yalnız sabit olay adları ile int/bool veri kabul eder; kullanıcı
/// kimliği, e-posta, token ve ham oturum içeriği buraya giremez.
class ObservabilityService {
  ObservabilityService({
    ObservabilityConfig? config,
    ObservabilityTransport? transport,
  }) : _config = config ?? ObservabilityConfig.fromEnvironment(),
       _transport = transport ?? SentryObservabilityTransport();

  static final instance = ObservabilityService();

  final ObservabilityConfig _config;
  final ObservabilityTransport _transport;
  var _initialized = false;
  var _enabled = false;
  var _collectionEnabled = false;
  var _nextCorrelationId = 0;
  final _localEvents = <ObservabilityLocalEvent>[];

  static const localBufferLimit = 64;

  /// Uzak sağlayıcıya olay gönderiminin açık olduğunu belirtir.
  bool get isEnabled => _enabled;

  /// Kullanıcı izni varsa, sağlayıcı kapalı/çevrimdışı olsa bile sınırlı yerel
  /// yapılandırılmış günlük tutulur.
  bool get isCollecting => _collectionEnabled;

  List<ObservabilityLocalEvent> get localEvents =>
      List.unmodifiable(_localEvents);

  var _transportReady = false;

  Future<void> initialize(SharedPreferences preferences) async {
    if (_initialized) return;
    _initialized = true;
    _collectionEnabled = TelemetryPreference.isEnabled(preferences);
    if (!_collectionEnabled || !_config.isConfigured) {
      return;
    }
    await _startTransport();
  }

  /// WP-111: Kullanıcı telemetri tercihi — kapatınca hemen olay kesilir;
  /// açınca (build DSN açıksa) transport başlatılır.
  Future<void> setTelemetryEnabled(
    SharedPreferences preferences,
    bool enabled,
  ) async {
    await TelemetryPreference.setEnabled(preferences, enabled);
    if (!enabled) {
      _enabled = false;
      _collectionEnabled = false;
      _localEvents.clear();
      return;
    }
    _collectionEnabled = true;
    if (!_config.isConfigured) return;
    if (!_transportReady) {
      await _startTransport();
    } else {
      _enabled = true;
    }
  }

  Future<void> _startTransport() async {
    try {
      await _transport.initialize(_config);
      _transportReady = true;
      _enabled = true;
      _record('telemetry_started', {
        'environment_is_production': _config.environment == 'production',
      });
    } catch (_) {
      // Telemetry hiçbir zaman uygulamanın açılmasını engellemez.
      _enabled = false;
      _transportReady = false;
      _record('telemetry_transport_unavailable', const {});
    }
  }

  void timerRestore({required bool hadActiveTimer}) {
    _record('timer_restore', {'had_active_timer': hadActiveTimer});
  }

  /// WP-502 (V58-N01 / rapor T12): soğuk açılış süresi + o anda açık realtime
  /// kanal sayısı. `elapsedMs` yalnız `main()` başlangıcından ilk çizilen
  /// kareye kadarki Dart-katmanı süresidir (OS süreç açılışı/engine init
  /// dışarıda kalır); açılışın "sürekli 2 gün yavaş kaldı" gibi anormal
  /// uzamalarını sonradan Sentry breadcrumb geçmişinden görünür kılmak
  /// içindir, kesin bir SLO ölçütü değildir.
  void coldStartBudget({
    required int elapsedMs,
    required int realtimeChannelCount,
  }) {
    _record('cold_start_budget', {
      'elapsed_ms': elapsedMs,
      'realtime_channel_count': realtimeChannelCount,
    });
  }

  /// WP-430: sayac gecisinin **sayisal** ozeti. Tanisal zaman cizelgesi
  /// cihazda kalir ([TimerDiagnosticJournal]); buraya yalniz kapali sozlukten
  /// gelen slug'lar ve tamsayilar cikar. Ham hesap/kosu/ders kimligi ve mesaj
  /// icerigi bu yoldan gecemez.
  void timerTransition({
    required String event,
    required String reason,
    required String outcome,
    String origin = TimerJournalOrigins.unknown,
    int? stateVersion,
    int? queueAgeMs,
  }) {
    _record('timer_transition', {
      'event': TimerJournalSlug.normalize(event),
      'reason': TimerJournalSlug.normalize(reason),
      'outcome': TimerJournalSlug.normalize(outcome),
      'origin': TimerJournalSlug.normalize(origin),
      'state_version': ?stateVersion,
      'queue_age_ms': ?queueAgeMs,
    });
  }

  void outboxFlush({
    required int pendingCount,
    required int appliedCount,
    required int remainingCount,
    required int elapsedMilliseconds,
  }) {
    _record('outbox_flush', {
      'pending_count': pendingCount,
      'applied_count': appliedCount,
      'remaining_count': remainingCount,
      'elapsed_ms': elapsedMilliseconds,
    });
  }

  void realtimeSnapshot({
    required int sessionCount,
    required int pendingOutboxCount,
    required int elapsedMilliseconds,
  }) {
    _record('realtime_snapshot', {
      'session_count': sessionCount,
      'pending_outbox_count': pendingOutboxCount,
      'elapsed_ms': elapsedMilliseconds,
    });
  }

  void realtimeFallback({required bool hadCachedRows}) {
    _record('realtime_fallback', {'had_cached_rows': hadCachedRows});
  }

  /// WP-364: uzak presence yazımı başarısız oldu.
  ///
  /// Bu olay olmadığı için WP-363 aylarca görünmedi: yazma hatası koşulsuz
  /// yutuluyor, kullanıcı ise yerel cache sayesinde kendini aktif görmeye devam
  /// ediyordu. Yalnız hata **türü** ve grup bilgisinin var olup olmadığı
  /// gönderilir; kullanıcı/grup kimliği gibi veriler asla.
  void presenceWriteFailed({
    required String errorType,
    required bool hasGroup,
    required int consecutiveFailures,
  }) {
    _record('presence_write_failed', {
      'error_type': errorType,
      'has_group': hasGroup,
      'consecutive_failures': consecutiveFailures,
    });
  }

  Future<void> captureSanitizedError(
    Object error,
    StackTrace stackTrace,
  ) async {
    await _captureError(
      error,
      stackTrace,
      operation: ObservabilityOperation.application,
      outcome: ObservabilityOutcome.failed,
      eventName: 'unhandled_error',
    );
  }

  /// Bir kullanıcı eyleminin sonucunu yalnız kapalı sözlük verileriyle kaydeder.
  ///
  /// Dönen correlation ID, aynı eylemin hata/arayüz sonucunda tekrar
  /// kullanılabilir. Çağıran kod kullanıcıya başarı gösteriyorsa burada da
  /// [ObservabilityOutcome.succeeded] kullanmalıdır; böylece sessiz başarısızlık
  /// ile tanısal kayıt birbirinden ayrışmaz.
  String recordOperationOutcome({
    required ObservabilityOperation operation,
    required ObservabilityOutcome outcome,
    String? correlationId,
  }) {
    final resolvedCorrelationId = _resolveCorrelationId(correlationId);
    _record('operation_outcome', {
      'operation': operation.slug,
      'outcome': outcome.slug,
      'correlation_id': resolvedCorrelationId,
    });
    return resolvedCorrelationId;
  }

  /// Bir kullanıcı eyleminin başarısızlığını UI hata yoluyla aynı anda çağırın.
  /// Ham hata metni, token, mesaj gövdesi ve kimlik bilgileri kayda alınmaz.
  Future<String> captureOperationFailure({
    required ObservabilityOperation operation,
    required Object error,
    required StackTrace stackTrace,
    ObservabilityOutcome outcome = ObservabilityOutcome.failed,
    String? correlationId,
  }) async {
    final resolvedCorrelationId = _resolveCorrelationId(correlationId);
    await _captureError(
      error,
      stackTrace,
      operation: operation,
      outcome: outcome,
      correlationId: resolvedCorrelationId,
      eventName: 'operation_failed',
    );
    return resolvedCorrelationId;
  }

  /// Flutter framework ve asenkron platform hataları için ortak güvenlik ağı.
  /// Tercih/sağlayıcı kapalıysa hata sessizce yerel olarak da atlanır.
  void installErrorHandlers() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(
        captureSanitizedError(
          details.exception,
          details.stack ?? StackTrace.current,
        ),
      );
    };
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      unawaited(captureSanitizedError(error, stackTrace));
      return true;
    };
  }

  void _record(String message, Map<String, Object> data) {
    if (!_collectionEnabled) return;
    final sanitizedData = _sanitizeData(data);
    _appendLocalEvent(message, sanitizedData);
    if (!_enabled) return;
    try {
      _transport.addBreadcrumb(
        ObservabilityBreadcrumb(message: message, data: sanitizedData),
      );
    } catch (_) {
      // Sağlayıcı hatası kullanıcı akışını kesemez; sınırlı yerel kayıt kalır.
    }
  }

  Future<void> _captureError(
    Object error,
    StackTrace stackTrace, {
    required ObservabilityOperation operation,
    required ObservabilityOutcome outcome,
    required String eventName,
    String? correlationId,
  }) async {
    if (!_collectionEnabled) return;
    final errorType = _safeErrorType(error);
    final resolvedCorrelationId = correlationId ?? _resolveCorrelationId(null);
    _record(eventName, {
      'operation': operation.slug,
      'outcome': outcome.slug,
      'correlation_id': resolvedCorrelationId,
      'error_type': errorType,
    });
    if (!_enabled) return;
    // Ham hata mesajı kullanıcı girdisi içerebilir. Uzak sağlayıcıya yalnız hata
    // türü, kapalı sözlükten gelen operasyon ve redakte edilmiş stack trace gider.
    final sanitized = StateError(
      'Uygulama hatası: $errorType / ${operation.slug}',
    );
    try {
      await _transport.captureException(
        sanitized,
        _sanitizeStackTrace(stackTrace),
      );
    } catch (_) {
      // Sağlayıcı erişilemezse yukarıdaki sınırlı bellek tamponu yeterli kanıttır.
    }
  }

  String _resolveCorrelationId(String? candidate) {
    if (candidate != null &&
        RegExp(r'^obs_[a-z0-9_]{1,48}$').hasMatch(candidate)) {
      return candidate;
    }
    _nextCorrelationId++;
    return 'obs_${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}_$_nextCorrelationId';
  }

  String _safeErrorType(Object error) {
    final type = error.runtimeType.toString();
    return RegExp(r'^[A-Za-z_][A-Za-z0-9_]{0,80}$').hasMatch(type)
        ? type
        : 'unknown_error';
  }

  Map<String, Object> _sanitizeData(Map<String, Object> data) {
    final sanitized = <String, Object>{};
    for (final entry in data.entries) {
      if (!RegExp(r'^[a-z][a-z0-9_]{0,48}$').hasMatch(entry.key)) continue;
      final value = entry.value;
      if (value is int || value is bool) {
        sanitized[entry.key] = value;
      } else if (value is String &&
          RegExp(r'^[A-Za-z0-9_]{1,64}$').hasMatch(value)) {
        sanitized[entry.key] = value;
      }
    }
    return sanitized;
  }

  StackTrace _sanitizeStackTrace(StackTrace stackTrace) {
    final lines = stackTrace
        .toString()
        .split('\n')
        .take(40)
        .map(
          (line) => line
              .replaceAll(RegExp(r'[A-Za-z]:\\[^\s\)]*'), '[local_path]')
              .replaceAll(RegExp(r'/Users/[^\s\)]*'), '[local_path]')
              .replaceAll(
                RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+'),
                '[email]',
              )
              .replaceAll(
                RegExp(
                  r'(token|secret|password|authorization)\s*[:=]\s*[^\s,\)]*',
                  caseSensitive: false,
                ),
                r'$1=[redacted]',
              ),
        )
        .join('\n');
    return StackTrace.fromString(lines);
  }

  void _appendLocalEvent(String name, Map<String, Object> data) {
    _localEvents.add(
      ObservabilityLocalEvent(
        name: name,
        data: data,
        recordedAt: DateTime.now().toUtc(),
      ),
    );
    if (_localEvents.length > localBufferLimit) {
      _localEvents.removeRange(0, _localEvents.length - localBufferLimit);
    }
  }
}
