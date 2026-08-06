// WP-493 (V58-N10 / rapor T14): ana ekranın üst güvenli alanı.
//
// WP-488 görüntüleme modundaki şeridi kaldırdı; şeridin taşıdığı durum çubuğu
// payını kimse devralmadı ve ilk kart saat/pil simgelerinin altına girdi.
// `tab_action_bar.dart` sözleşmesi "şerit yoksa çağıran gövdeyi
// `SafeArea(bottom: false)` ile sarar" der — bu testler o sözleşmenin çağıran
// tarafını bağlar.
//
// Ölçüt "boşluk büyüdü" değil: 48 dp üst inset enjekte edilir ve ilk kartın
// üst kenarı ölçülür. İkinci ölçüt de en az onun kadar önemli: düzenleme
// moduna girip çıkınca pay **iki kez eklenmez** (şerit varken `AppBar` zaten
// yutar; `getSafeVerticalPadding`e üst inset eklemek bu yüzden yasaktır).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/home/home_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cihazdaki durum çubuğu payı (çentikli telefonlarda tipik değer).
const double kTopInset = 48;

/// Gövdenin kendi akış boşluğu (`getSafeVerticalPadding` dikey tabanı).
const double kBodyPadding = 16;

/// Cihazdaki kabuğu taklit eder (Scaffold > Stack > IndexedStack) ve üst
/// inset'i `MediaQuery` üzerinden enjekte eder. Çıplak `HomeScreen` ile
/// ölçmek yetmez: pay kabuğun içinden geçerek gelir.
Future<void> _pumpHome(WidgetTester tester, {bool empty = false}) async {
  SharedPreferences.setMockInitialValues({
    if (!empty)
      'dashboard_layout_v2_32': <String>['timer:0:0:32:49', 'tasks:0:49:32:18'],
    if (!empty) 'dashboard_grid_last_columns': 32,
    if (empty) 'dashboard_layout_v2_32': <String>[],
    // Düzenleme ipucu ölçümü kaydırırdı; bu test yerleşimi ölçüyor.
    'home.edit_hint_seen_v1': true,
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
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(padding: const EdgeInsets.only(top: kTopInset)),
          child: child!,
        ),
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

double _firstCardTop(WidgetTester tester) =>
    tester.getRect(find.byType(Card).first).top;

void main() {
  testWidgets('şerit yokken ilk kart durum çubuğunun altında kalıyor', (
    tester,
  ) async {
    await _pumpHome(tester);

    expect(
      find.byType(AppBar),
      findsNothing,
      reason: 'WP-488 şeridi geri geldi',
    );
    expect(
      _firstCardTop(tester),
      greaterThanOrEqualTo(kTopInset),
      reason: 'ilk kart saat/pil simgelerinin altına giriyor',
    );
  });

  testWidgets('pay bir kez ekleniyor (çift boşluk yok)', (tester) async {
    await _pumpHome(tester);

    // 48 (inset) + 16 (gövde boşluğu) = 64. İki kez eklenirse 112 olurdu.
    expect(
      _firstCardTop(tester),
      lessThan(kTopInset + kBodyPadding * 2),
      reason: 'üst pay iki kez eklenmiş görünüyor: ${_firstCardTop(tester)}',
    );
  });

  testWidgets('düzenleme moduna girip çıkınca pay iki kez eklenmiyor', (
    tester,
  ) async {
    await _pumpHome(tester);
    final beforeEdit = _firstCardTop(tester);

    await tester.longPress(find.byType(Card).first);
    await tester.pump(const Duration(milliseconds: 600));

    // Şerit döndü: payı artık `AppBar` yutar. Gövde onu ikinci kez eklerse
    // kart, şeridin altından 48 dp daha aşağıda başlardı.
    final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
    expect(
      _firstCardTop(tester) - appBarBottom,
      lessThan(kTopInset),
      reason: 'düzenleme modunda üst pay şeride ek olarak ikinci kez eklendi',
    );

    await tester.tap(find.byIcon(Icons.check));
    await tester.pump(const Duration(milliseconds: 600));

    // Görüntülemeye dönünce yerleşim aynı: giriş/çıkış boşluk biriktirmiyor.
    expect(find.byType(AppBar), findsNothing);
    expect(_firstCardTop(tester), moreOrLessEquals(beforeEdit, epsilon: 0.5));
  });

  testWidgets('boş panoda da gövde üst güvenli alanı taşıyor', (tester) async {
    await _pumpHome(tester, empty: true);

    final safeAreas = tester.widgetList<SafeArea>(
      find.ancestor(
        of: find.byIcon(Icons.dashboard_outlined),
        matching: find.byType(SafeArea),
      ),
    );
    expect(
      safeAreas.any((s) => s.top && !s.bottom),
      isTrue,
      reason: 'kartsız kullanıcı da durum çubuğunun altında kalmalı',
    );
  });
}
