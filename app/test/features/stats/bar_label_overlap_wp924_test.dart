import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/features/stats/widgets/daily_bar_chart.dart';
import 'package:online_study_room/features/stats/widgets/personal_period_cards.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-924: çubuk üstü süre etiketleri üst üste binmez.
///
/// 🔴 Kusur (UX denetimi `s07`/`s08`, mağaza görseli): 14/30 günlük "Günlük
/// dağılım", Ana Sayfa "Çalışma grafiği" ve "Grup günlük trendi" her dolu
/// çubuğun üstüne süre yazıyordu; 360 dp'de yazılar birbirinin içine
/// giriyordu. 7 günde de ilk etiket "Hedef" yazısıyla çakışıyordu.
///
/// Ölçüm fl_chart'ın **çizdiği** paragraflardan yapılır: grafiğin render
/// nesnesi sahte tuvale boyanır, her `drawParagraph` çağrısının dikdörtgeni
/// (o anki `translate` yığınıyla) toplanır. Seçim fonksiyonunun kendi hesabı
/// kullanılmaz — o hesap kayarsa bu test onu yakalar.

/// Sabit tarihli seri (gerçek saat okunmaz). Değerler 2sa–5sa18dk arası,
/// komşular arasında büyük fark yok: etiketler aynı yükseklikte kalır, yani
/// yalnız yatay ayrım çakışmayı önleyebilir (en zor durum).
List<DayTotal> _series(int count) {
  const pattern = [
    4 * 3600 + 4 * 60,
    4 * 3600 + 41 * 60,
    4 * 3600 + 16 * 60,
    5 * 3600 + 2 * 60,
    4 * 3600 + 8 * 60,
    4 * 3600 + 25 * 60,
    2 * 3600 + 35 * 60,
    5 * 3600 + 18 * 60,
    3 * 3600 + 36 * 60,
  ];
  final start = DateTime(2026, 8, 25);
  return [
    for (var i = 0; i < count; i++)
      DayTotal(
        DateTime(start.year, start.month, start.day + i),
        pattern[i % pattern.length],
      ),
  ];
}

Future<void> _pump(WidgetTester tester, Widget chart) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('tr'),
      home: Scaffold(
        body: Padding(
          // İstatistik kartının iç boşluğu (12 + kart kenarı): 360 dp
          // ekranda grafiğe kalan gerçek genişlik.
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Center(child: SizedBox(height: 180, child: chart)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Grafik render nesnesinin çizdiği metinlerin dikdörtgenleri.
List<Rect> _paintedLabelRects(WidgetTester tester) {
  final render = tester.renderObject(
    find.descendant(
      of: find.byType(BarChart),
      matching: find.byWidgetPredicate(
        (w) => w.runtimeType.toString() == 'BarChartLeaf',
      ),
    ),
  );
  final rects = <Rect>[];
  var translation = Offset.zero;
  final stack = <Offset>[];
  expect(
    render,
    paints..everything((method, args) {
      switch (method) {
        case #save:
          stack.add(translation);
        case #restore:
          translation = stack.isEmpty ? Offset.zero : stack.removeLast();
        case #translate:
          translation += Offset(
            (args[0] as num).toDouble(),
            (args[1] as num).toDouble(),
          );
        case #drawParagraph:
          final paragraph = args[0] as ui.Paragraph;
          final offset = (args[1] as Offset) + translation;
          // Paragraf kutusu metinden geniş olabilir (ortalı balon metni
          // `maxContentWidth`e göre dizilir); gerçek glif kutuları alınır.
          final boxes = paragraph.getBoxesForRange(0, 1 << 16);
          if (boxes.isEmpty) break;
          var r = boxes.first.toRect();
          for (final box in boxes.skip(1)) {
            r = r.expandToInclude(box.toRect());
          }
          rects.add(r.shift(offset));
      }
      return true;
    }),
  );
  return rects;
}

void _expectNoOverlap(List<Rect> rects, double chartWidth, String label) {
  for (var a = 0; a < rects.length; a++) {
    for (var b = a + 1; b < rects.length; b++) {
      final overlap = rects[a].intersect(rects[b]);
      expect(
        overlap.width > 0.5 && overlap.height > 0.5,
        isFalse,
        reason:
            '$label: etiket ${rects[a]} ile ${rects[b]} üst üste '
            '(${rects.length} etiket çizildi)',
      );
    }
  }
  for (final r in rects) {
    expect(
      r.left >= -0.5 && r.right <= chartWidth + 0.5,
      isTrue,
      reason: '$label: etiket $r grafik dışına taşıyor (genişlik $chartWidth)',
    );
  }
}

void main() {
  for (final count in [7, 14, 30]) {
    for (final goal in [null, 4 * 3600]) {
      testWidgets(
        'DailyBarChart $count çubuk, hedef ${goal == null ? 'yok' : 'var'}: '
        '360 dp\'de çizilen etiketler kesişmez',
        (tester) async {
          await _pump(
            tester,
            DailyBarChart(days: _series(count), goalSeconds: goal),
          );
          final width = tester.getSize(find.byType(BarChart)).width;
          final rects = _paintedLabelRects(tester);
          // En yüksek gün + bugün her zaman yazılabilmeli; hepsini gizlemek
          // "çakışma yok"u ucuzca sağlar ama bilgiyi yok eder.
          expect(
            rects.length,
            greaterThanOrEqualTo(goal == null ? 1 : 2),
            reason: 'hiç etiket yok',
          );
          _expectNoOverlap(rects, width, '$count gün');
        },
      );
    }
  }

  testWidgets('7 günde yer olan etiketler gizlenmez (en az 4)', (tester) async {
    await _pump(tester, DailyBarChart(days: _series(7)));
    expect(_paintedLabelRects(tester).length, greaterThanOrEqualTo(4));
  });

  testWidgets('MonthlyBarChart 12 dolu ay: etiketler kesişmez', (tester) async {
    final months = [
      for (var i = 0; i < 12; i++)
        MonthTotal(DateTime(2025, 10 + i, 1), (60 + i * 7) * 3600 + 52 * 60),
    ];
    await _pump(tester, MonthlyBarChart(months: months));
    final width = tester.getSize(find.byType(BarChart)).width;
    final rects = _paintedLabelRects(tester);
    expect(rects, isNotEmpty);
    _expectNoOverlap(rects, width, '12 ay');
  });
}
