import 'package:flutter/material.dart';

import '../classroom/widgets/study_timer_card.dart';
import 'widgets/goal_card.dart';
import 'widgets/heatmap_card.dart';
import 'widgets/hour_activity_card.dart';
import 'widgets/leaderboard_card.dart';
import 'widgets/line_chart_card.dart';
import 'widgets/period_summary_card.dart';
import 'widgets/rhythm_card.dart';
import 'widgets/today_summary_card.dart';
import 'widgets/weekday_weekend_card.dart';
import 'widgets/weekly_chart_card.dart';

/// Ana Sayfa kontrol panelinde gösterilebilecek kart türleri (§3.9). Kullanıcı
/// hangilerini göreceğini, sırasını ve boyutunu kendi seçer.
enum DashboardCardType {
  timer,
  goal,
  today,
  weekly,
  line,
  monthly,
  weekdayWeekend,
  hours,
  rhythm,
  heatmap,
  leaderboard,
}

extension DashboardCardInfo on DashboardCardType {
  String get title => switch (this) {
        DashboardCardType.timer => 'Sayaç',
        DashboardCardType.goal => 'Günlük hedef',
        DashboardCardType.today => 'Bugün özeti',
        DashboardCardType.weekly => 'Haftalık grafik',
        DashboardCardType.line => 'Eğilim grafiği',
        DashboardCardType.monthly => 'Dönem özeti',
        DashboardCardType.weekdayWeekend => 'Hafta içi / sonu',
        DashboardCardType.hours => 'Çalışma saatleri',
        DashboardCardType.rhythm => 'Haftalık ritim',
        DashboardCardType.heatmap => 'Çalışma takvimi',
        DashboardCardType.leaderboard => 'Grup sıralaması',
      };

  String get description => switch (this) {
        DashboardCardType.timer => 'Kronometre, günlük hedef ve seri',
        DashboardCardType.goal => 'Hedef ilerlemesi ve büyük seri göstergesi',
        DashboardCardType.today => 'Bugünkü toplam ve ders dağılımı',
        DashboardCardType.weekly => 'Günlük çubuk grafiği (7/14/30 gün filtreli)',
        DashboardCardType.line => 'Çalışma eğilimi çizgi grafiği (14/30/90 gün)',
        DashboardCardType.monthly => 'Bugün / hafta / ay / yıl toplam ve ortalama',
        DashboardCardType.weekdayWeekend => 'Hafta içi ile hafta sonu kıyası',
        DashboardCardType.hours => 'Günün hangi saatlerinde çalıştığın',
        DashboardCardType.rhythm => 'Haftanın gün × saat çalışma ısı haritası',
        DashboardCardType.heatmap => 'GitHub tarzı çalışma yoğunluğu ısı haritası',
        DashboardCardType.leaderboard => 'Aktif grubun bugünkü sıralaması',
      };

  IconData get icon => switch (this) {
        DashboardCardType.timer => Icons.timer_outlined,
        DashboardCardType.goal => Icons.flag_outlined,
        DashboardCardType.today => Icons.today_outlined,
        DashboardCardType.weekly => Icons.bar_chart,
        DashboardCardType.line => Icons.show_chart,
        DashboardCardType.monthly => Icons.calendar_month_outlined,
        DashboardCardType.weekdayWeekend => Icons.weekend_outlined,
        DashboardCardType.hours => Icons.schedule_outlined,
        DashboardCardType.rhythm => Icons.view_week_outlined,
        DashboardCardType.heatmap => Icons.grid_on_outlined,
        DashboardCardType.leaderboard => Icons.leaderboard_outlined,
      };
}

/// Kart boyutu (§3.11). Küçük = yarım genişlik (yan yana 2'li), Orta = tam
/// genişlik, Büyük = tam genişlik + daha çok içerik (uzun grafik/geniş takvim).
enum DashboardCardSize { small, medium, large }

extension DashboardCardSizeInfo on DashboardCardSize {
  String get label => switch (this) {
        DashboardCardSize.small => 'Küçük',
        DashboardCardSize.medium => 'Orta',
        DashboardCardSize.large => 'Büyük',
      };

  IconData get icon => switch (this) {
        DashboardCardSize.small => Icons.crop_square,
        DashboardCardSize.medium => Icons.crop_7_5,
        DashboardCardSize.large => Icons.crop_16_9,
      };

  /// Küçük kartlar yarım genişlik (grid'de yan yana 2 tane), diğerleri tam.
  bool get isHalfWidth => this == DashboardCardSize.small;

  /// Sıradaki boyut (döngüsel: küçük → orta → büyük → küçük).
  DashboardCardSize get next => switch (this) {
        DashboardCardSize.small => DashboardCardSize.medium,
        DashboardCardSize.medium => DashboardCardSize.large,
        DashboardCardSize.large => DashboardCardSize.small,
      };
}

/// Bir Ana Sayfa kartının yapılandırması: tür + boyut (§3.11). Kalıcılık için
/// `"tür:boyut"` (ör. `"weekly:large"`) biçiminde serileştirilir.
class DashboardCardConfig {
  const DashboardCardConfig(this.type,
      {this.size = DashboardCardSize.medium});

  final DashboardCardType type;
  final DashboardCardSize size;

  DashboardCardConfig withSize(DashboardCardSize size) =>
      DashboardCardConfig(type, size: size);

  /// `"tür:boyut"` (ör. `"weekly:large"`).
  String encode() => '${type.name}:${size.name}';

  /// `"tür:boyut"` (veya eski biçimde sade `"tür"`) çözümler; geçersizse null.
  static DashboardCardConfig? decode(String raw) {
    final parts = raw.split(':');
    DashboardCardType? type;
    for (final t in DashboardCardType.values) {
      if (t.name == parts.first) {
        type = t;
        break;
      }
    }
    if (type == null) return null;
    var size = DashboardCardSize.medium;
    if (parts.length > 1) {
      for (final s in DashboardCardSize.values) {
        if (s.name == parts[1]) {
          size = s;
          break;
        }
      }
    }
    return DashboardCardConfig(type, size: size);
  }

  @override
  bool operator ==(Object other) =>
      other is DashboardCardConfig &&
      other.type == type &&
      other.size == size;

  @override
  int get hashCode => Object.hash(type, size);
}

/// Bir kart türünün widget'ını, seçilen boyuta göre üretir.
Widget dashboardCardFor(DashboardCardType type, DashboardCardSize size) {
  switch (type) {
    case DashboardCardType.timer:
      return StudyTimerCard(size: size);
    case DashboardCardType.goal:
      return GoalCard(size: size);
    case DashboardCardType.today:
      return TodaySummaryCard(size: size);
    case DashboardCardType.weekly:
      return WeeklyChartCard(size: size);
    case DashboardCardType.line:
      return LineChartCard(size: size);
    case DashboardCardType.monthly:
      return PeriodSummaryCard(size: size);
    case DashboardCardType.weekdayWeekend:
      return WeekdayWeekendCard(size: size);
    case DashboardCardType.hours:
      return HourActivityCard(size: size);
    case DashboardCardType.rhythm:
      return RhythmCard(size: size);
    case DashboardCardType.heatmap:
      return HeatmapCard(size: size);
    case DashboardCardType.leaderboard:
      return const LeaderboardCard();
  }
}
