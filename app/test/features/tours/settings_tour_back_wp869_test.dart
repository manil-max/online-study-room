// WP-869: Ayarlar turu açıkken geri çıkılınca tur durumu "çalışıyor" kalıyordu.
//
// Senaryo (mobil): Ayarlar ilk kez açılır → tanıtım balonu çıkar. Balon
// yalnız gövdeyi örter; AppBar'daki geri oku (ve Android geri tuşu) açıktır.
// Kullanıcı "Atla"/"Devam"a basmadan geri çıkar. `TourHost` yok olur ama
// küresel `tourControllerProvider` hâlâ `settings.v1`i çalışıyor sanır:
//  - başka her ekranın turu (`otherTourRunning`) bir daha hiç başlamaz —
//    Ayarlar yeniden açılıp tur bitirilene kadar;
//  - o ekranların `TourHost`u her 400 ms'de boşuna yeniden dener.
//
// Beklenen: sahibi kalmayan tur askıya alınır (görüldü YAZILMAZ — kullanıcı
// okumadı), diğer turlar başlayabilir, Ayarlar yeniden açılınca tur yine çıkar.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/notification_preferences.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/tour/tour_host.dart';
import 'package:online_study_room/core/tour/tour_models.dart';
import 'package:online_study_room/core/tour/tour_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/features/profile/settings_screen.dart';
import 'package:online_study_room/features/tours/app_tours.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kUser = 'u1';
final _tr = AppLocalizationsTr();

final _otherTour = TourDefinition(
  id: 'other',
  version: 1,
  steps: [TourStep(id: 'one', text: 'Baska ekranin turu')],
);

class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      children: [
        TextButton(
          key: const Key('open-settings'),
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          child: const Text('ayarlar'),
        ),
        TextButton(
          key: const Key('open-other'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                body: TourHost(definition: _otherTour, child: const SizedBox()),
              ),
            ),
          ),
          child: const Text('diger'),
        ),
      ],
    ),
  );
}

void main() {
  testWidgets('turu yarida birakip geri cikmak baska turlari kilitlemez', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final prefs = await SharedPreferences.getInstance();
    final adminRepo = InMemoryAdminRepository();
    addTearDown(adminRepo.dispose);
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authStateProvider.overrideWith(
            (ref) => Stream.value(
              Profile(id: _kUser, displayName: 'Ben', createdAt: DateTime(2026)),
            ),
          ),
          adminRepositoryProvider.overrideWithValue(adminRepo),
          notificationPreferencesProvider.overrideWith(
            NotificationPreferencesNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _Home(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(_tr.tourSettingsOverview), findsOneWidget);

    // Balon açıkken Android geri tuşu (AppBar geri oku da örtülmez).
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Kullanıcı okumadı: görüldü yazılmaz.
    final seenKey = tourSeenKey(
      storageId: AppTours.settings(_tr).storageId,
      userId: _kUser,
    );
    expect(prefs.getBool(seenKey), isNull);

    // Başka bir ekranın turu başlayabilmeli.
    await tester.tap(find.byKey(const Key('open-other')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 900));
    expect(
      find.text('Baska ekranin turu'),
      findsOneWidget,
      reason: 'yarida birakilan Ayarlar turu diger turlari kilitledi',
    );
    await tester.tap(find.byKey(const Key('tour-next-button')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    // Ayarlar yeniden açılınca kendi turu yine çıkar.
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(_tr.tourSettingsOverview), findsOneWidget);
  });
}
