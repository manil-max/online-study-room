import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/theme/app_theme.dart';
import 'package:online_study_room/core/theme/theme_settings.dart';
import 'package:online_study_room/features/profile/appearance_preset_preview.dart';
import 'package:online_study_room/features/profile/appearance_screen.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// WP-921 — tema ekranı: gerçek mini önizleme, açık/koyu bölümleri, mod
/// açıklaması. Sahip: "tema ayarlamayı da geliştir birazcık".
Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container, {
  Locale locale = const Locale('tr'),
  double textScale = 1.0,
}) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: locale,
        theme: AppTheme.fromFamily(
          themePresetById(kFirstRunFamilyId),
          Brightness.light,
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const AppearanceScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Bölüm ızgarasındaki tema kimlikleri, ekrandaki sırayla.
List<String> _idsIn(WidgetTester tester, Brightness brightness) {
  final cards = find.descendant(
    of: find.byKey(ValueKey('appearance-grid-${brightness.name}')),
    matching: find.byWidgetPredicate((w) {
      final key = w.key;
      return key is ValueKey<String> &&
          key.value.startsWith('appearance-preset-') &&
          key.value != 'appearance-preset-selected';
    }),
  );
  return [
    for (final w in tester.widgetList(cards))
      (w.key! as ValueKey<String>).value.substring('appearance-preset-'.length),
  ];
}

String? _selectedId(WidgetTester tester) {
  for (final preset in kThemePresets) {
    final marker = find.descendant(
      of: find.byKey(ValueKey('appearance-preset-${preset.id}')),
      matching: find.byKey(const ValueKey('appearance-preset-selected')),
    );
    if (marker.evaluate().isNotEmpty) return preset.id;
  }
  return null;
}

/// Sayfanın kendisi (ızgaralar da `Scrollable`; ilki dış liste).
final Finder _pageScroll = find.byType(Scrollable).first;

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  test(
    'iki bölüm her temayı tam bir kez, doğru parlaklıkta ve sırayla içerir',
    () {
      final light = appearancePresetsFor(Brightness.light);
      final dark = appearancePresetsFor(Brightness.dark);
      expect(light.first.id, kFirstRunFamilyId);
      expect(light.every((p) => p.brightness == Brightness.light), isTrue);
      expect(dark.every((p) => p.brightness == Brightness.dark), isTrue);
      final all = [...light, ...dark].map((p) => p.id).toList();
      expect(all.length, kThemePresets.length);
      expect(all.toSet(), kThemePresets.map((p) => p.id).toSet());
      // Bölüm içi sıra = `kAppearancePresetOrder` sırası.
      final order = kAppearancePresetOrder.map((p) => p.id).toList();
      for (final section in [light, dark]) {
        final idx = section.map((p) => order.indexOf(p.id)).toList();
        expect(idx, [...idx]..sort());
      }
    },
  );

  testWidgets('ekran iki etiketli bölüm ve mod açıklamasını gösterir', (
    tester,
  ) async {
    _setSize(tester, const Size(360, 3000));
    final container = await _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    expect(find.text('Açık temalar'), findsOneWidget);
    expect(find.text('Koyu temalar'), findsOneWidget);
    expect(find.byKey(const ValueKey('appearance-mode-help')), findsOneWidget);
    expect(
      find.textContaining('Sistem telefonun ayarını izler'),
      findsOneWidget,
    );
    // Açık bölüm koyu bölümün üstünde.
    expect(
      tester.getTopLeft(find.text('Açık temalar')).dy,
      lessThan(tester.getTopLeft(find.text('Koyu temalar')).dy),
    );

    final lightIds = _idsIn(tester, Brightness.light);
    final darkIds = _idsIn(tester, Brightness.dark);
    expect(
      lightIds,
      appearancePresetsFor(Brightness.light).map((p) => p.id).toList(),
    );
    expect(
      darkIds,
      appearancePresetsFor(Brightness.dark).map((p) => p.id).toList(),
    );
    expect(lightIds.first, kFirstRunFamilyId);
    expect({...lightIds, ...darkIds}.length, kThemePresets.length);
    expect(lightIds.length + darkIds.length, kThemePresets.length);

    // Her kartta gerçek minyatür var.
    expect(
      find.byType(AppearancePresetPreview),
      findsNWidgets(kThemePresets.length),
    );
  });

  testWidgets('minyatür temanın kendi token\'larıyla çizilir', (tester) async {
    _setSize(tester, const Size(360, 3000));
    final container = await _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    for (final preset in kThemePresets) {
      final id = preset.id;
      final clock = tester.widget<Text>(
        find.byKey(ValueKey('theme-preset-clock-$id')),
      );
      expect(clock.data, '25:00');
      expect(clock.style?.color, preset.colors.textPrimary, reason: id);
      expect(
        clock.style?.fontFamily,
        preset.monospaceClock
            ? 'monospace'
            : (preset.serifTitles ? 'serif' : isNot('monospace')),
        reason: '$id sayaç fontu',
      );
      final scaffold = tester.widget<DecoratedBox>(
        find.byKey(ValueKey('theme-preset-scaffold-$id')),
      );
      final gradient =
          (scaffold.decoration as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors, [
        preset.atmosphere.gradientStart,
        preset.atmosphere.gradientEnd,
      ]);
      BoxDecoration deco(String part) =>
          tester
                  .widget<Container>(
                    find.byKey(ValueKey('theme-preset-$part-$id')),
                  )
                  .decoration!
              as BoxDecoration;
      expect(deco('primary').color, preset.colors.primary, reason: id);
      expect(deco('accent').color, preset.colors.accent, reason: id);
      final surface = deco('surface');
      expect(surface.color?.r, preset.colors.surface1.r, reason: id);
      expect(
        surface.borderRadius,
        BorderRadius.circular(preset.shapes.radiusMd * 0.5),
        reason: '$id kart yarıçapı temanın biçiminden',
      );
    }
  });

  testWidgets('hazır temaya dokunmak seçer; seçim işareti taşınır', (
    tester,
  ) async {
    _setSize(tester, const Size(360, 3000));
    final container = await _container();
    addTearDown(container.dispose);
    await _pump(tester, container);

    // İlk kurulum: karşılama teması seçili.
    expect(_selectedId(tester), kFirstRunFamilyId);

    await tester.tap(
      find.byKey(const ValueKey('appearance-preset-forest_study')),
    );
    await tester.pumpAndSettle();
    expect(container.read(themeSettingsProvider).familyId, 'forest_study');
    expect(container.read(themeSettingsProvider).mode, ThemeMode.dark);
    expect(_selectedId(tester), 'forest_study');
    expect(
      find.byKey(const ValueKey('appearance-preset-selected')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('appearance-preset-nordic_snow')),
    );
    await tester.pumpAndSettle();
    expect(container.read(themeSettingsProvider).mode, ThemeMode.light);
    expect(_selectedId(tester), 'nordic_snow');
  });

  group('taşma yok', () {
    for (final size in const [Size(320, 568), Size(360, 640)]) {
      for (final scale in const [1.0, 1.5]) {
        for (final locale in const [Locale('tr'), Locale('en')]) {
          testWidgets(
            '${size.width.toInt()}x${size.height.toInt()} · ölçek $scale · '
            '${locale.languageCode}',
            (tester) async {
              _setSize(tester, size);
              final container = await _container();
              addTearDown(container.dispose);
              await _pump(tester, container, locale: locale, textScale: scale);
              expect(tester.takeException(), isNull);
              // Listenin sonuna kadar kaydır: her kart en az bir kez çizilir.
              await tester.scrollUntilVisible(
                find.byKey(
                  ValueKey(
                    'appearance-preset-'
                    '${appearancePresetsFor(Brightness.dark).last.id}',
                  ),
                ),
                300,
                scrollable: _pageScroll,
              );
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }

    testWidgets('1280 genişlikte masaüstü penceresi', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      _setSize(tester, const Size(1280, 800));
      final container = await _container();
      addTearDown(container.dispose);
      await _pump(tester, container);
      expect(tester.takeException(), isNull);

      // WP-679: ızgara 760 px form tavanının içinde kalır.
      final grid = tester.getSize(
        find.byKey(const ValueKey('appearance-grid-dark')),
      );
      expect(grid.width, lessThanOrEqualTo(760));
      await tester.scrollUntilVisible(
        find.byKey(
          ValueKey(
            'appearance-preset-'
            '${appearancePresetsFor(Brightness.dark).last.id}',
          ),
        ),
        300,
        scrollable: _pageScroll,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
