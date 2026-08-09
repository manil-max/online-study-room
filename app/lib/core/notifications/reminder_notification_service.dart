import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import '../l10n/system_localizations.dart';
import 'alarm_notification_service.dart' show localNotificationsSupported;
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

  /// Yalnız test: singleton'ın `_initialized` durumu testler arasına sızmasın
  /// diye taze bir örnek üretir (WP-611 iki yönlü platform iddiası).
  @visibleForTesting
  factory ReminderNotificationService.forTest(
    FlutterLocalNotificationsPlugin plugin,
  ) => ReminderNotificationService._(plugin);

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  /// Bu platformda yerel hatırlatma **gönderilebilir mi?**
  ///
  /// 🔴 WP-611: masaüstünde `false`. Kapı [localNotificationsSupported] ile
  /// alarm servisiyle ortaktır — iki ayrı platform gerçeği tutulmaz.
  bool get isSupported => localNotificationsSupported;

  Future<void> initialize() async {
    if (_initialized) return;
    // 🔴 WP-611: burada koşulsuz olarak Android-only `InitializationSettings`
    // veriliyordu. FLN, Windows'ta `settings.windows == null` görünce
    // `ArgumentError` fırlatır ("Windows settings must be set..."). İstisna
    // `requestPermissionIfNeeded()`ten geri döndüğü için Bildirim
    // Merkezi'ndeki "Seri koruma"/"Haftalık özet" anahtarının `onChanged`i
    // tercihi yazan satıra HİÇ gelmiyordu: kullanıcı anahtarı açıyor, anahtar
    // geri kapanıyor, ekranda tek kelime hata yok.
    if (!isSupported) {
      _initialized = true;
      return;
    }
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  Future<bool> requestPermissionIfNeeded() async {
    // Masaüstünde işletim sistemi izni diye bir şey yok; `true` dönmek
    // "izin verildi" yalanı olurdu. Çağıran yüzey bu `false`u kullanıcıya
    // gösterir (bkz. `notification_center_screen.dart` devre dışı satırlar).
    if (!isSupported) return false;
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await android?.requestNotificationsPermission() ?? true;
  }

  /// Akıllı hatırlatmaları tercihlere göre yeniden planlar.
  Future<void> syncSmartReminders(NotificationPreferences prefs) async {
    // WP-611: `SmartReminderScheduler.sync` ilk iş olarak `cancelAll()` çağırır
    // ve kurulmamış eklentide o da atar.
    if (!isSupported) return;
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
