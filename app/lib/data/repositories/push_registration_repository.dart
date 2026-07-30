import '../models/push_notification.dart';

class PushRegistrationException implements Exception {
  const PushRegistrationException(this.code);

  final String code;

  @override
  String toString() => 'PushRegistrationException($code)';
}

abstract interface class PushRegistrationRepository {
  /// Server device UUID'si V2 timer RPC'lerinde account-bound capability'dir.
  Future<String?> registerDevice(PushDeviceRegistration registration);

  Future<void> unregisterDevice(String installationId);

  /// Self-test yalnız bu cihazın doğrulanmış sunucu kimliğine yönelir.
  Future<PushSelfTestRequest> requestSelfTest(String deviceId);

  Future<PushSelfTestStatus?> fetchSelfTestStatus(String outboxId);
}
