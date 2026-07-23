import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/push_notification.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_push_registration_repository.dart';

void main() {
  test('device registration maps every preference to guarded RPC params', () {
    const registration = PushDeviceRegistration(
      installationId: 'installation-123456',
      fcmToken: 'token-12345678901234567890',
      appChannel: 'beta',
      appVersion: '1.0.43-beta.1',
      buildNumber: 4301,
      locale: 'tr',
      timeZone: 'Europe/Istanbul',
      nudgeEnabled: true,
      announcementEnabled: false,
      updateEnabled: true,
      quietHoursEnabled: true,
      quietStartMinutes: 1320,
      quietEndMinutes: 420,
    );

    expect(registration.toRpcParams(), {
      'p_installation_id': 'installation-123456',
      'p_fcm_token': 'token-12345678901234567890',
      'p_app_channel': 'beta',
      'p_app_version': '1.0.43-beta.1',
      'p_build_number': 4301,
      'p_locale': 'tr',
      'p_time_zone': 'Europe/Istanbul',
      'p_nudge_enabled': true,
      'p_announcement_enabled': false,
      'p_update_enabled': true,
      'p_quiet_hours_enabled': true,
      'p_quiet_start_minutes': 1320,
      'p_quiet_end_minutes': 420,
    });
  });

  test('self-test status exposes terminal delivery states', () {
    final sent = PushSelfTestStatus.fromMap({
      'outbox_status': 'sent',
      'pending_count': 0,
      'sent_count': 1,
      'failed_count': 0,
      'requested_at': '2026-07-22T12:00:00Z',
      'completed_at': '2026-07-22T12:00:02Z',
      'attempt_count': 2,
      'last_error_code': 'network_error',
      'configuration_status': 'configured',
    });
    final queued = PushSelfTestStatus.fromMap({
      'outbox_status': 'dispatching',
      'pending_count': 1,
      'sent_count': 0,
      'failed_count': 0,
      'requested_at': '2026-07-22T12:00:00Z',
      'completed_at': null,
    });

    expect(sent.state, PushSelfTestDeliveryState.sent);
    expect(sent.terminal, isTrue);
    expect(sent.attemptCount, 2);
    expect(sent.errorCode, 'network_error');
    expect(queued.state, PushSelfTestDeliveryState.dispatching);
    expect(queued.terminal, isFalse);
  });

  test('self-test failures expose a safe operational class', () {
    final status = PushSelfTestStatus.fromMap({
      'outbox_status': 'failed',
      'pending_count': 0,
      'sent_count': 0,
      'failed_count': 1,
      'requested_at': '2026-07-22T12:00:00Z',
      'completed_at': '2026-07-22T12:00:02Z',
      'last_error_code': 'unregistered',
      'configuration_status': 'configured',
    });

    expect(classifyPushSelfTestFailure(status), 'fcm');
    expect(
      classifyPushSelfTestFailure(
        PushSelfTestStatus.fromMap({
          'outbox_status': 'dispatching',
          'pending_count': 1,
          'sent_count': 0,
          'failed_count': 0,
          'requested_at': '2026-07-22T12:00:00Z',
          'configuration_status': 'not_configured',
        }),
      ),
      'configuration',
    );
    expect(classifyPushSelfTestFailure(null), 'timeout');
  });

  test('in-memory mirror keeps registration lifecycle deterministic', () async {
    final repository = InMemoryPushRegistrationRepository();
    const registration = PushDeviceRegistration(
      installationId: 'installation-123456',
      fcmToken: 'token-12345678901234567890',
      appChannel: 'local',
      appVersion: '0.0.0-local',
      buildNumber: 0,
      locale: 'en',
      timeZone: 'UTC',
      nudgeEnabled: true,
      announcementEnabled: true,
      updateEnabled: true,
      quietHoursEnabled: false,
      quietStartMinutes: 1320,
      quietEndMinutes: 420,
    );

    await repository.registerDevice(registration);
    expect(repository.lastRegistration, same(registration));
    final request = await repository.requestSelfTest();
    final status = await repository.fetchSelfTestStatus(request.outboxId);
    expect(status?.state, PushSelfTestDeliveryState.noDevices);
    await repository.unregisterDevice(registration.installationId);
    expect(repository.lastRegistration, isNull);
    expect(
      repository.lastUnregisteredInstallationId,
      registration.installationId,
    );
  });
}
