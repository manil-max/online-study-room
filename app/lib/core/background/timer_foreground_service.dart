import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/duration_format.dart';

/// Native foreground-service yaşam döngüsünün Dart tarafı.
///
/// V8-A tek doğruluk kaynağı: sayaç çalışırken gösterilen **TEK** bildirim budur.
/// Bildirim başlığı, arka plan isolate'inde çalışan [_TimerTask] tarafından her
/// saniye güncellenir (akan `HH:MM:SS`); saat uygulamalarındaki gibi gövde yazısı
/// **yoktur** (yalnız süre + buton). Buton uygulama tamamen kapalıyken de işlenir
/// (`onNotificationButtonPressed`).
///
/// **Durdur↔Başlat kalıcı toggle (WP-41 R2):** Durdur'a basınca servis/bildirim
/// KAPANMAZ. Onun yerine bildirim `00:00:00` + **Başlat**'a döner (idle mod) ve
/// tamamlanan çalışma aralığı [_pendingIntervalsKey] kuyruğuna yazılır; uygulama
/// açılınca [StudyTimerNotifier] bu aralıkları oturum olarak kaydeder. Başlat'a
/// basınca yeni oturum başlar (running mod). Böylece kullanıcı uygulamayı hiç
/// açmadan bildirimden çalışmayı durdurup yeniden başlatabilir.
///
/// Zaman hesabı duvar saatinden (`timer_active_started_at`) yapılır; servis yalnız
/// CPU/lifecycle sahipliğini korur. Ayrı bir `flutter_local_notifications`
/// bildirimi YOKTUR (çift bildirim sorunu giderilir).
class TimerForegroundService {
  TimerForegroundService._();

  static const _serviceId = 7040;

  /// Running modda gösterilen "Durdur" butonunun kimliği.
  static const toggleButtonId = 'timer_toggle';

  /// Idle modda gösterilen "Başlat" butonunun kimliği.
  static const startButtonId = 'timer_start';

  /// FGS'in görünüm modu: `running` (akan süre + Durdur) veya `idle`
  /// (`00:00:00` + Başlat). Hem arka plan isolate'i hem ana isolate okur.
  static const fgModeKey = 'timer_fg_mode';

  /// Uygulama kapalıyken Durdur'a basıldığında üretilen tamamlanmış çalışma
  /// aralıklarının kuyruğu (JSON liste: `{start,end,subject}`). Ana isolate
  /// uygulama açılınca bunları oturum olarak kaydeder ve kuyruğu temizler.
  static const pendingIntervalsKey = 'timer_pending_intervals';

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
      // Running mod: akan süre + Durdur butonu.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(fgModeKey, 'running');
      final elapsed = DateTime.now().difference(startedAt).inSeconds;
      final title = formatHms(elapsed < 0 ? 0 : elapsed);
      if (await FlutterForegroundTask.isRunningService) {
        // Zaten çalışıyorsa (faz geçişi vb.) yalnız görünümü tazele.
        await FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: '',
          notificationButtons: _runningButtons,
        );
        return;
      }
      await FlutterForegroundTask.startService(
        serviceId: _serviceId,
        serviceTypes: const [ForegroundServiceTypes.dataSync],
        notificationTitle: title,
        notificationText: '',
        notificationButtons: _runningButtons,
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(fgModeKey);
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (_) {
      // Platform kanalı olmayan test hostu.
    }
  }

  /// Running modda (akan süre) gösterilen buton: Durdur.
  static const List<NotificationButton> _runningButtons = [
    NotificationButton(id: toggleButtonId, text: 'Durdur'),
  ];

  /// Idle modda (00:00:00) gösterilen buton: Başlat.
  static const List<NotificationButton> _idleButtons = [
    NotificationButton(id: startButtonId, text: 'Başlat'),
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

/// Arka plan isolate'i: bildirimdeki canlı süreyi günceller ve Durdur/Başlat
/// butonlarını uygulama kapalıyken işler.
class _TimerTask extends TaskHandler {
  static const _activeStartedAtKey = 'timer_active_started_at';
  static const _activeSubjectKey = 'timer_active_subject';
  static const _activePhaseKey = 'timer_active_phase';

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
      _pauseToIdle();
    } else if (id == TimerForegroundService.startButtonId) {
      _resumeToRunning();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  /// Bildirim başlığını çalışma süresine (HH:MM:SS) çevirir. Idle'da (duraklatıldı)
  /// süre dondurulur — görünüm tazelenmez.
  Future<void> _refreshNotification() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getString(TimerForegroundService.fgModeKey) == 'idle') return;
    final startedAt =
        DateTime.tryParse(prefs.getString(_activeStartedAtKey) ?? '');
    if (startedAt == null) return;
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    await FlutterForegroundTask.updateService(
      notificationTitle: formatHms(elapsed < 0 ? 0 : elapsed),
      notificationText: '',
      notificationButtons: TimerForegroundService._runningButtons,
    );
  }

  /// Durdur (app kapalıyken de çalışır): tamamlanan çalışma aralığını app
  /// açılışında oturum olarak kaydetmek üzere kuyruğa yaz, bildirimi `00:00:00` +
  /// **Başlat**'a çevir; servisi KAPATMA (canlı kalır, kullanıcı app açmadan
  /// yeniden başlatabilir).
  Future<void> _pauseToIdle() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final startedAt =
        DateTime.tryParse(prefs.getString(_activeStartedAtKey) ?? '');
    final phase = prefs.getString(_activePhaseKey) ?? 'work';
    // Yalnız çalışma fazı kaydedilir (mola sayılmaz). Kronometrede faz hep work.
    if (startedAt != null && phase == 'work') {
      final now = DateTime.now();
      if (now.isAfter(startedAt)) {
        await _appendPendingInterval(
          prefs,
          start: startedAt,
          end: now,
          subject: prefs.getString(_activeSubjectKey) ?? '',
        );
      }
    }
    // Aktif oturum bitti: started_at kalksın (idle), mod idle.
    await prefs.remove(_activeStartedAtKey);
    await prefs.setString(TimerForegroundService.fgModeKey, 'idle');
    await FlutterForegroundTask.updateService(
      notificationTitle: formatHms(0),
      notificationText: '',
      notificationButtons: TimerForegroundService._idleButtons,
    );
    // Uygulama AÇIKSA anında uzlaştır (onResume tetiklenmez); KAPALIYSA no-op olur
    // ve aralık app açılışında kuyruktan işlenir.
    FlutterForegroundTask.sendDataToMain(TimerForegroundService.toggleButtonId);
  }

  /// Başlat (app kapalıyken de çalışır): yeni oturum başlat (`started_at=now`),
  /// bildirimi akan süre + **Durdur**'a çevir.
  Future<void> _resumeToRunning() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final now = DateTime.now();
    await prefs.setString(_activeStartedAtKey, now.toIso8601String());
    await prefs.setString(TimerForegroundService.fgModeKey, 'running');
    await FlutterForegroundTask.updateService(
      notificationTitle: formatHms(0),
      notificationText: '',
      notificationButtons: TimerForegroundService._runningButtons,
    );
    FlutterForegroundTask.sendDataToMain(TimerForegroundService.startButtonId);
  }

  /// Tamamlanan bir çalışma aralığını app-açılış kuyruğuna ekler.
  Future<void> _appendPendingInterval(
    SharedPreferences prefs, {
    required DateTime start,
    required DateTime end,
    required String subject,
  }) async {
    final list = <dynamic>[];
    try {
      final raw = prefs.getString(TimerForegroundService.pendingIntervalsKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is List) list.addAll(decoded);
      }
    } catch (_) {
      // Bozuk kuyruk: sıfırdan yaz.
    }
    list.add(<String, dynamic>{
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'subject': subject,
    });
    await prefs.setString(
      TimerForegroundService.pendingIntervalsKey,
      jsonEncode(list),
    );
  }
}
