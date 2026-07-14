import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/clock/clock_widgets_screen.dart';

void main() {
  testWidgets('izinler açıldıktan sonra da sistemden yönetilebilir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 3;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ClockWidgetsScreen())),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('sistem ayarlarından açılıp kapatılır'),
      findsOneWidget,
    );
    expect(find.text('Yönet'), findsNWidgets(4));
  });
}
