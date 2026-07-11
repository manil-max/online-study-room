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
  testWidgets('SettingsScreen renders without Timer group', (tester) async {
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

    // Ayarlar gövdesi lazy bir ListView; ekran dışı gruplar kurulmaz. Tüm grupların
    // (WP-30 "Sürüm ve güncellemeler" eklendikten sonra dahil) tek karede build
    // edilip find.text ile bulunabilmesi için viewport'u bolca yüksek tut.
    tester.view.physicalSize = const Size(1080, 12000);
    tester.view.devicePixelRatio = 3.0;

    final details = <FlutterErrorDetails>[];
    final prev = FlutterError.onError;
    FlutterError.onError = details.add;

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    FlutterError.onError = prev;
    expect(details.map((d) => d.exceptionAsString()), isEmpty);

    expect(find.text('Görünüm'), findsOneWidget);
    expect(find.text('Kamp ateşi'), findsOneWidget);
    // WP-36: "Ana Sayfa" grubu kaldırıldı; sayaç anahtarı "Gruplar" grubuna taşındı.
    expect(find.text('Ana Sayfa'), findsNothing);
    expect(find.text('Gruplar'), findsOneWidget);
    // WP-36: "Bildirimler" grubu tek girişli "Bildirim Merkezi" oldu.
    expect(find.text('Bildirim Merkezi'), findsOneWidget);
    expect(find.text('Cihaz Entegrasyonları'), findsOneWidget);
    expect(find.text('Destek'), findsOneWidget);
    expect(find.text('Geri bildirim gönder'), findsOneWidget);
    expect(find.text('Yönetim'), findsNothing);

    // Verify timer group is removed
    expect(find.text('Sayaç'), findsNothing);
    expect(find.text('Zamanlayıcı modları ve odak ayarları'), findsNothing);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
