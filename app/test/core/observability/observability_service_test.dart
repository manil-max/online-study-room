import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/observability/observability_config.dart';
import 'package:online_study_room/core/observability/observability_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<SharedPreferences> preferences(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  const enabledConfig = ObservabilityConfig(
    dsn: 'https://public@example.invalid/1',
    environment: 'beta',
    release: 'odak-kampi@1.0.7+8',
    buildEnabled: true,
  );

  test('telemetry kapalıyken Sentry başlatılmaz ve olay yollanmaz', () async {
    final transport = _FakeTransport();
    final service = ObservabilityService(
      config: enabledConfig,
      transport: transport,
    );

    await service.initialize(
      await preferences({TelemetryPreference.key: false}),
    );
    service.timerRestore(hadActiveTimer: true);

    expect(service.isEnabled, isFalse);
    expect(transport.initializeCalls, 0);
    expect(transport.breadcrumbs, isEmpty);
  });

  test('timer, outbox ve realtime breadcrumbları yalnız güvenli veri taşır', () async {
    final transport = _FakeTransport();
    final service = ObservabilityService(
      config: enabledConfig,
      transport: transport,
    );
    await service.initialize(await preferences({}));

    service.timerRestore(hadActiveTimer: true);
    service.outboxFlush(
      pendingCount: 2,
      appliedCount: 1,
      remainingCount: 1,
      elapsedMilliseconds: 42,
    );
    service.realtimeSnapshot(
      sessionCount: 3,
      pendingOutboxCount: 1,
      elapsedMilliseconds: 18,
    );

    expect(transport.initializeCalls, 1);
    expect(
      transport.breadcrumbs.map((item) => item.message),
      containsAll(['timer_restore', 'outbox_flush', 'realtime_snapshot']),
    );
    for (final breadcrumb in transport.breadcrumbs) {
      expect(breadcrumb.category, 'app.sync');
      expect(
        breadcrumb.data.values.every(
          (value) => value is int || value is bool,
        ),
        isTrue,
      );
    }
  });

  test('bilinen hata, ham hata metni yerine yalnız hata türüyle yakalanır', () async {
    final transport = _FakeTransport();
    final service = ObservabilityService(
      config: enabledConfig,
      transport: transport,
    );
    await service.initialize(await preferences({}));

    await service.captureSanitizedError(
      StateError('v8-qa@ornek.com token=secret'),
      StackTrace.current,
    );

    expect(transport.exceptions, hasLength(1));
    expect(transport.exceptions.single.toString(), contains('StateError'));
    expect(transport.exceptions.single.toString(), isNot(contains('ornek.com')));
    expect(transport.exceptions.single.toString(), isNot(contains('secret')));
  });
}

class _FakeTransport implements ObservabilityTransport {
  var initializeCalls = 0;
  final breadcrumbs = <ObservabilityBreadcrumb>[];
  final exceptions = <Object>[];

  @override
  Future<void> initialize(ObservabilityConfig config) async {
    initializeCalls++;
  }

  @override
  void addBreadcrumb(ObservabilityBreadcrumb breadcrumb) {
    breadcrumbs.add(breadcrumb);
  }

  @override
  Future<void> captureException(Object exception, StackTrace stackTrace) async {
    exceptions.add(exception);
  }
}
