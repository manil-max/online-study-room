import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/alarm_rule.dart';
import '../../data/models/timer_preset.dart';
import '../time_engine/alarm_scheduler.dart';
import '../l10n/system_localizations.dart';
import '../time_engine/device_timezone.dart';
import '../time_engine/exact_alarm_permission.dart';
import 'native_alarm_bridge.dart';

final alarmNotificationServiceProvider = Provider<AlarmNotificationService>((
  ref,
) {
  return AlarmNotificationService.instance;
});

/// `flutter_local_notifications` bu platformda **kullanılabilir mi?**
///
/// 🔴 WP-611: bu kapı zaten [AlarmNotificationService.initialize] içinde vardı
/// ama YALNIZ oraya uygulanmıştı. Masaüstünde kurulum atlanıp `_initialized`
/// yine de `true` yazılıyor, sonra aynı eklentiye `zonedSchedule` / `cancel` /
/// `show` çağrısı yapılıyordu. Kurulmamış eklenti bu çağrılarda istisna atar
/// (Windows FFI: `StateError` "must be initialized before use"; test ortamı:
/// `LateInitializationError`) ve Windows implementasyonu plugin registrant'ta
/// **kayıtlı** olduğu için `resolvePlatformSpecificImplementation<...>()` null
/// dönmez — yani `?.` bir kurtarma sağlamaz.
///
/// Sonuç sahada: Windows'ta alarm diske yazılıyor ama liste tazelenmiyor ve
/// alarm hiç çalmıyordu. Kapı artık tek yerde tanımlıdır ve çağrı yüzeyinin
/// **tamamına** uygulanır; hatırlatıcı servisi de aynı kapıyı paylaşır.
///
/// 🔴 Bu bir *sessiz yutma* değildir: özelliğin masaüstünde bulunmadığını
/// kullanıcıya söyleyen yüzeyler `AlarmsScreen` / `TimersScreen` şeridi ve
/// Bildirim Merkezi'ndeki devre dışı hatırlatıcı satırlarıdır. Kapıyı
/// genişletirken o yüzeyleri de güncelle; yoksa "ayarı açtım, hiçbir şey
/// olmadı" hatası geri gelir.
///
/// Platform `defaultTargetPlatform` üzerinden okunur (`dart:io Platform`
/// değil): testte `debugDefaultTargetPlatformOverride` ile enjekte edilebilir.
bool get localNotificationsSupported =>
    !kIsWeb &&
    defaultTargetPlatform != TargetPlatform.windows &&
    defaultTargetPlatform != TargetPlatform.linux &&
    defaultTargetPlatform != TargetPlatform.macOS;

/// Alarm/timer planlama: **Android'de native AlarmManager birincil**;
/// FLN yedek/status; masaüstü/web FLN veya no-op.
class AlarmNotificationService {
  AlarmNotificationService({
    FlutterLocalNotificationsPlugin? plugin,
    ExactAlarmPermission? exactPermission,
    NativeAlarmBridge? bridge,
  }) : _plugin = plugin ?? FlutterLocalNotificationsPlugin(),
       _exact = exactPermission ?? ExactAlarmPermission(),
       _bridge = bridge ?? NativeAlarmBridge.instance;

  static final instance = AlarmNotificationService();

  static const String channelId = 'personal_alarms';

  final FlutterLocalNotificationsPlugin _plugin;
  final ExactAlarmPermission _exact;
  final NativeAlarmBridge _bridge;
  bool _initialized = false;

  bool lastUsedExact = true;

  bool get _useNative => !kIsWeb && Platform.isAndroid;

  Future<void> initialize({
    void Function(NotificationResponse)? onResponse,
  }) async {
    if (_initialized) return;
    final l10n = await loadSystemLocalizations();

    await DeviceTimezone.ensureInitialized();

    // Windows/macOS/Linux: FLN Windows settings zorunlu; Android-only init
    // MissingPlugin/Invalid argument fırlatıp log gürültüsü + boşa iş yapıyordu.
    // WP-611: aynı karar artık [localNotificationsSupported] ile tek yerden
    // verilir ve plan/iptal/göster çağrılarına da uygulanır.
    if (!localNotificationsSupported) {
      _initialized = true;
      return;
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: onResponse,
      onDidReceiveBackgroundNotificationResponse: alarmNotificationBg,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        l10n.coreAlarmlarVeZamanlayicilar,
        description: l10n.coreAlarmlarVeZamanlayicilar,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
      ),
    );

    _initialized = true;
  }

  Future<AndroidScheduleMode> _mode() async {
    if (kIsWeb) {
      lastUsedExact = false;
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
    final mode = await _exact.scheduleMode();
    lastUsedExact = mode == AndroidScheduleMode.exactAllowWhileIdle;
    return mode;
  }

  Future<void> scheduleAlarm(
    AlarmRule alarm, {
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    await initialize();
    final l10n = await loadSystemLocalizations();
    final n = now ?? DateTime.now();

    if (!alarm.isActive) {
      await cancelAlarm(alarm.id);
      return;
    }

    final next = AlarmScheduler.nextFire(alarm, n);
    if (next == null) {
      await cancelAlarm(alarm.id);
      return;
    }

    // Birincil: native exact
    if (_useNative) {
      await _bridge.scheduleAlarm(alarm, n);
      return;
    }

    // Yedek: FLN (native yok). WP-611: masaüstünde FLN de yok — kurulmamış
    // eklentiye plan yazmak istisna atıyor, çağıran zincir (liste tazeleme)
    // orada kopuyordu.
    if (!localNotificationsSupported) return;

    final scheduled = tz.TZDateTime.from(next, tz.local);
    final mode = await _mode();
    await _plugin.zonedSchedule(
      id: _notifId(alarm.id),
      title: alarm.label.isNotEmpty ? alarm.label : l10n.coreAlarm,
      body: '${l10n.profileSaat} ${alarm.timeLabel} — ${l10n.desktopOdakKampi}',
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          l10n.coreAlarmlarVeZamanlayicilar,
          channelDescription: l10n.coreAlarmlarVeZamanlayicilar,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
          playSound: true,
          enableVibration: alarm.vibrate,
          ongoing: true,
          autoCancel: false,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction('alarm_dismiss', l10n.clockKapat),
            AndroidNotificationAction('alarm_snooze', l10n.coreErtele),
          ],
        ),
      ),
      androidScheduleMode: mode,
      // Tek seferlik plan; tekrar native/nextFire ile yeniden kurulur
      // (matchDateTimeComponents skip-next ile çakışır).
      payload: 'alarm:${alarm.id}',
    );
  }

  Future<void> cancelAlarm(String id) async {
    await initialize();
    if (_useNative) {
      await _bridge.cancel(kind: 'alarm', id: id);
    }
    // WP-611: iptal her koşulda `_plugin.cancel` çağırıyordu; masaüstünde bu
    // istisna atıp silme akışını yarıda kesiyordu (satır ekranda kalıyordu).
    if (!localNotificationsSupported) return;
    await _plugin.cancel(id: _notifId(id));
  }

  Future<void> rescheduleAll(
    List<AlarmRule> alarms, {
    SharedPreferences? prefs,
    DateTime? now,
  }) async {
    final n = now ?? DateTime.now();
    if (prefs != null) {
      await _bridge.writeAlarmMirror(prefs, alarms, n);
    }
    for (final a in alarms) {
      if (!a.isActive) {
        await cancelAlarm(a.id);
      } else {
        await scheduleAlarm(a, prefs: prefs, now: n);
      }
    }
  }

  Future<void> scheduleTimer(
    TimerInstance instance, {
    SharedPreferences? prefs,
  }) async {
    await initialize();
    final l10n = await loadSystemLocalizations();
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    if (instance.status != TimerStateStatus.running) {
      await cancelTimer(instance.id);
      return;
    }

    if (_useNative) {
      await _bridge.scheduleTimer(instance, nowMs);
      return;
    }

    // WP-611: masaüstünde FLN kurulu değil. Sayaç uygulama açıkken Dart
    // ticker'ı ile çalışmaya devam eder; kurulmamış eklentiye plan yazma
    // denemesi yalnız istisna üretiyordu.
    if (!localNotificationsSupported) return;

    final remainingSec = instance.remainingAt(nowMs);
    if (remainingSec <= 0) {
      await cancelTimer(instance.id);
      return;
    }

    final scheduled = tz.TZDateTime.now(
      tz.local,
    ).add(Duration(seconds: remainingSec));
    final mode = await _mode();
    await _plugin.zonedSchedule(
      id: _notifId(instance.id),
      title: l10n.coreZamanlayiciBitti,
      body: instance.label,
      scheduledDate: scheduled,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          l10n.coreAlarmlarVeZamanlayicilar,
          channelDescription: l10n.coreAlarmlarVeZamanlayicilar,
          importance: Importance.max,
          priority: Priority.high,
          category: AndroidNotificationCategory.alarm,
          fullScreenIntent: true,
        ),
      ),
      androidScheduleMode: mode,
      payload: 'timer:${instance.id}',
    );
  }

  Future<void> cancelTimer(String id) async {
    await initialize();
    if (_useNative) {
      await _bridge.cancel(kind: 'timer', id: id);
    }
    if (!localNotificationsSupported) return;
    await _plugin.cancel(id: _notifId(id));
  }

  /// Geriye uyumluluk: eski API cancelAlarm(id) timer id de iptal ederdi.
  Future<void> cancelById(String id) async {
    await cancelAlarm(id);
    await cancelTimer(id);
  }

  Future<void> showImmediate(String title, String body) async {
    await initialize();
    if (!localNotificationsSupported) return;
    final l10n = await loadSystemLocalizations();
    final details = AndroidNotificationDetails(
      channelId,
      l10n.coreAlarmlarVeZamanlayicilar,
      channelDescription: l10n.coreAlarmlarVeZamanlayicilar,
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.alarm,
    );
    await _plugin.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: details),
    );
  }

  Future<void> previewNativeRing(AlarmRule alarm) => _bridge.previewRing(alarm);

  Future<ExactAlarmStatus> exactAlarmStatus() => _exact.status();

  Future<bool> requestExactAlarmPermission() => _exact.request();

  int _notifId(String id) => id.hashCode & 0x7fffffff;
}

@pragma('vm:entry-point')
void alarmNotificationBg(NotificationResponse response) {
  // Background isolate: native zaten birincil; burada no-op güvenli.
}
