import 'package:flutter/material.dart';

import '../classroom/widgets/study_timer_card.dart';
import 'widgets/leaderboard_card.dart';
import 'widgets/today_summary_card.dart';
import 'widgets/weekly_chart_card.dart';

/// Ana Sayfa kontrol panelinde gösterilebilecek kart türleri (§3.9). Kullanıcı
/// hangilerini göreceğini ve sırasını kendi seçer.
enum DashboardCardType { timer, today, weekly, leaderboard }

extension DashboardCardInfo on DashboardCardType {
  String get title => switch (this) {
        DashboardCardType.timer => 'Sayaç',
        DashboardCardType.today => 'Bugün özeti',
        DashboardCardType.weekly => 'Haftalık grafik',
        DashboardCardType.leaderboard => 'Sınıf sıralaması',
      };

  String get description => switch (this) {
        DashboardCardType.timer => 'Kronometre, günlük hedef ve seri',
        DashboardCardType.today => 'Bugünkü toplam ve ders dağılımı',
        DashboardCardType.weekly => 'Son 7 günün çubuk grafiği',
        DashboardCardType.leaderboard => 'Aktif sınıfın bugünkü sıralaması',
      };

  IconData get icon => switch (this) {
        DashboardCardType.timer => Icons.timer_outlined,
        DashboardCardType.today => Icons.today_outlined,
        DashboardCardType.weekly => Icons.bar_chart,
        DashboardCardType.leaderboard => Icons.leaderboard_outlined,
      };
}

/// Bir kart türünün widget'ını üretir.
Widget dashboardCardFor(DashboardCardType type) {
  switch (type) {
    case DashboardCardType.timer:
      return const StudyTimerCard();
    case DashboardCardType.today:
      return const TodaySummaryCard();
    case DashboardCardType.weekly:
      return const WeeklyChartCard();
    case DashboardCardType.leaderboard:
      return const LeaderboardCard();
  }
}
