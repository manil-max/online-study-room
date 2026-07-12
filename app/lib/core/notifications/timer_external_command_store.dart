import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../prefs/app_prefs.dart';

final timerExternalCommandStoreProvider = Provider<TimerExternalCommandStore>((ref) {
  return TimerExternalCommandStore(ref.watch(sharedPreferencesProvider));
});

/// Arka planda Native bileşenler (Widget veya Bildirim aksiyonları) tarafından
/// [SharedPreferences] üzerine yazılan başlat/durdur komutlarını yönetir.
/// Native taraf komutu "flutter.timer_external_command" anahtarıyla kaydeder.
class TimerExternalCommandStore {
  const TimerExternalCommandStore(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'timer_external_command';

  Future<void> reload() async {
    await _prefs.reload();
  }

  TimerExternalCommand? get pendingCommand {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return TimerExternalCommand(
        command: map['command'] as String,
        sequence: map['sequence'] as int? ?? 0,
      );
    } catch (_) {
      // Önceki native yazıcılarla geriye uyumluluk.
      return TimerExternalCommand(command: raw, sequence: 0);
    }
  }

  String? get command => pendingCommand?.command;

  Future<void> clearCommand() async {
    await _prefs.remove(_key);
  }

  Future<void> setCommand(String cmd) async {
    final nextSequence = (pendingCommand?.sequence ?? 0) + 1;
    await _prefs.setString(
      _key,
      jsonEncode({'command': cmd, 'sequence': nextSequence}),
    );
  }
}

class TimerExternalCommand {
  const TimerExternalCommand({required this.command, required this.sequence});
  final String command;
  final int sequence;
}
