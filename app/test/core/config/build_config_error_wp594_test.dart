import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/config/build_configuration_error_app.dart';

/// WP-594 · Yanlış yapılandırmayla çıkan sürümde kullanıcı ne görüyor?
///
/// Kart iddiası "Windows'ta pencere bomboş beyaz kalıyor" idi. Bilerek bozuk
/// `--dart-define` ile Windows sürümü derlenip çalıştırıldı ve çizilen kare
/// `RenderRepaintBoundary.toImage()` ile alındı: Flutter ekranı **çiziyordu**,
/// ama Türkçe Windows'ta metin **İngilizce** geliyordu. Sebep, ekranın kendi
/// `MaterialApp`'ini kurup uygulamanın `resolvePreferredAppLocale`
/// sözleşmesinin dışında kalması ve `en`e düşmesiydi.
///
/// Bu ekranın sözleşmesi artık şudur: **hiçbir yerelleştirme altyapısı
/// olmadan**, tek karede, iki dilde birden okunur olmak.
void main() {
  group('WP-594 · yapılandırma hata yüzeyi', () {
    testWidgets(
      'l10n kurulumu HİÇ olmadan TR ve EN metni birlikte çiziyor',
      (tester) async {
        // Bilerek çıplak: MaterialApp yok, Localizations yok, Directionality
        // yok. Ekran bunların hiçbirini bekleyemez — çünkü bu ekran tam da
        // derlemenin bozuk olduğu anda çalışır.
        await tester.pumpWidget(
          const BuildConfigurationErrorApp(errorCode: 'invalid_channel'),
        );

        expect(find.text(BuildConfigurationErrorApp.titleTr), findsOneWidget);
        expect(find.text(BuildConfigurationErrorApp.bodyTr), findsOneWidget);
        expect(find.text(BuildConfigurationErrorApp.titleEn), findsOneWidget);
        expect(find.text(BuildConfigurationErrorApp.bodyEn), findsOneWidget);
        expect(
          find.text(
            BuildConfigurationErrorApp.diagnosticLine('invalid_channel'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    // İki yönlü iddia: tek dil seçen bir gerileme (ör. yeniden `l10n`e bağlama
    // ya da `languageCode == 'tr'` üçlemesi) sistem dili İngilizceyken Türkçe
    // metni, Türkçeyken İngilizce metni düşürür. Tek locale ile ölçmek bu
    // sabotajı sessizce geçirirdi.
    for (final locale in const [Locale('tr'), Locale('en')]) {
      testWidgets(
        'sistem dili ${locale.languageCode} iken iki dil de duruyor',
        (tester) async {
          tester.platformDispatcher.localeTestValue = locale;
          tester.platformDispatcher.localesTestValue = [locale];
          addTearDown(tester.platformDispatcher.clearLocaleTestValue);
          addTearDown(tester.platformDispatcher.clearLocalesTestValue);

          await tester.pumpWidget(
            const BuildConfigurationErrorApp(errorCode: 'supabase_required'),
          );

          expect(find.text(BuildConfigurationErrorApp.titleTr), findsOneWidget);
          expect(find.text(BuildConfigurationErrorApp.titleEn), findsOneWidget);
        },
      );
    }

    testWidgets('dar pencerede taşmıyor, kaydırılabiliyor', (tester) async {
      // Masaüstü penceresi kullanıcının bıraktığı boyutta açılır; ölçümdeki
      // makinede istemci alanı %250 ölçekte 512×248 mantıksal piksele kadar
      // düşüyor. Sabit yükseklikli Column burada taşardı.
      tester.view.physicalSize = const Size(420, 260);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const BuildConfigurationErrorApp(errorCode: 'backend_ref_mismatch'),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsOneWidget);
      expect(find.text(BuildConfigurationErrorApp.titleTr), findsOneWidget);
    });

    test('hata yüzeyi hiçbir yerelleştirme bağımlılığı taşımıyor', () {
      // Widget testi `AppLocalizations`ı kendi kurmadığı için import geri
      // eklenirse test kırmızıya döner; yine de kablo iddiasını açıkça yaz:
      // bu ekranın çalışması için katalog/delegate zincirinin sağlam olması
      // GEREKMEZ, çünkü korumaya çalıştığı arıza tam da onu bozabilir.
      // Yorumlar çıkarılıyor: dosyanın başındaki gerekçe bu adları **neden**
      // kullanmadığını anlatıyor, onlar bulgu değil.
      final source =
          File('lib/core/config/build_configuration_error_app.dart')
              .readAsStringSync()
              .replaceAll(RegExp(r'//.*'), '');
      expect(source, isNot(contains('app_localizations.dart')));
      expect(source, isNot(contains('AppLocalizations')));
      expect(source, isNot(contains('MaterialApp')));
    });
  });
}
