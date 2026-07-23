import 'package:flutter/foundation.dart';

@immutable
class PushDeviceRegistration {
  const PushDeviceRegistration({
    required this.installationId,
    required this.fcmToken,
    required this.appChannel,
    required this.appVersion,
    required this.buildNumber,
    required this.locale,
    required this.timeZone,
    required this.nudgeEnabled,
    required this.announcementEnabled,
    required this.updateEnabled,
    required this.quietHoursEnabled,
    required this.quietStartMinutes,
    required this.quietEndMinutes,
  });

  final String installationId;
  final String fcmToken;
  final String appChannel;
  final String appVersion;
  final int buildNumber;
  final String locale;
  final String timeZone;
  final bool nudgeEnabled;
  final bool announcementEnabled;
  final bool updateEnabled;
  final bool quietHoursEnabled;
  final int quietStartMinutes;
  final int quietEndMinutes;

  Map<String, Object> toRpcParams() => {
    'p_installation_id': installationId,
    'p_fcm_token': fcmToken,
    'p_app_channel': appChannel,
    'p_app_version': appVersion,
    'p_build_number': buildNumber,
    'p_locale': locale,
    'p_time_zone': timeZone,
    'p_nudge_enabled': nudgeEnabled,
    'p_announcement_enabled': announcementEnabled,
    'p_update_enabled': updateEnabled,
    'p_quiet_hours_enabled': quietHoursEnabled,
    'p_quiet_start_minutes': quietStartMinutes,
    'p_quiet_end_minutes': quietEndMinutes,
  };
}

@immutable
class PushSelfTestRequest {
  const PushSelfTestRequest({
    required this.outboxId,
    required this.requestedAt,
  });

  final String outboxId;
  final DateTime requestedAt;

  factory PushSelfTestRequest.fromMap(Map<String, dynamic> map) {
    return PushSelfTestRequest(
      outboxId: map['outbox_id'] as String,
      requestedAt: DateTime.parse(map['requested_at'] as String),
    );
  }
}

enum PushSelfTestDeliveryState {
  queued,
  dispatching,
  sent,
  failed,
  noDevices,
  unknown,
}

@immutable
class PushSelfTestStatus {
  const PushSelfTestStatus({
    required this.state,
    required this.pendingCount,
    required this.sentCount,
    required this.failedCount,
    required this.requestedAt,
    this.completedAt,
    this.attemptCount = 0,
    this.errorCode,
    this.nextAttemptAt,
    this.configurationStatus = 'unknown',
  });

  final PushSelfTestDeliveryState state;
  final int pendingCount;
  final int sentCount;
  final int failedCount;
  final DateTime requestedAt;
  final DateTime? completedAt;
  final int attemptCount;
  final String? errorCode;
  final DateTime? nextAttemptAt;
  final String configurationStatus;

  bool get terminal => switch (state) {
    PushSelfTestDeliveryState.sent ||
    PushSelfTestDeliveryState.failed ||
    PushSelfTestDeliveryState.noDevices => true,
    _ => false,
  };

  factory PushSelfTestStatus.fromMap(Map<String, dynamic> map) {
    final raw = map['outbox_status'] as String?;
    final state = switch (raw) {
      'queued' => PushSelfTestDeliveryState.queued,
      'dispatching' => PushSelfTestDeliveryState.dispatching,
      'sent' => PushSelfTestDeliveryState.sent,
      'failed' => PushSelfTestDeliveryState.failed,
      'no_devices' => PushSelfTestDeliveryState.noDevices,
      _ => PushSelfTestDeliveryState.unknown,
    };
    return PushSelfTestStatus(
      state: state,
      pendingCount: (map['pending_count'] as num?)?.toInt() ?? 0,
      sentCount: (map['sent_count'] as num?)?.toInt() ?? 0,
      failedCount: (map['failed_count'] as num?)?.toInt() ?? 0,
      requestedAt: DateTime.parse(map['requested_at'] as String),
      completedAt: map['completed_at'] == null
          ? null
          : DateTime.parse(map['completed_at'] as String),
      attemptCount: (map['attempt_count'] as num?)?.toInt() ?? 0,
      errorCode: map['last_error_code'] as String?,
      nextAttemptAt: map['next_attempt_at'] == null
          ? null
          : DateTime.parse(map['next_attempt_at'] as String),
      configurationStatus: map['configuration_status'] as String? ?? 'unknown',
    );
  }
}

/// Kullanıcı arayüzü için provider/credential ayrıntısı sızdırmadan sınıflanır.
/// Ham kod yalnız tanı için görünür; token veya payload hiçbir zaman taşınmaz.
String classifyPushSelfTestFailure(PushSelfTestStatus? status) {
  if (status?.configurationStatus == 'not_configured') return 'configuration';
  if (status == null || !status.terminal) return 'timeout';
  if (status.configurationStatus != 'configured') return 'configuration';
  final code = status.errorCode?.toLowerCase() ?? '';
  if (code.contains('timeout')) return 'timeout';
  if (code.contains('network') || code.contains('transport')) {
    return 'transport';
  }
  if (code.contains('oauth') ||
      code.contains('service_account') ||
      code.contains('not_configured')) {
    return 'configuration';
  }
  if (code.contains('unavailable') ||
      code.contains('internal') ||
      code.contains('quota')) {
    return 'server';
  }
  return 'fcm';
}
