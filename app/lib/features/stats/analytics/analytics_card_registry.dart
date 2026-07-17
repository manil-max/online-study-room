import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/study_session.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/auth_providers.dart';
import '../../../data/providers/group_providers.dart';
import '../../../data/providers/study_providers.dart';
import '../../../data/providers/subject_providers.dart';
import '../charts/area_line_chart.dart';
import '../charts/gauge_chart.dart';
import '../charts/series_palette.dart';
import '../charts/stacked_bar_chart.dart';
import '../widgets/daily_bar_chart.dart';
import '../widgets/daily_line_chart.dart';
import '../widgets/hour_activity_chart.dart';
import '../widgets/session_scatter_chart.dart';
import '../widgets/stat_heat_table.dart';
import '../widgets/study_heatmap.dart';
import '../widgets/study_records.dart';
import '../widgets/subject_donut.dart';
import '../widgets/week_hour_heatmap.dart';
import 'analytics_card_config.dart';
import 'analytics_card_shell.dart';
import 'analytics_card_type.dart';
import 'analytics_period.dart';

/// WP-159–161: kart kataloğu → widget.
class AnalyticsCardRegistry {
  const AnalyticsCardRegistry._();

  static Widget build({
    required BuildContext context,
    required WidgetRef ref,
    required AnalyticsCardConfig config,
    required AnalyticsSurface surface,
    required AnalyticsPeriod period,
  }) {
    final l10n = AppLocalizations.of(context);
    final title = titleFor(l10n, config.type);
    final h = (config.h * 56.0).clamp(120.0, 420.0);

    return SizedBox(
      height: h,
      child: AnalyticsCardShell(
        title: title,
        child: _body(context, ref, config, surface, period, l10n),
      ),
    );
  }

  static String titleFor(AppLocalizations l10n, AnalyticsCardType t) {
    // Geçici: mevcut stats string'leri + type name; WP-162 ARB zenginleştirir.
    return switch (t) {
      AnalyticsCardType.totalPeriod => l10n.statsIstatistik,
      AnalyticsCardType.goalGauge => l10n.homeGunlukHedef,
      AnalyticsCardType.trendLine => l10n.homeEgilimGrafigi,
      AnalyticsCardType.trendBar => l10n.homeHaftalikGrafik,
      AnalyticsCardType.subjectDonut => l10n.statsIstatistik,
      AnalyticsCardType.hourOfDay => l10n.homeCalismaSaatleri,
      AnalyticsCardType.weekHourHeat => l10n.homeHaftalikRitim,
      AnalyticsCardType.streakHeatmap => l10n.homeCalismaTakvimi,
      AnalyticsCardType.records => l10n.homeRekorlar,
      AnalyticsCardType.scatterSessions => l10n.homeOturumDagilimi,
      AnalyticsCardType.groupTrend => l10n.homeGrupGunlukTrendi,
      AnalyticsCardType.groupLeaderboard => l10n.homeGrupSiralamasi,
      AnalyticsCardType.groupGoalGauge => l10n.homeGrupHedefi,
      _ => t.name,
    };
  }

  static Widget _body(
    BuildContext context,
    WidgetRef ref,
    AnalyticsCardConfig config,
    AnalyticsSurface surface,
    AnalyticsPeriod period,
    AppLocalizations l10n,
  ) {
    final sessionsAsync = ref.watch(userSessionsProvider);
    final subjects = ref.watch(userSubjectsProvider).asData?.value ?? const [];
    final groupStats = ref.watch(groupDailyStatsProvider);
    final members = ref.watch(groupMembersProvider).asData?.value ?? const [];
    final group = ref.watch(userGroupProvider).asData?.value;
    final profile = ref.watch(authStateProvider).asData?.value;
    final (from, to) = period.range();

    return switch (config.type) {
      AnalyticsCardType.totalPeriod => sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) {
            final sec = totalSeconds(inRange(sessions, from, to));
            return Center(
              child: Text(
                formatHuman(sec),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            );
          },
        ),
      AnalyticsCardType.goalGauge => sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) {
            final goal = (profile?.dailyGoalMinutes ?? 360) * 60;
            final today = secondsOnDay(sessions, DateTime.now());
            final p = goal <= 0 ? 0.0 : today / goal;
            return GaugeChart(progress: p, label: l10n.homeGunlukHedef);
          },
        ),
      AnalyticsCardType.trendLine || AnalyticsCardType.trendBar =>
        sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) {
            final days = lastNDays(sessions, 14);
            if (days.isEmpty) {
              return AnalyticsCardEmpty(message: l10n.statsHenuzCalismaKaydinYok);
            }
            if (config.type == AnalyticsCardType.trendBar) {
              return DailyBarChart(days: days);
            }
            return DailyLineChart(days: days);
          },
        ),
      AnalyticsCardType.subjectDonut => sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) {
            final periodSessions = inRange(sessions, from, to).toList();
            final by = <String, int>{};
            for (final s in periodSessions) {
              final id = s.subjectId ?? '_';
              by[id] = (by[id] ?? 0) + s.durationSeconds;
            }
            if (by.isEmpty) {
              return AnalyticsCardEmpty(message: l10n.statsHenuzCalismaKaydinYok);
            }
            final palette = SeriesPalette(Theme.of(context).colorScheme);
            var i = 0;
            final slices = [
              for (final e in by.entries)
                SubjectDonutSlice(
                  label: e.key == '_' ? '—' : _subjectName(subjects, e.key),
                  color: e.key == '_'
                      ? palette.colorAt(i++)
                      : subjectColor(_subjectColorToken(subjects, e.key, i++)),
                  seconds: e.value,
                ),
            ];
            return Center(child: SubjectDonut(slices: slices, size: 120));
          },
        ),
      AnalyticsCardType.hourOfDay => sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) => HourActivityChart(
            hourly: hourlyTotals(inRange(sessions, from, to)),
          ),
        ),
      AnalyticsCardType.weekHourHeat => sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) => WeekHourHeatmap(
            grid: weekdayHourTotals(inRange(sessions, from, to)),
          ),
        ),
      AnalyticsCardType.weekdaySplit => sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) {
            final split = weekdayWeekendSplit(inRange(sessions, from, to));
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _kv(context, l10n.homeHaftaIciHaftaSonu, formatHuman(split.weekday)),
                _kv(context, 'WE', formatHuman(split.weekend)),
              ],
            );
          },
        ),
      AnalyticsCardType.records => sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) => StudyRecords(sessions: sessions, columns: 2),
        ),
      AnalyticsCardType.scatterSessions => sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) =>
              SessionScatterChart(sessions: inRange(sessions, from, to).toList()),
        ),
      AnalyticsCardType.streakHeatmap => sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) {
            final streak = studyStreak(sessions);
            return Column(
              children: [
                Text('${l10n.homeCalismaTakvimi}: $streak',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Expanded(child: StudyHeatmap(sessions: sessions, weeks: 12)),
              ],
            );
          },
        ),
      AnalyticsCardType.subjectStacked => sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) {
            final days = lastNDays(sessions, 7);
            if (days.isEmpty) {
              return AnalyticsCardEmpty(message: l10n.statsHenuzCalismaKaydinYok);
            }
            // Basit 2 seri: first half subjects vs rest (placeholder stack).
            final stacks = [
              for (final d in days)
                [d.seconds * 0.6, d.seconds * 0.4],
            ];
            return StackedBarChart(stacks: stacks);
          },
        ),
      AnalyticsCardType.periodCompare => sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) {
            final cur = totalSeconds(inRange(sessions, from, to));
            final prevR = period.previousRange() ??
                AnalyticsPeriod(
                  period.kind,
                  compare: AnalyticsCompare.previousEqualLength,
                ).previousRange();
            final prev = prevR == null
                ? 0
                : totalSeconds(inRange(sessions, prevR.$1, prevR.$2));
            final delta = prev <= 0
                ? (cur > 0 ? 100 : 0)
                : (((cur - prev) / prev) * 100).round();
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(formatHuman(cur),
                    style: Theme.of(context).textTheme.headlineSmall),
                Text(
                  '${delta >= 0 ? '+' : ''}$delta%',
                  style: TextStyle(
                    color: delta >= 0
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          },
        ),
      AnalyticsCardType.insightStrip => sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) {
            final sec = totalSeconds(inRange(sessions, from, to));
            final msg = sec <= 0
                ? l10n.statsHenuzCalismaKaydinYok
                : '${formatHuman(sec)} · ${l10n.statsIstatistik}';
            return Center(child: Text(msg, textAlign: TextAlign.center));
          },
        ),
      AnalyticsCardType.groupTotal => groupStats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (stats) {
            final totals = userTotalsInRange(stats, from, to);
            final sum = totals.values.fold<int>(0, (a, b) => a + b);
            return Center(
              child: Text(formatHuman(sum),
                  style: Theme.of(context).textTheme.headlineSmall),
            );
          },
        ),
      AnalyticsCardType.groupGoalGauge => groupStats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (stats) {
            final goal = (group?.dailyGoalMinutes ?? 360) * 60;
            final dayMap = groupDayTotals(stats);
            final today = dayMap[dayOf(DateTime.now())] ?? 0;
            return GaugeChart(
              progress: goal <= 0 ? 0 : today / goal,
              label: l10n.homeGrupHedefi,
            );
          },
        ),
      AnalyticsCardType.groupTrend => groupStats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (stats) {
            final dayMap = groupDayTotals(stats);
            final days = lastNDays(const <StudySession>[], 14, totals: dayMap);
            return AreaLineChart(
              values: [for (final d in days) d.seconds.toDouble()],
            );
          },
        ),
      AnalyticsCardType.groupLeaderboard => groupStats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (stats) {
            final totals = userTotalsInRange(stats, from, to);
            final rows = [
              for (final m in members) (m, totals[m.id] ?? 0),
            ]..sort((a, b) => b.$2.compareTo(a.$2));
            if (rows.isEmpty) {
              return AnalyticsCardEmpty(message: l10n.statsHenuzCalismaKaydinYok);
            }
            return ListView(
              children: [
                for (var i = 0; i < rows.length && i < 5; i++)
                  ListTile(
                    dense: true,
                    leading: Text('${i + 1}'),
                    title: Text(
                      rows[i].$1.displayName.isEmpty
                          ? l10n.statsIsimsiz
                          : rows[i].$1.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Text(formatHuman(rows[i].$2)),
                  ),
              ],
            );
          },
        ),
      AnalyticsCardType.groupMemberDonut => groupStats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (stats) {
            final totals = userTotalsInRange(stats, from, to);
            if (totals.isEmpty) {
              return AnalyticsCardEmpty(message: l10n.statsHenuzCalismaKaydinYok);
            }
            final palette = SeriesPalette(Theme.of(context).colorScheme);
            var i = 0;
            final slices = [
              for (final m in members)
                if ((totals[m.id] ?? 0) > 0)
                  SubjectDonutSlice(
                    label: m.displayName.isEmpty ? l10n.statsIsimsiz : m.displayName,
                    color: palette.colorAt(i++),
                    seconds: totals[m.id] ?? 0,
                  ),
            ];
            if (slices.isEmpty) {
              return AnalyticsCardEmpty(message: l10n.statsHenuzCalismaKaydinYok);
            }
            return Center(child: SubjectDonut(slices: slices, size: 120));
          },
        ),
      AnalyticsCardType.groupHeatTable => groupStats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (stats) {
            final now = DateTime.now();
            final todayTotals = userTotalsInRange(stats, dayOf(now), now);
            final weekTotals = userTotalsInRange(stats, startOfWeek(now), now);
            final monthTotals = userTotalsInRange(stats, startOfMonth(now), now);
            final heatRows = [
              for (final m in members)
                HeatRow(
                  label: m.displayName.isEmpty ? l10n.statsIsimsiz : m.displayName,
                  avatarUrl: m.avatarUrl,
                  userId: m.id,
                  highlight: m.id == profile?.id,
                  values: [
                    todayTotals[m.id] ?? 0,
                    weekTotals[m.id] ?? 0,
                    monthTotals[m.id] ?? 0,
                  ],
                ),
            ];
            return StatHeatTable(
              columns: [l10n.statsBugun, l10n.statsIstatistik, l10n.statsIstatistik],
              rows: heatRows,
            );
          },
        ),
      AnalyticsCardType.groupStreak => groupStats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (stats) {
            final goal = (group?.dailyGoalMinutes ?? 360) * 60;
            final streak = currentStreak(const [], goal, totals: groupDayTotals(stats));
            return Center(
              child: Text(
                '$streak',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            );
          },
        ),
      AnalyticsCardType.groupLeaderboardHistory => groupStats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (stats) {
            // v1: son 14 gün grup toplam alanı (history RPC gelince multi-line).
            final dayMap = groupDayTotals(stats);
            final days = lastNDays(const <StudySession>[], 14, totals: dayMap);
            return AreaLineChart(
              values: [for (final d in days) d.seconds.toDouble()],
            );
          },
        ),
    };
  }

  static Widget _kv(BuildContext context, String k, String v) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(v, style: Theme.of(context).textTheme.titleMedium),
        Text(k, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

String _subjectName(List<Subject> subjects, String id) {
  for (final s in subjects) {
    if (s.id == id) return s.name;
  }
  return id;
}

String _subjectColorToken(List<Subject> subjects, String id, int i) {
  for (final s in subjects) {
    if (s.id == id && s.color.isNotEmpty) return s.color;
  }
  return 'chart-${(i % 5) + 1}';
}
