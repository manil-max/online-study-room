import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prefs/app_prefs.dart';

class NotificationPreferences {
  const NotificationPreferences({required this.nudgeNotificationsEnabled});

  final bool nudgeNotificationsEnabled;

  NotificationPreferences copyWith({bool? nudgeNotificationsEnabled}) {
    return NotificationPreferences(
      nudgeNotificationsEnabled:
          nudgeNotificationsEnabled ?? this.nudgeNotificationsEnabled,
    );
  }
}

class NotificationPreferencesNotifier
    extends Notifier<NotificationPreferences> {
  static const _kNudgeNotifications = 'notification_nudges_enabled';

  @override
  NotificationPreferences build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return NotificationPreferences(
      nudgeNotificationsEnabled: prefs.getBool(_kNudgeNotifications) ?? true,
    );
  }

  Future<void> setNudgeNotificationsEnabled(bool value) async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_kNudgeNotifications, value);
    state = state.copyWith(nudgeNotificationsEnabled: value);
  }
}

final notificationPreferencesProvider =
    NotifierProvider<NotificationPreferencesNotifier, NotificationPreferences>(
      NotificationPreferencesNotifier.new,
    );
