import 'package:flutter/material.dart';

import '../../../core/utils/duration_format.dart';

const _kDays = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

/// Haftalık ritim ısı haritası: 7 gün (satır) × 24 saat (sütun). Renk koyuluğu o
/// gün/saatteki toplam süreyle artar. Her hücre dokunulabilir (gün + saat + süre).
class WeekHourHeatmap extends StatelessWidget {
  const WeekHourHeatmap({super.key, required this.grid});

  /// `[gün 0–6][saat 0–23]` → saniye (bkz. weekdayHourTotals).
  final List<List<int>> grid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
        'Henüz çalışma kaydın yok — haftalık ritim burada görünecek.',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    Color cellColor(int v) {
      if (v <= 0) return theme.colorScheme.surfaceContainerHighest;
      final r = maxV <= 0 ? 0.0 : v / maxV;
      return theme.colorScheme.primary.withValues(alpha: 0.28 + 0.72 * r);
    }

    const labelWidth = 30.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var d = 0; d < 7; d++)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                SizedBox(
                  width: labelWidth,
                  child: Text(_kDays[d],
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
                Expanded(
                  child: Row(
                    children: [
                      for (var h = 0; h < 24; h++)
                        Expanded(
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 0.5),
                            child: Tooltip(
                              message:
                                  '${_kDays[d]} ${h.toString().padLeft(2, '0')}:00 · ${formatHuman(grid[d][h])}',
                              waitDuration: Duration.zero,
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: cellColor(grid[d][h]),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        // Saat ekseni (00 / 06 / 12 / 18 / 23).
        Row(
          children: [
            const SizedBox(width: labelWidth),
            Expanded(
              child: Row(
                children: [
                  for (final l in ['00', '06', '12', '18', '23'])
                    Expanded(
                      child: Align(
                        alignment: l == '00'
                            ? Alignment.centerLeft
                            : l == '23'
                                ? Alignment.centerRight
                                : Alignment.center,
                        child: Text(l,
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
