/// WP-156/157+: tam 22 kart kataloğu (kişisel + grup).
enum AnalyticsSurface { personalStats, groupStats }

enum AnalyticsCardType {
  // Kişisel
  totalPeriod,
  goalGauge,
  trendLine,
  trendBar,
  subjectDonut,
  subjectStacked,
  hourOfDay,
  weekHourHeat,
  streakHeatmap,
  weekdaySplit,
  records,
  scatterSessions,
  periodCompare,
  insightStrip,
  // Grup
  groupTotal,
  groupGoalGauge,
  groupTrend,
  groupLeaderboard,
  groupLeaderboardHistory,
  groupMemberDonut,
  groupHeatTable,
  groupStreak,
}

extension AnalyticsCardTypeX on AnalyticsCardType {
  bool get isGroupOnly => switch (this) {
        AnalyticsCardType.groupTotal ||
        AnalyticsCardType.groupGoalGauge ||
        AnalyticsCardType.groupTrend ||
        AnalyticsCardType.groupLeaderboard ||
        AnalyticsCardType.groupLeaderboardHistory ||
        AnalyticsCardType.groupMemberDonut ||
        AnalyticsCardType.groupHeatTable ||
        AnalyticsCardType.groupStreak =>
          true,
        _ => false,
      };

  bool get isPersonalOnly => !isGroupOnly;

  bool allowedOn(AnalyticsSurface surface) {
    return switch (surface) {
      AnalyticsSurface.personalStats => isPersonalOnly,
      AnalyticsSurface.groupStats =>
        isGroupOnly ||
            this == AnalyticsCardType.trendLine ||
            this == AnalyticsCardType.trendBar,
    };
  }

  /// Varsayılan hücre boyutu (6 sütun ızgaraya göre).
  (int w, int h) get defaultCells => switch (this) {
        AnalyticsCardType.totalPeriod ||
        AnalyticsCardType.goalGauge ||
        AnalyticsCardType.groupTotal ||
        AnalyticsCardType.groupGoalGauge ||
        AnalyticsCardType.groupStreak ||
        AnalyticsCardType.insightStrip =>
          (3, 2),
        AnalyticsCardType.streakHeatmap ||
        AnalyticsCardType.groupHeatTable ||
        AnalyticsCardType.weekHourHeat ||
        AnalyticsCardType.subjectStacked ||
        AnalyticsCardType.periodCompare =>
          (6, 3),
        _ => (6, 3),
      };
}
