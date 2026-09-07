import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/study_session.dart';

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

/// GitHub tarzı çalışma yoğunluğu ısı haritası (yalnızca görsel — başlık/Card
/// çağıran tarafta). Sütunlar haftaları, satırlar haftanın günlerini gösterir;
/// renk koyuluğu o günkü süreyle artar. Her hücre dokunulabilir (tarih + süre).
class StudyHeatmap extends StatelessWidget {
  const StudyHeatmap({
    super.key,
    required this.sessions,
    this.weeks = 15,
    this.precomputedTotals,
  });

  final List<StudySession> sessions;
  final int weeks;

  /// Çağıran zaten `dailyTotals(sessions)` hesapladıysa buradan geçirir.
  final Map<DateTime, int>? precomputedTotals;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final months = _months(context);
    final totals = precomputedTotals ?? dailyTotals(sessions);
    final maxSeconds = totals.values.fold<int>(0, (m, v) => v > m ? v : m);

    final today = dayOf(DateTime.now());
    final firstMonday = startOfWeek(
      today,
    ).subtract(Duration(days: (weeks - 1) * 7));

    const cell = 13.0;
    const gap = 3.0;

    int levelOf(int seconds) {
      if (seconds <= 0) return 0;
      if (maxSeconds <= 0) return 1;
      final r = seconds / maxSeconds;
      if (r <= 0.25) return 1;
      if (r <= 0.5) return 2;
      if (r <= 0.75) return 3;
      return 4;
    }

    Color colorFor(int level) {
      if (level == 0) return theme.colorScheme.surfaceContainerHighest;
      const alphas = [0.25, 0.45, 0.7, 1.0];
      return theme.colorScheme.primary.withValues(alpha: alphas[level - 1]);
    }

    // Ay etiketi yuvası. Sabit 14 dp idi: %130 metin ölçeğinde `labelSmall`
    // yuvayı aşıp altındaki hücrelerin üstüne biniyordu. Yükseklik artık
    // gerçek metin ölçeğinden ÖLÇÜLÜR. Değer tüm sütunlar için TEK olmak
    // zorunda: ay yazan sütun diğerlerinden yüksek olursa hücre satırları
    // birbirinden kayar ve ızgara bozulur.
    // `height: 1.2` sıkı ama güvenli satır kutusu: varsayılan 1.45 satır
    // kutusu 11 dp yazıyı ölçeksiz hâlde bile 14 dp yuvadan taşırıyordu.
    // 1.2, tipik font yükseklik+alçaklığının (≈1.17 em) üstünde kalır, yani
    // "Eyl"in y kuyruğu kesilmez; ölçeksiz yuva 13.2 → 14'te sabit kalır ve
    // kartın yüksekliği DEĞİŞMEZ (kart-içi kaydırma çıtası buna bakıyor).
    final monthStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.2,
    );
    final monthProbe = TextPainter(
      text: TextSpan(text: months.first, style: monthStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final monthSlot = monthProbe.height < 14.0 ? 14.0 : monthProbe.height;
    monthProbe.dispose();

    final columns = <Widget>[];
    var prevMonth = -1;
    for (var w = 0; w < weeks; w++) {
      final weekStart = firstMonday.add(Duration(days: w * 7));
      final showMonth = weekStart.month != prevMonth;
      prevMonth = weekStart.month;

      final cells = <Widget>[];
      for (var d = 0; d < 7; d++) {
        final day = weekStart.add(Duration(days: d));
        final isFuture = day.isAfter(today);
        final seconds = totals[day] ?? 0;
        cells.add(
          Padding(
            padding: const EdgeInsets.only(bottom: gap),
            child: isFuture
                ? const SizedBox(width: cell, height: cell)
                : Tooltip(
                    message:
                        '${day.day} ${months[day.month - 1]} · ${formatHuman(seconds)}',
                    waitDuration: Duration.zero,
                    child: Container(
                      width: cell,
                      height: cell,
                      decoration: BoxDecoration(
                        color: colorFor(levelOf(seconds)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
          ),
        );
      }

      columns.add(
        Padding(
          padding: const EdgeInsets.only(right: gap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                key: const ValueKey('heatmapMonthSlot'),
                height: monthSlot,
                child: showMonth
                    ? Text(months[weekStart.month - 1], style: monthStyle)
                    : null,
              ),
              ...cells,
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true, // en yeni haftalar (sağ) öncelikli görünür
          child: Row(children: columns),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              AppLocalizations.of(context).statsAz,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 6),
            for (var l = 0; l <= 4; l++) ...[
              Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: colorFor(l),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 3),
            ],
            const SizedBox(width: 3),
            Text(
              AppLocalizations.of(context).statsCok,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
