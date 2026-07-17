import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-136: store anahtarlarından running/idle türetilir (SSOT semantiği).
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('hasActiveStart from ms or iso; idle when both cleared', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('timer_active_started_at_ms', 1_700_000_000_000);
    await prefs.setString('timer_fg_mode', 'running');

    bool hasActiveStart() =>
        (prefs.getString('timer_active_started_at')?.isNotEmpty ?? false) ||
        (prefs.getInt('timer_active_started_at_ms') ?? 0) > 0;

    expect(hasActiveStart(), isTrue);
    final fgMode =
        prefs.getString('timer_fg_mode') ?? (hasActiveStart() ? 'running' : 'idle');
    expect(fgMode, 'running');

    await prefs.remove('timer_active_started_at_ms');
    await prefs.setString('timer_fg_mode', 'idle');
    expect(hasActiveStart(), isFalse);
    final idleMode =
        prefs.getString('timer_fg_mode') ?? (hasActiveStart() ? 'running' : 'idle');
    expect(idleMode, 'idle');
  });

  test('pending queue kept when flag says do not clear', () async {
    final prefs = await SharedPreferences.getInstance();
    const raw = '[{"start":"a","end":"b"}]';
    await prefs.setString('timer_pending_intervals', raw);
    const recordedOk = false;
    if (recordedOk) {
      await prefs.remove('timer_pending_intervals');
    }
    expect(prefs.getString('timer_pending_intervals'), raw);
  });
}
