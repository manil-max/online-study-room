import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/global_timer.dart';
import '../global_timer_repository.dart';

class SupabaseGlobalTimerRepository implements GlobalTimerRepository {
  SupabaseGlobalTimerRepository(this._client);
  final SupabaseClient _client;

  @override
  Future<GlobalTimerSnapshot> fetchSnapshot({String? deviceId}) async =>
      GlobalTimerSnapshot.fromMap(
        Map<String, dynamic>.from(
          await _client.rpc(
                'get_global_timer_v2_snapshot',
                params: {'p_device_id': deviceId},
              )
              as Map,
        ),
      );

  @override
  Future<GlobalTimerSnapshot> applyCommand({
    required String commandId,
    required String deviceId,
    required String action,
    String? runId,
    int? expectedRunRevision,
    DateTime? clientOccurredAt,
    Map<String, Object?> payload = const {},
  }) async => GlobalTimerSnapshot.fromMap(
    Map<String, dynamic>.from(
      await _client.rpc(
            'apply_global_timer_command',
            params: {
              'p_command_id': commandId,
              'p_device_id': deviceId,
              'p_action': action,
              'p_run_id': runId,
              'p_expected_run_revision': expectedRunRevision,
              'p_client_occurred_at': clientOccurredAt
                  ?.toUtc()
                  .toIso8601String(),
              'p_payload': payload,
              'p_protocol_version': 2,
            },
          )
          as Map,
    ),
  );

  @override
  Future<GlobalTimerSnapshot> acknowledge({
    required String deviceId,
    required int stateVersion,
    required String status,
    String? runId,
    int? runRevision,
    String? errorCode,
  }) async => GlobalTimerSnapshot.fromMap(
    Map<String, dynamic>.from(
      await _client.rpc(
            'ack_global_timer_v2_snapshot',
            params: {
              'p_device_id': deviceId,
              'p_state_version': stateVersion,
              'p_status': status,
              'p_run_id': runId,
              'p_run_revision': runRevision,
              'p_error_code': errorCode,
            },
          )
          as Map,
    ),
  );
}
