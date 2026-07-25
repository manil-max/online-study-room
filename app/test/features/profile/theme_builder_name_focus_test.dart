import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_builder_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-306: Sahip raporu — tema adı alanına dokununca klavye açılıp hemen
/// kapanıyordu; telefon yana çevrilince yazılabiliyordu.
///
/// Sebep WP-302'nin sabit önizleme dalıydı: karar doğrudan
/// `constraints.maxHeight` ile veriliyordu. Klavye gövdeyi küçültünce ölçüt
/// eşiğin altına düşüyor, düzen `Column` → `ListView`'a atlıyor, ağaç şekli
/// değiştiği için `TextField` sıfırdan kuruluyor ve odağı düşürüyordu.
void main() {
  testWidgets('klavye açılınca ad alanı odağını korur', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ThemeBuilderScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Son adım (Özet) ad alanını taşır.
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.text('İleri'));
      await tester.pumpAndSettle();
    }
    final field = find.byType(TextField);
    expect(field, findsOneWidget);

    await tester.tap(field);
    await tester.pumpAndSettle();
    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.focusNode.hasFocus, isTrue, reason: 'dokunuşta odak gelmeli');

    // Klavye açılıyor: görünür gövde ~800 → ~400 dp'ye iner.
    tester.view.viewInsets = const FakeViewPadding(bottom: 1200);
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
      reason: 'klavye açılınca düzen dalı değişip odağı düşürmemeli',
    );

    // Ad gerçekten yazılabiliyor ve klavye kapanınca korunuyor.
    await tester.enterText(field, 'Gece Modu');
    await tester.pumpAndSettle();
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.text('Gece Modu'), findsWidgets);
  });
}
