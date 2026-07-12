import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/duration_format.dart';

/// Native foreground-service yaşam döngüsünün Dart tarafı.
///
/// V8-A tek doğruluk kaynağı: sayaç çalışırken gösterilen **TEK** bildirim budur.
/// Bildirim başlığı, arka plan isolate'inde çalışan [_TimerTask] tarafından her
/// saniye güncellenir (akan `HH:MM:SS`), altında **Durdur** butonu bulunur ve bu
/// buton uygulama tamamen kapalıyken bile işlenir (`onNotificationButtonPressed`).
/// Böylece ayrı bir `flutter_local_notifications` bildirimi YOKTUR (çift bildirim
/// sorunu giderilir). Zaman hesabı duvar saatinden (`timer_active_started_at`)
/// yapılır; servis yalnız CPU/lifecycle sahipliğini korur.
class TimerForegroundService {
  TimerForegroundService._();

  static const _serviceId = 7040;
  static const toggleButtonId = 'timer_toggle';
  static bool _initialized = false;

  static Future<void> start({
    required DateTime startedAt,
    required String mode,
    required String phase,
    required int cycle,
    String? subjectId,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      _initialize();
      await FlutterForegroundTask.saveData(
        key: 'timer_state',
        value: <String, dynamic>{
          'startedAt': startedAt.toUtc().toIso8601String(),
          'mode': mode,
          'phase': phase,
          'cycle': cycle,
          'subjectId': subjectId,
        },
      );
      final elapsed = DateTime.now().difference(startedAt).inSeconds;
      final title = formatHms(elapsed < 0 ? 0 : elapsed);
      if (await FlutterForegroundTask.isRunningService) {
        // Zaten çalışıyorsa (faz geçişi vb.) yalnız görünümü tazele.
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: 'Odak Kampı çalışıyor',
          notificationButtons: _buttons,
        );
        return;
      }
      await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        serviceTypes: const [ForegroundServiceTypes.dataSync],
        notificationTitle: title,
        notificationText: 'Odak Kampı çalışıyor',
        notificationButtons: _buttons,
        callback: _startTimerTask,
      );
    } catch (_) {
      // Test/web-benzeri hostlarda platform kanalı yoktur; timer state bozulmaz.
    }
  }

  static Future<void> stop() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await FlutterForegroundTask.removeData(key: 'timer_state');
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {
      // Platform kanalı olmayan test hostu.
    }
  }

  static const List<NotificationButton> _buttons = [
    NotificationButton(id: toggleButtonId, text: 'Durdur'),
  ];

  static void _initialize() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        // Tek bildirim olduğu için görünür (DEFAULT) — ama sessiz.
        channelId: 'study_timer_live_fg',
        channelName: 'Çalışma sayacı',
        channelDescription: 'Sayaç çalışırken canlı süreyi gösteren bildirim',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.DEFAULT,
        enableVibration: false,
        playSound: false,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions:
          const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Bildirimdeki süreyi saniyede bir tazelemek için 1 sn periyot.
        eventAction: ForegroundTaskEventAction.repeat(1000),
        allowWakeLock: true,
        allowAutoRestart: true,
        autoRunOnBoot: false,
      ),
    );
    _initialized = true;
  }
}

@pragma('vm:entry-point')
void _startTimerTask() => FlutterForegroundTask.setTaskHandler(_TimerTask());

/// Arka plan isolate'i: bildirimdeki canlı süreyi günceller ve Durdur butonunu
/// uygulama kapalıyken işler.
class _TimerTask extends TaskHandler {
  static const _activeStartedAtKey = 'timer_active_started_at';
  static const _commandKey = 'timer_external_command';

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _refreshNotification();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _refreshNotification();
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == TimerForegroundService.toggleButtonId) {
      _requestStopAndHide();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  /// Bildirim başlığını çalışma süresine (HH:MM:SS) çevirir.
  Future<void> _refreshNotification() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final startedAt = DateTime.tryParse(prefs.getString(_activeStartedAtKey) ?? '');
    if (startedAt == null) return;
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    await FlutterForegroundTask.updateService(
      notificationTitle: formatHms(elapsed < 0 ? 0 : elapsed),
      notificationText: 'Odak Kampı çalışıyor',
      notificationButtons: TimerForegroundService._buttons,
    );
  }

  /// Durdur: gerçek durdurma anını yaz (app açılınca oturum bu anla kaydedilir),
  /// sonra servisi/bildirimi kapat. Sayaç state'i app açılışında sonlandırılır.
  Future<void> _requestStopAndHide() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    var sequence = 1;
    try {
      final raw = prefs.getString(_commandKey);
      if (raw != null) {
        sequence =
            ((jsonDecode(raw) as Map<String, dynamic>)['sequence'] as int? ?? 0) +
                1;
      }
    } catch (_) {}
    await prefs.setString(
      _commandKey,
      jsonEncode({
        'command': 'stop',
        'sequence': sequence,
        'at': DateTime.now().toIso8601String(),
      }),
    );
    // Uygulama AÇIKSA anında işlensin (onResume tetiklenmez); KAPALIYSA no-op olur
    // ve komut app açılışında işlenir.
    FlutterForegroundTask.sendDataToMain(TimerForegroundService.toggleButtonId);
    await FlutterForegroundTask.stopService();
  }
}
