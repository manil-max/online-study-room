import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import '../l10n/system_localizations.dart';
import 'notification_preferences.dart';
import 'smart_reminder_scheduler.dart';

final reminderNotificationServiceProvider =
    Provider<ReminderNotificationService>((ref) {
      return ReminderNotificationService.instance;
    });

/// Akıllı hatırlatmaları (seri + haftalık özet) yerel bildirim olarak planlar.
///
/// Alarm/timer servisinden ayrıdır; kendi kanalını kullanır.
///
/// WP-304: kişisel çalışma hatırlatıcıları (`StudyReminder`) kaldırıldı —
/// alarm aynı işi sesli, tam ekran ve ertelemeli yapıyordu, iki kavram tek
/// işi anlatıyordu. Geriye yalnız WP-153'ün akıllı hatırlatmaları kaldı.
class ReminderNotificationService {
  ReminderNotificationService._(this._plugin);

  static final instance = ReminderNotificationService._(
    FlutterLocalNotificationsPlugin(),
  );

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<bool> requestPermissionIfNeeded() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Akıllı hatırlatmaları tercihlere göre yeniden planlar.
  Future<void> syncSmartReminders(NotificationPreferences prefs) async {
    await initialize();
    final l10n = await loadSystemLocalizations();
    await SmartReminderScheduler(_plugin).sync(
      prefs: prefs,
      streakTitle: l10n.smartStreakTitle,
      streakBody: l10n.smartStreakBody,
      weeklyTitle: l10n.smartWeeklyTitle,
      weeklyBody: l10n.smartWeeklyBody,
      channelName: l10n.coreCalismaHatirlaticilari,
      channelDescription: l10n.corePlanlanmisCalismaHatirlaticilari,
    );
  }
}
