import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/notification_preferences.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/features/clock/clock_widgets_screen.dart';
import 'package:online_study_room/features/notifications/notification_center_screen.dart';
import 'package:online_study_room/features/profile/settings_screen.dart';
import 'package:online_study_room/features/updater/release_notes_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('SettingsScreen ayarlari tek katmanda ve dogrudan acar', (
    tester,
  ) async {
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
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    FlutterError.onError = prev;
    expect(details.map((d) => d.exceptionAsString()), isEmpty);

    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text('Görünüm'), findsNothing);
    expect(find.text('Ana Sayfa ızgarası'), findsNothing);
    expect(find.text('Izgara yoğunluğu'), findsOneWidget);
    expect(find.text('Otomatik'), findsNothing);
    await tester.tap(find.text('6'));
    await tester.pumpAndSettle();
    expect(find.text('16'), findsOneWidget);
    await tester.tap(find.text('16'));
    await tester.pumpAndSettle();

    expect(find.text('Kamp ateşi'), findsNothing);
    expect(find.text('Kamp hayvanın'), findsOneWidget);
    expect(find.text('Gruplar'), findsNothing);
    expect(find.text('Gruplar ekranında da sayaç göster'), findsNothing);
    expect(find.text('Bildirim Merkezi'), findsOneWidget);
    expect(find.text('Bildirim Merkezi’ni aç'), findsNothing);
    expect(find.text('Widget ve alarm izinleri'), findsOneWidget);
    expect(find.text('Görünüm ve atmosfer temaları'), findsOneWidget);
    expect(find.text('Sürüm ve güncellemeler'), findsOneWidget);
    expect(find.text('Uygulama Kısayolları (Rutinler)'), findsOneWidget);
    expect(find.text('Geri bildirim gönder'), findsOneWidget);
    expect(find.text('Yönetim'), findsNothing);

    await tester.tap(find.text('Bildirim Merkezi'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationCenterScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(NotificationCenterScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Widget ve alarm izinleri'));
    await tester.pumpAndSettle();
    expect(find.byType(ClockWidgetsScreen), findsOneWidget);
    expect(find.textContaining('Ana ekran widget'), findsOneWidget);
    Navigator.of(tester.element(find.byType(ClockWidgetsScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sürüm ve güncellemeler'));
    await tester.pumpAndSettle();
    expect(find.byType(ReleaseNotesScreen), findsOneWidget);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
