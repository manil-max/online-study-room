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

  String? get command => _prefs.getString(_key);

  Future<void> clearCommand() async {
    await _prefs.remove(_key);
  }

  Future<void> setCommand(String cmd) async {
    await _prefs.setString(_key, cmd);
  }
}
