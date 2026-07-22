import '../models/push_notification.dart';

class PushRegistrationException implements Exception {
  const PushRegistrationException(this.code);

  final String code;

  @override
  String toString() => 'PushRegistrationException($code)';
}

abstract interface class PushRegistrationRepository {
  Future<void> registerDevice(PushDeviceRegistration registration);

  Future<void> unregisterDevice(String installationId);

  Future<PushSelfTestRequest> requestSelfTest();

  Future<PushSelfTestStatus?> fetchSelfTestStatus(String outboxId);
}
