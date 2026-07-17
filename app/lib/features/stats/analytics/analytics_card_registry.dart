import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:online_study_room/l10n/app_localizations.dart';

import '../../../core/stats/study_stats.dart';
import '../../../core/theme/subject_colors.dart';
import '../../../core/utils/duration_format.dart';
import '../../../data/models/study_session.dart';
import '../../../data/models/subject.dart';
import '../../../data/providers/analytics_query_providers.dart';
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

/// WP-159–164: kart kataloğu → widget (gerçek veri; placeholder yok).
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
    // Grid Positioned zaten boyut verir; iç yükseklik h hücrelerine bağlı.
    final h = (config.h * 56.0).clamp(100.0, 480.0);

    return SizedBox(
      height: h,
      width: double.infinity,
      child: AnalyticsCardShell(
        title: title,
        child: _body(context, ref, config, surface, period, l10n),
      ),
    );
  }

  static String titleFor(AppLocalizations l10n, AnalyticsCardType t) {
    return switch (t) {
      AnalyticsCardType.totalPeriod => l10n.analyticsCardTotalPeriod,
      AnalyticsCardType.goalGauge => l10n.homeGunlukHedef,
      AnalyticsCardType.trendLine => l10n.homeEgilimGrafigi,
      AnalyticsCardType.trendBar => l10n.homeHaftalikGrafik,
      AnalyticsCardType.subjectDonut => l10n.analyticsCardSubjectDonut,
      AnalyticsCardType.subjectStacked => l10n.analyticsCardSubjectStacked,
      AnalyticsCardType.hourOfDay => l10n.homeCalismaSaatleri,
      AnalyticsCardType.weekHourHeat => l10n.homeHaftalikRitim,
      AnalyticsCardType.streakHeatmap => l10n.homeCalismaTakvimi,
      AnalyticsCardType.weekdaySplit => l10n.homeHaftaIciHaftaSonu,
      AnalyticsCardType.records => l10n.homeRekorlar,
      AnalyticsCardType.scatterSessions => l10n.homeOturumDagilimi,
      AnalyticsCardType.periodCompare => l10n.analyticsCardPeriodCompare,
      AnalyticsCardType.insightStrip => l10n.analyticsCardInsight,
      AnalyticsCardType.groupTotal => l10n.analyticsCardGroupTotal,
      AnalyticsCardType.groupGoalGauge => l10n.homeGrupHedefi,
      AnalyticsCardType.groupTrend => l10n.homeGrupGunlukTrendi,
      AnalyticsCardType.groupLeaderboard => l10n.homeGrupSiralamasi,
      AnalyticsCardType.groupLeaderboardHistory =>
        l10n.analyticsCardLeaderboardHistory,
      AnalyticsCardType.groupMemberDonut => l10n.analyticsCardMemberDonut,
      AnalyticsCardType.groupHeatTable => l10n.statsKarsilastirmaTablosu,
      AnalyticsCardType.groupStreak => l10n.analyticsCardGroupStreak,
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
    final effectivePeriod = period.compare == AnalyticsCompare.none &&
            !config.comparePrevious
        ? period
        : AnalyticsPeriod(
            period.kind,
            customFrom: period.customFrom,
            customTo: period.customTo,
            compare: period.compare == AnalyticsCompare.previousEqualLength ||
                    config.comparePrevious
                ? AnalyticsCompare.previousEqualLength
                : AnalyticsCompare.none,
          );
    final (from, to) = effectivePeriod.range();
    final sessionsAsync = ref.watch(analyticsUserSessionsInRangeProvider(period));
    final dayTotalsAsync = ref.watch(analyticsUserDayTotalsProvider(period));
    final subjects = ref.watch(userSubjectsProvider).asData?.value ?? const [];
    final groupStats = ref.watch(groupDailyStatsProvider);
    final members = ref.watch(groupMembersProvider).asData?.value ?? const [];
    final group = ref.watch(userGroupProvider).asData?.value;
    final profile = ref.watch(authStateProvider).asData?.value;
    final contributionAsync =
        ref.watch(analyticsGroupContributionProvider(period));
    final seriesAsync =
        ref.watch(analyticsGroupLeaderboardSeriesProvider(period));

    return switch (config.type) {
      AnalyticsCardType.totalPeriod => dayTotalsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (totals) {
            final sec = totals.values.fold<int>(0, (a, b) => a + b);
            final prevR = effectivePeriod.previousRange();
            if (prevR == null || profile?.id == null) {
              return Center(
                child: Text(
                  formatHuman(sec),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              );
            }
            // Kıyas açıkken önceki dönem toplamı + % değişim.
            return FutureBuilder<int>(
              future: ref
                  .read(analyticsQueryRepositoryProvider)
                  .getUserDayTotals(
                    userId: profile!.id,
                    from: prevR.$1,
                    to: prevR.$2,
                  )
                  .then(
                    (rows) => rows.fold<int>(0, (a, r) => a + r.seconds),
                  ),
              builder: (context, snap) {
                final prev = snap.data ?? 0;
                final delta = prev <= 0
                    ? (sec > 0 ? 100 : 0)
                    : (((sec - prev) / prev) * 100).round();
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      formatHuman(sec),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      '${delta >= 0 ? '+' : ''}$delta% · ${formatHuman(prev)}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: delta >= 0
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      AnalyticsCardType.goalGauge => dayTotalsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (totals) {
            final goal = (profile?.dailyGoalMinutes ?? 360) * 60;
            final today = totals[dayOf(DateTime.now())] ?? 0;
            final p = goal <= 0 ? 0.0 : today / goal;
            return GaugeChart(progress: p, label: l10n.homeGunlukHedef);
          },
        ),
      AnalyticsCardType.trendLine || AnalyticsCardType.trendBar =>
        dayTotalsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (totals) {
            final days = dailyRange(const <StudySession>[], from, to,
                totals: totals);
            if (days.every((d) => d.seconds == 0)) {
              return AnalyticsCardEmpty(
                  message: l10n.statsHenuzCalismaKaydinYok);
            }
            if (config.type == AnalyticsCardType.trendBar) {
              return DailyBarChart(days: days);
            }
            return DailyLineChart(days: days);
          },
        ),
      AnalyticsCardType.subjectDonut => sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) {
            final by = <String, int>{};
            for (final s in sessions) {
              final id = s.subjectId ?? '_';
              by[id] = (by[id] ?? 0) + s.durationSeconds;
            }
            if (by.isEmpty) {
              return AnalyticsCardEmpty(
                  message: l10n.statsHenuzCalismaKaydinYok);
            }
            final palette = SeriesPalette(Theme.of(context).colorScheme);
            var i = 0;
            final slices = [
              for (final e in by.entries)
                SubjectDonutSlice(
                  label: e.key == '_'
                      ? '—'
                      : _subjectName(subjects, e.key),
                  color: e.key == '_'
                      ? palette.colorAt(i++)
                      : subjectColor(
                          _subjectColorToken(subjects, e.key, i++)),
                  seconds: e.value,
                ),
            ];
            return Center(child: SubjectDonut(slices: slices, size: 120));
          },
        ),
      AnalyticsCardType.hourOfDay => sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) =>
              HourActivityChart(hourly: hourlyTotals(sessions)),
        ),
      AnalyticsCardType.weekHourHeat => sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) =>
              WeekHourHeatmap(grid: weekdayHourTotals(sessions)),
        ),
      AnalyticsCardType.weekdaySplit => sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) {
            final split = weekdayWeekendSplit(sessions);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _kv(context, l10n.statsHaftaIci, formatHuman(split.weekday)),
                _kv(context, l10n.statsHaftaSonu, formatHuman(split.weekend)),
              ],
            );
          },
        ),
      AnalyticsCardType.records => sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) => StudyRecords(sessions: sessions, columns: 2),
        ),
      AnalyticsCardType.scatterSessions => sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) => SessionScatterChart(sessions: sessions),
        ),
      AnalyticsCardType.streakHeatmap => sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) {
            final streak = studyStreak(sessions);
            return Column(
              children: [
                Text(
                  '${l10n.homeCalismaTakvimi}: $streak',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Expanded(child: StudyHeatmap(sessions: sessions, weeks: 12)),
              ],
            );
          },
        ),
      AnalyticsCardType.subjectStacked => sessionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (sessions) {
            if (sessions.isEmpty) {
              return AnalyticsCardEmpty(
                  message: l10n.statsHenuzCalismaKaydinYok);
            }
            // Gerçek konu×gün yığını (placeholder 60/40 yok).
            final subjectIds = <String?>{};
            final byDaySubject = <DateTime, Map<String?, int>>{};
            for (final s in sessions) {
              final d = dayOf(s.start);
              subjectIds.add(s.subjectId);
              final m = byDaySubject.putIfAbsent(d, () => {});
              m[s.subjectId] = (m[s.subjectId] ?? 0) + s.durationSeconds;
            }
            final series = subjectIds.toList()
              ..sort((a, b) {
                final sa = sessions
                    .where((s) => s.subjectId == a)
                    .fold<int>(0, (x, s) => x + s.durationSeconds);
                final sb = sessions
                    .where((s) => s.subjectId == b)
                    .fold<int>(0, (x, s) => x + s.durationSeconds);
                return sb.compareTo(sa);
              });
            // En fazla 6 seri (okunabilirlik).
            final top = series.take(6).toList();
            final days = dailyRange(const [], from, to);
            final stacks = [
              for (final d in days)
                [
                  for (final sid in top)
                    (byDaySubject[d.day]?[sid] ?? 0).toDouble(),
                ],
            ];
            final names = [
              for (final sid in top)
                sid == null ? '—' : _subjectName(subjects, sid),
            ];
            return StackedBarChart(stacks: stacks, seriesNames: names);
          },
        ),
      AnalyticsCardType.periodCompare => dayTotalsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (totals) {
            final cur = totals.values.fold<int>(0, (a, b) => a + b);
            final comparePeriod = AnalyticsPeriod(
              period.kind,
              customFrom: period.customFrom,
              customTo: period.customTo,
              compare: AnalyticsCompare.previousEqualLength,
            );
            final prevR = comparePeriod.previousRange();
            return FutureBuilder<Map<DateTime, int>>(
              future: prevR == null
                  ? Future.value(const {})
                  : ref
                      .read(analyticsQueryRepositoryProvider)
                      .getUserDayTotals(
                        userId: profile?.id ?? '',
                        from: prevR.$1,
                        to: prevR.$2,
                      )
                      .then(
                        (rows) => {
                          for (final r in rows) dayOf(r.day): r.seconds,
                        },
                      ),
              builder: (context, snap) {
                final prevMap = snap.data ?? const {};
                final prev =
                    prevMap.values.fold<int>(0, (a, b) => a + b);
                final delta = prev <= 0
                    ? (cur > 0 ? 100 : 0)
                    : (((cur - prev) / prev) * 100).round();
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      formatHuman(cur),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
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
            );
          },
        ),
      AnalyticsCardType.insightStrip => dayTotalsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (totals) {
            final sec = totals.values.fold<int>(0, (a, b) => a + b);
            final msg = sec <= 0
                ? l10n.statsHenuzCalismaKaydinYok
                : '${formatHuman(sec)} · ${l10n.statsIstatistik}';
            return Center(child: Text(msg, textAlign: TextAlign.center));
          },
        ),
      AnalyticsCardType.groupTotal => groupStats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (stats) {
            final totals = userTotalsInRange(stats, from, to);
            final sum = totals.values.fold<int>(0, (a, b) => a + b);
            return Center(
              child: Text(
                formatHuman(sum),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            );
          },
        ),
      AnalyticsCardType.groupGoalGauge => groupStats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
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
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (stats) {
            final dayMap = groupDayTotals(stats);
            final days =
                dailyRange(const <StudySession>[], from, to, totals: dayMap);
            return AreaLineChart(
              values: [for (final d in days) d.seconds.toDouble()],
            );
          },
        ),
      AnalyticsCardType.groupLeaderboard => groupStats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (stats) {
            final totals = userTotalsInRange(stats, from, to);
            final rows = [
              for (final m in members) (m, totals[m.id] ?? 0),
            ]..sort((a, b) => b.$2.compareTo(a.$2));
            if (rows.isEmpty) {
              return AnalyticsCardEmpty(
                  message: l10n.statsHenuzCalismaKaydinYok);
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
      AnalyticsCardType.groupMemberDonut => contributionAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (rows) {
            if (rows.isEmpty) {
              return AnalyticsCardEmpty(
                  message: l10n.statsHenuzCalismaKaydinYok);
            }
            final nameOf = {for (final m in members) m.id: m.displayName};
            final palette = SeriesPalette(Theme.of(context).colorScheme);
            var i = 0;
            final slices = [
              for (final r in rows)
                if (r.seconds > 0)
                  SubjectDonutSlice(
                    label: (nameOf[r.userId] ?? '').isEmpty
                        ? l10n.statsIsimsiz
                        : nameOf[r.userId]!,
                    color: palette.colorAt(i++),
                    seconds: r.seconds,
                  ),
            ];
            if (slices.isEmpty) {
              return AnalyticsCardEmpty(
                  message: l10n.statsHenuzCalismaKaydinYok);
            }
            return Center(child: SubjectDonut(slices: slices, size: 120));
          },
        ),
      AnalyticsCardType.groupHeatTable => groupStats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (stats) {
            final now = DateTime.now();
            final todayTotals = userTotalsInRange(stats, dayOf(now), now);
            final weekTotals =
                userTotalsInRange(stats, startOfWeek(now), now);
            final monthTotals =
                userTotalsInRange(stats, startOfMonth(now), now);
            final heatRows = [
              for (final m in members)
                HeatRow(
                  label: m.displayName.isEmpty
                      ? l10n.statsIsimsiz
                      : m.displayName,
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
              columns: [
                l10n.statsBugun,
                l10n.statsHafta,
                l10n.statsAy,
              ],
              rows: heatRows,
            );
          },
        ),
      AnalyticsCardType.groupStreak => groupStats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (stats) {
            final goal = (group?.dailyGoalMinutes ?? 360) * 60;
            final streak = currentStreak(
              const [],
              goal,
              totals: groupDayTotals(stats),
            );
            return Center(
              child: Text(
                '$streak',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            );
          },
        ),
      AnalyticsCardType.groupLeaderboardHistory => seriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) =>
              AnalyticsCardEmpty(message: l10n.authBeklenmeyenBirHataOlustu),
          data: (points) {
            if (points.isEmpty) {
              return AnalyticsCardEmpty(
                  message: l10n.statsHenuzCalismaKaydinYok);
            }
            // Dönem günleri için toplam üye saniyesi (gerçek series RPC).
            final byDay = <DateTime, int>{};
            for (final p in points) {
              final d = dayOf(p.day);
              byDay[d] = (byDay[d] ?? 0) + p.seconds;
            }
            final days =
                dailyRange(const <StudySession>[], from, to, totals: byDay);
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
