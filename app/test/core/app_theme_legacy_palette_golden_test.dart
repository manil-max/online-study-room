import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/theme/app_theme.dart';

Widget _legacyPaletteProbe({
  required ThemeData lightTheme,
  required ThemeData darkTheme,
  required ThemeMode mode,
}) {
  return MaterialApp(
    theme: lightTheme,
    darkTheme: darkTheme,
    themeMode: mode,
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
            FilledButton(onPressed: null, child: Text('Başlat')),
          ],
        ),
      ),
    ),
  );
}

void main() {
  final palette = kAppPalettes.first;

  testWidgets('legacy palette light baseline', (tester) async {
    await tester.pumpWidget(
      _legacyPaletteProbe(
        lightTheme: AppTheme.light(palette),
        darkTheme: AppTheme.dark(palette),
        mode: ThemeMode.light,
      ),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/legacy_palette_light.png'),
    );
  });

  testWidgets('legacy palette dark baseline', (tester) async {
    await tester.pumpWidget(
      _legacyPaletteProbe(
        lightTheme: AppTheme.light(palette),
        darkTheme: AppTheme.dark(palette),
        mode: ThemeMode.dark,
      ),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/legacy_palette_dark.png'),
    );
  });

  testWidgets('legacy palette system baseline', (tester) async {
    tester.binding.platformDispatcher.platformBrightnessTestValue =
        Brightness.dark;
    addTearDown(
      tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
    );

    await tester.pumpWidget(
      _legacyPaletteProbe(
        lightTheme: AppTheme.light(palette),
        darkTheme: AppTheme.dark(palette),
        mode: ThemeMode.system,
      ),
    );

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/legacy_palette_system_dark.png'),
    );
  });
}
