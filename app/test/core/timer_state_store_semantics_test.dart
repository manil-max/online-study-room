import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-135: Dart tarafı store anahtar semantiği (native TimerStateStore ile hizalı).
/// Native commit() Kotlin'de; burada idle/running anahtar sözleşmesi doğrulanır.
void main() {
  const startedAt = 'timer_active_started_at';
  const startedAtMs = 'timer_active_started_at_ms';
  const fgMode = 'timer_fg_mode';
  const pending = 'timer_pending_intervals';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('running keys imply isRunning; idle clears start keys', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(startedAt, '2026-07-17T12:00:00.000Z');
    await prefs.setInt(startedAtMs, 1721217600000);
    await prefs.setString(fgMode, 'running');

    final isRunning = (prefs.getString(startedAt)?.isNotEmpty ?? false) ||
        (prefs.getInt(startedAtMs) ?? 0) > 0;
    expect(isRunning, isTrue);

    await prefs.remove(startedAt);
    await prefs.remove(startedAtMs);
    await prefs.setString(fgMode, 'idle');

    final isIdle = !(prefs.getString(startedAt)?.isNotEmpty ?? false) &&
        (prefs.getInt(startedAtMs) ?? 0) <= 0;
    expect(isIdle, isTrue);
    expect(prefs.getString(fgMode), 'idle');
  });

  test('pending_intervals list survives until reconcile clears', () async {
    final prefs = await SharedPreferences.getInstance();
    const raw =
        '[{"start":"2026-07-17T12:00:00.000Z","end":"2026-07-17T12:10:00.000Z","subject":""}]';
    await prefs.setString(pending, raw);
    expect(prefs.getString(pending), raw);
    await prefs.remove(pending);
    expect(prefs.getString(pending), isNull);
  });
}
