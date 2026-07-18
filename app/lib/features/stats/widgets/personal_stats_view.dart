import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/stats/session_window.dart';
import '../../../core/stats/stats_period.dart';
import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/safe_screen_padding.dart';
import '../../../data/models/study_session.dart';
import '../../../data/models/subject.dart';
import '../../../data/models/user_study_summary.dart';
import '../../../data/providers/analytics_query_providers.dart';
import '../../../data/providers/stats_period_provider.dart';
import '../../../data/providers/study_providers.dart';
import '../../../data/providers/subject_providers.dart';
import '../analytics/analytics_period.dart';
import '../charts/area_line_chart.dart';
import '../charts/gauge_chart.dart';
import '../charts/radar_stat_chart.dart';
import 'daily_bar_chart.dart';
import 'hour_activity_chart.dart';
import 'session_scatter_chart.dart';
import 'study_heatmap.dart';
import 'study_records.dart';
import 'subject_donut.dart';
import 'week_hour_heatmap.dart';
import '../stats_l10n.dart';

/// Kişisel istatistik: sabit ListView bölümleri (WP-179; sürükle-grid yok).
/// [sessions] sıcak pencere; [summary] yıl/ömür; uzun aralık RPC.
class PersonalStatsView extends ConsumerWidget {
  const PersonalStatsView({super.key, required this.sessions, this.summary});

  final List<StudySession> sessions;
  final UserStudySummary? summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    final sel = ref.watch(statsPeriodProvider);
    final period = sel.period;
    final (from, to) = sel.range(now: now);
    final periodSessions = inRange(sessions, from, to).toList();
    final analyticsPeriod = analyticsPeriodFromSelection(sel);
    final longTotalsAsync = ref.watch(
      analyticsUserDayTotalsProvider(analyticsPeriod),
    );
    final goalMinutes = ref.watch(dailyGoalMinutesProvider);
    final goalSeconds = goalMinutes * 60;

    final today = secondsOnDay(sessions, now);
    final thisWeek = totalSeconds(inRange(sessions, startOfWeek(now), now));
    final thisMonth = totalSeconds(inRange(sessions, startOfMonth(now), now));
    // Yıl ve ömür: özetten (1 yıllık satır listesi RAM'de yok).
    final thisYear =
        summary?.yearSeconds ??
        totalSeconds(inRange(sessions, startOfYear(now), now));
    final lifetime = summary?.lifetimeSeconds;

    // Döneme göre ortalama + hafta içi/sonu.
    final avgPeriod = dailyAverageSeconds(periodSessions, from, to);
    final split = weekdayWeekendSplit(periodSessions);

    if (sessions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timelapse, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context).statsHenuzCalismaKaydinYok,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context).statsBuDonemdeCalismaKaydin,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Gün→saniye haritası: rekor/heatmap tüm sıcak pencere; trend alt seçici.
    final dailyTotalsMap = dailyTotals(sessions);
    final periodTotalSec = totalSeconds(periodSessions);

    return ListView(
      padding: getSafeVerticalPadding(context),
      children: [
        // Üst dönem + seçili dönem özeti
        Text(
          statsPeriodLabel(AppLocalizations.of(context), period),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: AppLocalizations.of(context).statsToplam,
                seconds: period == StatsPeriod.all && lifetime != null
                    ? lifetime
                    : periodTotalSec,
                icon: Icons.timelapse,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: AppLocalizations.of(context).statsGunlukOrtalama,
                seconds: avgPeriod.round(),
                icon: Icons.trending_up,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: AppLocalizations.of(context).statsHaftaIci,
                seconds: split.weekday,
                icon: Icons.work_outline,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: AppLocalizations.of(context).statsHaftaSonu,
                seconds: split.weekend,
                icon: Icons.weekend_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context).statsDonemToplamlari,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: AppLocalizations.of(context).statsBugun,
                seconds: today,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: AppLocalizations.of(context).statsBuHafta,
                seconds: thisWeek,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: AppLocalizations.of(context).statsBuAy,
                seconds: thisMonth,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: AppLocalizations.of(context).statsBuYil,
                seconds: thisYear,
              ),
            ),
          ],
        ),
        if (lifetime != null) ...[
          const SizedBox(height: 8),
          _StatCard(
            label: AppLocalizations.of(context).statsTumZamanlar,
            seconds: lifetime,
          ),
        ],
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context).statsDonemToplamlari,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context).statsRekorlar,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StudyRecords(sessions: sessions, totals: dailyTotalsMap),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context).statsGunlukDagilim,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        // Yerel 7/14/30 kalır; master period değişince otomatik senkron.
        _TrendCard(sessions: sessions, totals: dailyTotalsMap),
        const SizedBox(height: 16),
        _WeekComparisonCard(sessions: sessions, now: now),
        const SizedBox(height: 16),
        Text(
          '${AppLocalizations.of(context).homeCalismaTakvimi} · '
          '${AppLocalizations.of(context).statsStreakGun(kUserSessionsHotWindowDays.toString())}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: StudyHeatmap(
              sessions: sessions,
              weeks: 13,
              precomputedTotals: dailyTotalsMap,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${AppLocalizations.of(context).statsCalismaSaatleri} · '
          '${statsPeriodLabel(AppLocalizations.of(context), period)}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: HourActivityChart(hourly: hourlyTotals(periodSessions)),
          ),
        ),
        const SizedBox(height: 16),
        // P6 hedef gauge
        Text(l10n.homeGunlukHedef, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GaugeChart(
                  progress: goalSeconds <= 0
                      ? 0
                      : today / goalSeconds,
                  label: l10n.homeGunlukHedef,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    goalSeconds <= 0
                        ? '—'
                        : '${formatHuman(today)} / ${formatHuman(goalSeconds)}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // P2 area trend (dönem serisi)
        Text(
          '${l10n.homeEgilimGrafigi} · ${statsPeriodLabel(l10n, period)}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              height: 140,
              child: Builder(
                builder: (context) {
                  final series = lastNDays(
                    periodSessions,
                    period.chartDays(),
                    totals: dailyTotalsMap,
                  );
                  if (series.isEmpty || series.every((d) => d.seconds == 0)) {
                    return Center(
                      child: Text(
                        l10n.statsBuDonemdeCalismaKaydin,
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return AreaLineChart(
                    values: [
                      for (final d in series) d.seconds / 3600.0,
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        if (sel.comparePrevious) ...[
          const SizedBox(height: 8),
          _CompareStrip(
            currentSeconds: periodTotalSec,
            previousSeconds: () {
              final prev = sel.previousRange(now: now);
              if (prev == null) return 0;
              return totalSeconds(inRange(sessions, prev.$1, prev.$2));
            }(),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          '${AppLocalizations.of(context).statsOturumDagilimi} · '
          '${statsPeriodLabel(AppLocalizations.of(context), period)}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        // P10 scatter — varsayılan katlı (WP ürün kararı)
        _CollapsibleSection(
          title: l10n.statsOturumDagilimi,
          initiallyExpanded: false,
          child: periodSessions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.statsBuDonemdeCalismaKaydin,
                    style: theme.textTheme.bodySmall,
                  ),
                )
              : SessionScatterChart(sessions: periodSessions),
        ),
        const SizedBox(height: 16),
        Text(
          '${AppLocalizations.of(context).statsHaftalikRitim} · '
          '${statsPeriodLabel(AppLocalizations.of(context), period)}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: WeekHourHeatmap(grid: weekdayHourTotals(periodSessions)),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${AppLocalizations.of(context).statsDersBazindaDagilimSon} · '
          '${statsPeriodLabel(AppLocalizations.of(context), period)}',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _SubjectBreakdownCard(sessions: periodSessions),
        const SizedBox(height: 16),
        // P12 radar — basit türetilmiş skorlar
        Text(l10n.analyticsCardInsight, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 200,
              child: _PersonalRadar(
                sessions: periodSessions,
                today: today,
                goalSeconds: goalSeconds,
                split: split,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // P11 detaylı geçmiş (RPC / uzun aralık)
        Text(
          l10n.statsSeciliTarihAraligi,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        longTotalsAsync.when(
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (_, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.authBeklenmeyenBirHataOlustu,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          data: (map) {
            if (map.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    l10n.statsBuDonemdeCalismaKaydin,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              );
            }
            final days = map.keys.toList()..sort();
            final vals = [for (final d in days) (map[d] ?? 0) / 3600.0];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${formatHuman(map.values.fold<int>(0, (a, b) => a + b))} · ${days.length}d',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: AreaLineChart(values: vals),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context).statsSeciliTarihAraligi,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _RangeCard(sessions: sessions, totals: dailyTotalsMap),
      ],
    );
  }
}

class _CompareStrip extends StatelessWidget {
  const _CompareStrip({
    required this.currentSeconds,
    required this.previousSeconds,
  });

  final int currentSeconds;
  final int previousSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final delta = currentSeconds - previousSeconds;
    final sign = delta >= 0 ? '+' : '';
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          '${l10n.analyticsComparePrevious}: $sign${formatHuman(delta.abs())} '
          '(${formatHuman(previousSeconds)} → ${formatHuman(currentSeconds)})',
          style: theme.textTheme.bodySmall,
        ),
      ),
    );
  }
}

class _CollapsibleSection extends StatefulWidget {
  const _CollapsibleSection({
    required this.title,
    required this.child,
    this.initiallyExpanded = true,
  });

  final String title;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  late bool _open = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          ListTile(
            title: Text(widget.title),
            trailing: Icon(_open ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _open = !_open),
            minVerticalPadding: 12,
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

/// Basit 5 eksen radar (tempo, tutarlılık, çeşitlilik, süre, odak saati).
class _PersonalRadar extends StatelessWidget {
  const _PersonalRadar({
    required this.sessions,
    required this.today,
    required this.goalSeconds,
    required this.split,
  });

  final List<StudySession> sessions;
  final int today;
  final int goalSeconds;
  final ({int weekday, int weekend}) split;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (sessions.isEmpty) {
      return Center(
        child: Text(
          l10n.statsBuDonemdeCalismaKaydin,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      );
    }
    final total = totalSeconds(sessions).toDouble();
    final tempo = goalSeconds <= 0
        ? 0.5
        : (today / goalSeconds).clamp(0.0, 1.0);
    final days = dailyTotals(sessions).values.where((s) => s > 0).length;
    final consistency = (days / 14.0).clamp(0.0, 1.0);
    final subjects = <String>{
      for (final s in sessions)
        if (s.subjectId != null) s.subjectId!,
    };
    final variety = (subjects.length / 5.0).clamp(0.0, 1.0);
    final durationScore = (total / (10 * 3600)).clamp(0.0, 1.0);
    final balance = total <= 0
        ? 0.5
        : (1.0 -
                ((split.weekday - split.weekend).abs() / total))
            .clamp(0.0, 1.0);

    return RadarStatChart(
      values: [tempo, consistency, variety, durationScore, balance],
      labels: [
        l10n.homeGunlukHedef,
        l10n.statsRekorlar,
        l10n.statsDersBazindaDagilimSon,
        l10n.statsToplam,
        l10n.statsHaftaIci,
      ],
    );
  }
}

/// Günlük çubuk grafiği + gün aralığı seçici (7 / 14 / 30 gün).
///
/// Yerel seçici kalır; üst [statsPeriodProvider] değişince en yakın
/// seçeneğe otomatik senkronlanır (kullanıcı sonra yine yerel değiştirebilir).
class _TrendCard extends ConsumerStatefulWidget {
  const _TrendCard({required this.sessions, this.totals});

  final List<StudySession> sessions;
  final Map<DateTime, int>? totals;

  @override
  ConsumerState<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends ConsumerState<_TrendCard> {
  static const _options = [7, 14, 30];
  late int _days;

  @override
  void initState() {
    super.initState();
    // İlk açılış: mevcut master dönemle hizala.
    _days = ref.read(statsPeriodProvider).period.chartDays(options: _options);
  }

  @override
  Widget build(BuildContext context) {
    // Master dönem değişince yerel 7/14/30'u güncelle; kullanıcı override edebilir.
    ref.listen(statsPeriodProvider, (prev, next) {
      if (prev?.period == next.period) return;
      final mapped = next.period.chartDays(options: _options);
      if (_days != mapped) setState(() => _days = mapped);
    });

    final series = lastNDays(widget.sessions, _days, totals: widget.totals);
    final goalSeconds = ref.watch(dailyGoalMinutesProvider) * 60;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          children: [
            SegmentedButton<int>(
              segments: [
                ButtonSegment(
                  value: 7,
                  label: Text(AppLocalizations.of(context).statsValue7Gun),
                ),
                ButtonSegment(
                  value: 14,
                  label: Text(AppLocalizations.of(context).statsValue14Gun),
                ),
                ButtonSegment(
                  value: 30,
                  label: Text(AppLocalizations.of(context).statsValue30Gun),
                ),
              ],
              selected: {_days},
              onSelectionChanged: (s) => setState(() => _days = s.first),
              showSelectedIcon: false,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: DailyBarChart(days: series, goalSeconds: goalSeconds),
            ),
          ],
        ),
      ),
    );
  }
}

/// Serbest tarih aralığı: kullanıcı bir aralık seçer; toplam + günlük ortalama
/// ve (aralık 45 günü aşmıyorsa) günlük grafik gösterilir (project.md §3.4).
class _RangeCard extends StatefulWidget {
  const _RangeCard({required this.sessions, this.totals});

  final List<StudySession> sessions;
  final Map<DateTime, int>? totals;

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
      setState(
        () => _range = DateTimeRange(
          start: dayOf(picked.start),
          end: dayOf(picked.end),
        ),
      );
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
    final series = dailyRange(widget.sessions, from, to, totals: widget.totals);

    String d(DateTime x) =>
        DateFormat.yMd(AppLocalizations.of(context).localeName).format(x);

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
                    '${d(from)} – ${d(to)} · '
                    '${AppLocalizations.of(context).statsStreakGun(dayCount.toString())}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(AppLocalizations.of(context).statsSec),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _MiniMetric(
                    label: AppLocalizations.of(context).statsToplam,
                    value: formatHuman(total),
                  ),
                ),
                Expanded(
                  child: _MiniMetric(
                    label: AppLocalizations.of(context).statsGunlukOrt,
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
                AppLocalizations.of(context).statsGrafikIcin45Gunden,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
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
    final lastWeek = totalSeconds(
      inRange(sessions, lastWeekStart, lastWeekEnd),
    );
    final diff = thisWeek - lastWeek;
    final improved = diff >= 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context).statsBuHaftaVsGecen,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniMetric(
                    label: AppLocalizations.of(context).statsBuHafta,
                    value: formatHuman(thisWeek),
                  ),
                ),
                Expanded(
                  child: _MiniMetric(
                    label: AppLocalizations.of(context).statsGecenHafta,
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
                  color: improved
                      ? subjectColor('chart-2')
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 4),
                Text(
                  '${improved ? '+' : '-'}${formatHuman(diff.abs())}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: improved
                        ? subjectColor('chart-2')
                        : theme.colorScheme.error,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  AppLocalizations.of(context).statsBuHaftaVsGecen,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
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
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }
}

/// Tek bir istatistik kartı (etiket + süre).
class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.seconds, this.icon});

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
                  Icon(
                    icon,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
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
            AppLocalizations.of(context).statsBuDonemdeCalismaKaydin,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // id→Subject map'i: döngü içinde O(1) arama (önceki O(slices×subjects)).
    final subjectById = {for (final s in subjects) s.id: s};
    Subject? subjectFor(String? id) => id == null ? null : subjectById[id];

    final total = breakdown.fold<int>(0, (s, e) => s + e.value);
    final slices = [
      for (final entry in breakdown)
        () {
          final subject = subjectFor(entry.key);
          return SubjectDonutSlice(
            label: subject?.name ?? AppLocalizations.of(context).statsGenel,
            color: subject != null
                ? subjectColor(subject.color)
                : theme.colorScheme.onSurfaceVariant,
            seconds: entry.value,
          );
        }(),
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
                segments: [
                  ButtonSegment(value: true, label: Text('%')),
                  ButtonSegment(
                    value: false,
                    label: Text(AppLocalizations.of(context).statsSure),
                  ),
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
                                child: Text(
                                  s.label,
                                  style: theme.textTheme.bodyMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                valueFor(s.seconds),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
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
