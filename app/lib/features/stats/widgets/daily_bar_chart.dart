import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/utils/duration_format.dart';
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

/// Günlük çalışma süresi çubuk grafiği (y: dakika). Süre **her zaman** çubuğun
/// üstünde; alt eksende tarih ay adıyla ("21 Haz"). [goalSeconds] verilirse günlük
/// hedef **kesikli çizgiyle** gösterilir; hedefi tutturan günler renkli, tutmayanlar
/// gri çizilir.
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
        // WP-237: yer varken her günün numarası (eskiden dense'te her 3 gün).
        // Gün+ay iki satır olduğu için etiket ~26px yer kaplar.
        final labelStep = axisLabelStep(
          days.length,
          constraints.maxWidth,
          labelWidth: 26,
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
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                      labelResolver: (_) =>
                          AppLocalizations.of(context).statsHedef,
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
                getTooltipItem: (group, _, rod, _) {
                  final label = _short(
                    AppLocalizations.of(context),
                    days[group.x].seconds,
                  );
                  if (label.isEmpty) return null;
                  return BarTooltipItem(
                    label,
                    theme.textTheme.labelSmall!.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                      fontSize: dense ? 9 : 11,
                    ),
                  );
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
                            months[d.month - 1],
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
                  showingTooltipIndicators: days[i].seconds > 0
                      ? const [0]
                      : const [],
                  barRods: [
                    BarChartRodData(
                      toY: days[i].seconds / 60,
                      color: barColor(days[i].seconds),
                      width: dense ? 8 : 16,
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
