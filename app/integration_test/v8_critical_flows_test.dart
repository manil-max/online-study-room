import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:online_study_room/features/classroom/classroom_screen.dart';
import 'package:online_study_room/features/desktop/desktop_navigation_pane.dart';
import 'package:online_study_room/features/home/home_screen.dart';
import 'package:online_study_room/features/profile/profile_screen.dart';

import '../test/support/v8_test_setup.dart';

/// Windows kritik akış kapısı — `flutter test -d windows` ile koşar.
///
/// 🔴 **WP-614: bu dosya kapı gibi görünüyordu ama ölçmüyordu.** İki kusur
/// vardı ve ikisi birlikte kapıyı tamamen etkisiz kılıyordu:
///
/// 1. **Sessiz mobil geri düşüş.** Masaüstü paneli bulunamazsa test
///    `NavigationBar`'a düşüp YEŞİL dönüyordu. `home_shell.dart` içindeki
///    `if (isDesktopWindow)` dalını tamamen silseniz — yani Windows kullanıcısı
///    mobil alt çubuğa düşse — adı "Windows integration (critical flows)" olan
///    iş yine geçerdi.
/// 2. **Tıklama yoktu.** Test `onSelected` geri çağrısını DOĞRUDAN çağırıyordu.
///    Yani panelin çizilip çizilmediği, öğenin tıklanabilir olup olmadığı, bir
///    diyaloğun üstünü kapatıp kapatmadığı hiç ölçülmüyordu; ölçülen tek şey
///    "verdiğim sayıyı geri aldım mı" idi.
///
/// Artık: masaüstü paneli **zorunlu**, geçişler **gerçek tıklamayla** yapılıyor
/// ve sonuç ekranın kendisinden okunuyor (`_DesktopLazyTabHost` ziyaret
/// edilmemiş sekmeyi hiç kurmaz — bu yüzden ekranın varlığı gerçek bir kanıt).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows kabuğunda sol panelden V8 yüzeylerine tıklanarak geçilir', (
    tester,
  ) async {
    final preferences = await v8SharedPreferences();
    final auth = await signedInV8AuthRepository(prefs: preferences);

    await tester.pumpWidget(
      buildV8TestApp(authRepository: auth, preferences: preferences),
    );
    await tester.pumpAndSettle();

    // 🔴 KAPININ ASIL İDDİASI. Mobil kola düşmek "geçti" değildir: bu iş
    // Windows kabuğunu ölçmek için var. Panel yoksa burada durur.
    expect(
      find.byType(DesktopNavigationPane),
      findsOneWidget,
      reason:
          'Windows kabuğu (DesktopNavigationPane) çizilmedi. Ya '
          '`home_shell.dart` masaüstü dalı kayboldu ya da test masaüstü '
          'hedefinde koşmuyor. Mobil NavigationBar bu kapıda GEÇERLİ '
          'bir sonuç DEĞİLDİR.',
    );
    expect(
      _navigationTiles(),
      findsNWidgets(5),
      reason:
          'Sol panelde 5 tıklanabilir sekme bekleniyor; bulunan sayı farklı '
          'ise kullanıcı bir yüzeye Windows üzerinden hiç ulaşamıyor demektir.',
    );

    expect(_selectedIndex(tester), 0);
    expect(find.byType(HomeScreen), findsOneWidget);
    // Tembel sekme sunucusu ziyaret edilmemiş ekranı hiç kurmaz. Bu yüzden
    // aşağıdaki `findsNothing` iddiaları, sonraki `findsOneWidget`leri gerçek
    // bir kanıt hâline getirir: ekran tıklamadan SONRA doğdu.
    expect(find.byType(ClassroomScreen), findsNothing);
    expect(find.byType(ProfileScreen), findsNothing);

    // 2 = Gruplar (home_shell `_screens` kanonik sırası)
    await tester.tap(_navigationTiles().at(2));
    await tester.pumpAndSettle();
    expect(_selectedIndex(tester), 2);
    expect(
      find.byType(ClassroomScreen),
      findsOneWidget,
      reason: 'Sekme seçildi ama Gruplar ekranı hiç kurulmadı.',
    );
    expect(
      _isOnstage(tester, find.byType(ClassroomScreen)),
      isTrue,
      reason: 'Gruplar ekranı kuruldu ama `Offstage` altında gizli kaldı.',
    );
    expect(
      _isOnstage(tester, find.byType(HomeScreen)),
      isFalse,
      reason: 'Ana Sayfa geçişten sonra hâlâ görünür — iki ekran üst üste.',
    );

    // 4 = Profil
    await tester.tap(_navigationTiles().at(4));
    await tester.pumpAndSettle();
    expect(_selectedIndex(tester), 4);
    expect(
      find.byType(ProfileScreen),
      findsOneWidget,
      reason: 'Sekme seçildi ama Profil ekranı hiç kurulmadı.',
    );
    expect(
      _isOnstage(tester, find.byType(ProfileScreen)),
      isTrue,
      reason: 'Profil ekranı kuruldu ama `Offstage` altında gizli kaldı.',
    );
    expect(_isOnstage(tester, find.byType(ClassroomScreen)), isFalse);
  });
}

/// Sol paneldeki tıklanabilir sekme döşemeleri.
///
/// Yalnız panelin `ListView`'ı kapsanır: alt eylemler (Ayarlar/Yenile/Üstte
/// tut/Kompakt) da `InkWell` taşır ve dizinleri kaydırırdı.
Finder _navigationTiles() => find.descendant(
  of: find.descendant(
    of: find.byType(DesktopNavigationPane),
    matching: find.byType(ListView),
  ),
  matching: find.byType(InkWell),
);

int _selectedIndex(WidgetTester tester) =>
    tester.widget<DesktopNavigationPane>(
      find.byType(DesktopNavigationPane),
    ).selectedIndex;

/// Widget kurulu **ve** hiçbir `Offstage` atası tarafından gizlenmemiş mi?
///
/// `find.byType(...)` tek başına yetmez: `_DesktopLazyTabHost` ziyaret edilmiş
/// sekmeleri ağaçta tutmaya devam eder, yalnız `Offstage` ile gizler.
bool _isOnstage(WidgetTester tester, Finder finder) {
  if (finder.evaluate().isEmpty) return false;
  final hidden = tester
      .widgetList<Offstage>(
        find.ancestor(of: finder, matching: find.byType(Offstage)),
      )
      .any((offstage) => offstage.offstage);
  return !hidden;
}
