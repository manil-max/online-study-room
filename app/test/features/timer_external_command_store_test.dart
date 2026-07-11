import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:online_study_room/core/notifications/timer_external_command_store.dart';

void main() {
  test('TimerExternalCommandStore correctly reads and writes commands', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = TimerExternalCommandStore(prefs);

    expect(store.command, isNull);

    await store.setCommand('start');
    expect(store.command, 'start');

    await store.clearCommand();
    expect(store.command, isNull);
  });
}
