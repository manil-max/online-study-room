@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/theme/app_theme.dart';
import 'package:online_study_room/features/profile/theme_builder/feel_overlay.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_draft.dart';
import 'package:online_study_room/features/profile/theme_builder/theme_feel_catalog.dart';

/// WP-290 kabul: 3 temsili özel tema × {açık, koyu} = 6 golden.
///
/// Sonda `FeelOverlay` var — atmosfer ve his seçimlerinin gerçekten çizildiği
/// bu goldenlarda görünür; sessizce ölü kalırlarsa golden değişir.

ThemeDraft _modern() => ThemeDraft.fromPreset(
  slotId: 'custom_1',
  name: 'Modern',
  preset: themePresetById('campfire_night'),
);

ThemeDraft _paper() => ThemeDraft.fromPreset(
  slotId: 'custom_2',
  name: 'Defter',
  preset: themePresetById('nordic_snow'),
).withFeel(feelOptionById('paper').feel).copyWith(
  typography: const DraftTypography(
    titleFamily: kFontFamilySerif,
    bodyFamily: kFontFamilySerif,
    clockFamily: kFontFamilyMono,
  ),
);

ThemeDraft _neon() => ThemeDraft.fromPreset(
  slotId: 'custom_3',
  name: 'Neon',
  preset: themePresetById('neon_focus'),
).withFeel(feelOptionById('neon').feel).copyWith(
  typography: const DraftTypography(
    titleFamily: kFontFamilyMono,
    bodyFamily: kFontFamilySans,
    clockFamily: kFontFamilyMono,
    scale: 1.1,
  ),
);

Widget _probe(ThemeData theme) {
  return MaterialApp(
    theme: theme,
    debugShowCheckedModeBanner: false,
    builder: (context, child) => FeelOverlay(child: child!),
    home: Scaffold(
      appBar: AppBar(title: const Text('Odak Kampı')),
      body: const Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('12:34', style: TextStyle(fontSize: 48)),
            SizedBox(height: 16),
            Text('Bugünün odağı'),
            SizedBox(height: 8),
            Text('Kısa bir çalışma oturumu planla.'),
            SizedBox(height: 20),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Kart yüzeyi'),
              ),
            ),
            SizedBox(height: 20),
            FilledButton(onPressed: null, child: Text('Başlat')),
          ],
        ),
      ),
    ),
  );
}

void main() {
  final cases = <String, ThemeDraft Function()>{
    'modern': _modern,
    'paper': _paper,
    'neon': _neon,
  };

  for (final entry in cases.entries) {
    for (final brightness in Brightness.values) {
      final mode = brightness == Brightness.light ? 'light' : 'dark';
      testWidgets('özel tema golden · ${entry.key} · $mode', (tester) async {
        await tester.pumpWidget(_probe(entry.value().themeFor(brightness)));
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/custom_theme_${entry.key}_$mode.png'),
        );
      });
    }
  }
}
