import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/study_session.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/study_providers.dart';
import '../../../data/providers/subject_providers.dart';
import 'daily_bar_chart.dart';
import 'hour_activity_chart.dart';
import 'session_scatter_chart.dart';
import 'study_heatmap.dart';
import 'study_records.dart';
import 'subject_donut.dart';
import 'week_hour_heatmap.dart';

/// Kişisel istatistik özeti: dönem toplamları, günlük ortalama ve
/// hafta içi / hafta sonu ayrımı. Grafikler Faz 3b'de eklenecek.
class PersonalStatsView extends StatelessWidget {
  const PersonalStatsView({super.key, required this.sessions});

  final List<StudySession> sessions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();

    final today = secondsOnDay(sessions, now);
    final thisWeek = totalSeconds(inRange(sessions, startOfWeek(now), now));
    final thisMonth = totalSeconds(inRange(sessions, startOfMonth(now), now));
    final thisYear = totalSeconds(inRange(sessions, startOfYear(now), now));

    // Son 30 günün günlük ortalaması (çalışılmayan günler de paydada).
    final avg30 = dailyAverageSeconds(
      sessions,
      dayOf(now).subtract(const Duration(days: 29)),
      now,
    );

    // Hafta içi / hafta sonu ayrımı (son 30 gün).
    final last30 = inRange(
      sessions,
      dayOf(now).subtract(const Duration(days: 29)),
      now,
    );
    final split = weekdayWeekendSplit(last30);

    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timelapse,
                  size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text('Henüz çalışma kaydın yok',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Ana Sayfa’daki sayaçtan çalışmaya başlayınca istatistiklerin burada görünecek.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Dönem toplamları', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _StatCard(label: 'Bugün', seconds: today)),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(label: 'Bu hafta', seconds: thisWeek)),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _StatCard(label: 'Bu ay', seconds: thisMonth)),
            const SizedBox(width: 8),
            Expanded(child: _StatCard(label: 'Bu yıl', seconds: thisYear)),
          ],
        ),
        const SizedBox(height: 16),
        Text('Rekorlar', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StudyRecords(sessions: sessions),
          ),
        ),
        const SizedBox(height: 16),
        Text('Günlük dağılım', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _TrendCard(sessions: sessions),
        const SizedBox(height: 16),
        _WeekComparisonCard(sessions: sessions, now: now),
        const SizedBox(height: 16),
        Text('Çalışma takvimi (son 6 ay)', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StudyHeatmap(sessions: sessions, weeks: 26),
          ),
        ),
        const SizedBox(height: 16),
        Text('Çalışma saatleri', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: HourActivityChart(hourly: hourlyTotals(sessions)),
          ),
        ),
        const SizedBox(height: 16),
        Text('Oturum dağılımı', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SessionScatterChart(sessions: sessions),
          ),
        ),
        const SizedBox(height: 16),
        Text('Haftalık ritim', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: WeekHourHeatmap(grid: weekdayHourTotals(sessions)),
          ),
        ),
        const SizedBox(height: 16),
        Text('Ders bazında dağılım (son 30 gün)',
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _SubjectBreakdownCard(
          sessions: inRange(
            sessions,
            dayOf(now).subtract(const Duration(days: 29)),
            now,
          ).toList(),
        ),
        const SizedBox(height: 16),
        Text('Seçili tarih aralığı', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _RangeCard(sessions: sessions),
        const SizedBox(height: 16),
        Text('Son 30 gün', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        _StatCard(
          label: 'Günlük ortalama',
          seconds: avg30.round(),
          icon: Icons.trending_up,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Hafta içi',
                seconds: split.weekday,
                icon: Icons.work_outline,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: 'Hafta sonu',
                seconds: split.weekend,
                icon: Icons.weekend_outlined,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Günlük çubuk grafiği + gün aralığı seçici (7 / 14 / 30 gün).
class _TrendCard extends ConsumerStatefulWidget {
  const _TrendCard({required this.sessions});

  final List<StudySession> sessions;

  @override
  ConsumerState<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends ConsumerState<_TrendCard> {
  int _days = 14;

  @override
  Widget build(BuildContext context) {
    final series = lastNDays(widget.sessions, _days);
    final goalSeconds = ref.watch(dailyGoalMinutesProvider) * 60;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 gün')),
                ButtonSegment(value: 14, label: Text('14 gün')),
                ButtonSegment(value: 30, label: Text('30 gün')),
              ],
              selected: {_days},
              onSelectionChanged: (s) => setState(() => _days = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 16),
            SizedBox(
                height: 180,
                child: DailyBarChart(days: series, goalSeconds: goalSeconds)),
          ],
        ),
      ),
    );
  }
}

/// Serbest tarih aralığı: kullanıcı bir aralık seçer; toplam + günlük ortalama
/// ve (aralık 45 günü aşmıyorsa) günlük grafik gösterilir (project.md §3.4).
class _RangeCard extends StatefulWidget {
  const _RangeCard({required this.sessions});

  final List<StudySession> sessions;

  @override
  State<_RangeCard> createState() => _RangeCardState();
}

class _RangeCardState extends State<_RangeCard> {
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: dayOf(now).subtract(const Duration(days: 29)),
      end: dayOf(now),
    );
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() => _range = DateTimeRange(
            start: dayOf(picked.start),
            end: dayOf(picked.end),
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final from = _range.start;
    final to = _range.end;
    final total = totalSeconds(inRange(widget.sessions, from, to));
    final avg = dailyAverageSeconds(widget.sessions, from, to);
    final dayCount = to.difference(from).inDays + 1;
    final series = dailyRange(widget.sessions, from, to);

    String d(DateTime x) => '${x.day}.${x.month}.${x.year}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${d(from)} – ${d(to)}  ($dayCount gün)',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: const Text('Seç'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _MiniMetric(label: 'Toplam', value: formatHuman(total))),
                Expanded(
                  child: _MiniMetric(
                    label: 'Günlük ort.',
                    value: formatHuman(avg.round()),
                  ),
                ),
              ],
            ),
            if (series.length <= 45) ...[
              const SizedBox(height: 16),
              SizedBox(height: 160, child: DailyBarChart(days: series)),
            ] else ...[
              const SizedBox(height: 12),
              Text(
                'Grafik için 45 günden kısa bir aralık seçin.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bu hafta ile geçen haftanın kıyaslaması (dönemler arası — project.md §3.4).
class _WeekComparisonCard extends StatelessWidget {
  const _WeekComparisonCard({required this.sessions, required this.now});

  final List<StudySession> sessions;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thisWeekStart = startOfWeek(now);
    final lastWeekStart = thisWeekStart.subtract(const Duration(days: 7));
    final lastWeekEnd = thisWeekStart.subtract(const Duration(days: 1));

    final thisWeek = totalSeconds(inRange(sessions, thisWeekStart, now));
    final lastWeek = totalSeconds(inRange(sessions, lastWeekStart, lastWeekEnd));
    final diff = thisWeek - lastWeek;
    final improved = diff >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bu hafta vs geçen hafta',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniMetric(
                    label: 'Bu hafta',
                    value: formatHuman(thisWeek),
                  ),
                ),
                Expanded(
                  child: _MiniMetric(
                    label: 'Geçen hafta',
                    value: formatHuman(lastWeek),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  improved ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 18,
                  color:
                      improved ? subjectColor('chart-2') : theme.colorScheme.error,
                ),
                const SizedBox(width: 4),
                Text(
                  '${improved ? '+' : '-'}${formatHuman(diff.abs())}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color:
                      improved ? subjectColor('chart-2') : theme.colorScheme.error,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  improved ? 'geçen haftaya göre artış' : 'geçen haftaya göre azalış',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Küçük etiket + değer (kıyas kartı için).
class _MiniMetric extends StatelessWidget {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

/// Tek bir istatistik kartı (etiket + süre).
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.seconds,
    this.icon,
  });

  final String label;
  final int seconds;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(formatHuman(seconds), style: theme.textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

/// Ders bazında dağılım: verilen oturumları derse göre toplar, etkileşimli donut
/// + açıklama (legend) ile gösterir. Veri formatı (yüzde / süre) seçilebilir.
/// Derssiz süreler "Genel" altında toplanır (project.md §3.7).
class _SubjectBreakdownCard extends ConsumerStatefulWidget {
  const _SubjectBreakdownCard({required this.sessions});

  final List<StudySession> sessions;

  @override
  ConsumerState<_SubjectBreakdownCard> createState() =>
      _SubjectBreakdownCardState();
}

class _SubjectBreakdownCardState extends ConsumerState<_SubjectBreakdownCard> {
  bool _showPercent = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjects = ref.watch(userSubjectsProvider).value ?? const <Subject>[];
    final breakdown = subjectBreakdown(widget.sessions);

    if (breakdown.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Bu dönemde çalışma kaydın yok.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    Subject? subjectFor(String? id) {
      for (final s in subjects) {
        if (s.id == id) return s;
      }
      return null;
    }

    final total = breakdown.fold<int>(0, (s, e) => s + e.value);
    final slices = [
      for (final entry in breakdown)
        SubjectDonutSlice(
          label: subjectFor(entry.key)?.name ?? 'Genel',
          color: subjectFor(entry.key) != null
              ? subjectColor(subjectFor(entry.key)!.color)
              : theme.colorScheme.onSurfaceVariant,
          seconds: entry.value,
        ),
    ];

    String valueFor(int seconds) => _showPercent
        ? '%${total == 0 ? 0 : (seconds * 100 / total).round()}'
        : formatHuman(seconds);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Veri formatı seçici: yüzde / süre.
            Align(
              alignment: Alignment.centerRight,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('%')),
                  ButtonSegment(value: false, label: Text('Süre')),
                ],
                selected: {_showPercent},
                onSelectionChanged: (s) =>
                    setState(() => _showPercent = s.first),
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SubjectDonut(slices: slices, size: 132),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final s in slices)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              CircleAvatar(radius: 5, backgroundColor: s.color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(s.label,
                                    style: theme.textTheme.bodyMedium,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Text(
                                valueFor(s.seconds),
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                    ],
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
