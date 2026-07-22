import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/push_notification.dart';
import '../push_registration_repository.dart';

class SupabasePushRegistrationRepository implements PushRegistrationRepository {
  SupabasePushRegistrationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> registerDevice(PushDeviceRegistration registration) async {
    try {
      await _client.rpc(
        'register_push_device',
        params: registration.toRpcParams(),
      );
    } catch (_) {
      // FCM tokenı veya backend ayrıntısı exception metniyle üst katmana taşınmaz.
      throw const PushRegistrationException('device_registration_failed');
    }
  }

  @override
  Future<void> unregisterDevice(String installationId) async {
    try {
      await _client.rpc(
        'unregister_push_device',
        params: {'p_installation_id': installationId},
      );
    } catch (_) {
      throw const PushRegistrationException('device_unregistration_failed');
    }
  }

  @override
  Future<PushSelfTestRequest> requestSelfTest() async {
    try {
      final response = await _client.rpc('request_push_self_test');
      final rows = (response as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) throw const FormatException('missing_self_test');
      return PushSelfTestRequest.fromMap(rows.single);
    } on PostgrestException catch (error) {
      if (error.message.contains('push_test_cooldown')) {
        throw const PushRegistrationException('push_test_cooldown');
      }
      throw const PushRegistrationException('push_test_request_failed');
    } catch (_) {
      throw const PushRegistrationException('push_test_request_failed');
    }
  }

  @override
  Future<PushSelfTestStatus?> fetchSelfTestStatus(String outboxId) async {
    try {
      final response = await _client.rpc(
        'get_push_self_test_status',
        params: {'p_outbox_id': outboxId},
      );
      final rows = (response as List).cast<Map<String, dynamic>>();
      if (rows.isEmpty) return null;
      return PushSelfTestStatus.fromMap(rows.single);
    } catch (_) {
      throw const PushRegistrationException('push_test_status_failed');
    }
  }
}
