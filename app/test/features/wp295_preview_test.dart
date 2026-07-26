import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/wp295_preview.dart' as preview;

void main() {
  const scenarios = [
    (
      locale: Locale('tr'),
      title: 'WP-295 · Kamp ateşi parametrik önizleme',
      initialStatus: '6 üye · 4 çalışıyor',
      selectedStatus: '3 üye · 3 çalışıyor',
      animal: '1. hayvan',
      increaseTooltip: 'Ateşe yatay uzaklık değerini 0.01 artır',
    ),
    (
      locale: Locale('en'),
      title: 'WP-295 · Campfire parametric preview',
      initialStatus: '6 members · 4 working',
      selectedStatus: '3 members · 3 working',
      animal: 'Animal 1',
      increaseTooltip: 'Increase Horizontal fire distance by 0.01',
    ),
  ];

  for (final scenario in scenarios) {
    testWidgets(
      'WP-295 preview renders and remains interactive in ${scenario.locale.languageCode}',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          preview.buildWp295PreviewApp(locale: scenario.locale),
        );
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text(scenario.title), findsOneWidget);
        expect(find.textContaining(scenario.initialStatus), findsOneWidget);
        expect(find.byTooltip(scenario.increaseTooltip), findsOneWidget);
        for (var step = 0; step < 80; step++) {
          final key = step.isEven ? 'ring-increase' : 'ring-decrease';
          await tester.tap(find.byKey(ValueKey(key)));
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.takeException(), isNull);
        }
        await tester.tap(find.byKey(const ValueKey('member-count-3')));
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.textContaining(scenario.selectedStatus), findsOneWidget);
        expect(find.text(scenario.animal), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('member-count-6')));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.drag(find.byType(ListView).last, const Offset(0, -1400));
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.textContaining('ring=0.35'), findsOneWidget);
        expect(find.textContaining('count=6'), findsOneWidget);
        expect(find.textContaining('pairs=(0.40,-0.68)'), findsOneWidget);
        expect(find.textContaining('stickReach=0.76'), findsOneWidget);
        expect(tester.takeException(), isNull);

        tester.view.physicalSize = const Size(360, 800);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
