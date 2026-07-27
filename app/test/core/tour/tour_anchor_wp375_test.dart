// WP-375: tanıtım turunun hedef/konum/sıra onarımı.
//
// Sahibin bildirdiği belirti "mantık doğru, uygulama kötü"ydü. Kodda üç ayrı
// mekanizma çıktı ve üçü de burada kapana bağlanıyor:
//   1. Hedef yalnız `build` anında ölçülüyordu → kaydırınca spot ışığı eski
//      yerde kalıyordu.
//   2. Hedefi görünür alana getiren kaydırma hiç yoktu → ekranın altındaki
//      hedef için tur boş bir alanı işaret ediyordu.
//   3. İlan edilmiş ama bulunamayan hedef **sessizce** ortalanmış balona
//      dönüşüyordu → kullanıcıya sıra bozulmuş gibi geliyordu.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/tour/tour_host.dart';
import 'package:online_study_room/core/tour/tour_models.dart';
import 'package:online_study_room/core/tour/tour_prefs.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/data/providers/auth_providers.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Profile _profile(String id) =>
    Profile(id: id, displayName: id, createdAt: DateTime(2026));

Widget _host({
  required SharedPreferences prefs,
  required TourDefinition definition,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      authStateProvider.overrideWith((ref) => Stream.value(_profile('ayse'))),
    ],
    child: MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: TourHost(definition: definition, child: child),
    ),
  );
}

/// Hedefi görünür alanın çok altına koyan gövde.
///
/// `SingleChildScrollView` bilerek seçildi: bütün çocuklar monte olur, yalnız
/// görünür pencerenin dışında kalır. Sahibin bildirdiği durum budur — hedef
/// vardır, ekranda değildir. (Hiç monte olmayan hedef ayrı bir vaka: o adım
/// "kayıp" sayılıp atlanır, aşağıdaki testlerde ayrıca kanıtlanıyor.)
Widget _longList(GlobalKey anchor, ScrollController controller) {
  return Scaffold(
    body: SingleChildScrollView(
      controller: controller,
      child: Column(
        children: [
          for (var i = 0; i < 12; i++)
            SizedBox(height: 120, child: Text('satır $i')),
          SizedBox(key: anchor, height: 48, child: const Text('hedef')),
          for (var i = 0; i < 12; i++)
            SizedBox(height: 120, child: Text('alt $i')),
        ],
      ),
    ),
  );
}

/// Spot ışığının deliği: boyayıcıya giden dikdörtgen. Balonun hedefe komşu
/// yerleşmesi üzerinden ölçüyoruz — spot ile balon aynı `_anchor`'ı kullanır.
Rect _bubbleRect(WidgetTester tester) =>
    tester.getRect(find.byKey(const Key('tour-bubble')));

void main() {
  testWidgets('ekranın altındaki hedef görünür alana kaydırılır', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final anchor = GlobalKey();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final definition = TourDefinition(
      id: 'scrolltest',
      version: 1,
      steps: [TourStep(id: 'target', text: 'Şuraya bak.', anchor: anchor)],
    );

    await tester.pumpWidget(
      _host(
        prefs: prefs,
        definition: definition,
        child: _longList(anchor, controller),
      ),
    );
    await tester.pumpAndSettle();

    // 🔴 Kapan: `Scrollable.ensureVisible` olmadan liste 0'da kalır; hedef
    // monte olduğu için tur "çalışıyor" görünür ama spot ışığı ekranın çok
    // altındaki bir yeri gösterir — sahibin gördüğü tam olarak budur.
    expect(controller.offset, greaterThan(0));
    expect(find.text('hedef'), findsOneWidget);
    expect(find.byKey(const Key('tour-bubble')), findsOneWidget);
  });

  testWidgets('kaydırma sonrası spot/balon hedefi takip eder', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final anchor = GlobalKey();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final definition = TourDefinition(
      id: 'followtest',
      version: 1,
      steps: [TourStep(id: 'target', text: 'Şuraya bak.', anchor: anchor)],
    );

    await tester.pumpWidget(
      _host(
        prefs: prefs,
        definition: definition,
        child: _longList(anchor, controller),
      ),
    );
    await tester.pumpAndSettle();

    final before = _bubbleRect(tester);
    final anchorBefore = tester.getRect(find.byKey(anchor));

    controller.jumpTo(controller.offset + 200);
    await tester.pumpAndSettle();

    final anchorAfter = tester.getRect(find.byKey(anchor));
    final after = _bubbleRect(tester);

    // Hedef gerçekten yer değiştirdi...
    expect(anchorAfter.top, isNot(closeTo(anchorBefore.top, 1)));
    // ...ve balon onunla birlikte taşındı. Eski kod `build` anında bir kez
    // ölçtüğü için balon yerinde kalırdı.
    expect(after.top, isNot(closeTo(before.top, 1)));
  });

  testWidgets('hedefi bulunamayan adım atlanır, sessizce ortalanmaz', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final missing = GlobalKey();
    final definition = TourDefinition(
      id: 'losttest',
      version: 1,
      steps: [
        // Hedefi ilan edilmiş ama gövdede hiç monte edilmeyecek adım.
        TourStep(id: 'ghost', text: 'Bu adım gösterilmemeli.', anchor: missing),
        TourStep(id: 'welcome', text: 'Bu adım gösterilmeli.'),
      ],
    );

    await tester.pumpWidget(
      _host(
        prefs: prefs,
        definition: definition,
        child: const Scaffold(body: Center(child: Text('gövde'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bu adım gösterilmemeli.'), findsNothing);
    expect(find.text('Bu adım gösterilmeli.'), findsOneWidget);
  });

  testWidgets('tek adımın hedefi kayıpsa tur biter ve görüldü işaretlenir', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final missing = GlobalKey();
    final definition = TourDefinition(
      id: 'lostonly',
      version: 1,
      steps: [TourStep(id: 'ghost', text: 'Yok.', anchor: missing)],
    );

    await tester.pumpWidget(
      _host(
        prefs: prefs,
        definition: definition,
        child: const Scaffold(body: Center(child: Text('gövde'))),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('tour-bubble')), findsNothing);
    expect(
      tourSeen(prefs, storageId: definition.storageId, userId: 'ayse'),
      isTrue,
    );
  });

  testWidgets('kasıtlı hedefsiz adım atlanmaz, ortada gösterilir', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final definition = TourDefinition(
      id: 'centered',
      version: 1,
      steps: [TourStep(id: 'welcome', text: 'Hoş geldin.')],
    );

    await tester.pumpWidget(
      _host(
        prefs: prefs,
        definition: definition,
        child: const Scaffold(body: Center(child: Text('gövde'))),
      ),
    );
    await tester.pumpAndSettle();

    // `anchor == null` bilinçli bir üründür; "hedef vardı ama bulunamadı" ile
    // aynı sepete atılmamalı.
    expect(find.text('Hoş geldin.'), findsOneWidget);
    expect(
      tourSeen(prefs, storageId: definition.storageId, userId: 'ayse'),
      isFalse,
    );
  });
}
