import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs/app_prefs.dart';

/// Bildirim Merkezi tercihleri (§WP-36). Tüm türler ve sessiz saatler tek
/// yerden yönetilir; değerler cihazda `SharedPreferences` ile kalıcıdır.
class NotificationPreferences {
  const NotificationPreferences({
    required this.nudgeNotificationsEnabled,
    required this.remindersEnabled,
    required this.announcementsEnabled,
    required this.updatesEnabled,
    required this.quietHoursEnabled,
    required this.quietStartMinutes,
    required this.quietEndMinutes,
  });

  final bool nudgeNotificationsEnabled;
  final bool remindersEnabled;
  final bool announcementsEnabled;
  final bool updatesEnabled;
  final bool quietHoursEnabled;

  /// Gün içi dakika cinsinden (0–1439) sessiz saat başlangıcı ve bitişi.
  final int quietStartMinutes;
  final int quietEndMinutes;

  /// Verilen an sessiz saat aralığında mı? Gece yarısını saran aralıkları
  /// (ör. 22:00–07:00) da doğru değerlendirir.
  bool isWithinQuietHours(DateTime now) {
    if (!quietHoursEnabled) return false;
    if (quietStartMinutes == quietEndMinutes) return false;
    final m = now.hour * 60 + now.minute;
    if (quietStartMinutes < quietEndMinutes) {
      return m >= quietStartMinutes && m < quietEndMinutes;
    }
    // Gece yarısını saran aralık.
    return m >= quietStartMinutes || m < quietEndMinutes;
  }

  NotificationPreferences copyWith({
    bool? nudgeNotificationsEnabled,
    bool? remindersEnabled,
    bool? announcementsEnabled,
    bool? updatesEnabled,
    bool? quietHoursEnabled,
    int? quietStartMinutes,
    int? quietEndMinutes,
  }) {
    return NotificationPreferences(
      nudgeNotificationsEnabled:
          nudgeNotificationsEnabled ?? this.nudgeNotificationsEnabled,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      announcementsEnabled: announcementsEnabled ?? this.announcementsEnabled,
      updatesEnabled: updatesEnabled ?? this.updatesEnabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
      quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
    );
  }
}

class NotificationPreferencesNotifier
    extends Notifier<NotificationPreferences> {
  static const kNudgeNotifications = 'notification_nudges_enabled';
  static const kReminders = 'notification_reminders_enabled';
  static const kAnnouncements = 'notification_announcements_enabled';
  static const kUpdates = 'notification_updates_enabled';
  static const kQuietEnabled = 'notification_quiet_enabled';
  static const kQuietStart = 'notification_quiet_start';
  static const kQuietEnd = 'notification_quiet_end';

  static const _defaultQuietStart = 22 * 60; // 22:00
  static const _defaultQuietEnd = 7 * 60; // 07:00

  @override
  NotificationPreferences build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return NotificationPreferences(
      nudgeNotificationsEnabled: prefs.getBool(kNudgeNotifications) ?? true,
      remindersEnabled: prefs.getBool(kReminders) ?? true,
      announcementsEnabled: prefs.getBool(kAnnouncements) ?? true,
      updatesEnabled: prefs.getBool(kUpdates) ?? true,
      quietHoursEnabled: prefs.getBool(kQuietEnabled) ?? false,
      quietStartMinutes: prefs.getInt(kQuietStart) ?? _defaultQuietStart,
      quietEndMinutes: prefs.getInt(kQuietEnd) ?? _defaultQuietEnd,
    );
  }

  Future<void> setNudgeNotificationsEnabled(bool value) =>
      _setBool(kNudgeNotifications, value,
          () => state = state.copyWith(nudgeNotificationsEnabled: value));

  Future<void> setRemindersEnabled(bool value) => _setBool(kReminders, value,
      () => state = state.copyWith(remindersEnabled: value));

  Future<void> setAnnouncementsEnabled(bool value) => _setBool(
      kAnnouncements, value,
      () => state = state.copyWith(announcementsEnabled: value));

  Future<void> setUpdatesEnabled(bool value) => _setBool(kUpdates, value,
      () => state = state.copyWith(updatesEnabled: value));

  Future<void> setQuietHoursEnabled(bool value) => _setBool(
      kQuietEnabled, value,
      () => state = state.copyWith(quietHoursEnabled: value));

  Future<void> setQuietHours({required int startMinutes, required int endMinutes}) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(kQuietStart, startMinutes);
    await prefs.setInt(kQuietEnd, endMinutes);
    state = state.copyWith(
      quietStartMinutes: startMinutes,
      quietEndMinutes: endMinutes,
    );
  }

  Future<void> _setBool(String key, bool value, void Function() apply) async {
    await ref.read(sharedPreferencesProvider).setBool(key, value);
    apply();
  }
}

final notificationPreferencesProvider =
    NotifierProvider<NotificationPreferencesNotifier, NotificationPreferences>(
      NotificationPreferencesNotifier.new,
    );
