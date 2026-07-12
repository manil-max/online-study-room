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
    DashboardCardType.scatter =>
      'Her oturum bir nokta (süre × gün, derse göre renkli)',
    DashboardCardType.records =>
      'Toplam, rekor seri, en verimli gün, en çok ders',
    DashboardCardType.heatmap => 'GitHub tarzı çalışma yoğunluğu ısı haritası',
    DashboardCardType.leaderboard => 'Aktif grubun bugünkü sıralaması',
    DashboardCardType.groupGoal =>
      'Grubun günlük hedef ilerlemesi + grup serisi',
    DashboardCardType.groupTrend =>
      'Grubun son günlerdeki toplam çalışma grafiği',
    DashboardCardType.activeMembers =>
      'Grupta o an çalışan üyeler (canlı süreyle)',
  };

  /// Ekleme menüsünde gruplama başlığı.
  String get category => switch (this) {
    DashboardCardType.timer || DashboardCardType.goal => 'Sayaç & Hedef',
    DashboardCardType.today ||
    DashboardCardType.monthly ||
    DashboardCardType.weekdayWeekend ||
    DashboardCardType.records => 'Özetler',
    DashboardCardType.weekly ||
    DashboardCardType.line ||
    DashboardCardType.scatter => 'Grafikler',
    DashboardCardType.hours ||
    DashboardCardType.rhythm ||
    DashboardCardType.heatmap => 'Isı haritaları',
    DashboardCardType.leaderboard ||
    DashboardCardType.groupGoal ||
    DashboardCardType.groupTrend ||
    DashboardCardType.activeMembers => 'Grup',
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

/// Ana Sayfa matrisinin sütun sayısı (§2.2). Yükseklik aşağı doğru sınırsız
/// satır olarak büyür; kartlar `x,y,w,h` hücreleriyle saklanır.
const int kDefaultGridColumns = 6;
const int kMaxGridColumns = 12;
const List<int> kSupportedGridColumns = [6, 8, 12];

/// Eski çağrılar/testler için 6-sütun varsayılanı. Aktif render sütunu artık
/// `dashboardGridColumnsProvider` üzerinden gelir.
const int kGridColumns = kDefaultGridColumns;

const int kDefaultCardRows = 3;
const int _kLegacyGridColumns = 12;
const double _kLegacyNominalRowHeight = 80;

// R3, render katmanını hücre tabanlı yüksekliğe taşıyana kadar eski akış
// ekranını derlenir tutan geçici köprüler.
const double kMinCardHeight = _kLegacyNominalRowHeight;
const double kMaxCardHeight = _kLegacyNominalRowHeight * 7;

/// R3'e kadar eski render'a verilecek nominal yükseklik. Kalıcı veri artık
/// piksel değil, [DashboardCardConfig.h] satırıdır.
double defaultCardHeight(DashboardCardSize size) => switch (size) {
  DashboardCardSize.small => _kLegacyNominalRowHeight * 2,
  DashboardCardSize.medium => _kLegacyNominalRowHeight * 3,
  DashboardCardSize.large => _kLegacyNominalRowHeight * 4,
};

class _DecodedDashboardCard {
  const _DecodedDashboardCard(this.config, {required this.isLegacy});

  final DashboardCardConfig config;
  final bool isLegacy;
}

/// Bir Ana Sayfa kartının 6xN matris yerleşimi. Kalıcı format `"tür:x:y:w:h"`;
/// eski `"tür:genişlik[:yükseklik]"`, `"tür:boyut"` ve sade `"tür"` formatları
/// geriye uyumluluk için okunup yeni formata göçürülür.
class DashboardCardConfig {
  const DashboardCardConfig(
    this.type, {
    this.x = 0,
    this.y = 0,
    this.w = kGridColumns,
    this.h = kDefaultCardRows,
  }) : assert(x >= 0),
       assert(y >= 0),
       assert(w >= 1 && w <= kMaxGridColumns),
       assert(h >= 1),
       assert(x + w <= kMaxGridColumns);

  final DashboardCardType type;
  final int x;
  final int y;
  final int w;
  final int h;

  /// R3'e kadar eski akış ekranını derlenir tutan genişlik köprüsü.
  int get width => w;

  /// Kart içeriği hâlâ S/M/L'ye göre çiziliyor (16 kart). R3'te piksel yerine
  /// hücre boyutu verildiğinde bu köprü sadeleşecek.
  DashboardCardSize get size => sizeForColumns(kDefaultGridColumns);

  DashboardCardSize sizeForColumns(int columns) {
    if (w * 3 <= columns) return DashboardCardSize.small;
    if (w * 6 >= columns * 5) return DashboardCardSize.large;
    return DashboardCardSize.medium;
  }

  /// R3'e kadar eski `SizedBox(height: ...)` kullanan render için hücre satırını
  /// nominal piksele çevirir. Kalıcı veri yine hücre tabanlıdır.
  double get effectiveHeight => h * _kLegacyNominalRowHeight;

  DashboardCardConfig withBounds({
    int? x,
    int? y,
    int? w,
    int? h,
    int columns = kDefaultGridColumns,
  }) {
    return _clamped(
      type,
      x ?? this.x,
      y ?? this.y,
      w ?? this.w,
      h ?? this.h,
      columns: columns,
    );
  }

  DashboardCardConfig withWidth(int width) => withBounds(w: width);

  DashboardCardConfig withHeight(double heightPx) =>
      withBounds(h: rowsForLegacyHeight(heightPx));

  String encode() => '${type.name}:$x:$y:$w:$h';

  static DashboardCardConfig? decode(String raw) => _decodeRaw(raw)?.config;

  static List<DashboardCardConfig> decodeList(
    List<String> rawItems, {
    int columns = kDefaultGridColumns,
  }) {
    final placed = <DashboardCardConfig>[];
    for (final raw in rawItems) {
      final decoded = _decodeRaw(raw, columns: columns);
      if (decoded == null) continue;
      final config = decoded.isLegacy
          ? _firstAvailable(placed, decoded.config, columns: columns)
          : decoded.config;
      placed.add(config);
    }
    return placed;
  }

  static DashboardCardConfig firstAvailable(
    List<DashboardCardConfig> existing,
    DashboardCardType type, {
    int columns = kDefaultGridColumns,
    int? w,
    int h = kDefaultCardRows,
  }) {
    return _firstAvailable(
      existing,
      _clamped(type, 0, 0, w ?? columns ~/ 2, h, columns: columns),
      columns: columns,
    );
  }

  static int rowsForLegacyHeight(double heightPx) {
    final rows = (heightPx / _kLegacyNominalRowHeight).round();
    return rows.clamp(1, 99);
  }

  static DashboardCardConfig _clamped(
    DashboardCardType type,
    int x,
    int y,
    int w,
    int h, {
    int columns = kDefaultGridColumns,
  }) {
    final safeW = w.clamp(1, columns);
    final safeX = x.clamp(0, columns - safeW);
    return DashboardCardConfig(
      type,
      x: safeX,
      y: y < 0 ? 0 : y,
      w: safeW,
      h: h < 1 ? 1 : h,
    );
  }

  static _DecodedDashboardCard? _decodeRaw(
    String raw, {
    int columns = kDefaultGridColumns,
  }) {
    final parts = raw.split(':');
    final type = DashboardCardType.values
        .where((t) => t.name == parts.first)
        .firstOrNull;
    if (type == null) return null;

    if (parts.length == 5) {
      final x = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      final w = int.tryParse(parts[3]);
      final h = int.tryParse(parts[4]);
      if (x != null && y != null && w != null && h != null) {
        return _DecodedDashboardCard(
          _clamped(type, x, y, w, h, columns: columns),
          isLegacy: false,
        );
      }
    }

    return _DecodedDashboardCard(
      _decodeLegacy(type, parts, columns: columns),
      isLegacy: true,
    );
  }

  static DashboardCardConfig _decodeLegacy(
    DashboardCardType type,
    List<String> parts, {
    int columns = kDefaultGridColumns,
  }) {
    var legacyWidth = _kLegacyGridColumns;
    var legacyHeight = defaultCardHeight(DashboardCardSize.large);

    if (parts.length > 1) {
      final numericWidth = int.tryParse(parts[1]);
      if (numericWidth != null) {
        legacyWidth = numericWidth.clamp(1, _kLegacyGridColumns);
        legacyHeight = defaultCardHeight(_legacySizeForWidth(legacyWidth));
      } else {
        final size = switch (parts[1]) {
          'small' => DashboardCardSize.small,
          'medium' => DashboardCardSize.medium,
          'large' => DashboardCardSize.large,
          _ => DashboardCardSize.large,
        };
        legacyWidth = size == DashboardCardSize.small
            ? _kLegacyGridColumns ~/ 2
            : _kLegacyGridColumns;
        legacyHeight = defaultCardHeight(size);
      }
    }

    if (parts.length > 2) {
      final parsedHeight = double.tryParse(parts[2]);
      if (parsedHeight != null) legacyHeight = parsedHeight;
    }

    final w = (legacyWidth * columns / _kLegacyGridColumns).round().clamp(
      1,
      columns,
    );
    final h = rowsForLegacyHeight(legacyHeight);
    return _clamped(type, 0, 0, w, h, columns: columns);
  }

  static DashboardCardSize _legacySizeForWidth(int legacyWidth) {
    if (legacyWidth <= 4) return DashboardCardSize.small;
    if (legacyWidth >= 9) return DashboardCardSize.large;
    return DashboardCardSize.medium;
  }

  static DashboardCardConfig _firstAvailable(
    List<DashboardCardConfig> existing,
    DashboardCardConfig target, {
    required int columns,
  }) {
    for (var y = 0; y < 10000; y++) {
      for (var x = 0; x <= columns - target.w; x++) {
        final candidate = target.withBounds(x: x, y: y, columns: columns);
        if (existing.every((c) => !candidate.overlaps(c))) {
          return candidate;
        }
      }
    }
    final bottom = existing.fold(
      0,
      (max, c) => max > c.y + c.h ? max : c.y + c.h,
    );
    return target.withBounds(x: 0, y: bottom, columns: columns);
  }

  bool overlaps(DashboardCardConfig other) {
    return x < other.x + other.w &&
        x + w > other.x &&
        y < other.y + other.h &&
        y + h > other.y;
  }

  @override
  bool operator ==(Object other) =>
      other is DashboardCardConfig &&
      other.type == type &&
      other.x == x &&
      other.y == y &&
      other.w == w &&
      other.h == h;

  @override
  int get hashCode => Object.hash(type, x, y, w, h);
}

Widget dashboardCardFor(
  DashboardCardType type,
  DashboardCardSize size, {
  double? height,
}) {
  final Widget card = switch (type) {
    DashboardCardType.timer => StudyTimerCard(size: size),
    DashboardCardType.goal => GoalCard(size: size),
    DashboardCardType.today => TodaySummaryCard(size: size),
    DashboardCardType.weekly => WeeklyChartCard(size: size),
    DashboardCardType.line => LineChartCard(size: size),
    DashboardCardType.monthly => PeriodSummaryCard(size: size),
    DashboardCardType.weekdayWeekend => WeekdayWeekendCard(size: size),
    DashboardCardType.hours => HourActivityCard(size: size),
    DashboardCardType.rhythm => RhythmCard(size: size),
    DashboardCardType.scatter => ScatterCard(size: size),
    DashboardCardType.records => RecordsCard(size: size),
    DashboardCardType.heatmap => HeatmapCard(size: size),
    DashboardCardType.leaderboard => LeaderboardCard(size: size),
    DashboardCardType.groupGoal => GroupGoalCard(size: size),
    DashboardCardType.groupTrend => GroupTrendCard(size: size),
    DashboardCardType.activeMembers => ActiveMembersCard(size: size),
  };

  // Sınırlı yükseklik ver (Row'da sınırsız kısıtı engeller). Kullanıcı serbest
  // boyut ayarladıysa onu, yoksa boyuta göre varsayılanı kullan (§2D).
  return SizedBox(height: height ?? defaultCardHeight(size), child: card);
}
