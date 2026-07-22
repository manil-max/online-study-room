import 'package:uuid/uuid.dart';

import '../../models/push_notification.dart';
import '../push_registration_repository.dart';

/// Local/InMemory uygulama remote push taklidi yapmaz. Repository sözleşmesi
/// test edilebilir kalır; sağlık ekranı Firebase config yokken bu yola self-test
/// göndermeden "kurulmamış" gösterir.
class InMemoryPushRegistrationRepository implements PushRegistrationRepository {
  PushDeviceRegistration? lastRegistration;
  String? lastUnregisteredInstallationId;
  final Map<String, PushSelfTestStatus> _tests = {};

  @override
  Future<void> registerDevice(PushDeviceRegistration registration) async {
    lastRegistration = registration;
  }

  @override
  Future<void> unregisterDevice(String installationId) async {
    lastUnregisteredInstallationId = installationId;
    lastRegistration = null;
  }

  @override
  Future<PushSelfTestRequest> requestSelfTest() async {
    final now = DateTime.now().toUtc();
    final id = const Uuid().v4();
    _tests[id] = PushSelfTestStatus(
      state: PushSelfTestDeliveryState.noDevices,
      pendingCount: 0,
      sentCount: 0,
      failedCount: 0,
      requestedAt: now,
      completedAt: now,
    );
    return PushSelfTestRequest(outboxId: id, requestedAt: now);
  }

  @override
  Future<PushSelfTestStatus?> fetchSelfTestStatus(String outboxId) async {
    return _tests[outboxId];
  }
}
