import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/providers/study_providers.dart';
import '../dashboard_card.dart';

enum _Period { today, week, month, year }

extension on _Period {
  String get label => switch (this) {
        _Period.today => 'Bugün',
        _Period.week => 'Hafta',
        _Period.month => 'Ay',
        _Period.year => 'Yıl',
      };
}

/// Dönem özeti (§3.11 kart): seçilebilir dönem (bugün/hafta/ay/yıl) için toplam
/// ve günlük ortalama. Etkileşimli — kullanıcı dönemi kart üstünden değiştirir.
class PeriodSummaryCard extends ConsumerStatefulWidget {
  const PeriodSummaryCard({super.key, this.size = DashboardCardSize.medium});

  final DashboardCardSize size;

  @override
  ConsumerState<PeriodSummaryCard> createState() => _PeriodSummaryCardState();
}

class _PeriodSummaryCardState extends ConsumerState<PeriodSummaryCard> {
  _Period _period = _Period.week;

  DateTime _from(DateTime now) => switch (_period) {
        _Period.today => dayOf(now),
        _Period.week => startOfWeek(now),
        _Period.month => startOfMonth(now),
        _Period.year => startOfYear(now),
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessions = ref.watch(userSessionsProvider).value ?? const [];
    final now = DateTime.now();
    final from = _from(now);
    final total = totalSeconds(inRange(sessions, from, now));
    final avg = dailyAverageSeconds(sessions, from, now).round();
    final activeDays = inRange(sessions, from, now)
        .map((s) => s.day)
        .toSet()
        .length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Dönem özeti', style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            // Etkileşimli dönem seçici.
            SegmentedButton<_Period>(
              segments: [
                for (final p in _Period.values)
                  ButtonSegment(value: p, label: Text(p.label)),
              ],
              selected: {_period},
              onSelectionChanged: (s) => setState(() => _period = s.first),
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'Toplam',
                    value: formatHuman(total),
                    color: theme.colorScheme.primary,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Günlük ort.',
                    value: formatHuman(avg),
                    color: theme.colorScheme.secondary,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Aktif gün',
                    value: '$activeDays',
                    color: theme.colorScheme.tertiary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700)),
      ],
    );
  }
}
