import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/features/stats/widgets/draggable_date_range_picker.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

void main() {
  const startHandle = ValueKey('range-handle-start');
  const endHandle = ValueKey('range-handle-end');

  Future<void> pumpPicker(
    WidgetTester tester, {
    DateTime? firstDate,
    DateTime? lastDate,
    DateTimeRange? initialRange,
    Locale locale = const Locale('en'),
    double textScale = 1,
    double width = 440,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: SizedBox(
              width: width,
              child: DraggableDateRangePickerDialog(
                firstDate: firstDate ?? DateTime(2026),
                lastDate: lastDate ?? DateTime(2026, 7, 31),
                initialRange:
                    initialRange ??
                    DateTimeRange(
                      start: DateTime(2026, 7, 5),
                      end: DateTime(2026, 7, 10),
                    ),
              ),
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

  testWidgets('sıradan gün dokunuşu uç seçilmeden aralığı değiştirmez', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      initialRange: DateTimeRange(
        start: DateTime(2026, 7, 14),
        end: DateTime(2026, 7, 30),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('date-2026-07-21')));
    await tester.pumpAndSettle();

    expect(handleText(tester, startHandle), contains('14'));
    expect(handleText(tester, endHandle), contains('30'));
  });

  testWidgets('uçlar 44px hedeflerdir ve açıkça seçilen bitiş düzenlenir', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      initialRange: DateTimeRange(
        start: DateTime(2026, 7, 14),
        end: DateTime(2026, 7, 30),
      ),
    );

    expect(
      tester.getSize(find.byKey(startHandle)).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSize(find.byKey(endHandle)).height,
      greaterThanOrEqualTo(44),
    );

    await tester.tap(find.byKey(endHandle));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('date-2026-07-21')));
    await tester.pumpAndSettle();

    expect(handleText(tester, startHandle), contains('14'));
    expect(handleText(tester, endHandle), contains('21'));
  });

  testWidgets('14–30 bitiş tutamacını 21’e sürüklemek 14–21 üretir', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      initialRange: DateTimeRange(
        start: DateTime(2026, 7, 14),
        end: DateTime(2026, 7, 30),
      ),
    );

    await tester.drag(
      find.byKey(endHandle),
      tester.getCenter(find.byKey(const ValueKey('date-2026-07-21'))) -
          tester.getCenter(find.byKey(endHandle)),
    );
    await tester.pumpAndSettle();

    expect(handleText(tester, startHandle), contains('14'));
    expect(handleText(tester, endHandle), contains('21'));
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

    // Sürüklenen başlangıç ucu karşıya geçtiğinde artık mantıksal bitiş
    // ucudur. Sonraki açık erişilebilirlik/dokunma eylemi doğru ucu izler.
    await tester.tap(find.byKey(const ValueKey('date-2026-07-18')));
    await tester.pumpAndSettle();
    expect(handleText(tester, startHandle), contains('10'));
    expect(handleText(tester, endHandle), contains('18'));
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

  testWidgets('ilk aralık min ve max sınırlara deterministik kırpılır', (
    tester,
  ) async {
    await pumpPicker(
      tester,
      firstDate: DateTime(2026, 7, 10),
      lastDate: DateTime(2026, 7, 20),
      initialRange: DateTimeRange(
        start: DateTime(2026, 7, 5),
        end: DateTime(2026, 7, 25),
      ),
    );

    expect(handleText(tester, startHandle), contains('10'));
    expect(handleText(tester, endHandle), contains('20'));
  });

  testWidgets('tek günlük aralık iki görünür ucu korur', (tester) async {
    await pumpPicker(
      tester,
      initialRange: DateTimeRange(
        start: DateTime(2026, 7, 14),
        end: DateTime(2026, 7, 14),
      ),
    );

    expect(handleText(tester, startHandle), contains('14'));
    expect(handleText(tester, endHandle), contains('14'));

    await tester.drag(
      find.byKey(endHandle),
      tester.getCenter(find.byKey(const ValueKey('date-2026-07-21'))) -
          tester.getCenter(find.byKey(endHandle)),
    );
    await tester.pumpAndSettle();

    expect(handleText(tester, startHandle), contains('14'));
    expect(handleText(tester, endHandle), contains('21'));
  });

  testWidgets('ekran okuyucu başlangıç ve bitiş için ayrı eylem sunar', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpPicker(
      tester,
      initialRange: DateTimeRange(
        start: DateTime(2026, 7, 14),
        end: DateTime(2026, 7, 30),
      ),
    );

    final day = find.byKey(const ValueKey('date-2026-07-21'));
    final localizations = MaterialLocalizations.of(tester.element(day));
    final formatted = localizations.formatMediumDate(DateTime(2026, 7, 21));
    final startAction = CustomSemanticsAction(
      label: localizations.dateRangeStartDateSemanticLabel(formatted),
    );
    final endAction = CustomSemanticsAction(
      label: localizations.dateRangeEndDateSemanticLabel(formatted),
    );
    final startActionId = CustomSemanticsAction.getIdentifier(startAction);
    final endActionId = CustomSemanticsAction.getIdentifier(endAction);
    final node = tester.getSemantics(day);

    expect(
      node.getSemanticsData().customSemanticsActionIds,
      containsAll(<int>[startActionId, endActionId]),
    );

    semantics.dispose();
  });

  testWidgets(
    'desteklenmeyen Arapça EN/LTR fallback ve text scale 1.3 kullanır',
    (tester) async {
      await pumpPicker(
        tester,
        locale: const Locale('ar'),
        textScale: 1.3,
        width: 320,
      );

      expect(tester.takeException(), isNull);
      expect(
        tester.getCenter(find.byKey(startHandle)).dx,
        lessThan(tester.getCenter(find.byKey(endHandle)).dx),
      );
    },
  );
}
