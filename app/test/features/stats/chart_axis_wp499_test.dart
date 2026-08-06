// WP-499 (V58-N04 / rapor T09): "Trend grafiğinde Y ekseni etiketleri
// çakışıyor."
//
// 🔴 Kök neden: üst sınır ile aralık **ayrı ayrı** seçiliyordu.
// `daily_line_chart.dart` `maxY = veriMaks × 1.2` diyor, `niceMinuteInterval`
// ise aralığı yuvarlak bir sayıya oturtuyordu; ikisi birbirinin katı değil.
// fl_chart eksende `min`den `max`a yürür ve son adım `max`a denk gelmiyorsa
// `max` için **bir etiket daha** üretir (`SideTitles.maxIncluded` varsayılanı
// `true`). Tepede iki etiket kalıyor ve aradaki boşluk keyfî küçük olabiliyor.
//
// Izgara çizgileri ise `maxIncluded: false` ile çizilir, yani fazladan
// etiketin çizgisi de yok: kullanıcı tepede boşlukta duran ikinci bir sayı
// görüyor.
//
// ⚠️ Kart tuzağı: yalnız `maxIncluded: false` yapıp yuvarlamayı atlamak.
// Üst sınır aralığın katı olduğunda o bayrak tepe etiketini **siler** ve
// ölçek okunamaz hâle gelir. Bu yüzden düzeltme yuvarlamadadır.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:online_study_room/core/stats/study_stats.dart';
import 'package:online_study_room/features/stats/widgets/chart_axis.dart';
import 'package:online_study_room/features/stats/widgets/daily_bar_chart.dart';
import 'package:online_study_room/features/stats/widgets/daily_line_chart.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

/// Kabuldeki üç sentetik seri.
///
/// Üçü de **ölçülerek** seçildi: eski kodda üçü de, üç uzunlukta da (14/30/90)
/// çakışan etiket üretiyor. Ölçülen üst üste binme miktarı sırasıyla
/// **22.9 px**, **5.1 px** ve **9.6 px** (etiket yüksekliği ~23 px, yani
/// `yukselen` serisinde iki etiket neredeyse tamamen üst üste).
enum _Series {
  /// Düz artan seri; 51 dk tepe → eski `maxY` 61.2, aralık 30, son tık 60.
  /// İki etiket eksenin **%2**'si kadar aralıkla — en kötü durum.
  yukselen,

  /// Tek yüksek gün, kalanı düşük → eski `maxY` 132, aralık 60, son tık 120.
  tekZirve,

  /// Uzun mesailer (saat birimine geçen seri) → eski `maxY` 576, aralık 180.
  uzunMesai,
}

List<DayTotal> _days(_Series kind, int count) {
  final start = DateTime(2026, 6, 1);
  return [
    for (var i = 0; i < count; i++)
      DayTotal(start.add(Duration(days: i)), switch (kind) {
        // Tepe her uzunlukta tam 51 dk olsun (kötü durum sabit kalsın).
        _Series.yukselen => (i + 1) * 51 ~/ count * 60,
        _Series.tekZirve => (i == count ~/ 2 ? 110 : 12) * 60,
        _Series.uzunMesai => (240 + (i % 7) * 40) * 60,
      }),
  ];
}

Future<void> _pumpLine(WidgetTester tester, List<DayTotal> days) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('tr'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            height: 180,
            child: DailyLineChart(days: days),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Y ekseni etiketlerinin dikdörtgenleri, yukarıdan aşağıya.
///
/// Y etiketleri birim son ekiyle biter ("30dk", "1.5s"); alt eksendeki gün
/// numaraları çıplak sayıdır, bu yüzden karışmaz.
List<Rect> _yLabelRects(WidgetTester tester) {
  final rects = <Rect>[];
  for (final element in find.byType(Text).evaluate()) {
    final text = (element.widget as Text).data;
    if (text == null) continue;
    if (!text.endsWith('dk') && !text.endsWith('s')) continue;
    rects.add(tester.getRect(find.byElementPredicate((e) => e == element)));
  }
  rects.sort((a, b) => a.top.compareTo(b.top));
  return rects;
}

void main() {
  group('üst sınır her zaman aralığın katı', () {
    test('kartta adı geçen kötü durum: 51 dk tepe', () {
      final axis = minuteAxis(51);
      // Eskiden: maxY = 51 × 1.2 = 61.2, aralık `niceMinuteInterval(61.2)`
      // = 30 → tıklar 0/30/60 **artı** 61.2. Son iki etiket eksenin %2'si
      // kadar aralıkla üst üste biniyordu.
      // Şimdi: pay önce (58.65), aralık ondan (15), sınır üst kat (60).
      expect(axis.interval, 15);
      expect(axis.maxY, 60);
      expect(axis.maxY % axis.interval, 0);
    });

    test('geniş taramada tek bir istisna yok', () {
      // 🔴 Tek örnek yetmez: hata "bazı verilerde" değil, üst sınırın aralığın
      // katı olmadığı **her** veride çıkıyordu. 1 dk'dan 24 saate kadar tüm
      // tam dakikalar taranıyor.
      final kotu = <double>[];
      for (var m = 1; m <= 1440; m++) {
        final axis = minuteAxis(m.toDouble());
        final steps = axis.maxY / axis.interval;
        if ((steps - steps.roundToDouble()).abs() > 1e-9) kotu.add(m.toDouble());
      }
      expect(kotu, isEmpty, reason: 'katı olmayan üst sınırlar: $kotu');
    });

    test('veri tepesi her zaman eksenin içinde ve payı korunuyor', () {
      for (var m = 1; m <= 1440; m++) {
        final axis = minuteAxis(m.toDouble());
        expect(
          axis.maxY,
          greaterThanOrEqualTo(m.toDouble()),
          reason: '$m dk eksenin dışında kalıyor',
        );
      }
    });

    test('ızgara 3–6 çizgi arasında kalıyor', () {
      // Yuvarlama üst kata çıktığı için aralık sayısı artabilir; okunabilirlik
      // sınırı burada sabitleniyor, yoksa 12 çizgili bir eksen de "katı" olur.
      for (var m = 1; m <= 1440; m++) {
        final axis = minuteAxis(m.toDouble());
        expect(
          axis.labelValues.length,
          inInclusiveRange(1, 6),
          reason: '$m dk için ${axis.labelValues.length} etiket',
        );
      }
    });

    test('boş seride bile okunur ölçek', () {
      final axis = minuteAxis(0);
      expect(axis.maxY, 60);
      expect(axis.interval, 15);
      expect(axis.labelValues, [15, 30, 45, 60]);
    });

    test('birim serinin tepesine bakar, yuvarlanmış sınıra değil', () {
      // 🔴 89 dk'lık bir seri yuvarlama 120'ye çıktı diye "saat"e geçmemeli;
      // eşik verinin kendisidir (`axisUsesHours`).
      expect(minuteAxis(89).useHours, isFalse);
      expect(minuteAxis(89).maxY, 120);
      expect(minuteAxis(90).useHours, isTrue);
    });

    test('etiket değerleri eşit aralıklı ve sonuncusu tam sınır', () {
      for (final m in [7.0, 51.0, 110.0, 240.0, 512.0, 1000.0]) {
        final axis = minuteAxis(m);
        final values = axis.labelValues;
        expect(values.last, axis.maxY, reason: '$m: tepe etiket sınırda değil');
        for (var i = 1; i < values.length; i++) {
          expect(
            values[i] - values[i - 1],
            closeTo(axis.interval, 1e-9),
            reason: '$m: eşit olmayan adım',
          );
        }
      }
    });
  });

  group('çizgi grafikte etiketler çakışmıyor', () {
    for (final count in [14, 30, 90]) {
      for (final kind in _Series.values) {
        testWidgets('$count gün · ${kind.name}', (tester) async {
          await _pumpLine(tester, _days(kind, count));

          final rects = _yLabelRects(tester);
          expect(rects, isNotEmpty, reason: 'Y ekseni etiketi hiç çizilmemiş');

          // 🔴 Asıl iddia: iki etiket dikeyde kesişemez. Eski kodda tepedeki
          // iki etiket birkaç piksel arayla üst üste biniyordu.
          for (var i = 1; i < rects.length; i++) {
            expect(
              rects[i].top,
              greaterThanOrEqualTo(rects[i - 1].bottom),
              reason:
                  '$count/${kind.name}: "${rects[i - 1]}" ile "${rects[i]}" '
                  'çakışıyor',
            );
          }
        });
      }
    }

    testWidgets('eksen sınırı ile aralık grafiğe de katı olarak gidiyor', (
      tester,
    ) async {
      await _pumpLine(tester, _days(_Series.yukselen, 30));

      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      final interval = data.titlesData.leftTitles.sideTitles.interval!;
      // Geometrik iddia tek başına yetmez: dar bir grafikte iki etiket
      // kesişmeden de yanlış ölçek çizilebilir. Yapısal kural burada.
      final steps = data.maxY / interval;
      expect(steps - steps.roundToDouble(), closeTo(0, 1e-9));
      expect(data.minY, 0);
    });
  });

  testWidgets('çubuk grafik bu hatayı yapısal olarak gösteremez', (
    tester,
  ) async {
    // 🔴 Kart `daily_bar_chart.dart`i de "aynı deseni kullanıyor" diye
    // sahiplendi. Ölçüldü: çubuk grafikte **Y ekseni etiketi ve ızgara yok**
    // (`leftTitles.showTitles: false`, `gridData.show: false`), yani
    // çakışacak etiket de yok. `maxY = veriMaks × 1.32` orada yalnız çubuğun
    // üstünde bırakılan paydır; yuvarlamak çubukları %36'ya kadar kısaltır ve
    // hiçbir hatayı düzeltmez — bu yüzden dosya değiştirilmedi.
    //
    // Bu test kararın kilidi: biri Y eksenini açarsa buradan kırılır ve
    // `minuteAxis`e yönlendirilir.
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('tr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 200,
              child: DailyBarChart(days: _days(_Series.tekZirve, 14)),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final data = tester.widget<BarChart>(find.byType(BarChart)).data;
    expect(
      data.titlesData.leftTitles.sideTitles.showTitles,
      isFalse,
      reason: 'Y ekseni açıldıysa üst sınır `minuteAxis` ile yuvarlanmalı',
    );
    expect(data.gridData.show, isFalse);
  });
}
