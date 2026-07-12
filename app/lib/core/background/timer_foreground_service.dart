import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Native foreground-service yaşam döngüsünün Dart tarafı.
/// Zaman hesabı duvar saatinden yapılır; servis yalnız CPU/lifecycle sahipliğini
/// korur. Canlı chronometer görünümü WP-41'in kapsamındadır.
class TimerForegroundService {
  TimerForegroundService._();

  static const _serviceId = 7040;
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
      if (await FlutterForegroundTask.isRunningService) return;
      await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [ForegroundServiceTypes.dataSync],
      notificationTitle: 'Odak Kampı çalışıyor',
      notificationText: 'Sayaç arka planda korunuyor',
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

  static void _initialize() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'timer_foreground_service',
        channelName: 'Çalışma sayacı servisi',
        channelDescription: 'Çalışan sayacın arka planda korunması',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(15000),
        allowWakeLock: true,
        allowAutoRestart: true,
        // Android 15 dataSync kısıtı nedeniyle boot'tan doğrudan başlatılmaz.
        autoRunOnBoot: false,
      ),
    );
    _initialized = true;
  }
}

@pragma('vm:entry-point')
void _startTimerTask() => FlutterForegroundTask.setTaskHandler(_TimerTask());

class _TimerTask extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async =>
      _heartbeat(timestamp);

  @override
  void onRepeatEvent(DateTime timestamp) => _heartbeat(timestamp);

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  Future<void> _heartbeat(DateTime timestamp) => FlutterForegroundTask.saveData(
    key: 'timer_last_heartbeat',
    value: timestamp.toUtc().toIso8601String(),
  );
}
