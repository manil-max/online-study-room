import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/timer_sync_signal.dart';

void main() {
  test('timer sync accepts only the minimal versioned signal schema', () {
    final signal = TimerSyncSignal.tryParse({
      'notification_type': 'timer_sync',
      'schema_version': '1',
      'kind': 'timer_sync',
      'run_id': 'run-1',
      'state_version': '7',
      'run_revision': '2',
    });
    expect(signal?.stateVersion, 7);
    expect(signal?.runRevision, 2);
  });

  test('timer sync rejects malformed or non-timer payloads', () {
    expect(
      TimerSyncSignal.tryParse({'notification_type': 'announcement'}),
      isNull,
    );
    expect(
      TimerSyncSignal.tryParse({
        'notification_type': 'timer_sync',
        'schema_version': '2',
        'kind': 'timer_sync',
        'run_id': 'run-1',
        'state_version': '1',
        'run_revision': '1',
      }),
      isNull,
    );
  });
}
