import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/clock/clock_widgets_screen.dart';

void main() {
  testWidgets('izinler açıldıktan sonra sistem ayarından kapatılabilir', (
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
    expect(find.text('Kapat'), findsNWidgets(4));

    await tester.tap(find.text('İzni geri almak ister misin?'));
    await tester.pumpAndSettle();

    expect(find.text('Bildirimleri kapat:'), findsOneWidget);
    expect(find.text('Kesin alarmı kapat:'), findsOneWidget);
    expect(find.text('Pil istisnasını kaldır:'), findsOneWidget);
    expect(find.text('Tam ekran alarmı kapat:'), findsOneWidget);
  });
}
