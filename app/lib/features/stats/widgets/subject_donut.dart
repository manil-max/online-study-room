import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/duration_format.dart';

/// Donut grafiğinde bir dilim (ders bazında dağılım için).
class SubjectDonutSlice {
  const SubjectDonutSlice({
    required this.label,
    required this.color,
    required this.seconds,
  });

  final String label;
  final Color color;
  final int seconds;
}

/// Ders bazında dağılımı donut (halka) grafikle gösterir. Etkileşimli: bir dilime
/// dokununca o dilim büyür ve ortada o dersin adı + süresi/yüzdesi görünür; aksi
/// hâlde ortada toplam saat durur (§3.11).
class SubjectDonut extends StatefulWidget {
  const SubjectDonut({super.key, required this.slices, this.size = 140});

  final List<SubjectDonutSlice> slices;
  final double size;

  @override
  State<SubjectDonut> createState() => _SubjectDonutState();
}

class _SubjectDonutState extends State<SubjectDonut> {
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = widget.size;
    final total = widget.slices.fold<int>(0, (s, e) => s + e.seconds);
    final active = _touched >= 0 && _touched < widget.slices.length
        ? widget.slices[_touched]
        : null;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: size * 0.30,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        response?.touchedSection == null) {
                      _touched = -1;
                      return;
                    }
                    _touched = response!.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              sections: [
                for (var i = 0; i < widget.slices.length; i++)
                  PieChartSectionData(
                    value: widget.slices[i].seconds.toDouble(),
                    color: widget.slices[i].color,
                    // Dokunulan dilim biraz büyür (geri bildirim).
                    radius: size * (i == _touched ? 0.21 : 0.17),
                    showTitle: false,
                  ),
              ],
            ),
          ),
          // Ortadaki bilgi: dokunulan dilim varsa onun adı + süresi/yüzdesi.
          Column(
            mainAxisSize: MainAxisSize.min,
            children: active == null
                ? [
                    Text(
                      NumberFormat.decimalPatternDigits(
                        locale: AppLocalizations.of(context).localeName,
                        decimalDigits: 1,
                      ).format(total / 3600),
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      AppLocalizations.of(context).statsSaat,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ]
                : [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        active.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      formatHuman(active.seconds),
                      style: theme.textTheme.labelSmall,
                    ),
                    Text(
                      '%${total == 0 ? 0 : (active.seconds * 100 / total).round()}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}
