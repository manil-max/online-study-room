// 🔴 WP-709 — gunluk hedefi ayarladiktan sonra bir anligina TANITIM EKRANI.
//
// Sahip (2026-08-11): "gunluk hedefi ayarladiktan sonra bir anligina ekrana
// tanitim ekrani geliyor, uygulamayi ilk actigindaki ekran".
//
// OLCULEN ZINCIR (tahmin degil, kaynak okundu):
//  1. `settings_screen.dart:109-110` — hedef yazilir, sonra
//     `ref.invalidate(authStateProvider)`.
//  2. `auth_providers.dart:228` — `authStateProvider` bir `StreamProvider`dir.
//     Invalidate ile akis YENIDEN kurulur; uretimdeki gercek govde
//     (`SupabaseAuthRepository._sessionProfiles`, satir 142-146) ilk `yield`den
//     ONCE `profiles` satirini AGDAN ceker. Yani yeniden kurulum aninda degil,
//     bir ag gidis-donusu kadar sonra deger uretir.
//  3. O pencerede sagalayici `AsyncLoading` + ONCEKI deger durumundadir
//     (`isRefreshing`). `AuthGate` `when`i varsayilan
//     `skipLoadingOnRefresh: true` ile calistigi icin VERI dalini cizmeye
//     devam eder (riverpod 3.3.2, `async_value.dart:242-265`).
//  4. Ama `OnboardingNotifier.build` (`onboarding_prefs.dart`) ayni pencerede
//     `auth.isLoading` gorup `false` donuyordu → `auth_gate.dart:105` "tanitim
//     tamamlanmadi" okuyup `OnboardingScreen` ciziyordu.
//
// Depoda kayitli desen: `asData` yeniden yuklemede BOSALIR
// (`docs/qa/V58-ASYNC-EMPTY-AUDIT.md §1`, `home_shell.dart:74-78`). Bu dosya
// ayni kusurun kapi/onboarding ayagidir.
//
// OLCUM SEKLI: iddia sagalayici degeri degil **CIZILEN WIDGET**tir. Gercek
// `AuthGate` monte edilir; `find.byType(OnboardingScreen)` ve
// `find.byType(HomeShell)` sayilir. Sagalayiciyi izole okuyan bir test bu
// kusuru yakalayamazdi, cunku kusur bir karelik ekran olayidir.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/navigation/home_shell.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/data/providers/push_notification_providers.dart';
import 'package:online_study_room/data/providers/study_providers.dart';
import 'package:online_study_room/data/repositories/in_memory/in_memory_auth_repository.dart';
import 'package:online_study_room/features/auth/auth_gate.dart';
import 'package:online_study_room/features/onboarding/onboarding_prefs.dart';
import 'package:online_study_room/features/onboarding/onboarding_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _userId = 'u-709';

Profile _profileWithGoal({int goal = 120}) => Profile(
  id: _userId,
  displayName: 'Sahip',
  createdAt: DateTime.utc(2026, 1, 1),
  dailyGoalMinutes: goal,
);

/// Uretimdeki yeniden-kurulum penceresini modelleyen depo.
///
/// 🔴 Kritik ayrinti: `authStateChanges()` abone olur olmaz deger YAYINLAMAZ.
/// Bu bir kolaylik degil, uretimin birebir davranisidir
/// (`SupabaseAuthRepository._sessionProfiles` ilk `yield`den once `profiles`
/// satirini ceker). Aninda tekrar yayinlayan bir sahte, olcmek istedigimiz
/// pencereyi yok ederdi.
class _ReconnectingAuthRepository extends InMemoryAuthRepository {
  _ReconnectingAuthRepository() : _profile = _profileWithGoal();

  Profile _profile;
  final StreamController<Profile?> _controller =
      StreamController<Profile?>.broadcast();

  /// Kac kez yeniden abone olundu — invalidate'in gercekten akisi yeniden
  /// kurdugunun kaniti (olu kablo kontrolu).
  int subscriptions = 0;

  @override
  Stream<Profile?> authStateChanges() {
    subscriptions++;
    return _controller.stream;
  }

  @override
  Future<void> updateDailyGoal(int minutes) async {
    _profile = _profile.copyWith(dailyGoalMinutes: minutes.clamp(1, 24 * 60));
  }

  /// Sunucu (nihayet) konustu.
  void serverAnswers() => _controller.add(_profile);
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

Future<ProviderContainer> _container(
  _ReconnectingAuthRepository repo, {
  required bool onboardingDone,
}) async {
  SharedPreferences.setMockInitialValues({
    if (onboardingDone) onboardingCompletedKeyFor(_userId): true,
  });
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authRepositoryProvider.overrideWithValue(repo),
      pushLifecycleListenerProvider.overrideWithValue(null),
      // Cevrimdisi yedek bu olcumun konusu degil: sussun.
      localSessionProfileProvider.overrideWithValue(() async => null),
    ],
  );
}

/// Agaci soker, kabi kapatir ve `authStateWithOfflineFallback`in butce
/// zamanlayicisini bosaltir; aksi halde HomeShell'in presence nabzi ve butce
/// zamanlayicisi "Timer is still pending" olarak dokulur. `dispose` idempotent
/// oldugu icin `addTearDown` ile birlikte guvenle cagrilir.
Future<void> _teardownTree(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(const SizedBox());
  container.dispose();
  await tester.pump(kAuthColdStartBudget);
}

void main() {
  // Kapi HomeShell'i cizerken 5 sekme birden kurulur; telefon boyu dar kalirsa
  // olcum overflow gurultusune bogulur.
  void useTallPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  testWidgets('gunluk hedef yazilinca kapi TANITIM EKRANI cizmez', (
    tester,
  ) async {
    useTallPhone(tester);
    final repo = _ReconnectingAuthRepository();
    final container = await _container(repo, onboardingDone: true);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pump();
    repo.serverAnswers();
    await tester.pump();

    // Baslangic: kullanici iceride.
    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(repo.subscriptions, 1);

    // --- Ayarlar'daki gunluk hedef yazimi (settings_screen.dart:109-110) ---
    await repo.updateDailyGoal(240);
    container.invalidate(authStateProvider);
    await tester.pump();

    // 🔴 KUSURUN GORULDUGU KARE. Duzeltme oncesi burada `OnboardingScreen`
    // ciziliyordu: sunucu cevabini beklerken kapi kullaniciyi "ilk acilis"
    // ekranina atiyordu.
    expect(
      repo.subscriptions,
      2,
      reason:
          'invalidate akisi gercekten yeniden kurmali; kurmuyorsa bu test '
          'olcmek istedigi pencereyi hic acmamis olur',
    );
    expect(
      find.byType(OnboardingScreen),
      findsNothing,
      reason:
          'oturumu acik, tanitimi bitmis kullaniciya yazma sonrasi bir kare de '
          'olsa tanitim ekrani gosterilemez',
    );
    expect(
      find.byType(HomeShell),
      findsOneWidget,
      reason: 'yeniden yukleme penceresinde ekran YERINDE kalmali',
    );

    // Sunucu nihayet cevap verince de dogru ekran + yeni hedef.
    repo.serverAnswers();
    await tester.pump();
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(HomeShell), findsOneWidget);
    expect(
      container.read(dailyGoalMinutesProvider),
      240,
      reason:
          'yazma gercekten aktarilmali; aksi halde ustteki iddialar bos '
          'bir akisi olcerdi',
    );
    await _teardownTree(tester, container);
  });

  // Iddianin OTEKI ucu. Bu olmadan "her zaman true don" sabotaji sessizce
  // gecerdi ve tanitim ekrani hic gorunmezdi.
  testWidgets('tanitimi bitmemis kullaniciya tanitim ekrani HALA cizilir', (
    tester,
  ) async {
    useTallPhone(tester);
    final repo = _ReconnectingAuthRepository();
    final container = await _container(repo, onboardingDone: false);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pump();
    repo.serverAnswers();
    await tester.pump();

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);

    // Yeniden yukleme penceresi bu kullaniciyi da kaydirmamali.
    container.invalidate(authStateProvider);
    await tester.pump();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(HomeShell), findsNothing);
    await _teardownTree(tester, container);
  });

  testWidgets(
    'Ayarlar > tanitim turlarini sifirla hala tanitimi geri getirir',
    (tester) async {
      useTallPhone(tester);
      final repo = _ReconnectingAuthRepository();
      final container = await _container(repo, onboardingDone: true);
      addTearDown(container.dispose);

      await tester.pumpWidget(_app(container));
      await tester.pump();
      repo.serverAnswers();
      await tester.pump();
      expect(find.byType(HomeShell), findsOneWidget);

      // settings_screen.dart:169 ile ayni cagri.
      await container.read(onboardingCompletedProvider.notifier).reset();
      await tester.pump();

      expect(
        find.byType(OnboardingScreen),
        findsOneWidget,
        reason: 'sifirlama olu anahtar olmamali',
      );
      await _teardownTree(tester, container);
    },
  );

  testWidgets('soguk acilisda tanitim degil cember gorunur', (tester) async {
    useTallPhone(tester);
    final repo = _ReconnectingAuthRepository();
    final container = await _container(repo, onboardingDone: true);
    addTearDown(container.dispose);

    await tester.pumpWidget(_app(container));
    await tester.pump();

    // Hic deger yok: bilinmezlik gercek. Kapi beklemeli, ekran uydurmamali.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.byType(HomeShell), findsNothing);
    await _teardownTree(tester, container);
  });
}
