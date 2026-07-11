import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/updater/updater_service.dart';

/// Yeni sürüm bulunduğunda gösterilen yerel/best-effort bildirim.
///
/// Push/FCM değildir; uygulama açıldığında yapılan GitHub release kontrolünün
/// sonucunu kullanıcıya daha görünür kılar. Bildirim izni yoksa sessizce geçer.
class UpdateNotificationService {
  UpdateNotificationService._(this._plugin);

  static final instance = UpdateNotificationService._(
    FlutterLocalNotificationsPlugin(),
  );

  static const _channelId = 'app_updates';
  static const _channelName = 'Güncellemeler';
  static const _kLastNotifiedVersionCode =
      'update_notification_last_version_code';

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<void> showUpdateAvailable(UpdateInfo info) async {
    if (!_isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_kLastNotifiedVersionCode) == info.versionCode) return;

    await initialize();
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted =
        await androidPlugin?.requestNotificationsPermission() ?? false;
    if (!granted) return;

    const details = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Yeni Odak Kampı sürümleri için bildirimler',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
      ticker: 'Yeni güncelleme hazır',
    );

    await _plugin.show(
      id: 30030,
      title: 'Yeni güncelleme hazır',
      body: '${info.versionName} yayınlandı. Yenilikleri görmek için aç.',
      notificationDetails: const NotificationDetails(android: details),
      payload: 'update:${info.versionCode}',
    );
    await prefs.setInt(_kLastNotifiedVersionCode, info.versionCode);
  }

  bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
