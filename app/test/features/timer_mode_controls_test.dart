import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:online_study_room/core/prefs/app_prefs.dart';
import 'package:online_study_room/features/classroom/widgets/timer_mode_controls.dart';

Future<Widget> _harness() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: const MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 400, child: TimerModeControls())),
      ),
    ),
  );
}

void main() {
  testWidgets('Kronometre modunda ayar editörü yok', (tester) async {
    await tester.pumpWidget(await _harness());
    await tester.pumpAndSettle();

    expect(find.text('Kronometre'), findsOneWidget);
    expect(find.text('Süre (dakika)'), findsNothing);
    expect(find.text('Çalışma dk'), findsNothing);
  });

  testWidgets('Pomodoro seçilince çalışma/mola/döngü editörleri gelir',
      (tester) async {
    await tester.pumpWidget(await _harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Pomodoro'));
    await tester.pumpAndSettle();

    expect(find.text('Çalışma dk'), findsOneWidget);
    expect(find.text('Mola dk'), findsOneWidget);
    expect(find.text('Döngü'), findsOneWidget);
  });

  testWidgets('Geri sayım seçilince süre editörü gelir', (tester) async {
    await tester.pumpWidget(await _harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Geri sayım'));
    await tester.pumpAndSettle();

    expect(find.text('Süre (dakika)'), findsOneWidget);
    // Varsayılan 25 dk görünür.
    expect(find.text('25'), findsOneWidget);
  });
}
