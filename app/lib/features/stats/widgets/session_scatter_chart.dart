import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../data/models/study_session.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/subject_providers.dart';
import 'chart_axis.dart';
import 'personal_period_cards.dart';

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

/// Oturum dağılım grafiği (scatter): son [days] gündeki her çalışma oturumu bir
/// nokta — x = gün, y = süre (dk), renk = ders. Noktaya dokununca tarih+süre ipucu.
class SessionScatterChart extends ConsumerWidget {
  const SessionScatterChart({
    super.key,
    required this.sessions,
    this.days = 30,
    this.endDay,
    this.height = 200,
  });

  final List<StudySession> sessions;
  final int days;

  /// Pencerenin **son** günü (dâhil). `null` ise bugün.
  ///
  /// 🔴 WP-765: grafik önceden yalnız pencerenin UZUNLUĞUNU ([days])
  /// biliyordu ve pencereyi daima `DateTime.now()`da bitiriyordu; başlangıç
  /// oradan geriye sayılıyordu. Kişisel sekmede WP-745 bu yüzden `days`i
  /// "dönemin başından BUGÜNE" diye uzatmak zorunda kalmıştı — grafik boş
  /// çıkmıyordu ama eksen dönemden geniş oluyordu. Ölçülen hâl (bugün
  /// 27 Ağustos, "Ay" dönemi offset -1 = Temmuz): eksen 31 değil **58** gün,
  /// alt eksende "1 Tem · 21 Tem · **10 Ağu**" yazıyor (sonuncusu dönemin
  /// dışında) ve bütün noktalar sol yarıya sıkışıyordu. Başlık Temmuz'u,
  /// grafik Temmuz+Ağustos'u anlatıyordu.
  ///
  /// Uç artık dönemin `to`sudur; tek kaynak `StatsPeriodSelection.range()`.
  final DateTime? endDay;

  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final months = _months(context);
    final subjects = ref.watch(userSubjectsProvider).value ?? const <Subject>[];
    final colorBySubject = {for (final s in subjects) s.id: s.color};

    final endKey = dayOf(endDay ?? DateTime.now());
    // 🔴 Takvim aritmetiği: `subtract(Duration(days: …))` kullanılmaz.
    // Gün anahtarı cihazın YEREL gece yarısıdır; yaz saati uygulayan bir
    // bölgede iki gece yarısının arası 23 ya da 25 saattir ve pencere bir gün
    // kayar (aynı tuzağın ölçümü: `personal_period_cards.dart` [statsDayNumber]
    // yorumu). `DateTime` bileşen taşmasını kendisi normalleştirir.
    final startDay = DateTime(
      endKey.year,
      endKey.month,
      endKey.day - (days - 1),
    );
    final startNumber = statsDayNumber(startDay);
    // Üst uç da kırpılır: dönemin SONUNU aşan oturum artık çizilmez.
    final recent = sessions
        .where((s) => !s.day.isBefore(startDay) && !s.day.isAfter(endKey))
        .toList();

    if (recent.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            AppLocalizations.of(context).statsBuDonemdeCalismaKaydin,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    Color colorOf(String? subjectId) {
      final token = colorBySubject[subjectId];
      return token != null
          ? subjectColor(token)
          : theme.colorScheme.onSurfaceVariant;
    }

    var maxMin = 0.0;
    final spots = <ScatterSpot>[];
    for (final s in recent) {
      final x = (statsDayNumber(s.day) - startNumber).toDouble();
      final y = s.durationSeconds / 60;
      if (y > maxMin) maxMin = y;
      spots.add(
        ScatterSpot(
          x,
          y,
          dotPainter: FlDotCirclePainter(
            color: colorOf(s.subjectId).withValues(alpha: 0.85),
            radius: 5,
            strokeWidth: 1,
            strokeColor: theme.colorScheme.surface,
          ),
        ),
      );
    }
    // 🔴 WP-503 (WP-499 yan bulgusu): burada `maxMin * 1.2` vardı ve eksen
    // aralığı ayrıca **hiç verilmiyordu** (`leftTitles`in `interval`i yok,
    // `gridData`nın `horizontalInterval`ı yok) — fl_chart ikisi için de kendi
    // aralığını seçiyor, üstelik üst sınır o aralığın katı olmadığı için
    // tepeye fazladan bir etiket daha koyuyordu. Aynı desen çizgi grafiğinde
    // ölçüldü: en kötü seride iki etiket **22.9 px** üst üste biniyordu.
    // Ortak kural artık `minuteAxis()`: önce aralık, sonra aralığın üst katı.
    final axis = minuteAxis(maxMin);
    final maxY = axis.maxY;

    DateTime dateAt(double x) =>
        DateTime(startDay.year, startDay.month, startDay.day + x.round());
    // Alt eksende ~3-4 tarih etiketi (dar kartta da karışmasın).
    final step = (days / 3).ceilToDouble().clamp(1, days.toDouble()).toDouble();

    return SizedBox(
      height: height,
      child: ScatterChart(
        ScatterChartData(
          scatterSpots: spots,
          minX: -0.5,
          maxX: (days - 1) + 0.5,
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            // Izgara ve etiketler **aynı** aralığı kullanmalı; ikisi ayrı
            // seçilince çizgisiz etiket ve etiketsiz çizgi çıkıyordu.
            horizontalInterval: axis.interval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: axis.interval,
                getTitlesWidget: (value, meta) {
                  // `0` ve sınır dışı değerler çizilmez: taban çizgisinin
                  // üstündeki sıfır ile alt eksen tarihleri çakışıyordu.
                  if (value <= 0 || value > maxY) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    '${value.round()}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
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
                reservedSize: 22,
                interval: step,
                getTitlesWidget: (value, meta) {
                  final i = value.round();
                  if (i < 0 || i > days - 1) return const SizedBox.shrink();
                  if (i % step.round() != 0) return const SizedBox.shrink();
                  // Sağ kenara çok yakın etiketi atla (yığılmasın).
                  if (i != 0 && (days - 1 - i) < step * 0.5) {
                    return const SizedBox.shrink();
                  }
                  final d = dateAt(i.toDouble());
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${d.day} ${months[d.month - 1]}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          scatterTouchData: ScatterTouchData(
            enabled: true,
            touchTooltipData: ScatterTouchTooltipData(
              getTooltipItems: (touchedSpot) {
                final d = dateAt(touchedSpot.x);
                final mins = touchedSpot.y.round();
                final h = mins ~/ 60;
                final m = mins % 60;
                final dur = h > 0 ? '$h sa $m dk' : '$m dk';
                return ScatterTooltipItem(
                  '${d.day} ${months[d.month - 1]}\n$dur',
                  textStyle: TextStyle(
                    color: theme.colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
