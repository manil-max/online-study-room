import 'package:flutter/widgets.dart';

/// WP-924: çubuk grafiklerde hangi çubuğun üstüne **kalıcı** süre etiketi
/// yazılacağını seçer.
///
/// 🔴 ÖLÇÜLEN KUSUR: [DailyBarChart] her dolu çubuğa `showingTooltipIndicators`
/// ile etiket basıyordu. 360 dp telefonda 14 günlük seride iki çubuk merkezi
/// arası ~23 px, "4sa 32dk" etiketi ~40 px — yazılar birbirinin içine
/// giriyordu (istatistik "Günlük dağılım" 14/30 gün, Ana Sayfa "Çalışma
/// grafiği", "Grup günlük trendi"; mağaza görsellerinde de görünüyordu).
/// 7 günde bile ilk etiket "Hedef" yazısıyla çakışıyor, uçtaki etiketler kart
/// kenarından taşıyordu.
///
/// Kural: etiketler öncelik sırasıyla yerleştirilir ve daha önce kabul edilmiş
/// bir dikdörtgenle (ya da [reserved] ile, ör. "Hedef" yazısı) kesişen etiket
/// **çizilmez** — o çubuğun değeri dokununca görünür (fl_chart dokunma
/// balonu). Öncelik: en yüksek çubuk → en yeni dolu çubuk (bugün / içinde
/// bulunulan dönem) → [keyBarsOnly] değilse kalanlar büyükten küçüğe.
///
/// Geometri fl_chart 1.2'nin kendisidir (`BarChartAlignment.spaceBetween`,
/// `bar_chart_data_extension.dart` `calculateGroupsX`; balon yerleşimi
/// `bar_chart_painter.dart` `drawTouchTooltip`, `fitInsideHorizontally`):
/// - çubuk merkezi `w/2 + i·(W − w)/(n − 1)`,
/// - etiketin altı çubuk tepesinin [tooltipMargin] üstü,
/// - yatayda grafiğin içine kaydırılmış.
///
/// Testi (`bar_label_overlap_wp924_test.dart`) bu hesabı değil, **çizilen**
/// paragrafları ölçer; burada bir kayma olursa test kırmızıya döner.
Set<int> pickBarValueLabels({
  required List<Size?> labelSizes,
  required List<double> values,
  required double maxY,
  required double barWidth,
  required Size chartSize,
  double tooltipMargin = 2,
  List<Rect> reserved = const [],
  bool keyBarsOnly = false,
  double gap = 4,
}) {
  final n = labelSizes.length;
  if (n == 0 ||
      maxY <= 0 ||
      !chartSize.isFinite ||
      chartSize.width <= 0 ||
      chartSize.height <= 0) {
    return const {};
  }
  final width = chartSize.width;
  final height = chartSize.height;
  final step = n > 1 ? (width - barWidth) / (n - 1) : 0.0;

  Rect? rectOf(int i) {
    final size = labelSizes[i];
    if (size == null) return null;
    final center = barWidth / 2 + i * step;
    var left = center - size.width / 2;
    if (left + size.width > width) left = width - size.width;
    if (left < 0) left = 0;
    final barTop = height - (values[i] / maxY) * height;
    final bottom = barTop - tooltipMargin;
    return Rect.fromLTRB(left, bottom - size.height, left + size.width, bottom);
  }

  final candidates = [
    for (var i = 0; i < n; i++)
      if (labelSizes[i] != null) i,
  ];
  if (candidates.isEmpty) return const {};

  // En yüksek çubuk (eşitlikte en yenisi), sonra son çubuk, sonra kalanlar.
  final byValue = [...candidates]
    ..sort((a, b) {
      final c = values[b].compareTo(values[a]);
      return c != 0 ? c : b.compareTo(a);
    });
  // "Son" = en yeni DOLU çubuk (bugün). Dönem grafiğinde (WP-925) bugünden
  // sonraki günler boş çubuktur; son indeks o boş gün olurdu ve bugünün
  // etiketi hiç aday olmazdı.
  final order = <int>[byValue.first];
  final last = candidates.last;
  if (!order.contains(last)) order.add(last);
  if (!keyBarsOnly) {
    for (final i in byValue) {
      if (!order.contains(i)) order.add(i);
    }
  }

  final taken = <Rect>[for (final r in reserved) r.inflate(gap / 2)];
  final chosen = <int>{};
  for (final i in order) {
    final rect = rectOf(i);
    if (rect == null) continue;
    final padded = rect.inflate(gap / 2);
    if (taken.any((t) => t.overlaps(padded))) continue;
    taken.add(padded);
    chosen.add(i);
  }
  return chosen;
}

/// [text]in [style] ve [textScaler] ile çizildiğindeki boyutu.
///
/// fl_chart balon/çizgi etiketini `DefaultTextStyle` üzerine birleştirerek
/// çizer (`Utils.getThemeAwareTextStyle`); ölçü de aynı birleşimle alınır.
Size measureChartLabel(
  BuildContext context,
  String text,
  TextStyle? style, {
  TextStyle? base,
}) {
  final merged = DefaultTextStyle.of(
    context,
  ).style.merge(base == null ? style : base.merge(style));
  final painter = TextPainter(
    text: TextSpan(text: text, style: merged),
    textDirection: TextDirection.ltr,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final size = painter.size;
  painter.dispose();
  return size;
}
