import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/utils/duration_format.dart';
import 'bar_value_labels.dart';
import 'chart_axis.dart';

List<String> _months(BuildContext context) => [
  AppLocalizations.of(context).statsOca,
  AppLocalizations.of(context).statsSub,
  AppLocalizations.of(context).statsMar,
  AppLocalizations.of(context).statsNis,
  AppLocalizations.of(context).statsMay,
  AppLocalizations.of(context).statsHaz,
  AppLocalizations.of(context).statsTem,
  AppLocalizations.of(context).statsAgu,
  AppLocalizations.of(context).statsEyl,
  AppLocalizations.of(context).statsEki,
  AppLocalizations.of(context).statsKas,
  AppLocalizations.of(context).statsAra,
];

/// Kısa süre etiketi (çubuk üstü): "1s 30d", "45d", "" (boş gün).
String _short(AppLocalizations l10n, int seconds) {
  if (seconds <= 0) return '';
  return formatHuman(seconds);
}

/// Günlük çalışma süresi çubuk grafiği (y: dakika). Süre çubuğun üstünde —
/// **yer varsa** (WP-924, [pickBarValueLabels]); sığmayan çubuğun süresi
/// dokununca görünür. Alt eksende gün numarası, ay değişince ay adı.
/// [goalSeconds] verilirse günlük hedef **kesikli çizgiyle** gösterilir; hedefi
/// tutturan günler renkli, tutmayanlar gri çizilir.
class DailyBarChart extends StatelessWidget {
  const DailyBarChart({super.key, required this.days, this.goalSeconds});

  final List<DayTotal> days;
  final int? goalSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = _months(context);
    final hasGoal = goalSeconds != null && goalSeconds! > 0;
    final goalMin = hasGoal ? goalSeconds! / 60 : 0.0;
    final maxSeconds = days.fold<int>(
      0,
      (m, d) => d.seconds > m ? d.seconds : m,
    );
    final maxMinutes = maxSeconds / 60;
    var maxY = maxMinutes <= 0 ? 60.0 : maxMinutes * 1.32;
    if (hasGoal && goalMin * 1.12 > maxY) maxY = goalMin * 1.12;
    final dense = days.length > 10;
    final barWidth = dense ? 8.0 : 16.0;
    // Alt eksen etiketlerine ayrılan yükseklik; çubuk alanı bunun üstüdür.
    const bottomReserved = 40.0;
    final valueLabelStyle = theme.textTheme.labelSmall!.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w700,
      fontSize: dense ? 9 : 11,
    );
    final goalLabelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.secondary,
      fontWeight: FontWeight.w700,
    );
    final goalLabelText = AppLocalizations.of(context).statsHedef;

    final reachedColor = theme.colorScheme.primary;
    final missedColor = theme.colorScheme.onSurfaceVariant.withValues(
      alpha: 0.5,
    );

    Color barColor(int seconds) {
      if (!hasGoal) return reachedColor;
      return seconds >= goalSeconds! ? reachedColor : missedColor;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // WP-313: gün numarası **her sütunda** yazılır; ay adı yalnız ay
        // değiştiğinde (ve ilk sütunda) görünür. Eskiden ay adı her etikette
        // olduğu için ~26 px yer varsayılıyor, 14 günlük seride adım 2'ye
        // çıkıyor ve tarihler gün aşırı yazılıyordu. Tek satır gün numarası
        // ~14 px'e sığar → 7/14 günde adım 1.
        final labelStep = axisLabelStep(
          days.length,
          constraints.maxWidth,
          labelWidth: 14,
        );
        // WP-924: kalıcı süre etiketi yalnız komşusuna ve "Hedef" yazısına
        // değmeyen çubuklarda. 10 günden uzun seride yalnız en yüksek gün ve
        // bugün yazılır; diğerleri dokununca.
        final chartSize = Size(
          constraints.maxWidth,
          constraints.maxHeight - bottomReserved,
        );
        final l10n = AppLocalizations.of(context);
        final labelSizes = <Size?>[
          for (final d in days)
            d.seconds > 0
                ? measureChartLabel(
                    context,
                    _short(l10n, d.seconds),
                    valueLabelStyle,
                  )
                : null,
        ];
        final reserved = <Rect>[];
        if (hasGoal && chartSize.height > 0) {
          final size = measureChartLabel(
            context,
            goalLabelText,
            goalLabelStyle,
            // fl_chart çizgi etiketinin taban stili (`drawHorizontalLines`).
            base: TextStyle(fontSize: 11, color: theme.colorScheme.secondary),
          );
          final goalY = chartSize.height - (goalMin / maxY) * chartSize.height;
          reserved.add(
            Rect.fromLTWH(2, goalY - 1 - size.height, size.width, size.height),
          );
        }
        final labelled = pickBarValueLabels(
          labelSizes: labelSizes,
          values: [for (final d in days) d.seconds / 60],
          maxY: maxY,
          barWidth: barWidth,
          chartSize: chartSize,
          reserved: reserved,
          keyBarsOnly: dense,
        );
        return BarChart(
          BarChartData(
            maxY: maxY,
            alignment: BarChartAlignment.spaceBetween,
            extraLinesData: ExtraLinesData(
              horizontalLines: [
                if (hasGoal)
                  HorizontalLine(
                    y: goalMin,
                    color: theme.colorScheme.secondary,
                    strokeWidth: 1.5,
                    dashArray: const [6, 4],
                    label: HorizontalLineLabel(
                      show: true,
                      // Sol üstte: sağdaki çubuk/etiketlerle çakışmasın.
                      alignment: Alignment.topLeft,
                      padding: const EdgeInsets.only(left: 2, bottom: 1),
                      style: goalLabelStyle,
                      labelResolver: (_) => goalLabelText,
                    ),
                  ),
              ],
            ),
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipColor: (_) => Colors.transparent,
                tooltipPadding: EdgeInsets.zero,
                tooltipMargin: 2,
                // Uçtaki etiket kart kenarından taşmasın; seçim hesabı da bu
                // kaydırmayı varsayar ([pickBarValueLabels]).
                fitInsideHorizontally: true,
                getTooltipItem: (group, _, rod, _) {
                  final label = _short(l10n, days[group.x].seconds);
                  if (label.isEmpty) return null;
                  return BarTooltipItem(label, valueLabelStyle);
                },
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= days.length) {
                      return const SizedBox.shrink();
                    }
                    if (i % labelStep != 0 && i != days.length - 1) {
                      return const SizedBox.shrink();
                    }
                    final d = days[i].day;
                    // Ay adı yalnız ilk sütunda ve ay değiştiğinde. İkinci
                    // satır her zaman **çizilir** (gerekmediğinde boş metin)
                    // ki etiketlerin taban hizası bozulmasın.
                    final showMonth =
                        i == 0 || days[i - 1].day.month != d.month;
                    return Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${d.day}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w600,
                              height: 1.1,
                            ),
                          ),
                          Text(
                            showMonth ? months[d.month - 1] : '',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 9,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            barGroups: [
              for (var i = 0; i < days.length; i++)
                BarChartGroupData(
                  x: i,
                  showingTooltipIndicators: labelled.contains(i)
                      ? const [0]
                      : const [],
                  barRods: [
                    BarChartRodData(
                      toY: days[i].seconds / 60,
                      color: barColor(days[i].seconds),
                      width: barWidth,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(3),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
