import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/duration_format.dart';

List<String> _days(BuildContext context) => [
  AppLocalizations.of(context).statsPzt,
  AppLocalizations.of(context).statsSal,
  AppLocalizations.of(context).statsCar,
  AppLocalizations.of(context).statsPer,
  AppLocalizations.of(context).statsCum,
  AppLocalizations.of(context).statsCmt,
  AppLocalizations.of(context).statsPaz,
];

/// Haftalık ritim ısı haritası: 7 gün (satır) × 24 saat (sütun). Renk koyuluğu o
/// gün/saatteki toplam süreyle artar. Her hücre dokunulabilir (gün + saat + süre).
///
/// Hücreler **sabit boyutlu** (LayoutBuilder ile genişliğe göre hesaplanır) —
/// böylece `Tooltip`'in fare bölgesi sıfır-boyutlu olup "no size" hatası vermez.
class WeekHourHeatmap extends StatelessWidget {
  const WeekHourHeatmap({super.key, required this.grid});

  /// `[gün 0–6][saat 0–23]` → saniye (bkz. weekdayHourTotals).
  final List<List<int>> grid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _days(context);
    var maxV = 0;
    var total = 0;
    for (final row in grid) {
      for (final v in row) {
        if (v > maxV) maxV = v;
        total += v;
      }
    }

    if (total == 0) {
      return Text(
        AppLocalizations.of(context).statsBuDonemdeCalismaKaydin,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    Color cellColor(int v) {
      if (v <= 0) return theme.colorScheme.surfaceContainerHighest;
      final r = maxV <= 0 ? 0.0 : v / maxV;
      return theme.colorScheme.primary.withValues(alpha: 0.28 + 0.72 * r);
    }

    const labelWidth = 30.0;
    const gap = 2.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final avail = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 320.0;
        // 24 sütun + aralık, etiket sütunu hariç. Min/max ile güvenli boyut.
        final cell = (((avail - labelWidth) / 24) - gap)
            .clamp(6.0, 22.0)
            .toDouble();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var d = 0; d < 7; d++)
              Padding(
                padding: const EdgeInsets.only(bottom: gap),
                child: Row(
                  children: [
                    SizedBox(
                      width: labelWidth,
                      child: Text(
                        days[d],
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (var h = 0; h < 24; h++)
                      Padding(
                        padding: const EdgeInsets.only(right: gap),
                        child: Tooltip(
                          message:
                              '${days[d]} ${h.toString().padLeft(2, '0')}:00 · ${formatHuman(grid[d][h])}',
                          waitDuration: const Duration(milliseconds: 200),
                          child: Container(
                            width: cell,
                            height: cell,
                            decoration: BoxDecoration(
                              color: cellColor(grid[d][h]),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            // Saat ekseni (00 / 06 / 12 / 18 / 23) — hücre genişliğine hizalı.
            Padding(
              padding: const EdgeInsets.only(left: labelWidth),
              child: SizedBox(
                width: 24 * (cell + gap),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final l in ['00', '06', '12', '18', '23'])
                      Text(
                        l,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
