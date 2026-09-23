import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/data/models/daily_stat.dart';
import 'package:online_study_room/data/models/profile.dart';
import 'package:online_study_room/features/stats/charts/area_line_chart.dart';
import 'package:online_study_room/features/stats/widgets/daily_bar_chart.dart';
import 'package:online_study_room/features/stats/widgets/daily_line_chart.dart';
import 'package:online_study_room/features/stats/widgets/leaderboard_rank_chart.dart';
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

/// Ekranda çizilen, [labels] kümesindeki metinlerin dikdörtgenleri.
List<(String, Rect)> _axisTexts(WidgetTester tester, Set<String> labels) {
  final out = <(String, Rect)>[];
  for (final element in find.byType(Text).evaluate()) {
    final text = (element.widget as Text).data;
    if (text == null || !labels.contains(text)) continue;
    out.add((
      text,
      tester.getRect(find.byElementPredicate((e) => e == element)),
    ));
  }
  return out;
}

void _expectAxisClean(List<(String, Rect)> texts, Rect bounds, String label) {
  final names = [for (final t in texts) t.$1];
  expect(names.toSet(), hasLength(names.length), reason: '$label: $names');
  for (var a = 0; a < texts.length; a++) {
    for (var b = a + 1; b < texts.length; b++) {
      final o = texts[a].$2.intersect(texts[b].$2);
      expect(
        o.width > 0.5 && o.height > 0.5,
        isFalse,
        reason:
            '$label: "${texts[a].$1}" ${texts[a].$2} ile "${texts[b].$1}" ${texts[b].$2} üst üste',
      );
    }
  }
  for (final t in texts) {
    expect(
      t.$2.left >= bounds.left - 0.5 && t.$2.right <= bounds.right + 0.5,
      isTrue,
      reason: '$label: "${t.$1}" ${t.$2} grafik dışına taşıyor ($bounds)',
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

  // ---- Eksen etiketleri (WP-924 ek: yeniden çizimde görüldü) --------------

  testWidgets('DailyBarChart 30 gün: son gün yazılır, ona yapışık hizalı '
      'gün yazılmaz ("2930" yok)', (tester) async {
    // Test yazı tipi her glifi 1 em çizer (gerçek fonttan ~2 kat geniş); bu
    // yüzden iddia geometrik değil yapısaldır: 30 günde adım 2, hizalı son
    // gün 29 (indeks 28) son gün 30'un hemen yanıdır ve çizilmemelidir.
    final days = [
      for (var i = 0; i < 30; i++)
        DayTotal(DateTime(2026, 9, 1 + i), i < 23 ? 3600 : 0),
    ];
    await _pump(tester, DailyBarChart(days: days));
    expect(find.text('30'), findsOneWidget);
    expect(find.text('29'), findsNothing);
    expect(find.text('27'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('DailyBarChart ay görünümü: bugünün (son dolu gün) süresi '
      'yazılır, arkada boş günler olsa da', (tester) async {
    // 1–30 Eylül, 24'ünden sonrası gelecek (0). Eskiden "son çubuk" 30
    // Eylül sayıldığı için bugünün etiketi hiç aday olmuyordu.
    final days = [
      for (var i = 0; i < 30; i++)
        DayTotal(
          DateTime(2026, 9, 1 + i),
          i < 23 ? 4 * 3600 + i * 60 : (i == 23 ? 24 * 60 : 0),
        ),
    ];
    await _pump(tester, DailyBarChart(days: days, goalSeconds: 4 * 3600));
    final chart = tester.widget<BarChart>(find.byType(BarChart));
    final shown = [
      for (final g in chart.data.barGroups)
        if (g.showingTooltipIndicators.isNotEmpty) g.x,
    ];
    expect(shown, contains(23), reason: 'bugünün (24 Eyl) etiketi yok: $shown');
    expect(shown, contains(22), reason: 'en yüksek gün etiketi yok: $shown');
  });

  for (final n in [4, 12, 23, 39]) {
    testWidgets('AreaLineChart $n nokta: X etiketleri tekil, çakışmaz, '
        'grafik içinde', (tester) async {
      final labels = [
        for (var i = 0; i < n; i++)
          '${DateTime(2026, 1, 1 + 7 * i).day}/${DateTime(2026, 1, 1 + 7 * i).month}',
      ];
      await _pump(
        tester,
        AreaLineChart(
          values: [for (var i = 0; i < n; i++) (i % 5) + 1.0],
          labels: labels,
          yUnit: 'sa',
        ),
      );
      final texts = _axisTexts(tester, labels.toSet());
      expect(texts.map((t) => t.$1), contains(labels.last));
      _expectAxisClean(
        texts,
        tester.getRect(find.byType(AreaLineChart)),
        '$n nokta',
      );
    });
  }

  testWidgets('LeaderboardRankChart 4 günlük pencere: gün numarası bir kez '
      '("21 22 22 23 23 24 24" değil)', (tester) async {
    final members = [
      Profile(id: 'a', displayName: 'Ada', createdAt: DateTime(2026)),
      Profile(id: 'b', displayName: 'Bora', createdAt: DateTime(2026)),
    ];
    await _pump(
      tester,
      LeaderboardRankChart(
        members: members,
        memberColors: const {'a': Colors.red, 'b': Colors.blue},
        stats: [
          for (var d = 21; d <= 24; d++) ...[
            DailyStat(userId: 'a', day: DateTime(2026, 9, d), seconds: 3600),
            DailyStat(
              userId: 'b',
              day: DateTime(2026, 9, d),
              seconds: 1800 * d % 7200,
            ),
          ],
        ],
        days: 7,
        startDay: DateTime(2026, 9, 21),
        endDay: DateTime(2026, 9, 24),
        currentUserId: 'a',
        emptyLabel: '-',
        namelessLabel: '?',
      ),
    );
    final texts = _axisTexts(tester, {'21', '22', '23', '24'});
    expect(texts, hasLength(4), reason: '${texts.map((t) => t.$1)}');
    _expectAxisClean(
      texts,
      tester.getRect(find.byType(LeaderboardRankChart)),
      'sıralama geçmişi',
    );
  });

  for (final n in [3, 4, 7]) {
    testWidgets('DailyLineChart $n gün (grup eğilimi): gün numarası bir kez '
        '("21 21 22 22" değil)', (tester) async {
      final days = [
        for (var i = 0; i < n; i++)
          DayTotal(DateTime(2026, 9, 21 + i), 3600 * (i + 1)),
      ];
      await _pump(tester, DailyLineChart(days: days));
      final labels = {for (final d in days) '${d.day.day}'};
      final texts = _axisTexts(tester, labels);
      expect(texts, hasLength(n), reason: '${texts.map((t) => t.$1)}');
      _expectAxisClean(
        texts,
        tester.getRect(find.byType(DailyLineChart)).inflate(8),
        '$n gün çizgi',
      );
    });
  }
}
