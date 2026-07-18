import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/stats/stats_period.dart';
import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../core/widgets/safe_screen_padding.dart';
import '../../../core/widgets/crowned_avatar.dart';
import '../../../data/models/daily_stat.dart';
import '../../../data/models/profile.dart';
import '../../../data/providers/analytics_query_providers.dart';
import '../../../data/providers/stats_period_provider.dart';
import '../../classroom/widgets/class_switcher.dart';
import '../../profile/widgets/profile_tap.dart';
import '../analytics/analytics_period.dart';
import '../charts/area_line_chart.dart';
import '../charts/gauge_chart.dart';
import 'daily_bar_chart.dart';
import 'daily_line_chart.dart';
import 'stat_heat_table.dart';
import 'subject_donut.dart';
import '../stats_l10n.dart';

/// Sınıf (ortak) istatistikleri: ortak dönem + sıralama + özet.
/// Dönem üst [StatsPeriodBar] / [statsPeriodProvider] ile gelir; yerel seçici yok.
class ClassStatsView extends ConsumerWidget {
  const ClassStatsView({
    super.key,
    required this.stats,
    required this.members,
    required this.currentUserId,
    required this.groupName,
    required this.groupGoalMinutes,
  });

  /// Sınıfın per-user-per-gün toplamları (F1: ham oturum yerine sunucu agregası).
  final List<DailyStat> stats;
  final List<Profile> members;
  final String currentUserId;
  final String groupName;
  final int groupGoalMinutes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final sel = ref.watch(statsPeriodProvider);
    final period = sel.period;
    final (from, to) = sel.range(now: now);
    final analyticsPeriod = analyticsPeriodFromSelection(sel);
    final contribAsync = ref.watch(
      analyticsGroupContributionProvider(analyticsPeriod),
    );
    final seriesAsync = ref.watch(
      analyticsGroupLeaderboardSeriesProvider(analyticsPeriod),
    );

    // Seçili dönem leaderboard'u: userId → saniye (per-user-per-gün toplamdan).
    final totals = userTotalsInRange(stats, from, to);
    final rows = [
      for (final m in members) (member: m, seconds: totals[m.id] ?? 0),
    ]..sort((a, b) => b.seconds.compareTo(a.seconds));

    final classTotal = totals.values.fold<int>(0, (s, v) => s + v);
    final memberCount = members.isEmpty ? 1 : members.length;
    final classAvg = classTotal ~/ memberCount;
    final maxSeconds = rows.isEmpty ? 0 : rows.first.seconds;
    // Üst dönem → bar/çizgi penceresi (7 veya 30; yerelde ayrı seçici yok).
    final chartDays = period.chartDays(options: const [7, 14, 30]);
    final trendDays =
        period == StatsPeriod.month ||
            period == StatsPeriod.year ||
            period == StatsPeriod.all ||
            period == StatsPeriod.custom
        ? 30
        : chartDays;
    // Üye başına çalışma serisi (tüm günlük toplamlardan, dönemden bağımsız).
    final streaks = <String, int>{
      for (final m in members)
        m.id: studyStreak(const [], totals: userDayTotals(stats, m.id)),
    };
    // Renk-kodlu karşılaştırma tablosu: üye × [Bugün, Hafta, Ay].
    final todayTotals = userTotalsInRange(stats, dayOf(now), now);
    final weekTotals = userTotalsInRange(stats, startOfWeek(now), now);
    final monthTotals = userTotalsInRange(stats, startOfMonth(now), now);
    final heatRows = [
      for (final m in members)
        HeatRow(
          label: !m.isActive
              ? AppLocalizations.of(context).statsEskiGrupUyesi
              : (m.displayName.isEmpty
                    ? AppLocalizations.of(context).statsIsimsiz
                    : m.displayName),
          avatarUrl: m.avatarUrl,
          userId: m.id,
          highlight: m.id == currentUserId,
          values: [
            todayTotals[m.id] ?? 0,
            weekTotals[m.id] ?? 0,
            monthTotals[m.id] ?? 0,
          ],
        ),
    ]..sort((a, b) => b.values[2].compareTo(a.values[2]));

    // Grup günlük hedefi: bugünkü grup toplamı + gruba göre seri.
    final goalSeconds = groupGoalMinutes * 60;
    final groupDay = groupDayTotals(stats);
    final todayGroupTotal = groupDay[dayOf(now)] ?? 0;
    final groupStreak = currentStreak(const [], goalSeconds, totals: groupDay);

    // Tüm-zamanlar metrikleri (§WP-10) — dönem seçiminden bağımsız.
    final allTimeTotal = totalOfDayTotals(groupDay);
    final activeDays = activeDayCount(groupDay);
    final peak = peakDay(groupDay);
    final recordStreak = longestStudyStreak(const [], totals: groupDay);
    // En istikrarlı üye: en uzun (ardışık çalışılan gün) serisi.
    String? consistentName;
    var consistentStreak = 0;
    for (final m in members) {
      final st = longestStudyStreak(
        const [],
        totals: userDayTotals(stats, m.id),
      );
      if (st > consistentStreak) {
        consistentStreak = st;
        consistentName = !m.isActive
            ? AppLocalizations.of(context).statsEskiGrupUyesi
            : (m.displayName.isEmpty
                  ? AppLocalizations.of(context).statsIsimsiz
                  : m.displayName);
      }
    }

    return ListView(
      padding: getSafeVerticalPadding(context),
      children: [
        // Grup başlığı + grup değiştirici (yalnızca geçiş, basılan yerde açılır).
        Row(
          children: [
            Expanded(
              child: Text(
                groupName,
                style: theme.textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Builder(
              builder: (iconContext) => TextButton.icon(
                onPressed: () =>
                    showClassSwitcher(iconContext, ref, switchOnly: true),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: Text(AppLocalizations.of(context).statsDegistir),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          statsPeriodLabel(AppLocalizations.of(context), period),
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        // G1: hedef gauge + mevcut özet kart
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GaugeChart(
                  progress: goalSeconds <= 0
                      ? 0
                      : todayGroupTotal / goalSeconds,
                  label: AppLocalizations.of(context).homeGrupHedefi,
                  size: 100,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _GroupGoalCard(
                todaySeconds: todayGroupTotal,
                goalSeconds: goalSeconds,
                streak: groupStreak,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: AppLocalizations.of(context).statsGrupToplami,
                seconds: classTotal,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SummaryCard(
                label: AppLocalizations.of(context).statsKisiBasiOrt,
                seconds: classAvg,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // G2: üye katkı donut (varsayılan açık)
        Text(
          AppLocalizations.of(context).analyticsCardMemberDonut,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        contribAsync.when(
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
                AppLocalizations.of(context).statsBuDonemdeHenuzCalisma,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    AppLocalizations.of(context).statsBuDonemdeHenuzCalisma,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              );
            }
            final nameOf = {for (final m in members) m.id: m.displayName};
            final slices = [
              for (var i = 0; i < rows.length; i++)
                SubjectDonutSlice(
                  label: (nameOf[rows[i].userId] ?? '').isEmpty
                      ? AppLocalizations.of(context).statsIsimsiz
                      : nameOf[rows[i].userId]!,
                  color: subjectColor('chart-${(i % 5) + 1}'),
                  seconds: rows[i].seconds,
                ),
            ];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SubjectDonut(slices: slices),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // G4: liderlik zaman serisi (aggregate area)
        Text(
          AppLocalizations.of(context).analyticsCardLeaderboardHistory,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        seriesAsync.when(
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
                AppLocalizations.of(context).statsBuDonemdeHenuzCalisma,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          data: (points) {
            if (points.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    AppLocalizations.of(context).statsBuDonemdeHenuzCalisma,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              );
            }
            // Gün toplamı (tüm üyeler) → area
            final byDay = <DateTime, int>{};
            for (final p in points) {
              final d = dayOf(p.day);
              byDay[d] = (byDay[d] ?? 0) + p.seconds;
            }
            final days = byDay.keys.toList()..sort();
            final vals = [for (final d in days) (byDay[d] ?? 0) / 3600.0];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SizedBox(
                  height: 120,
                  child: AreaLineChart(values: vals),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        // G3: Sıralama — ortak dönem seçimine bağlı.
        Text(
          AppLocalizations.of(context).statsSiralama,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                AppLocalizations.of(context).statsBuDonemdeHenuzCalisma,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          for (var i = 0; i < rows.length; i++)
            _LeaderboardRow(
              rank: i + 1,
              name: rows[i].member.displayName,
              avatarUrl: rows[i].member.avatarUrl,
              seconds: rows[i].seconds,
              maxSeconds: maxSeconds,
              streak: streaks[rows[i].member.id] ?? 0,
              isMe: rows[i].member.id == currentUserId,
              profile: rows[i].member.isActive ? rows[i].member : null,
            ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${AppLocalizations.of(context).statsGrupGunlukTrendiSon} · '
                    '${AppLocalizations.of(context).statsStreakGun(chartDays.toString())} · '
                    '${statsPeriodLabel(AppLocalizations.of(context), period)}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 150,
                  child: DailyBarChart(
                    days: lastNDays(const [], chartDays, totals: groupDay),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Grup eğilimi — master dönemle hizalı çizgi penceresi.
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${AppLocalizations.of(context).statsGrupEgilimiSon30} · '
                    '${AppLocalizations.of(context).statsStreakGun(trendDays.toString())} · '
                    '${statsPeriodLabel(AppLocalizations.of(context), period)}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 160,
                  child: DailyLineChart(
                    days: lastNDays(const [], trendDays, totals: groupDay),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _AllTimeCard(
          total: allTimeTotal,
          activeDays: activeDays,
          peak: peak,
          recordStreak: recordStreak,
          consistentName: consistentName,
          consistentStreak: consistentStreak,
        ),
        const SizedBox(height: 16),
        Text(
          AppLocalizations.of(context).statsKarsilastirmaTablosu,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: heatRows.isEmpty
                ? Text(
                    AppLocalizations.of(context).statsUyeYok,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : StatHeatTable(
                    columns: [
                      AppLocalizations.of(context).statsBugun,
                      AppLocalizations.of(context).statsHafta,
                      AppLocalizations.of(context).statsAy,
                    ],
                    rows: heatRows,
                  ),
          ),
        ),
      ],
    );
  }
}

/// Grup günlük hedefi kartı: bugünkü grup toplamının hedefe oranı + grup serisi.
class _GroupGoalCard extends StatelessWidget {
  const _GroupGoalCard({
    required this.todaySeconds,
    required this.goalSeconds,
    required this.streak,
  });

  final int todaySeconds;
  final int goalSeconds;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = goalSeconds <= 0
        ? 0.0
        : (todaySeconds / goalSeconds).clamp(0.0, 1.0);
    final reached = goalSeconds > 0 && todaySeconds >= goalSeconds;
    final fire = subjectColor('chart-5');
    final barColor = reached
        ? subjectColor('chart-2')
        : theme.colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, size: 20, color: barColor),
                const SizedBox(width: 6),
                Text(
                  AppLocalizations.of(context).statsBugunkuGrupHedefi,
                  style: theme.textTheme.titleMedium,
                ),
                const Spacer(),
                if (streak > 0) ...[
                  Icon(Icons.local_fire_department, size: 18, color: fire),
                  const SizedBox(width: 2),
                  Text(
                    AppLocalizations.of(
                      context,
                    ).statsStreakGun(streak.toString()),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: fire,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${formatHuman(todaySeconds)} / ${formatHuman(goalSeconds)}',
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  '%${(pct * 100).round()}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: barColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            ),
            if (reached) ...[
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context).statsGrupBugunkuHedefiniTuttu,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: subjectColor('chart-2'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tüm-zamanlar sınıf metrikleri kartı (§WP-10): grup geneli toplam, aktif gün
/// sayısı, en yoğun gün, grup rekor serisi ve en istikrarlı üye.
class _AllTimeCard extends StatelessWidget {
  const _AllTimeCard({
    required this.total,
    required this.activeDays,
    required this.peak,
    required this.recordStreak,
    required this.consistentName,
    required this.consistentStreak,
  });

  final int total;
  final int activeDays;
  final DayTotal? peak;
  final int recordStreak;
  final String? consistentName;
  final int consistentStreak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fire = subjectColor('chart-5');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_graph,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  AppLocalizations.of(context).statsTumZamanlar,
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _Metric(
                    label: AppLocalizations.of(context).statsGrupToplami,
                    value: formatHuman(total),
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: AppLocalizations.of(context).statsAktifGun,
                    value: '$activeDays',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: AppLocalizations.of(context).statsRekorSeri,
                    value: recordStreak > 0
                        ? AppLocalizations.of(
                            context,
                          ).statsStreakGun(recordStreak.toString())
                        : '—',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 12),
            _AllTimeRow(
              icon: Icons.event_available_outlined,
              label: AppLocalizations.of(context).statsEnYogunGun,
              value: peak == null
                  ? '—'
                  : '${DateFormat.yMd(AppLocalizations.of(context).localeName).format(peak!.day)} · '
                        '${formatHuman(peak!.seconds)}',
            ),
            const SizedBox(height: 8),
            _AllTimeRow(
              icon: Icons.local_fire_department,
              iconColor: fire,
              label: AppLocalizations.of(context).statsEnIstikrarliUye,
              value: consistentName == null || consistentStreak <= 0
                  ? '—'
                  : '$consistentName · '
                        '${AppLocalizations.of(context).statsStreakGun(consistentStreak.toString())}',
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AllTimeRow extends StatelessWidget {
  const _AllTimeRow({
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: iconColor ?? theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Sınıf özet kartı (toplam / ortalama).
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.seconds});

  final String label;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(formatHuman(seconds), style: theme.textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

/// Tek bir leaderboard satırı: sıra, isim, oransal çubuk ve süre.
class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.rank,
    required this.name,
    required this.avatarUrl,
    required this.seconds,
    required this.maxSeconds,
    required this.streak,
    required this.isMe,
    this.profile,
  });

  final int rank;
  final String name;
  final String? avatarUrl;
  final int seconds;
  final int maxSeconds;
  final int streak;
  final bool isMe;
  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fraction = maxSeconds <= 0 ? 0.0 : seconds / maxSeconds;
    final medal = switch (rank) {
      1 => '🥇',
      2 => '🥈',
      3 => '🥉',
      _ => '$rank.',
    };

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(medal, style: theme.textTheme.titleMedium),
          ),
          const SizedBox(width: 8),
          if (profile != null)
            LiveCrownedAvatar(
              userId: profile!.id,
              displayName: name,
              avatarUrl: avatarUrl,
              radius: 16,
            )
          else
            CrownedAvatar(displayName: name, avatarUrl: avatarUrl, radius: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        isMe ? '$name (sen)' : name,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (streak > 0) ...[
                          Icon(
                            Icons.local_fire_department,
                            size: 14,
                            color: subjectColor('chart-5'),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '$streak',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: subjectColor('chart-5'),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          formatHuman(seconds),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    color: isMe
                        ? theme.colorScheme.primary
                        : theme.colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (profile == null) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => openMemberProfile(context, profile!),
      child: row,
    );
  }
}
