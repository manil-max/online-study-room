import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/theme/app_theme.dart';
import 'package:online_study_room/core/theme/theme_settings.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_builder_screen.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_draft.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_preview.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

Future<void> _pumpWizard(
  WidgetTester tester,
  ProviderContainer container,
) async {
  // Sihirbaz uzun listeler içeriyor; varsayılan 800×600 yüzey seçenekleri
  // ekran dışında bırakıyor.
  await tester.binding.setSurfaceSize(const Size(900, 1800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ThemeBuilderScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

ThemeData _previewTheme(WidgetTester tester) =>
    tester.widget<ThemePreviewCard>(find.byType(ThemePreviewCard)).theme;

Future<void> _goToStep(WidgetTester tester, int step) async {
  for (var i = 0; i < step; i++) {
    await tester.tap(find.widgetWithText(FilledButton, 'İleri'));
    await tester.pumpAndSettle();
  }
}

/// Uzun listede hedefi görünür yapıp dokun.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sihirbaz canlı önizlemeyle açılır ve adımlar gezilebilir', (
    tester,
  ) async {
    final container = await _container();
    addTearDown(container.dispose);
    await _pumpWizard(tester, container);

    expect(find.text('Kendi Temanı Oluştur'), findsOneWidget);
    expect(find.byType(ThemePreviewCard), findsOneWidget);
    expect(find.textContaining('1/8'), findsOneWidget);

    await _goToStep(tester, 2);
    expect(find.textContaining('3/8'), findsOneWidget);
    // WP-311: etiket artık hem adımda hem önizleme örnekliğinde görünür.
    expect(find.text('Başlık yazı tipi'), findsNWidgets(2));
  });

  testWidgets('zemin seçimi önizlemeyi anında değiştirir', (tester) async {
    final container = await _container();
    addTearDown(container.dispose);
    await _pumpWizard(tester, container);

    final before = _previewTheme(tester).colorScheme.primary;
    await _tap(tester, find.text('Nordik Kar'));

    expect(_previewTheme(tester).colorScheme.primary, isNot(before));
  });

  testWidgets('yazı tipi seçimi tüm TextTheme slotlarına yansır', (
    tester,
  ) async {
    final container = await _container();
    addTearDown(container.dispose);
    await _pumpWizard(tester, container);
    await _goToStep(tester, 2);

    await _tap(tester, find.widgetWithText(ChoiceChip, 'Tırnaklı'));

    final text = _previewTheme(tester).textTheme;
    expect(text.titleLarge!.fontFamily, kFontFamilySerif);
    // R17: yalnız dört slot değil, sözleşmenin tamamı tema kontrolünde.
    expect(text.headlineSmall!.fontFamily, kFontFamilySerif);
    expect(text.displayMedium!.fontFamily, kFontFamilySerif);
  });

  testWidgets('his seçimi biçim ve atmosfer token\'larını gerçekten değiştirir', (
    tester,
  ) async {
    final container = await _container();
    addTearDown(container.dispose);
    await _pumpWizard(tester, container);
    await _goToStep(tester, 5);

    await _tap(tester, find.text('Neon'));
    final neon = _previewTheme(tester);
    expect(neon.extension<AppFeel>()!.feelId, 'neon');
    expect(neon.extension<AppAtmosphere>()!.glowStrength, greaterThan(0));

    await _tap(tester, find.text('Kâğıt'));
    final paper = _previewTheme(tester);
    expect(paper.extension<AppFeel>()!.grainKind, 'paper');
    expect(
      paper.extension<AppShapes>()!.radiusMd,
      lessThan(neon.extension<AppShapes>()!.radiusMd + 10),
    );
  });

  testWidgets('AA altı renkte uyarı çıkar ve düzelt tek dokunuşta çözer', (
    tester,
  ) async {
    final container = await _container();
    addTearDown(container.dispose);
    await _pumpWizard(tester, container);
    await _goToStep(tester, 1);

    // Metin rengini yüzeye çok yakın bir tona çek → AA düşer.
    await _tap(tester, find.text('Metin'));
    // Kart yüzeyine çok yakın bir ton — kontrast AA'nın altına düşer.
    await _tap(
      tester,
      find.byKey(ValueKey('themeColor_${const Color(0xFF141821).toARGB32()}')),
    );

    expect(find.textContaining('Kontrast düşük'), findsWidgets);

    await _tap(tester, find.text('Düzelt'));

    expect(find.textContaining('Kontrast düşük'), findsNothing);
  });

  testWidgets('adsız tema kaydedilemez; ad girilince kaydedilir ve uygulanır', (
    tester,
  ) async {
    final container = await _container();
    addTearDown(container.dispose);
    await _pumpWizard(tester, container);
    await _goToStep(tester, 7);

    expect(find.text('Temaya bir ad ver.'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'Kaydet ve uygula');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Gece Defteri');
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(save).onPressed, isNotNull);

    await _tap(tester, save);

    final settings = container.read(themeSettingsProvider);
    expect(settings.activeCustomTheme?.name, 'Gece Defteri');
    expect(settings.activeCustomTheme?.id, 'custom_1');
  });

  testWidgets('tema adı 24 karakterle sınırlıdır', (tester) async {
    final container = await _container();
    addTearDown(container.dispose);
    await _pumpWizard(tester, container);
    await _goToStep(tester, 7);

    await tester.enterText(
      find.byType(TextField),
      'Çok uzun bir tema adı yazıyorum burada',
    );
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.maxLength, kThemeNameMaxLength);
    expect(
      container.read(themeSettingsProvider).customThemes.first.name.length,
      lessThanOrEqualTo(kThemeNameMaxLength),
    );
  });

  testWidgets('WP-302: seçenekleri kaydırınca canlı önizleme ekranda kalır', (
    tester,
  ) async {
    final container = await _container();
    addTearDown(container.dispose);
    // Telefon yüzeyi: önizleme sabit, seçenek listesi kendi içinde kayar.
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ThemeBuilderScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final preview = find.byType(ThemePreviewCard);
    final topBefore = tester.getTopLeft(preview).dy;

    // Zemin adımının seçenek listesini sonuna kadar kaydır.
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();

    // Eskiden önizleme listenin ilk çocuğuydu; bu kaydırmada ekrandan
    // tamamen çıkıyordu — yani kullanıcı denediği rengi göremiyordu.
    expect(preview, findsOneWidget);
    expect(tester.getTopLeft(preview).dy, topBefore);
  });

  testWidgets('kaydedilmemiş değişiklikle çıkışta uyarı gösterilir', (
    tester,
  ) async {
    final container = await _container();
    addTearDown(container.dispose);
    await _pumpWizard(tester, container);

    await _tap(tester, find.text('Nordik Kar'));

    final state = tester.state<NavigatorState>(find.byType(Navigator));
    state.maybePop();
    await tester.pumpAndSettle();

    expect(find.textContaining('Kaydedilmemiş değişiklikler'), findsOneWidget);
    await tester.tap(find.text('Devam et'));
    await tester.pumpAndSettle();
    expect(find.byType(ThemeBuilderScreen), findsOneWidget);
  });
}
