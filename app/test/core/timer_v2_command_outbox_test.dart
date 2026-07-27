import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/background/timer_v2_command_outbox.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-373: şema 2 → 3 ve `origin` artık **protokol** sözlüğündedir
/// (`widget`), native'in yerel `startOrigin` sözlüğü (`native_widget`) değil.
/// Ayrışmanın kendisi WP-373'nin kök nedeniydi; sözleşme kapanı
/// `timer_v2_origin_contract_test.dart` içindedir.
Map<String, Object?> _command({String accountId = 'account-a'}) => {
  'kind': 'global_timer_command',
  'schema_version': TimerV2CommandEnvelope.schemaVersion,
  'command_id': 'command-1',
  'account_id': accountId,
  'installation_id': 'installation-1',
  'action': 'start',
  'client_occurred_at': '2026-07-26T14:51:00.000Z',
  'origin': 'widget',
};

void main() {
  const adapter = TimerV2CommandFlushAdapter();

  group('WP-340 V2 command envelope', () {
    test('parses a scoped start command without a synthetic run token', () {
      final command = TimerV2CommandEnvelope.tryParse(_command());

      expect(command, isNotNull);
      expect(command!.action, 'start');
      expect(command.accountId, 'account-a');
      expect(command.runId, isNull);
      expect(command.clientOccurredAt, DateTime.utc(2026, 7, 26, 14, 51));
    });

    test(
      'defers only the authenticated account and quarantines all others',
      () {
        expect(
          adapter.inspect(_command(), authenticatedAccountId: 'account-a'),
          TimerV2CommandDisposition.deferred,
        );
        expect(
          adapter.inspect(_command(), authenticatedAccountId: 'account-b'),
          TimerV2CommandDisposition.quarantine,
        );
        expect(
          adapter.inspect(
            _command(accountId: ''),
            authenticatedAccountId: 'account-a',
          ),
          TimerV2CommandDisposition.quarantine,
        );
      },
    );

    test(
      'invalid V2 records are discarded and legacy records stay untouched',
      () {
        final malformed = _command()..remove('command_id');
        expect(
          adapter.inspect(malformed, authenticatedAccountId: 'account-a'),
          TimerV2CommandDisposition.discard,
        );
        expect(
          adapter.inspect({
            'action': 'finalize',
            'runToken': 'legacy',
          }, authenticatedAccountId: 'account-a'),
          TimerV2CommandDisposition.notV2,
        );
      },
    );

    test(
      'account binding clears on logout without rewriting queued envelopes',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        await adapter.bindActiveAccount(prefs, 'account-a');
        expect(
          prefs.getString(TimerV2CommandEnvelope.accountIdKey),
          'account-a',
        );
        await adapter.bindActiveAccount(prefs, null);
        expect(prefs.getString(TimerV2CommandEnvelope.accountIdKey), isNull);
      },
    );

    test(
      'native producer keeps V2 in the existing queue and covers every stop',
      () {
        final store = File(
          'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/TimerStateStore.kt',
        ).readAsStringSync();
        final service = File(
          'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/StudyTimerService.kt',
        ).readAsStringSync();

        expect(store, contains('fun appendV2Command'));
        expect(store, contains('"kind", "global_timer_command"'));
        expect(store, contains('KEY_PENDING_INTERVALS'));
        expect(service, contains('mode == "stopwatch" && phase == "work"'));
        expect(service, contains('startOrigin != "global_timer_mirror"'));
        expect(
          service,
          contains('appendV2Command(prefs(), "start", startOrigin)'),
        );
        expect(service, contains('action = "stop"'));
        // 🔴 WP-373: bu testin eski hâli arızayı DOĞRU davranış diye kayda
        // geçiriyordu ("excludes silent stop"). STOP_SILENT uygulama içi
        // Durdur'dur; senkron sinyali üretmemesi tam olarak karşı cihazın
        // durmamasının sebebiydi. Zarf artık `recordInterval`'dan bağımsızdır.
        expect(
          service,
          contains('ACTION_STOP_SILENT -> handleStop(recordInterval = false)'),
        );
        expect(service, contains('KEY_V2_RUN_ID'));
      },
    );
  });
}
