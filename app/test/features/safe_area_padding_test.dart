import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/notification_preferences.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/features/profile/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('SettingsScreen applies bottom padding for safe area (WP-25)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final adminRepo = InMemoryAdminRepository();
    addTearDown(adminRepo.dispose);

    final overrides = [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authStateProvider.overrideWith(
        (ref) => Stream.value(
          Profile(id: 'u1', displayName: 'Ben', createdAt: DateTime.now()),
        ),
      ),
      adminRepositoryProvider.overrideWithValue(adminRepo),
      notificationPreferencesProvider.overrideWith(
        () => NotificationPreferencesNotifier(),
      ),
    ];

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MediaQuery(
          // Simulate 48 logical pixels of bottom padding (3-button nav)
          data: const MediaQueryData(padding: EdgeInsets.only(bottom: 48)),
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify SettingsScreen list view padding
    final listView = tester.widget<ListView>(find.byType(ListView));
    final padding = listView.padding as EdgeInsets;
    
    // The base padding was fromLTRB(16, 12, 16, 24).
    // Adding 48 safe bottom makes it 24 + 48 = 72.
    expect(padding.bottom, 72.0);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
