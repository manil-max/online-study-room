import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/notification_preferences.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/features/notifications/notification_permissions_screen.dart';
import 'package:online_study_room/features/profile/about_screen.dart';
import 'package:online_study_room/features/profile/settings_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('SettingsScreen ayarlari tek katmanda ve dogrudan acar', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'onboarding.completed_v1.u1': true,
    });
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
    // (WP-456 "Hakkında ve güncellemeler" dahil) tek karede build
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
    expect(find.text('Ana Sayfa ızgarası'), findsNothing);
    // WP-186: ızgara yoğunluğu seçicisi kaldırıldı (sabit 32).
    expect(find.text('Izgara yoğunluğu'), findsNothing);
    expect(find.text('Otomatik'), findsNothing);

    expect(find.text('Kamp ateşi'), findsNothing);
    expect(find.text('Kamp hayvanın'), findsOneWidget);
    expect(find.text('Gruplar'), findsNothing);
    expect(find.text('Gruplar ekranında da sayaç göster'), findsNothing);
    expect(find.text('Bildirim Merkezi'), findsOneWidget);
    expect(find.text('Bildirim Merkezi’ni aç'), findsNothing);
    expect(find.text('Widget ve alarm izinleri'), findsNothing);
    expect(find.text('Görünüm ve atmosfer temaları'), findsOneWidget);
    expect(find.text('Uygulama dili'), findsOneWidget);
    expect(find.text('Hakkında ve güncellemeler'), findsOneWidget);
    expect(find.text('Sürüm ve güncellemeler'), findsNothing);
    expect(find.text('Uygulama Kısayolları (Rutinler)'), findsNothing);
    // WP-420: ad kısaldı — ekran artık gönderme + geçmiş sekmesi taşıyor.
    expect(find.text('Geri bildirim gönder'), findsNothing);
    expect(find.text('Geri bildirim'), findsOneWidget);
    expect(find.text('Yönetim'), findsNothing);
    // WP-456: ayrı Hakkında ve Sürüm satırları tek girişte birleşti.
    expect(find.text('Hakkında'), findsNothing);

    // WP-320: 1080 fiziksel px / 3x DPR = 360dp dar ekranda da bilgi
    // mimarisi sabit kalır; hesap silme ekranına giden giriş ile dışa aktarma
    // aynı "Hesap" bölümündedir, yasal merkez en son bölümdedir.
    final sections = [
      find.text('Görünüm'),
      find.text('Bildirimler'),
      find.text('Hesap'),
      find.text('Çalışma tercihleri'),
      find.text('Gizlilik ve güvenlik'),
      find.text('Hakkında ve yasal'),
    ];
    for (final section in sections) {
      expect(section, findsOneWidget);
    }
    for (var index = 1; index < sections.length; index++) {
      expect(
        tester.getTopLeft(sections[index - 1]).dy,
        lessThan(tester.getTopLeft(sections[index]).dy),
      );
    }
    expect(
      tester.getTopLeft(find.text('Hesabımı Yönet')).dy,
      greaterThan(tester.getTopLeft(find.text('Hesap')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Verilerimi dışa aktar')).dy,
      greaterThan(tester.getTopLeft(find.text('Hesap')).dy),
    );

    await tester.tap(find.byKey(const Key('reset-introduction-tours')));
    await tester.pumpAndSettle();
    expect(prefs.getBool('onboarding.completed_v1.u1'), isFalse);

    await tester.tap(find.text('Bildirim Merkezi'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationPermissionsScreen), findsOneWidget);
    Navigator.of(
      tester.element(find.byType(NotificationPermissionsScreen)),
    ).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings-about-updates')));
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsOneWidget);

    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets('monthly report switch keeps the optimistic disabled value', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authRepo = InMemoryAuthRepository();
    addTearDown(authRepo.dispose);
    await authRepo.signUp(
      email: 'ben@example.com',
      password: 'secret1',
      displayName: 'Ben',
    );
    tester.view.physicalSize = const Size(1080, 12000);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(authRepo),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NotificationPermissionsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final reportTile = find.byKey(const Key('monthly-report-opt-in'));
    expect(tester.widget<SwitchListTile>(reportTile).value, isTrue);
    await tester.ensureVisible(reportTile);
    await tester.pumpAndSettle();
    await tester.tap(reportTile);
    await tester.pump();

    expect(tester.widget<SwitchListTile>(reportTile).value, isFalse);
    await tester.pumpAndSettle();
    expect(authRepo.currentUser?.monthlyReportOptIn, isFalse);
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets(
    'WP-320 bölüm başlıkları 360dp ve tüm desteklenen dillerde taşmaz',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final adminRepo = InMemoryAdminRepository();
      addTearDown(adminRepo.dispose);
      tester.view.physicalSize = const Size(1080, 12000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      for (final locale in const [
        Locale('tr'),
        Locale('en'),
        Locale('de'),
        Locale('ar'),
      ]) {
        final details = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = details.add;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              authStateProvider.overrideWith(
                (ref) => Stream.value(
                  Profile(
                    id: 'u1',
                    displayName: 'Ben',
                    createdAt: DateTime.now(),
                  ),
                ),
              ),
              adminRepositoryProvider.overrideWithValue(adminRepo),
              notificationPreferencesProvider.overrideWith(
                () => NotificationPreferencesNotifier(),
              ),
            ],
            child: MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        FlutterError.onError = previousOnError;
        expect(
          details.map((detail) => detail.exceptionAsString()),
          isEmpty,
          reason: '${locale.languageCode} yerleşim hatası üretmemeli',
        );
      }
    },
  );
}
