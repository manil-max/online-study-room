import 'package:flutter/material.dart';

import '../../../core/utils/duration_format.dart';

/// "Günün hangi saatlerinde çalışıyorsun?" — 24 saatlik etkileşimli sütun grafiği.
/// Her sütun o saatteki toplam süreyle orantılı yükseklikte ve yoğunlukla renklenir;
/// en verimli saat vurgulanır. Üzerine gelince saat + süre ipucu açılır.
class HourActivityChart extends StatelessWidget {
  const HourActivityChart({super.key, required this.hourly, this.height = 130});

  /// 24 elemanlı liste: saat (0–23) → saniye.
  final List<int> hourly;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxV = hourly.fold<int>(0, (m, v) => v > m ? v : m);
    final total = hourly.fold<int>(0, (s, v) => s + v);
    // En verimli saat (veri varsa).
    var peak = -1;
    for (var h = 0; h < 24; h++) {
      if (hourly[h] > 0 && (peak < 0 || hourly[h] > hourly[peak])) peak = h;
    }

    if (total == 0) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'Henüz çalışma kaydın yok — saat dağılımı burada görünecek.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    Color barColor(int h) {
      if (h == peak) return theme.colorScheme.secondary; // vurgu (accent)
      if (hourly[h] == 0) return theme.colorScheme.surfaceContainerHighest;
      final r = maxV <= 0 ? 0.0 : hourly[h] / maxV;
      // Az → soluk, çok → canlı (birincil rengin alfası).
      return theme.colorScheme.primary.withValues(alpha: 0.35 + 0.65 * r);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (peak >= 0)
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.bolt, size: 16, color: theme.colorScheme.secondary),
                const SizedBox(width: 4),
                Text(
                  'En verimli saat: ${peak.toString().padLeft(2, '0')}:00 '
                  '(${formatHuman(hourly[peak])})',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var h = 0; h < 24; h++)
                Expanded(
                  child: Tooltip(
                    message:
                        '${h.toString().padLeft(2, '0')}:00 · ${formatHuman(hourly[h])}',
                    waitDuration: Duration.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 1.5),
                      // Açık (bounded) yükseklikli çubuk — FractionallySizedBox
                      // bir Column içinde sınırsız yükseklik alıp çökmesin diye.
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: (hourly[h] <= 0 || maxV <= 0)
                              ? 0
                              : 2 + (height - 2) * (hourly[h] / maxV),
                          decoration: BoxDecoration(
                            color: barColor(h),
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(3)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // Saat ekseni etiketleri (0 / 6 / 12 / 18 / 23).
        Row(
          children: [
            for (final label in ['00', '06', '12', '18', '23'])
              Expanded(
                child: Align(
                  alignment: label == '00'
                      ? Alignment.centerLeft
                      : label == '23'
                          ? Alignment.centerRight
                          : Alignment.center,
                  child: Text(label,
                      style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
