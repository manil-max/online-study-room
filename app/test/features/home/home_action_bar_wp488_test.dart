// WP-488 (V57-N12): ana ekranın üst şeridi kalkıyor, düzenleme uzun basmada.
//
// 🔴 Sahip kararı (bağlayıcı): üst şerit ve düzenle butonu kalkacak, ilk kart
// doğrudan üstten başlayacak, **yerine yeni buton konmayacak**. Giriş yolu
// uzun basmadır; keşfedilebilirlik tanıtım turu + SSS ile sağlanır.
//
// Kabul "boşluk küçüldü" demek değildir: görüntüleme modunda `AppBar`ın **hiç
// kurulmadığı** doğrulanır. `buildTabActionBar` zaten "eylem yoksa null dön"
// sözleşmesine sahip; tek eylemi kaldırmak şeridi kendiliğinden yok eder.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/home/home_screen.dart';
import 'package:online_study_room/features/tours/app_tours.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:online_study_room/l10n/app_localizations_en.dart';
import 'package:online_study_room/l10n/app_localizations_tr.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cihazdaki kabuğu taklit eder (Scaffold > Stack > IndexedStack); şerit
/// davranışı yalnız çıplak `HomeScreen` ile ölçülürse kabuğun kendi
/// `AppBar`ıyla karışırdı.
Future<void> _pumpHome(WidgetTester tester, {bool empty = false}) async {
  SharedPreferences.setMockInitialValues({
    if (!empty)
      'dashboard_layout_v2_32': <String>['timer:0:0:32:49', 'tasks:0:49:32:18'],
    if (!empty) 'dashboard_grid_last_columns': 32,
    if (empty) 'dashboard_layout_v2_32': <String>[],
  });
  final prefs = await SharedPreferences.getInstance();

  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              IndexedStack(index: 0, children: [HomeScreen(), SizedBox()]),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('görüntüleme modunda HİÇ app bar kurulmuyor', (tester) async {
    await _pumpHome(tester);

    // 🔴 Ölçüt bu: "boşluk küçüldü" demek yetmez.
    expect(find.byType(AppBar), findsNothing);
    // Eski tek eylem de gitti; yerine yeni buton konmadı (sahip kararı).
    expect(find.byIcon(Icons.dashboard_customize_outlined), findsNothing);
  });

  testWidgets('ilk kart üst güvenli alanın hemen altından başlıyor', (
    tester,
  ) async {
    await _pumpHome(tester);

    final firstCard = tester.getRect(find.byType(Card).first);
    // Şerit 48 dp idi; kaldırıldığına göre ilk kart onun altında kalamaz.
    expect(
      firstCard.top,
      lessThan(48),
      reason: 'ilk kart hâlâ eski şerit yüksekliğinin altında: $firstCard',
    );
  });

  testWidgets('uzun basma düzenlemeye giriyor ve dört eylem erişilebilir', (
    tester,
  ) async {
    await _pumpHome(tester);

    await tester.longPress(find.byType(Card).first);
    await tester.pump(const Duration(milliseconds: 600));

    // Düzenleme modu şeridi KALIR: bu eylemler uzun basmayla erişilemez.
    // İddia şeridin İÇİYLE sınırlı; `Icons.add` boyut panelinde de geçiyor.
    expect(find.byType(AppBar), findsOneWidget);
    for (final icon in [
      Icons.check,
      Icons.vertical_align_top,
      Icons.restart_alt,
      Icons.add,
    ]) {
      expect(
        find.descendant(of: find.byType(AppBar), matching: find.byIcon(icon)),
        findsOneWidget,
        reason: 'düzenleme şeridinde $icon eylemi kayboldu',
      );
    }
  });

  testWidgets('boş panoda çıkış yolu duruyor', (tester) async {
    await _pumpHome(tester, empty: true);

    // Kartsız kullanıcı kilitlenmez: boş pano kendi eylemini taşır.
    expect(find.byType(AppBar), findsNothing);
    expect(find.byType(FilledButton), findsWidgets);
  });

  group('tanıtım turu çapasız ve uzun basmayı söylüyor', () {
    test('ana ekran adımının çapası yok', () {
      final tour = AppTours.home(AppLocalizationsTr(), isEmpty: false);
      expect(tour.steps.single.anchor, isNull);
    });

    test('iki dilde de metin uzun basmayı tarif ediyor', () {
      expect(
        AppTours.home(AppLocalizationsTr(), isEmpty: false).steps.single.text,
        contains('uzun bas'),
      );
      expect(
        AppTours.home(AppLocalizationsEn(), isEmpty: false).steps.single.text,
        contains('hold'),
      );
    });

    test('tur sürümü ilerledi: metin değiştiği için yeniden gösterilir', () {
      expect(AppTours.home(AppLocalizationsTr(), isEmpty: false).version, 2);
    });
  });
}
