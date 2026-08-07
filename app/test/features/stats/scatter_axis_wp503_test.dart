// WP-503 (WP-499 yan bulgusu): dağılım grafiğinde Y ekseni aynı hatayı
// taşıyordu.
//
// 🔴 `session_scatter_chart.dart:93` `maxY = maxMin * 1.2` diyordu — WP-499'un
// çizgi grafiğinde düzelttiği desenin aynısı. Üstelik iki kat kötü:
//   * `leftTitles`in `interval`i **hiç verilmemişti**, fl_chart kendi
//     aralığını seçiyordu;
//   * `gridData`nın `horizontalInterval`ı da yoktu, yani ızgara ile etiketler
//     ayrı ayrı aralık seçiyordu (çizgisiz etiket, etiketsiz çizgi);
//   * `getTitlesWidget` hiçbir değeri elemiyordu, `0` da çiziliyordu.
//
// Düzeltme WP-499'un ortak `minuteAxis()` fonksiyonunu çağırıyor: önce aralık,
// sonra o aralığın üst katı olan sınır. Böylece fl_chart eksen sınırı için
// fazladan etiket üretmiyor (`SideTitles.maxIncluded` varsayılanı `true`).
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/data/models/study_session.dart';
import 'package:online_study_room/data/models/subject.dart';
import 'package:online_study_room/data/providers/subject_providers.dart';
import 'package:online_study_room/features/stats/widgets/session_scatter_chart.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Ölçülerek seçilen seriler: her biri eski kodda üst sınırı aralığın katı
/// olmayan bir yere düşürüyor.
enum _Series {
  /// Tepe 51 dk → eski `maxY` 61.2.
  kisaOturumlar,

  /// Tepe 110 dk → eski `maxY` 132.
  ortaOturumlar,

  /// Tepe 480 dk → eski `maxY` 576.
  uzunMesai,
}

List<StudySession> _sessions(_Series kind, int days) {
  final start = DateTime.now().subtract(Duration(days: days - 1));
  final peak = switch (kind) {
    _Series.kisaOturumlar => 51,
    _Series.ortaOturumlar => 110,
    _Series.uzunMesai => 480,
  };
  return [
    for (var i = 0; i < days; i++)
      StudySession(
        id: 's$i',
        userId: 'u1',
        // Tepe her uzunlukta aynı kalsın ki "kötü durum" sabitlensin.
        start: DateTime(start.year, start.month, start.day + i, 9),
        end: DateTime(start.year, start.month, start.day + i, 9),
        durationSeconds: ((i + 1) * peak ~/ days) * 60,
        source: StudySource.live,
      ),
  ];
}

Future<void> _pump(WidgetTester tester, List<StudySession> sessions) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userSubjectsProvider.overrideWith((ref) => Stream.value(const <Subject>[])),
      ],
      child: MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: SessionScatterChart(sessions: sessions, height: 180),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Y ekseni etiketleri: **çıplak sayı**. Alt eksendeki tarihler boşluk ve ay
/// adı taşır ("5 Haz"), bu yüzden karışmaz.
List<Rect> _yLabelRects(WidgetTester tester) {
  final rects = <Rect>[];
  for (final element in find.byType(Text).evaluate()) {
    final text = (element.widget as Text).data;
    if (text == null || !RegExp(r'^\d+$').hasMatch(text)) continue;
    rects.add(tester.getRect(find.byElementPredicate((e) => e == element)));
  }
  rects.sort((a, b) => a.top.compareTo(b.top));
  return rects;
}

void main() {
  group('Y ekseni etiketleri çakışmıyor', () {
    for (final days in [14, 30, 90]) {
      for (final kind in _Series.values) {
        testWidgets('$days gün · ${kind.name}', (tester) async {
          await _pump(tester, _sessions(kind, days));

          final rects = _yLabelRects(tester);
          expect(rects, isNotEmpty, reason: 'Y ekseni etiketi hiç çizilmemiş');
          for (var i = 1; i < rects.length; i++) {
            expect(
              rects[i].top,
              greaterThanOrEqualTo(rects[i - 1].bottom),
              reason: '$days/${kind.name}: ${rects[i - 1]} ile ${rects[i]} '
                  'çakışıyor',
            );
          }
        });
      }
    }
  });

  testWidgets('eksen sınırı aralığın tam katı ve ızgara aynı aralıkta', (
    tester,
  ) async {
    await _pump(tester, _sessions(_Series.kisaOturumlar, 30));

    final data = tester.widget<ScatterChart>(find.byType(ScatterChart)).data;
    final interval = data.titlesData.leftTitles.sideTitles.interval;

    // 🔴 Eskiden bu `null`dı: aralık verilmediği için fl_chart kendi seçimini
    // yapıyor ve ızgarayla hizalanmıyordu.
    expect(interval, isNotNull);
    final steps = data.maxY / interval!;
    expect(steps - steps.roundToDouble(), closeTo(0, 1e-9));
    // Izgara ve etiketler aynı aralıkta olmalı; ayrıysa çizgisiz etiket çıkar.
    expect(data.gridData.horizontalInterval, interval);
    expect(data.minY, 0);
  });

  testWidgets('sıfır etiketi çizilmez', (tester) async {
    await _pump(tester, _sessions(_Series.ortaOturumlar, 14));

    // Taban çizgisindeki `0`, alt eksendeki tarih etiketleriyle çakışıyordu.
    expect(find.text('0'), findsNothing);
  });
}
