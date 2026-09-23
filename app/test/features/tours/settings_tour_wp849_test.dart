// WP-849 — AYARLAR TANITIM KARTI (sahip, v87).
//
// Sahip: "Ayarlar sekmesine tek seferlik, gerekli her seyi aciklayan sade ve
// net bir tanitim karti koy; ayarlari acinca ciksin, sigmazsa 2. kart olabilir."
//
// Olculen sey tanim degil EKRAN (bkz. `tour_surfaces_wp837_test.dart` basligi):
// Ayarlar ilk acildiginda balon CIKIYOR mu, "goruldu" isaretlendikten sonra bir
// daha CIKMIYOR mu.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/notifications/notification_preferences.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/tour/tour_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/admin_providers.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_admin_repository.dart';
import 'package:online_study_room/features/profile/settings_screen.dart';
import 'package:online_study_room/features/tours/app_tours.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_en.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kUser = 'u1';

final _tr = AppLocalizationsTr();

String get _seenKey =>
    tourSeenKey(storageId: AppTours.settings(_tr).storageId, userId: _kUser);

Finder _bubble() => find.byKey(const Key('tour-bubble'));

Future<SharedPreferences> _pumpSettings(
  WidgetTester tester,
  Map<String, Object> values,
) async {
  SharedPreferences.setMockInitialValues(values);
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
        home: SettingsScreen(),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  return prefs;
}

void main() {
  test('Ayarlar turu en fazla iki kart, sayaç ve ünlem yok', () {
    for (final l10n in [_tr, AppLocalizationsEn()]) {
      final tour = AppTours.settings(l10n);
      // WP-920: metinler zenginleşti → sürüm 2 (eski turu görenler yenisini
      // bir kez görür). Kart sayısı değişmedi.
      expect(tour.storageId, 'settings.v2');
      expect(tour.steps, hasLength(2));
      for (final step in tour.steps) {
        expect(step.text, isNot(contains('!')));
        expect(step.anchor, isNull);
      }
    }
  });

  testWidgets('Ayarlar ilk açılışta balonu bir kez gösterir', (tester) async {
    final prefs = await _pumpSettings(tester, const <String, Object>{});

    expect(_bubble(), findsOneWidget);
    expect(find.text(_tr.tourSettingsOverview), findsOneWidget);

    // Iki kart: "Devam" ikinciye gecer, ikincide tur biter.
    await tester.tap(find.byKey(const Key('tour-next-button')));
    await tester.pump();
    expect(find.text(_tr.tourSettingsAccount), findsOneWidget);
    await tester.tap(find.byKey(const Key('tour-next-button')));
    await tester.pump();

    expect(_bubble(), findsNothing);
    expect(prefs.getBool(_seenKey), isTrue);
  });

  testWidgets('görüldü işaretlendiyse bir daha çıkmaz', (tester) async {
    await _pumpSettings(tester, <String, Object>{_seenKey: true});

    expect(_bubble(), findsNothing);
    expect(find.text(_tr.tourSettingsOverview), findsNothing);
  });
}
