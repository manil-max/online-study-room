import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/wp295_preview.dart' as preview;

void main() {
  testWidgets('WP-295 parametrik önizleme geniş ekranda taşmadan render olur', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    preview.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('WP-295 · Kamp ateşi parametrik önizleme'),
      findsOneWidget,
    );
    expect(find.textContaining('6 üye · 4 çalışıyor'), findsOneWidget);
    for (var step = 0; step < 80; step++) {
      final key = step.isEven ? 'ring-increase' : 'ring-decrease';
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.byKey(const ValueKey('member-count-3')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('3 üye · 3 çalışıyor'), findsOneWidget);
    expect(find.text('1. hayvan'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('member-count-6')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.drag(find.byType(ListView).last, const Offset(0, -1400));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('ring=0.35'), findsOneWidget);
    expect(find.textContaining('count=6'), findsOneWidget);
    expect(find.textContaining('pairs=(0.40,-0.68)'), findsOneWidget);
    expect(find.textContaining('stickReach=0.76'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
