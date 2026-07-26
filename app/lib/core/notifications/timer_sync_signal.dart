import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// WP-345: FCM timer_sync verisi bir komut değil, doğrulanmış snapshot için
/// kısa ömürlü tetikleyicidir. Token, kullanıcı kimliği veya timer gerçeği
/// taşınmaz; uygulama açılınca coordinator auth'lı RPC ile yeniden okur.
class TimerSyncSignal {
  const TimerSyncSignal({
    required this.eventId,
    required this.runId,
    required this.stateVersion,
    required this.runRevision,
  });

  final String eventId;
  final String runId;
  final int stateVersion;
  final int runRevision;

  static const pendingKey = 'timer_sync_pending_v1';
  static final _stream = StreamController<TimerSyncSignal>.broadcast();
  static Stream<TimerSyncSignal> get stream => _stream.stream;

  static TimerSyncSignal? tryParse(
    Map<String, dynamic> data, {
    String? eventId,
  }) {
    if (data['notification_type']?.toString() != 'timer_sync' ||
        data['schema_version']?.toString() != '1' ||
        data['kind']?.toString() != 'timer_sync') {
      return null;
    }
    final runId = data['run_id']?.toString().trim() ?? '';
    final stateVersion = int.tryParse(data['state_version']?.toString() ?? '');
    final runRevision = int.tryParse(data['run_revision']?.toString() ?? '');
    if (runId.isEmpty ||
        stateVersion == null ||
        stateVersion < 1 ||
        runRevision == null ||
        runRevision < 1) {
      return null;
    }
    return TimerSyncSignal(
      eventId: eventId?.trim().isNotEmpty == true
          ? eventId!.trim()
          : 'timer_sync:$runId:$stateVersion:$runRevision',
      runId: runId,
      stateVersion: stateVersion,
      runRevision: runRevision,
    );
  }

  static Future<void> record(
    Map<String, dynamic> data, {
    String? eventId,
  }) async {
    final signal = tryParse(data, eventId: eventId);
    if (signal == null) return;
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getString(pendingKey);
    final encoded =
        '${signal.eventId}|${signal.runId}|${signal.stateVersion}|${signal.runRevision}';
    if (previous == encoded) return;
    await prefs.setString(pendingKey, encoded);
    _stream.add(signal);
  }

  /// Sinyal tüketimi auth snapshot apply başarıyla tamamlanana kadar ertelenir.
  static Future<void> clear() async =>
      (await SharedPreferences.getInstance()).remove(pendingKey);
}
