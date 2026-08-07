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

  test(
    'timer, outbox ve realtime breadcrumbları yalnız güvenli veri taşır',
    () async {
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
      service.coldStartBudget(elapsedMs: 812, realtimeChannelCount: 2);

      expect(transport.initializeCalls, 1);
      expect(
        transport.breadcrumbs.map((item) => item.message),
        containsAll([
          'timer_restore',
          'outbox_flush',
          'realtime_snapshot',
          'cold_start_budget',
        ]),
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
    },
  );

  test('WP-502: soğuk açılış bütçesi süre + kanal sayısını taşır', () async {
    final transport = _FakeTransport();
    final service = ObservabilityService(
      config: enabledConfig,
      transport: transport,
    );
    await service.initialize(await preferences({}));

    service.coldStartBudget(elapsedMs: 4200, realtimeChannelCount: 3);

    final breadcrumb = transport.breadcrumbs.firstWhere(
      (item) => item.message == 'cold_start_budget',
    );
    expect(breadcrumb.data['elapsed_ms'], 4200);
    expect(breadcrumb.data['realtime_channel_count'], 3);
  });

  test(
    'bilinen hata, ham hata metni yerine yalnız hata türüyle yakalanır',
    () async {
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
      expect(
        transport.exceptions.single.toString(),
        isNot(contains('ornek.com')),
      );
      expect(transport.exceptions.single.toString(), isNot(contains('secret')));
    },
  );

  test(
    'eylem hataları correlation ID ve sonuç sınıfıyla, PII olmadan yakalanır',
    () async {
      final transport = _FakeTransport();
      final service = ObservabilityService(
        config: enabledConfig,
        transport: transport,
      );
      await service.initialize(await preferences({}));

      for (final operation in const [
        ObservabilityOperation.timer,
        ObservabilityOperation.feedback,
        ObservabilityOperation.groupLeave,
        ObservabilityOperation.moderation,
      ]) {
        final correlationId = await service.captureOperationFailure(
          operation: operation,
          error: StateError('v8-qa@ornek.com token=secret mesaji'),
          stackTrace: StackTrace.fromString(
            'token=secret v8-qa@ornek.com C:\\Users\\qa\\source.dart',
          ),
          correlationId: 'obs_qa_case',
        );

        expect(correlationId, 'obs_qa_case');
      }

      final operationEvents = service.localEvents
          .where((event) => event.name == 'operation_failed')
          .toList();
      expect(operationEvents, hasLength(4));
      expect(
        operationEvents.map((event) => event.data['operation']),
        containsAll(['timer', 'feedback', 'group_leave', 'moderation']),
      );
      expect(
        operationEvents.every(
          (event) =>
              event.data['outcome'] == 'failed' &&
              event.data['correlation_id'] == 'obs_qa_case' &&
              event.data['error_type'] == 'StateError',
        ),
        isTrue,
      );
      for (final exception in transport.exceptions) {
        expect(exception.toString(), isNot(contains('ornek.com')));
        expect(exception.toString(), isNot(contains('secret')));
      }
      for (final stackTrace in transport.stackTraces) {
        expect(stackTrace.toString(), isNot(contains('ornek.com')));
        expect(stackTrace.toString(), isNot(contains('secret')));
        expect(stackTrace.toString(), isNot(contains('C:\\Users')));
      }
    },
  );

  test(
    'opt-out yerel tamponu temizler ve yeni olay toplamayı durdurur',
    () async {
      final transport = _FakeTransport();
      final service = ObservabilityService(
        config: enabledConfig,
        transport: transport,
      );
      final prefs = await preferences({});
      await service.initialize(prefs);
      service.recordOperationOutcome(
        operation: ObservabilityOperation.timer,
        outcome: ObservabilityOutcome.succeeded,
      );

      expect(service.localEvents, isNotEmpty);
      await service.setTelemetryEnabled(prefs, false);
      service.recordOperationOutcome(
        operation: ObservabilityOperation.feedback,
        outcome: ObservabilityOutcome.failed,
      );

      expect(service.isCollecting, isFalse);
      expect(service.localEvents, isEmpty);
    },
  );

  test(
    'yerel tampon sınırlandırılır ve rastgele correlation ID PII taşımaz',
    () async {
      final service = ObservabilityService(
        config: const ObservabilityConfig(
          dsn: '',
          environment: 'development',
          release: 'odak-kampi@test',
          buildEnabled: false,
        ),
        transport: _FakeTransport(),
      );
      await service.initialize(await preferences({}));

      for (
        var index = 0;
        index <= ObservabilityService.localBufferLimit;
        index++
      ) {
        service.recordOperationOutcome(
          operation: ObservabilityOperation.timer,
          outcome: ObservabilityOutcome.succeeded,
        );
      }

      expect(service.isEnabled, isFalse);
      expect(service.isCollecting, isTrue);
      expect(
        service.localEvents,
        hasLength(ObservabilityService.localBufferLimit),
      );
      expect(
        service.localEvents.every(
          (event) => RegExp(
            r'^obs_[a-z0-9_]+$',
          ).hasMatch(event.data['correlation_id']! as String),
        ),
        isTrue,
      );
    },
  );
}

class _FakeTransport implements ObservabilityTransport {
  var initializeCalls = 0;
  final breadcrumbs = <ObservabilityBreadcrumb>[];
  final exceptions = <Object>[];
  final stackTraces = <StackTrace>[];

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
    stackTraces.add(stackTrace);
  }
}
