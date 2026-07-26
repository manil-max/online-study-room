import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_global_timer_repository.dart';

void main() {
  test('V2 command is idempotent and start has a versioned snapshot', () async {
    final repo = InMemoryGlobalTimerRepository();
    final first = await repo.applyCommand(
      commandId: 'cmd-1',
      deviceId: 'device-1',
      action: 'start',
    );
    final retry = await repo.applyCommand(
      commandId: 'cmd-1',
      deviceId: 'device-1',
      action: 'start',
    );
    expect(first.stateVersion, 1);
    expect(first.run?.status, 'running');
    expect(retry.stateVersion, first.stateVersion);
  });

  test('stop clears the V2 run without touching a legacy model', () async {
    final repo = InMemoryGlobalTimerRepository();
    final started = await repo.applyCommand(
      commandId: 'cmd-1',
      deviceId: 'device-1',
      action: 'start',
    );
    final stopped = await repo.applyCommand(
      commandId: 'cmd-2',
      deviceId: 'device-1',
      action: 'stop',
      runId: started.run!.id,
      expectedRunRevision: started.run!.revision,
    );
    expect(stopped.run, isNull);
    expect(stopped.stateVersion, 2);
  });
}
