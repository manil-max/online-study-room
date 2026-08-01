import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/home/home_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-305: Beta 1'de "Kartları düzenle" ekranı cihazda bomboş açıldı —
/// yalnız boyut paneli görünüyordu, kaydırma ve kart ekleme işe yaramıyordu.
///
/// Panel WP-291'de `Scaffold.bottomSheet` yuvasına konmuştu. O yuva basit bir
/// alt şerit değil: Flutter onu kalıcı alt yaprak makinesine sokar (kendi
/// animasyon denetleyicisi, `ModalRoute` bağı ve gövdeyi örtebilen
/// `_ScaffoldSlot.bodyScrim` katmanı) ve gövdeye yer ayırmaz. Panel artık
/// gövdenin altında düz bir `Column` çocuğu; bu test onu bağlar.
void main() {
  /// Cihazdaki kabuğu taklit eder: Scaffold > Stack(expand) > IndexedStack.
  /// Düzenleme yüzeyini yalnız çıplak `HomeScreen` ile denemek yetmez;
  /// hatanın çıktığı yer kabuğun içiydi.
  Future<void> pumpShell(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'dashboard_layout_v2_32': <String>['timer:0:0:32:49', 'tasks:0:49:32:18'],
      'dashboard_grid_last_columns': 32,
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
          home: Scaffold(
            body: const Stack(
              fit: StackFit.expand,
              children: [
                IndexedStack(index: 0, children: [HomeScreen(), SizedBox()]),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: 0,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: 'A'),
                NavigationDestination(icon: Icon(Icons.person), label: 'B'),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    // WP-488: görüntüleme modundaki düzenle butonu kaldırıldı; düzenlemeye
    // giriş yolu artık karta uzun basmaktır.
    await tester.longPress(find.byType(Card).first);
    await tester.pump(const Duration(milliseconds: 600));
  }

  Finder panelFinder() => find.byKey(const Key('home-sticky-size-panel'));

  testWidgets('düzenleme modunda gövde çizilir (boş ekran değil)', (
    tester,
  ) async {
    await pumpShell(tester);

    // Cihazdaki belirti: ipucu metni de kartlar da yoktu.
    expect(find.textContaining('Kartı tutup'), findsOneWidget);
    expect(find.byType(Card), findsWidgets);
    expect(panelFinder(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('panel gövdeyi örtmez, altına yer ayırır', (tester) async {
    await pumpShell(tester);

    final scroll = tester.getRect(find.byType(SingleChildScrollView).first);
    final panel = tester.getRect(panelFinder());

    // `Scaffold.bottomSheet` panelin gövde ÜSTÜNDE yüzmesine yol açıyordu;
    // son kartın panelin altında kalmaması için akışa 96 dp boşluk konmuştu.
    // Column + Expanded ile yer kendiliğinden ayrılır.
    expect(panel.top, moreOrLessEquals(scroll.bottom, epsilon: 0.5));
  });

  testWidgets('en alta kaydırınca panel ekranda kalır (WP-291 DoD)', (
    tester,
  ) async {
    await pumpShell(tester);
    final before = tester.getRect(panelFinder());

    // Sahibin şikâyeti buydu: kart aşağıdayken boyut aracı ekrandan çıkıyor,
    // sürekli aşağı yukarı kaydırmak gerekiyordu.
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -4000),
    );
    await tester.pump();

    expect(panelFinder(), findsOneWidget);
    expect(tester.getRect(panelFinder()), before);
    expect(tester.takeException(), isNull);
  });
}
