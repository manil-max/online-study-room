import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/stats/widgets/draggable_date_range_picker.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

void main() {
  const startHandle = ValueKey('range-handle-start');
  const endHandle = ValueKey('range-handle-end');

  Future<void> pumpPicker(WidgetTester tester, {DateTime? lastDate}) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: DraggableDateRangePickerDialog(
            firstDate: DateTime(2026),
            lastDate: lastDate ?? DateTime(2026, 7, 31),
            initialRange: DateTimeRange(
              start: DateTime(2026, 7, 5),
              end: DateTime(2026, 7, 10),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String handleText(WidgetTester tester, ValueKey<String> key) {
    final text = find.descendant(
      of: find.byKey(key),
      matching: find.byType(Text),
    );
    return tester.widget<Text>(text).data!;
  }

  String cellText(WidgetTester tester, String isoDay) {
    final text = find.descendant(
      of: find.byKey(ValueKey('date-$isoDay')),
      matching: find.byType(Text),
    );
    return tester.widget<Text>(text).data!;
  }

  testWidgets('gün hücresi yalnız gün sayısını yazar', (tester) async {
    await pumpPicker(tester);

    // WP-412: hücreye `DateTime`ın kendisi basılırsa metin
    // "2026-07-01 00:00:00.000" olur, 40px daireden taşar ve dokunma
    // hedeflerini örter. Ekran görüntüsü değil, metin eşitliği ölçülür.
    expect(cellText(tester, '2026-07-01'), '1');
    expect(cellText(tester, '2026-07-09'), '9');
    expect(cellText(tester, '2026-07-31'), '31');

    final grid = find.byType(GridView);
    expect(find.descendant(of: grid, matching: find.text('1')), findsOneWidget);
    expect(
      find.descendant(of: grid, matching: find.textContaining('2026')),
      findsNothing,
    );
    expect(
      find.descendant(of: grid, matching: find.textContaining(':')),
      findsNothing,
    );
  });

  testWidgets('uç göstergeleri tam tarihi yazmaya devam eder', (tester) async {
    await pumpPicker(tester);

    // Hücre kısaldı diye uç etiketi kısalmamalı: uç, hangi güne oturduğunu
    // ayıyla birlikte göstermek zorunda (`formatMediumDate`).
    expect(handleText(tester, startHandle), contains('Jul'));
    expect(handleText(tester, startHandle), contains('5'));
    expect(handleText(tester, endHandle), contains('Jul'));
    expect(handleText(tester, endHandle), contains('10'));
    // Uç etiketi çıplak gün sayısına indirgenmiş olmamalı.
    expect(handleText(tester, startHandle), isNot('5'));
  });

  testWidgets('uçlar 44px hedeflerdir ve dokunarak düzenlenebilir', (
    tester,
  ) async {
    await pumpPicker(tester);

    expect(
      tester.getSize(find.byKey(startHandle)).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSize(find.byKey(endHandle)).height,
      greaterThanOrEqualTo(44),
    );

    await tester.tap(find.byKey(endHandle));
    await tester.tap(find.byKey(const ValueKey('date-2026-07-12')));
    await tester.pumpAndSettle();

    expect(handleText(tester, endHandle), contains('12'));
  });

  testWidgets('başlangıcı bitişin ötesine bırakmak uçları değiştirir', (
    tester,
  ) async {
    await pumpPicker(tester);

    await tester.drag(
      find.byKey(startHandle),
      tester.getCenter(find.byKey(const ValueKey('date-2026-07-15'))) -
          tester.getCenter(find.byKey(startHandle)),
    );
    await tester.pumpAndSettle();

    expect(handleText(tester, startHandle), contains('10'));
    expect(handleText(tester, endHandle), contains('15'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('gelecek tarih sınırı korunur', (tester) async {
    await pumpPicker(tester, lastDate: DateTime(2026, 7, 20));

    await tester.tap(find.byKey(startHandle));
    await tester.tap(find.byKey(const ValueKey('date-2026-07-21')));
    await tester.pumpAndSettle();

    expect(handleText(tester, startHandle), contains('5'));
    expect(
      tester
          .widget<IconButton>(
            find.ancestor(
              of: find.byIcon(Icons.chevron_right),
              matching: find.byType(IconButton),
            ),
          )
          .onPressed,
      isNull,
    );
  });
}
