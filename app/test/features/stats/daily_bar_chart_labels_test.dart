import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/features/stats/widgets/daily_bar_chart.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-313: sahip "tarihler 2 günde bir yazılıyor, her sütunun altında olsun"
/// dedi. Sebep: gün+ay iki satırlık etiket 26 px varsayıyordu, 14 günlük seri
/// sığmıyor ve adım 2'ye çıkıyordu. Artık ay adı yalnız ay değişince yazılır.
List<DayTotal> _series(DateTime start, int count) => [
  for (var i = 0; i < count; i++)
    DayTotal(start.add(Duration(days: i)), (i + 1) * 600),
];

Future<void> _pump(WidgetTester tester, List<DayTotal> days) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('tr'),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            height: 220,
            child: DailyBarChart(days: days),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('14 günde her sütunun altında gün numarası var', (tester) async {
    // 5–18 Haziran: tek ay, ay adı yalnız ilk sütunda.
    final days = _series(DateTime(2026, 6, 5), 14);
    await _pump(tester, days);

    for (final d in days) {
      expect(
        find.text('${d.day.day}'),
        findsOneWidget,
        reason: '${d.day.day}. günün etiketi eksik',
      );
    }
    expect(find.text('Haz'), findsOneWidget);
  });

  testWidgets('ay adı yalnız ay değiştiğinde tekrarlanır', (tester) async {
    // 26 Haziran – 2 Temmuz: iki ay adı beklenir (ilk sütun + ay dönümü).
    final days = _series(DateTime(2026, 6, 26), 7);
    await _pump(tester, days);

    expect(find.text('Haz'), findsOneWidget);
    expect(find.text('Tem'), findsOneWidget);
    for (final d in days) {
      expect(find.text('${d.day.day}'), findsOneWidget);
    }
  });
}
