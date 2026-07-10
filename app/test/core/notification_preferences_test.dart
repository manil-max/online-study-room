import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/notification_preferences.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'nudge notification preference defaults to enabled and persists',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(
        container
            .read(notificationPreferencesProvider)
            .nudgeNotificationsEnabled,
        isTrue,
      );

      await container
          .read(notificationPreferencesProvider.notifier)
          .setNudgeNotificationsEnabled(false);

      expect(prefs.getBool('notification_nudges_enabled'), isFalse);
      expect(
        container
            .read(notificationPreferencesProvider)
            .nudgeNotificationsEnabled,
        isFalse,
      );
    },
  );
}
