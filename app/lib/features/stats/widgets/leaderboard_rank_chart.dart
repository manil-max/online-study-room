import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/stats/study_stats.dart';
import 'chart_axis.dart';
import '../../../data/models/daily_stat.dart';
import '../../../data/models/profile.dart';

/// Liderlik geçmişi: **Y ekseni = sıralama (1 en üstte), X ekseni = zaman**.
/// Her üye bir çizgi; kümülatif (biriken) toplama göre günlük sıra — futbol
/// ligi sezon içi sıralama grafiği gibi (WP-203).
///
/// Veri [stats] (per-user-per-gün) üzerinden hesaplanır; ek RPC gerekmez.
class LeaderboardRankChart extends StatelessWidget {
  const LeaderboardRankChart({
    super.key,
    required this.members,
    required this.memberColors,
    required this.stats,
    required this.days,
    this.endDay,
    this.startDay,
    required this.currentUserId,
    required this.emptyLabel,
    required this.namelessLabel,
  });

  final List<Profile> members;
  final Map<String, Color> memberColors;
  final List<DailyStat> stats;
  final int days;

  /// Pencerenin SON günü. Saat bileşeni [dayOf] ile düşer.
  ///
  /// 🔴 WP-747: pencerenin sonu eskiden widget'ın İÇİNDE `DateTime.now()` ile
  /// sabitlenmişti, dışarıdan verilemiyordu. "Geçen ay"a gidildiğinde başlık
  /// geçen ayı yazarken grafik BU ayın sıralama yarışını çiziyordu (aynı
  /// kusurun grup eğilimi grafiğindeki hâli WP-746'da düzeltildi).
  ///
  /// Opsiyoneldir: verilmezse eski davranış (`DateTime.now()`) korunur.
  final DateTime? endDay;

  /// Donemin ILK gunu. Saat bileseni [dayOf] ile duser.
  ///
  /// 🔴 WP-758: [days] pencerenin uzunlugunu tek basina belirliyordu ve
  /// secili donemle hicbir iliskisi yoktu. Iki yonlu bozuluyordu:
  ///
  ///   * **Tasma.** "Hafta" Carsamba gunu UC gunluk bir donemdir; grafik yine 7
  ///     gun ciziyor, GECEN haftanin dort gununu yarisa katiyordu. Hemen
  ///     ustteki "Siralama" listesi o gunleri saymadigi icin iki widget ayni
  ///     soruya farkli cevap veriyordu ("Ozel aralik"ta pencere aralik ne
  ///     olursa olsun sabit 30 gundu — ayni kusurun en gorunur hâli).
  ///   * **Kirpilma.** "Yil" / "Tumu" 30 gunluk bir KUYRUK cizer; kumulatif o
  ///     kuyrugun basinda sifirlandigi icin donemin ilk aylari yok sayiliyordu.
  ///
  /// Verilirse pencere donemin ONUNE tasmaz ve donemden kisa kaldiginda
  /// kumulatif toplam donem basi ile pencere basi arasindaki sureyle
  /// **tohumlanir** — cizilen sira, donemin gercek siralamasidir. Verilmezse
  /// eski davranis (yalnizca [days] gun) korunur.
  final DateTime? startDay;

  final String currentUserId;
  final String emptyLabel;
  final String namelessLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final memberIds = [for (final m in members) m.id];
    final n = memberIds.length;
    if (n == 0) {
      return _empty(theme);
    }

    // Pencere: [endDay] gününde biten en fazla [days] gün (eski → yeni).
    // [endDay] yoksa bugünde biter; [startDay] varsa pencere onun ÖNÜNE taşmaz.
    final end = dayOf(endDay ?? DateTime.now());
    final start = startDay == null ? null : dayOf(startDay!);
    var count = days;
    if (start != null) {
      final span = _daySpanInclusive(start, end);
      if (span < count) count = span;
    }
    if (count < 1) count = 1;
    // 🔴 Gün anahtarı takvim aritmetiğiyle kurulur (`day - i`), `subtract` ile
    // değil: `Duration` mutlak süredir ve yaz saati uygulayan bir cihazda
    // 23/25 saatlik günde gece yarısını ıskalar. Harita anahtarları ise her
    // zaman YEREL gece yarısıdır — kaçan gün sessizce 0 okunurdu.
    final window = [
      for (var i = count - 1; i >= 0; i--)
        DateTime(end.year, end.month, end.day - i),
    ];

    final perMember = {
      for (final id in memberIds) id: userDayTotals(stats, id),
    };
    final indexOf = {
      for (var i = 0; i < memberIds.length; i++) memberIds[i]: i,
    };

    // Kümülatif toplam → her gün sıralama; çizgi noktaları (plottedY: rank1 üstte).
    // Pencere dönemden kısaysa dönem başı ile pencere başı arası TOHUMLANIR.
    final cumulative = {
      for (final id in memberIds)
        id: start == null
            ? 0
            : _sumBetween(perMember[id]!, start, window.first),
    };
    final spotsByMember = {for (final id in memberIds) id: <FlSpot>[]};
    var anyData = cumulative.values.any((v) => v > 0);
    for (var di = 0; di < window.length; di++) {
      final day = window[di];
      for (final id in memberIds) {
        cumulative[id] = cumulative[id]! + (perMember[id]![day] ?? 0);
      }
      if (!anyData && cumulative.values.any((v) => v > 0)) anyData = true;
      final sorted = [...memberIds]
        ..sort((a, b) {
          final c = cumulative[b]!.compareTo(cumulative[a]!);
          if (c != 0) return c;
          return indexOf[a]!.compareTo(indexOf[b]!);
        });
      for (var r = 0; r < sorted.length; r++) {
        final id = sorted[r];
        // rank = r+1; plottedY: rank 1 → n (üst), rank n → 1 (alt).
        spotsByMember[id]!.add(FlSpot(di.toDouble(), (n - r).toDouble()));
      }
    }

    if (!anyData) {
      return _empty(theme);
    }

    String nameFor(Profile m) =>
        m.displayName.isEmpty ? namelessLabel : m.displayName;

    final bars = [
      for (final m in members)
        LineChartBarData(
          spots: spotsByMember[m.id]!,
          isCurved: false,
          color: memberColors[m.id]!,
          barWidth: m.id == currentUserId ? 3.5 : 2,
          dotData: FlDotData(show: window.length <= 14),
        ),
    ];

    final chartHeight = (n * 12 + 70).clamp(140, 300).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend: isim + renk (basılı tutmaya gerek yok).
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final m in members)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 3,
                    decoration: BoxDecoration(
                      color: memberColors[m.id]!,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    m.id == currentUserId ? '${nameFor(m)} •' : nameFor(m),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: m.id == currentUserId
                          ? FontWeight.w700
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: chartHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // WP-237: yer varken her günün numarası (eskiden sabit /4 adım).
              final labelStep = axisLabelStep(
                window.length,
                constraints.maxWidth - 28,
              );
              return LineChart(
                LineChartData(
                  minY: 0.5,
                  maxY: n + 0.5,
                  lineTouchData: const LineTouchData(enabled: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 1,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: scheme.outlineVariant.withValues(alpha: 0.20),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      left: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      bottom: BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 26,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          // plottedY = value → rank = n + 1 - value.
                          final rank = n + 1 - value.round();
                          if (rank < 1 || rank > n) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              '$rank.',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontSize: 9,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 18,
                        getTitlesWidget: (value, meta) {
                          final i = value.round();
                          if (i < 0 || i >= window.length) {
                            return const SizedBox.shrink();
                          }
                          if (i % labelStep != 0 && i != window.length - 1) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${window[i].day}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontSize: 9,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: bars,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// [from, to] (iki uç dâhil) arasındaki gün sayısı.
  ///
  /// 🔴 Fark `difference().inDays` ile ham alınmaz: gün anahtarı cihazın YEREL
  /// gece yarısıdır, yaz saati uygulayan bölgede iki gece yarısının arası 23/25
  /// saattir ve tam bölme 23 saati 0 güne yuvarlar. UTC'de her gün 24 saattir
  /// (aynı tuzağın tanığı `stats_period_provider.dart` `_dayNumber`).
  static int _daySpanInclusive(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day)
          .difference(DateTime.utc(from.year, from.month, from.day))
          .inDays +
      1;

  /// `[from, before)` yarı açık aralığındaki toplam saniye (pencere tohumu).
  static int _sumBetween(
    Map<DateTime, int> dayTotals,
    DateTime from,
    DateTime before,
  ) {
    var sum = 0;
    for (final e in dayTotals.entries) {
      if (e.key.isBefore(from) || !e.key.isBefore(before)) continue;
      sum += e.value;
    }
    return sum;
  }

  Widget _empty(ThemeData theme) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text(
      emptyLabel,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
