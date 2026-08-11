// WP-716 — `complete()` / `reset()` icindeki `asData` tuzagi.
//
// 🔴 DURUSTLUK NOTU (bu dosyanin en onemli satirlari):
// WP-709 raporunda "gunluk hedef yazildiktan sonra `complete()` sessizce
// dusuyor" demistim. **Bu iddia yanlisti** ve bu dosya once onu curuttu:
// riverpod 3.3.2 `async_value.dart:780-816` okundu, `ref.invalidate` yolu
// `isRefresh: true` ile calisir ve `AsyncLoading.copyWithPrevious` o kolda
// **`AsyncData`** dondurur — yalniz `isLoading` bayragi acilir. Yani
// invalidate penceresinde `asData` DOLUDUR; kullanicinin bugun yasadigi bir
// kayip yoktur. Ilk iki iddia bunu kilitler ve duzeltme OLMADAN da yesildi.
//
// Gercekten bosalan kol yeniden kurulumun ikinci cesididir: `authStateProvider`
// bir WATCH bagimliligi degistigi icin yeniden kurulursa (`isRefresh: false`)
// gercek bir `AsyncLoading` uretilir, `asData` bosalir, `value` onceki degeri
// korur. Son iki iddia bu kolu olcer ve duzeltme olmadan KIRMIZI duser.
// Bu kol bugun uretimde tetiklenemiyor (`offlineCacheStoreProvider` hicbir
// yerde invalidate edilmiyor), yani duzeltme **savunmacidir**: zincir bir gun
// oynadiginda tanitim tamamlama/sifirlama sessizce dusmesin.
//
// OLCUM SEKLI: iddia sagalayici degeri degil DAVRANIStir — (1) diske yazilan
// bayrak, (2) sunucu cevap verdikten SONRA kapinin cizdigi ekran. Tek kareye
// bakan bir test `reset()`in kendini geri aldigini goremezdi.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/navigation/home_shell.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/push_notification_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/features/auth/auth_gate.dart';
import 'package:online_study_room/features/onboarding/onboarding_prefs.dart';
import 'package:online_study_room/features/onboarding/onboarding_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _userId = 'u-716';

/// `authStateProvider`in bir WATCH bagimliligini oynatan tetikleyici.
///
/// 🔴 Neden gerekli: yeniden kurulumun IKI cesidi var ve `asData` yalniz
/// birinde bosalir (riverpod 3.3.2 `async_value.dart:780-816`):
///   * `ref.invalidate` → `isRefresh: true` → `AsyncLoading.copyWithPrevious`
///     **`AsyncData`** dondurur (yalniz `isLoading` bayragi acilir). `asData`
///     DOLUDUR.
///   * watch bagimliligi degisti → `isRefresh: false` → gercek `AsyncLoading`
///     dondurulur. `asData` BOSTUR, `value` onceki degeri korur.
/// `authStateProvider` `localSessionProfileProvider`i izledigi icin ikinci
/// cesit buradan uretilir.
final _reloadTrigger = NotifierProvider<_ReloadTrigger, int>(
  _ReloadTrigger.new,
);

class _ReloadTrigger extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

/// Yeniden kurulan akisin uretimdeki suskunlugunu modelleyen depo: abone olur
/// olmaz deger yayinlamaz (bkz. `_sessionProfiles`, ilk `yield`den once ag).
class _ReconnectingAuthRepository extends InMemoryAuthRepository {
  final StreamController<Profile?> _controller =
      StreamController<Profile?>.broadcast();

  final Profile _profile = Profile(
    id: _userId,
    displayName: 'Sahip',
    createdAt: DateTime.utc(2026, 1, 1),
  );

  @override
  Stream<Profile?> authStateChanges() => _controller.stream;

  void serverAnswers() => _controller.add(_profile);
}

ProviderContainer _containerWith(
  _ReconnectingAuthRepository repo,
  SharedPreferences prefs,
) {
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(repo),
      pushLifecycleListenerProvider.overrideWithValue(null),
      // Cevrimdisi yedek sussun; ama `overrideWithValue` DEGIL: sagalayici
      // canli kalmali ki [_reloadTrigger] ile yeniden kurulabilsin.
      localSessionProfileProvider.overrideWith((ref) {
        ref.watch(_reloadTrigger);
        return () async => null;
      }),
    ],
  );
}

Widget _app(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AuthGate(),
    ),
  );
}

/// Agaci soker, kabi kapatir ve butce zamanlayicisini bosaltir.
Future<void> _teardownTree(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(const SizedBox());
  container.dispose();
  await tester.pump(kAuthColdStartBudget);
}

void main() {
  void useTallPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('yeniden yukleme penceresinde "Atla" tanitimi GERCEKTEN bitirir', (
    tester,
  ) async {
    useTallPhone(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _ReconnectingAuthRepository();
    final container = _containerWith(repo, prefs);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pump();
    repo.serverAnswers();
    await tester.pump();
    expect(find.byType(OnboardingScreen), findsOneWidget);

    // --- Pencereyi ac: herhangi bir profil yazmasi bunu yapar ---
    container.invalidate(authStateProvider);
    await tester.pump();
    expect(
      find.byType(OnboardingScreen),
      findsOneWidget,
      reason: 'pencere acikken kullanici hala tanitimda olmali',
    );

    // --- Kullanicinin GERCEK dokunusu (onboarding_screen.dart:104 → _finish) ---
    await tester.tap(find.widgetWithText(TextButton, 'Atla'));
    await tester.pump();
    await tester.pump();

    // DAVRANIS 1: bayrak diske yazildi mi? Kusurlu surumde `complete()`
    // `user == null` gorup sessizce cikiyordu, yani burasi null kaliyordu.
    expect(
      prefs.getBool(onboardingCompletedKeyFor(_userId)),
      isTrue,
      reason:
          'tanitim tamam bayragi kalici olarak yazilmali; yazilmazsa '
          'kullanici tanitimi her acilista yeniden gorur',
    );

    // DAVRANIS 2: ekran gercekten degisti mi?
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);

    // DAVRANIS 3: sunucu nihayet cevap verince karar GERI ALINMAMALI.
    repo.serverAnswers();
    await tester.pump();
    expect(
      find.byType(OnboardingScreen),
      findsNothing,
      reason: 'sunucu cevabi tanitimi geri getiremez',
    );
    expect(find.byType(HomeShell), findsOneWidget);

    await _teardownTree(tester, container);
  });

  testWidgets('yeniden yukleme penceresinde sifirlama kendini GERI ALMAZ', (
    tester,
  ) async {
    useTallPhone(tester);
    SharedPreferences.setMockInitialValues({
      onboardingCompletedKeyFor(_userId): true,
    });
    final prefs = await SharedPreferences.getInstance();
    final repo = _ReconnectingAuthRepository();
    final container = _containerWith(repo, prefs);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pump();
    repo.serverAnswers();
    await tester.pump();
    expect(find.byType(HomeShell), findsOneWidget);

    // --- Pencere acik: Ayarlar'da bir seyler kaydedilmis olabilir ---
    container.invalidate(authStateProvider);
    await tester.pump();

    // settings_screen.dart:169 ile ayni cagri.
    await container.read(onboardingCompletedProvider.notifier).reset();
    await tester.pump();
    expect(
      find.byType(OnboardingScreen),
      findsOneWidget,
      reason: 'sifirlama hemen tanitimi acmali',
    );

    // 🔴 KUSURUN GORULDUGU YER. Kusurlu surumde kullaniciya ozel bayrak diske
    // hic `false` yazilmiyordu; sunucu cevap verince `build()` prefs'ten yine
    // `true` okuyup kullaniciyi HomeShell'e geri atiyordu.
    expect(
      prefs.getBool(onboardingCompletedKeyFor(_userId)),
      isFalse,
      reason:
          'sifirlama kalici olmali; yalniz bellekteki durumu degistiren '
          'bir sifirlama olu dugmedir',
    );
    repo.serverAnswers();
    await tester.pump();
    expect(
      find.byType(OnboardingScreen),
      findsOneWidget,
      reason: 'sifirlama sunucu cevabiyla sessizce geri alinamaz',
    );
    expect(find.byType(HomeShell), findsNothing);

    await _teardownTree(tester, container);
  });

  // ---------------------------------------------------------------------
  // `asData`nin GERCEKTEN bosaldigi cesit.
  //
  // 🔴 DURUSTLUK NOTU: bu iki iddia bugun URETIMDE tetiklenemez.
  // `authStateProvider`in watch bagimliliklari (`authRepositoryProvider`,
  // `localSessionProfileProvider` → `offlineCacheStoreProvider`) hicbir yerde
  // invalidate edilmiyor, yani ikinci cesit yeniden kurulum sahada olusmuyor.
  // Testler kusurun KENDISINI degil, `asData` tuzagini kilitler: bagimlilik
  // zinciri bir gun oynadiginda tanitim tamamlama sessizce dusmesin.
  // ---------------------------------------------------------------------
  testWidgets('bagimlilik yeniden kurulumunda da tanitim tamamlanir', (
    tester,
  ) async {
    useTallPhone(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _ReconnectingAuthRepository();
    final container = _containerWith(repo, prefs);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pump();
    repo.serverAnswers();
    await tester.pump();
    expect(find.byType(OnboardingScreen), findsOneWidget);

    // Watch bagimliligi oynar → `authStateProvider` gercek `AsyncLoading`e
    // duser (onceki profil hala `value` icinde durur).
    container.read(_reloadTrigger.notifier).bump();
    await tester.pump();

    await container.read(onboardingCompletedProvider.notifier).complete();
    await tester.pump();
    await tester.pump();

    expect(
      prefs.getBool(onboardingCompletedKeyFor(_userId)),
      isTrue,
      reason:
          'kullanici elimizdeyken (`value` dolu) tamamlama sessizce '
          'dusemez; `asData` bu kolda BOSTUR',
    );

    repo.serverAnswers();
    await tester.pump();
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);

    await _teardownTree(tester, container);
  });

  testWidgets('bagimlilik yeniden kurulumunda da sifirlama kalicidir', (
    tester,
  ) async {
    useTallPhone(tester);
    SharedPreferences.setMockInitialValues({
      onboardingCompletedKeyFor(_userId): true,
    });
    final prefs = await SharedPreferences.getInstance();
    final repo = _ReconnectingAuthRepository();
    final container = _containerWith(repo, prefs);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pump();
    repo.serverAnswers();
    await tester.pump();
    expect(find.byType(HomeShell), findsOneWidget);

    container.read(_reloadTrigger.notifier).bump();
    await tester.pump();

    await container.read(onboardingCompletedProvider.notifier).reset();
    await tester.pump();

    expect(
      prefs.getBool(onboardingCompletedKeyFor(_userId)),
      isFalse,
      reason:
          'sifirlama diske yazilmazsa ilk yeniden yuklemede geri alinir '
          've dugme olu kalir',
    );

    repo.serverAnswers();
    await tester.pump();
    expect(
      find.byType(OnboardingScreen),
      findsOneWidget,
      reason: 'sifirlama sunucu cevabiyla geri alinamaz',
    );

    await _teardownTree(tester, container);
  });

  // Iddianin oteki ucu: pencere YOKKEN de akis bozulmamali. Bu olmadan
  // "her zaman yaz" turu bir sabotaj (kullanici cikisliyken bile bayrak
  // yazmak) sessizce gecerdi.
  testWidgets('oturum yokken tanitim bayragi HIC yazilmaz', (tester) async {
    useTallPhone(tester);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _ReconnectingAuthRepository();
    final container = _containerWith(repo, prefs);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pump();
    container.read(authStateProvider); // akis kurulsun
    await tester.pump();

    await container.read(onboardingCompletedProvider.notifier).complete();
    await tester.pump();

    expect(
      prefs.getKeys().where((k) => k.startsWith(kOnboardingCompletedV1)),
      isEmpty,
      reason: 'kullanici bilinmiyorken hangi hesaba yazildigi da bilinemez',
    );

    await _teardownTree(tester, container);
  });
}
