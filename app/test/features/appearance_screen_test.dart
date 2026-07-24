import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/core/theme/custom_theme.dart';
import 'package:online_study_room/core/theme/theme_settings.dart';
import 'package:online_study_room/features/profile/appearance_screen.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_builder_screen.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_draft.dart';
import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:online_study_room/core/theme/app_theme.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

Future<void> _pumpScreen(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        locale: Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppearanceScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

CustomTheme _theme(String slot, String name, {required DateTime updatedAt}) {
  final draft = ThemeDraft.fromPreset(
    slotId: slot,
    name: name,
    preset: themePresetById('campfire_night'),
  );
  return draft.toCustomTheme().copyWith(updatedAt: updatedAt);
}

void main() {
  testWidgets('görünüm ekranı oluşturucu girişini ve hazır temaları gösterir', (
    tester,
  ) async {
    final container = await _container();
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    expect(find.text('Görünüm ve atmosfer'), findsOneWidget);
    expect(find.text('Kendi Temanı Oluştur'), findsOneWidget);
    expect(find.text('Hazır temalar'), findsOneWidget);
    // Boş yuvalar liste olarak gösterilmez (sahip kararı).
    expect(find.byTooltip('Sil'), findsNothing);
  });

  testWidgets('kaydedilen temalar en yeni en üstte listelenir', (tester) async {
    final container = await _container();
    addTearDown(container.dispose);
    final notifier = container.read(themeSettingsProvider.notifier);
    await notifier.saveCustomTheme(
      _theme('custom_1', 'Eski tema', updatedAt: DateTime(2026, 1, 1)),
    );
    await notifier.saveCustomTheme(
      _theme('custom_2', 'Yeni tema', updatedAt: DateTime(2026, 7, 1)),
    );
    await _pumpScreen(tester, container);

    final newest = tester.getTopLeft(find.text('Yeni tema')).dy;
    final oldest = tester.getTopLeft(find.text('Eski tema')).dy;
    expect(newest, lessThan(oldest));
    expect(find.byTooltip('Düzenle'), findsNWidgets(2));
    expect(find.byTooltip('Sil'), findsNWidgets(2));
  });

  testWidgets('silme onay ister; iptal edilirse tema kalır', (tester) async {
    final container = await _container();
    addTearDown(container.dispose);
    await container
        .read(themeSettingsProvider.notifier)
        .saveCustomTheme(
          _theme('custom_1', 'Silinecek', updatedAt: DateTime(2026, 7, 1)),
        );
    await _pumpScreen(tester, container);

    await tester.tap(find.byTooltip('Sil'));
    await tester.pumpAndSettle();
    expect(find.textContaining('silinsin mi'), findsOneWidget);

    await tester.tap(find.text('İptal'));
    await tester.pumpAndSettle();
    expect(find.text('Silinecek'), findsOneWidget);

    await tester.tap(find.byTooltip('Sil'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
    await tester.pumpAndSettle();

    expect(find.text('Silinecek'), findsNothing);
    expect(
      container.read(themeSettingsProvider).customThemes[0].isDefined,
      isFalse,
    );
  });

  testWidgets('üç yuva doluyken oluşturucu yerine net mesaj gösterilir', (
    tester,
  ) async {
    final container = await _container();
    addTearDown(container.dispose);
    final notifier = container.read(themeSettingsProvider.notifier);
    for (var slot = 1; slot <= 3; slot++) {
      await notifier.saveCustomTheme(
        _theme('custom_$slot', 'Tema $slot', updatedAt: DateTime(2026, 7, slot)),
      );
    }
    await _pumpScreen(tester, container);

    await tester.tap(find.text('Kendi Temanı Oluştur'));
    await tester.pumpAndSettle();

    expect(find.byType(ThemeBuilderScreen), findsNothing);
    expect(find.textContaining('yuvasının hepsi dolu'), findsOneWidget);
  });

  testWidgets('boş yuva varken oluşturucu açılır', (tester) async {
    final container = await _container();
    addTearDown(container.dispose);
    await _pumpScreen(tester, container);

    await tester.tap(find.text('Kendi Temanı Oluştur'));
    await tester.pumpAndSettle();

    expect(find.byType(ThemeBuilderScreen), findsOneWidget);
  });

  testWidgets('hazır tema seçimi aktif özel temayı bırakır (ölü anahtar yok)', (
    tester,
  ) async {
    final container = await _container();
    addTearDown(container.dispose);
    final notifier = container.read(themeSettingsProvider.notifier);
    await notifier.saveCustomTheme(
      _theme('custom_1', 'Özelim', updatedAt: DateTime(2026, 7, 1)),
    );
    await notifier.setActiveCustomTheme('custom_1');
    await _pumpScreen(tester, container);

    expect(container.read(themeSettingsProvider).activeCustomTheme, isNotNull);
    await tester.tap(find.text('Nordik Kar'));
    await tester.pumpAndSettle();

    final settings = container.read(themeSettingsProvider);
    expect(settings.activeCustomTheme, isNull);
    expect(settings.familyId, 'nordic_snow');
  });

  test('visibleThemes yalnız tanımlı temaları en yeni en üstte sıralar', () {
    final themes = [
      _theme('custom_1', 'A', updatedAt: DateTime(2026, 1, 1)),
      _theme('custom_2', 'B', updatedAt: DateTime(2026, 7, 1)),
      _theme(
        'custom_3',
        'C',
        updatedAt: DateTime(2026, 3, 1),
      ).copyWith(isDefined: false),
    ];
    final visible = AppearanceScreen.visibleThemes(themes);
    expect(visible.map((t) => t.name).toList(), ['B', 'A']);
  });
}
