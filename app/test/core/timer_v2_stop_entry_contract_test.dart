import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/background/timer_v2_command_outbox.dart';

const _storePath =
    'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/TimerStateStore.kt';
const _servicePath =
    'android/app/src/main/kotlin/com/manilmax/online_study_room/timer/StudyTimerService.kt';
const _migrationPath = '../supabase/migrations/0082_global_timer_v2.sql';
const _pgTapPath =
    '../supabase/tests/018_global_timer_command_contract.test.sql';

Map<String, String> _nativeOriginMapping(String store) {
  final body = store.substring(
    store.indexOf('fun canonicalV2Origin'),
    store.indexOf('\n    }', store.indexOf('fun canonicalV2Origin')),
  );
  return {
    for (final match in RegExp(
      r'"([a-z_]+)"\s*->\s*"([a-z_]+)"',
    ).allMatches(body))
      match.group(1)!: match.group(2)!,
  };
}

Set<String> _serverAllowlist(String migration) {
  final body = RegExp(
    r"v_origin not in \(([^)]*)\)",
  ).firstMatch(migration)!.group(1)!;
  return RegExp(
    "'([a-z_]+)'",
  ).allMatches(body).map((match) => match.group(1)!).toSet();
}

void main() {
  final store = File(_storePath).readAsStringSync();
  final service = File(_servicePath).readAsStringSync();
  final serverOrigins = _serverAllowlist(
    File(_migrationPath).readAsStringSync(),
  );
  final pgTap = File(_pgTapPath).readAsStringSync();
  final mapping = _nativeOriginMapping(store);

  void verifyEntry({
    required String name,
    required String nativeOrigin,
    required String sourceNeedle,
  }) {
    test(
      '$name Durdur istemci zarfı ve sunucu sözleşmesi aynı origin’i kullanır',
      () {
        expect(service, contains(sourceNeedle));
        final emittedOrigin = mapping[nativeOrigin];
        expect(
          emittedOrigin,
          isNotNull,
          reason: '$name ham native origin yazamaz',
        );
        expect(
          TimerV2CommandEnvelope.canonicalOrigins,
          contains(emittedOrigin),
        );
        expect(serverOrigins, contains(emittedOrigin));
        expect(
          pgTap,
          contains("jsonb_build_object('origin', '$emittedOrigin')"),
          reason:
              'pgTAP istemcinin gerçekten kanonikleştirdiği origin’i sunucuya vermeli',
        );
      },
    );
  }

  verifyEntry(
    name: 'Uygulama içi',
    nativeOrigin: 'dart_app',
    sourceNeedle:
        'ACTION_STOP_SILENT -> handleStop(\n                    recordInterval = false,\n                    commandOrigin = "dart_app",',
  );
  verifyEntry(
    name: 'Bildirim',
    nativeOrigin: 'native_notification',
    sourceNeedle:
        'ACTION_STOP -> handleStop(\n                    recordInterval = true,\n                    commandOrigin = "native_notification",',
  );
  verifyEntry(
    name: 'Widget',
    nativeOrigin: 'native_widget',
    sourceNeedle:
        'handleStop(\n                            recordInterval = true,\n                            commandOrigin = "native_widget",',
  );
}
