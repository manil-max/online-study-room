// WP-593: ilk acilisin iki purruzu.
//
// 1. 🔴 Yepyeni kurulumda kullanicinin gordugu ILK ekran, giris ekranindan bile
//    once acilan "Yenilikler" degisiklik gunluguydu. `shouldShowWhatsNew`
//    `getInt(...) ?? 0` diyordu, yani HIC kayit olmayan taze kurulum ile
//    "0. build'i gormus" kullanici ayni sayiliyordu. Hic kullanmadigi bir
//    surumun "yenilikleri" ilk izlenim olamaz.
// 2. `AuthGate` yukleme dali cikissiz/zaman asimsiz duz spinner'di. Oturum
//    akisi hic cevap vermezse (uykuda kalan istek, DNS'te asili baglanti)
//    cember sonsuza kadar doner ve tek care uygulamayi oldurmektir. Hata dali
//    WP-539'da cikis kazanmisti, yukleme dali unutulmustu.
//
// 🔴 Bu dosya saate degil ENJEKTE degerlere bakar: bu repoda gece yarisi
// flake'i iki kez surum kosumunu kirdi. Zaman asimi `tester.pump(...)` ile
// sanal saatte ilerletilir.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/widgets/error_retry_view.dart';
import 'package:online_study_room/features/auth/auth_gate.dart';
import 'package:online_study_room/features/updater/release_notes_service.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLastSeenBuild = 'release_notes_last_seen_build';

Future<ReleaseNotesService> _service(Map<String, Object> seed) async {
  SharedPreferences.setMockInitialValues(seed);
  final prefs = await SharedPreferences.getInstance();
  return ReleaseNotesService(preferences: prefs);
}

void main() {
  group('WP-593 (1) "Yenilikler" taze kurulumda cikmaz', () {
    test('hic kayit yokken GOSTERILMEZ ve mevcut build gorulmus isaretlenir', () async {
      final service = await _service(const <String, Object>{});

      expect(await service.shouldShowWhatsNew(currentBuildNumber: 62), isFalse);

      // Isaretlenmezse bir sonraki acilista yine cikardi: "gosterme" karari
      // kaliciliga yazilmali, yoksa hata her aciliste tekrar eder.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt(_kLastSeenBuild), 62);
    });

    test('61 -> 62 guncellemesinde GOSTERILIR (guncelleme yolu bozulmadi)', () async {
      final service = await _service(<String, Object>{_kLastSeenBuild: 61});

      expect(await service.shouldShowWhatsNew(currentBuildNumber: 62), isTrue);
    });

    test('ayni build tekrar acilinca GOSTERILMEZ', () async {
      final service = await _service(<String, Object>{_kLastSeenBuild: 62});

      expect(await service.shouldShowWhatsNew(currentBuildNumber: 62), isFalse);
    });
  });

  group('WP-593 (2) AuthGate yukleme dali sonsuza kadar donmez', () {
    Widget host(VoidCallback onRetry) => MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: AuthGateLoadingView(onRetry: onRetry),
    );

    testWidgets('esik dolmadan spinner, doldugunda cikis gorunur', (
      tester,
    ) async {
      await tester.pumpWidget(host(() {}));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.byKey(kErrorRetryButtonKey),
        findsNothing,
        reason: 'Esik dolmadan cikis gostermek normal acilisi bozar.',
      );

      await tester.pump(kAuthGateLoadingTimeout + const Duration(seconds: 1));

      expect(find.byKey(kErrorRetryButtonKey), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('tekrar-dene akisi yeniden kurar VE spinner a geri doner', (
      tester,
    ) async {
      var retries = 0;
      await tester.pumpWidget(host(() => retries++));
      await tester.pump(kAuthGateLoadingTimeout + const Duration(seconds: 1));
      expect(find.byKey(kErrorRetryButtonKey), findsOneWidget);

      await tester.tap(find.byKey(kErrorRetryButtonKey));
      await tester.pump();

      // Iki ayri iddia: (1) dugme olu degil, (2) ekran degisiyor. Ikincisi
      // olmadan "cagirdi ama ayni ekran duruyor" hali gecerdi -- WP-560'in
      // dersi: kullanici o zaman uygulamayi donmus sayar.
      expect(retries, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byKey(kErrorRetryButtonKey), findsNothing);

      // Sayac SIFIRLANMALI: yeniden beklemeye giren kullanici esik dolunca
      // cikisi tekrar gorebilmeli.
      await tester.pump(kAuthGateLoadingTimeout + const Duration(seconds: 1));
      expect(find.byKey(kErrorRetryButtonKey), findsOneWidget);
    });
  });
}
