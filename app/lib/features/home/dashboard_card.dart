import 'package:flutter/material.dart';

import '../classroom/widgets/study_timer_card.dart';
import 'widgets/active_members_card.dart';
import 'widgets/goal_card.dart';
import 'widgets/group_goal_card.dart';
import 'widgets/group_trend_card.dart';
import 'widgets/heatmap_card.dart';
import 'widgets/hour_activity_card.dart';
import 'widgets/leaderboard_card.dart';
import 'widgets/line_chart_card.dart';
import 'widgets/period_summary_card.dart';
import 'widgets/records_card.dart';
import 'widgets/rhythm_card.dart';
import 'widgets/scatter_card.dart';
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
  scatter,
  records,
  heatmap,
  leaderboard,
  groupGoal,
  groupTrend,
  activeMembers,
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
        DashboardCardType.scatter => 'Oturum dağılımı',
        DashboardCardType.records => 'Rekorlar',
        DashboardCardType.heatmap => 'Çalışma takvimi',
        DashboardCardType.leaderboard => 'Grup sıralaması',
        DashboardCardType.groupGoal => 'Grup hedefi',
        DashboardCardType.groupTrend => 'Grup günlük trendi',
        DashboardCardType.activeMembers => 'Şu an çalışanlar',
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
        DashboardCardType.scatter => 'Her oturum bir nokta (süre × gün, derse göre renkli)',
        DashboardCardType.records => 'Toplam, rekor seri, en verimli gün, en çok ders',
        DashboardCardType.heatmap => 'GitHub tarzı çalışma yoğunluğu ısı haritası',
        DashboardCardType.leaderboard => 'Aktif grubun bugünkü sıralaması',
        DashboardCardType.groupGoal => 'Grubun günlük hedef ilerlemesi + grup serisi',
        DashboardCardType.groupTrend => 'Grubun son günlerdeki toplam çalışma grafiği',
        DashboardCardType.activeMembers => 'Grupta o an çalışan üyeler (canlı süreyle)',
      };

  /// Ekleme menüsünde gruplama başlığı.
  String get category => switch (this) {
        DashboardCardType.timer ||
        DashboardCardType.goal =>
          'Sayaç & Hedef',
        DashboardCardType.today ||
        DashboardCardType.monthly ||
        DashboardCardType.weekdayWeekend ||
        DashboardCardType.records =>
          'Özetler',
        DashboardCardType.weekly ||
        DashboardCardType.line ||
        DashboardCardType.scatter =>
          'Grafikler',
        DashboardCardType.hours ||
        DashboardCardType.rhythm ||
        DashboardCardType.heatmap =>
          'Isı haritaları',
        DashboardCardType.leaderboard ||
        DashboardCardType.groupGoal ||
        DashboardCardType.groupTrend ||
        DashboardCardType.activeMembers =>
          'Grup',
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
        DashboardCardType.scatter => Icons.scatter_plot_outlined,
        DashboardCardType.records => Icons.military_tech_outlined,
        DashboardCardType.heatmap => Icons.grid_on_outlined,
        DashboardCardType.leaderboard => Icons.leaderboard_outlined,
        DashboardCardType.groupGoal => Icons.flag_circle_outlined,
        DashboardCardType.groupTrend => Icons.insights_outlined,
        DashboardCardType.activeMembers => Icons.groups_2_outlined,
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

/// Ana Sayfa serbest ızgarasının sütun sayısı (§2 FAZ 6). Kartlar bu ızgarada
/// 1..[kGridColumns] hücre **genişliğinde** serbestçe boyutlandırılır; yükseklik
/// içeriğe göre otomatiktir (sabit-hücreli tam 2D yerleşim, kartlar responsive
/// olunca — FAZ 6 §2E — gelecek).
const int kGridColumns = 12;

/// Bir Ana Sayfa kartının yapılandırması: tür + ızgara genişliği (hücre, 1..12).
/// Konum = listedeki sıra (akış yerleşimi). Kalıcılık için `"tür:genişlik"`
/// (ör. `"weekly:12"`) biçiminde serileştirilir; eski `"tür:boyut"`/`"tür"`
/// biçimleri de okunur (geriye-uyum).
class DashboardCardConfig {
  const DashboardCardConfig(this.type, {this.width = kGridColumns})
      : assert(width >= 1 && width <= kGridColumns);

  final DashboardCardType type;

  /// Izgara hücresi cinsinden genişlik (1..[kGridColumns]).
  final int width;

  /// Kart içeriği hâlâ S/M/L'ye göre çiziliyor (16 kart). Genişlikten türetilir;
  /// kartlar tam responsive olunca (FAZ 6 §2E) bu köprü kaldırılabilir.
  DashboardCardSize get size => width <= 4
      ? DashboardCardSize.small
      : width >= 9
          ? DashboardCardSize.large
          : DashboardCardSize.medium;

  DashboardCardConfig withWidth(int w) =>
      DashboardCardConfig(type, width: w.clamp(1, kGridColumns));

  /// `"tür:genişlik"` (ör. `"weekly:12"`).
  String encode() => '${type.name}:$width';

  /// `"tür:genişlik"` (yeni), `"tür:boyut"` (eski S/M/L) veya sade `"tür"`
  /// (en eski) çözümler; geçersizse null.
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
    var width = kGridColumns;
    if (parts.length > 1) {
      final p = parts[1];
      final n = int.tryParse(p);
      if (n != null) {
        width = n.clamp(1, kGridColumns);
      } else {
        // Eski S/M/L: küçük = yarım genişlik, orta/büyük = tam genişlik.
        width = switch (p) {
          'small' => kGridColumns ~/ 2,
          _ => kGridColumns,
        };
      }
    }
    return DashboardCardConfig(type, width: width);
  }

  @override
  bool operator ==(Object other) =>
      other is DashboardCardConfig &&
      other.type == type &&
      other.width == width;

  @override
  int get hashCode => Object.hash(type, width);
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
    case DashboardCardType.scatter:
      return ScatterCard(size: size);
    case DashboardCardType.records:
      return RecordsCard(size: size);
    case DashboardCardType.heatmap:
      return HeatmapCard(size: size);
    case DashboardCardType.leaderboard:
      return LeaderboardCard(size: size);
    case DashboardCardType.groupGoal:
      return GroupGoalCard(size: size);
    case DashboardCardType.groupTrend:
      return GroupTrendCard(size: size);
    case DashboardCardType.activeMembers:
      return ActiveMembersCard(size: size);
  }
}
