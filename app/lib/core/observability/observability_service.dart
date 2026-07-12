import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'observability_config.dart';

/// Derleme ortamı açık olsa bile kullanıcı bu yerel tercih ile telemetriyi
/// kapatabilir. Ayar ekranı eklendiğinde aynı anahtar tüketilir.
class TelemetryPreference {
  const TelemetryPreference._();

  static const key = 'observability.telemetry_enabled';

  static bool isEnabled(SharedPreferences preferences) =>
      preferences.getBool(key) ?? true;

  static Future<bool> setEnabled(
    SharedPreferences preferences,
    bool enabled,
  ) => preferences.setBool(key, enabled);
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

  bool get isEnabled => _enabled;

  Future<void> initialize(SharedPreferences preferences) async {
    if (_initialized) return;
    _initialized = true;
    if (!_config.isConfigured || !TelemetryPreference.isEnabled(preferences)) {
      return;
    }
    try {
      await _transport.initialize(_config);
      _enabled = true;
      _record('telemetry_started', {
        'environment_is_production': _config.environment == 'production',
      });
    } catch (_) {
      // Telemetry hiçbir zaman uygulamanın açılmasını engellemez.
      _enabled = false;
    }
  }

  void timerRestore({required bool hadActiveTimer}) {
    _record('timer_restore', {'had_active_timer': hadActiveTimer});
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

  Future<void> captureSanitizedError(
    Object error,
    StackTrace stackTrace,
  ) async {
    if (!_enabled) return;
    // Ham hata mesajı kullanıcı girdisi içerebilir. Sentry'ye yalnız hata türü
    // ve sabit mesaj gider; stack trace hata kaynağını korur.
    final sanitized = StateError('Uygulama hatası: ${error.runtimeType}');
    await _transport.captureException(sanitized, stackTrace);
  }

  void _record(String message, Map<String, Object> data) {
    if (!_enabled) return;
    _transport.addBreadcrumb(
      ObservabilityBreadcrumb(message: message, data: data),
    );
  }
}
