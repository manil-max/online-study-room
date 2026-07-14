import 'package:flutter/material.dart';

import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/crowned_avatar.dart';

/// Isı tablosunda bir satır: isim + her sütun için saniye değerleri.
class HeatRow {
  const HeatRow({
    required this.label,
    required this.values,
    this.avatarUrl,
    this.userId,
    this.highlight = false,
  });

  final String label;
  final List<int> values;
  final String? avatarUrl;
  final String? userId;
  final bool highlight; // "sen" satırı
}

/// Renk-kodlu karşılaştırma tablosu (yapayzeka.oguzergin.net tarzı): her **sütun
/// kendi içinde** renklendirilir — yüksek değer yeşil, orta amber, düşük kırmızı.
/// İlk sütun isim/avatar; kalan sütunlar süre (formatHuman) ısı hücreleri.
class StatHeatTable extends StatelessWidget {
  const StatHeatTable({
    super.key,
    required this.columns,
    required this.rows,
  });

  /// Sayısal sütun başlıkları (ör. ['Bugün', 'Hafta', 'Ay']).
  final List<String> columns;
  final List<HeatRow> rows;

  /// Değere göre yeşil(yüksek)→amber→kırmızı(düşük) ton.
  static Color _heat(double pct) {
    final p = pct.clamp(0.0, 1.0);
    final green = subjectColor('chart-2');
    final amber = subjectColor('chart-3');
    final red = subjectColor('chart-5');
    if (p >= 0.5) return Color.lerp(amber, green, (p - 0.5) / 0.5)!;
    return Color.lerp(red, amber, p / 0.5)!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Her sütunun min/max'ı (kendi içinde renklendirmek için).
    final colMax = List<int>.filled(columns.length, 0);
    final colMin = List<int>.filled(columns.length, 1 << 30);
    for (final r in rows) {
      for (var c = 0; c < columns.length; c++) {
        final v = c < r.values.length ? r.values[c] : 0;
        if (v > colMax[c]) colMax[c] = v;
        if (v < colMin[c]) colMin[c] = v;
      }
    }

    Widget cell(int value, int c) {
      final max = colMax[c];
      final min = colMin[c];
      final pct = (max <= 0 || max == min) ? 1.0 : (value - min) / (max - min);
      final heat = value <= 0 ? theme.colorScheme.onSurfaceVariant : _heat(pct);
      return Expanded(
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: value <= 0
                ? theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4)
                : heat.withValues(alpha: 0.20),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(
            value <= 0 ? '—' : formatHuman(value),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: value <= 0 ? theme.colorScheme.onSurfaceVariant : heat,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        // Başlık satırı.
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              const SizedBox(width: 130),
              for (final col in columns)
                Expanded(
                  child: Text(col,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
            ],
          ),
        ),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Row(
                    children: [
                      if (r.userId != null)
                        LiveCrownedAvatar(
                          userId: r.userId!,
                          displayName: r.label,
                          avatarUrl: r.avatarUrl,
                          radius: 12,
                        )
                      else
                        CrownedAvatar(
                          displayName: r.label,
                          avatarUrl: r.avatarUrl,
                          radius: 12,
                        ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          r.label,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight:
                                r.highlight ? FontWeight.w700 : FontWeight.w500,
                            color: r.highlight ? theme.colorScheme.primary : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                for (var c = 0; c < columns.length; c++)
                  cell(c < r.values.length ? r.values[c] : 0, c),
              ],
            ),
          ),
      ],
    );
  }
}
