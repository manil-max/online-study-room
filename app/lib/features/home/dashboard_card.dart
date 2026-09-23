import 'package:online_study_room/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../classroom/widgets/study_timer_card.dart';
import 'widgets/active_members_card.dart';
import 'widgets/dday_card.dart';
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
import 'widgets/tasks_card.dart';
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

  /// WP-188: günlük/haftalık görev listesi.
  tasks,

  /// WP-575: seçilen sınav tarihine kalan gün (cihaz içi, yeni veri yok).
  dday,
}

extension DashboardCardInfo on DashboardCardType {
  String title(BuildContext context) => switch (this) {
    DashboardCardType.timer => AppLocalizations.of(context).homeSayac,
    DashboardCardType.goal => AppLocalizations.of(context).homeGunlukHedef,
    DashboardCardType.today => AppLocalizations.of(context).homeBugunOzeti,
    DashboardCardType.weekly => AppLocalizations.of(context).homeHaftalikGrafik,
    DashboardCardType.line => AppLocalizations.of(context).homeEgilimGrafigi,
    DashboardCardType.monthly => AppLocalizations.of(context).homeDonemOzeti,
    DashboardCardType.weekdayWeekend => AppLocalizations.of(
      context,
    ).homeHaftaIciHaftaSonu,
    DashboardCardType.hours => AppLocalizations.of(context).homeCalismaSaatleri,
    DashboardCardType.rhythm => AppLocalizations.of(context).homeHaftalikRitim,
    DashboardCardType.scatter => AppLocalizations.of(
      context,
    ).homeOturumDagilimi,
    DashboardCardType.records => AppLocalizations.of(context).homeRekorlar,
    DashboardCardType.heatmap => AppLocalizations.of(
      context,
    ).homeCalismaTakvimi,
    DashboardCardType.leaderboard => AppLocalizations.of(
      context,
    ).homeGrupSiralamasi,
    DashboardCardType.groupGoal => AppLocalizations.of(context).homeGrupHedefi,
    DashboardCardType.groupTrend => AppLocalizations.of(
      context,
    ).homeGrupGunlukTrendi,
    DashboardCardType.activeMembers => AppLocalizations.of(
      context,
    ).homeSuAnCalisanlar,
    DashboardCardType.tasks => AppLocalizations.of(context).taskListTitle,
    DashboardCardType.dday => AppLocalizations.of(context).homeSinavGeriSayimi,
  };

  /// Kart seçicideki tek satır: kartın NE gösterdiği. 🔴 WP-932: yedi kartta
  /// başlığın aynısıydı ("Dönem özeti / Dönem özeti").
  String description(BuildContext context) => switch (this) {
    DashboardCardType.timer => AppLocalizations.of(
      context,
    ).homeKronometreGunlukHedefVe,
    DashboardCardType.goal => AppLocalizations.of(
      context,
    ).homeHedefIlerlemesiVeBuyuk,
    DashboardCardType.today => AppLocalizations.of(
      context,
    ).homeBugunkuToplamVeDers,
    DashboardCardType.weekly => AppLocalizations.of(
      context,
    ).homeKartAciklamaHaftalik,
    DashboardCardType.line => AppLocalizations.of(
      context,
    ).homeKartAciklamaEgilim,
    DashboardCardType.monthly => AppLocalizations.of(
      context,
    ).homeKartAciklamaDonem,
    DashboardCardType.weekdayWeekend => AppLocalizations.of(
      context,
    ).homeHaftaIciIleHafta,
    DashboardCardType.hours => AppLocalizations.of(
      context,
    ).homeGununHangiSaatlerindeCalistigin,
    DashboardCardType.rhythm => AppLocalizations.of(
      context,
    ).homeKartAciklamaRitim,
    DashboardCardType.scatter => AppLocalizations.of(
      context,
    ).homeKartAciklamaOturum,
    DashboardCardType.records => AppLocalizations.of(
      context,
    ).homeToplamRekorSeriEn,
    DashboardCardType.heatmap => AppLocalizations.of(
      context,
    ).homeGithubTarziCalismaYogunlugu,
    DashboardCardType.leaderboard => AppLocalizations.of(
      context,
    ).homeAktifGrubunBugunkuSiralamasi,
    DashboardCardType.groupGoal => AppLocalizations.of(
      context,
    ).homeKartAciklamaGrupHedefi,
    DashboardCardType.groupTrend => AppLocalizations.of(
      context,
    ).homeGrubunSonGunlerdekiToplam,
    DashboardCardType.activeMembers => AppLocalizations.of(
      context,
    ).homeKartAciklamaCalisanlar,
    DashboardCardType.tasks => AppLocalizations.of(context).taskListSubtitle,
    DashboardCardType.dday => AppLocalizations.of(
      context,
    ).homeSinavGeriSayimiAciklama,
  };

  /// Ekleme menüsünde gruplama başlığı.
  String category(BuildContext context) => switch (this) {
    DashboardCardType.timer ||
    DashboardCardType.goal ||
    DashboardCardType.tasks =>
      '${AppLocalizations.of(context).homeSayac} & '
          '${AppLocalizations.of(context).homeGunlukHedef}',
    DashboardCardType.today ||
    DashboardCardType.monthly ||
    DashboardCardType.weekdayWeekend ||
    DashboardCardType.records ||
    DashboardCardType.dday => AppLocalizations.of(context).homeOzetler,
    DashboardCardType.weekly ||
    DashboardCardType.line ||
    DashboardCardType.scatter => AppLocalizations.of(context).homeGrafikler,
    DashboardCardType.hours ||
    DashboardCardType.rhythm ||
    DashboardCardType.heatmap => AppLocalizations.of(context).homeIsiHaritalari,
    DashboardCardType.leaderboard ||
    DashboardCardType.groupGoal ||
    DashboardCardType.groupTrend ||
    DashboardCardType.activeMembers => AppLocalizations.of(context).homeGrup,
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
    DashboardCardType.tasks => Icons.checklist_outlined,
    DashboardCardType.dday => Icons.event_outlined,
  };
}

/// Kart boyutu (§3.11). Küçük = yarım genişlik (yan yana 2'li), Orta = tam
/// genişlik, Büyük = tam genişlik + daha çok içerik (uzun grafik/geniş takvim).
enum DashboardCardSize { small, medium, large }

extension DashboardCardSizeInfo on DashboardCardSize {
  String label(BuildContext context) => switch (this) {
    DashboardCardSize.small => AppLocalizations.of(context).homeKucuk,
    DashboardCardSize.medium => AppLocalizations.of(context).homeOrta,
    DashboardCardSize.large => AppLocalizations.of(context).homeBuyuk,
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
/// Serileştirme / legacy decode tabanı (6-sütun formatı). Runtime ızgara
/// WP-186'dan beri sabittir: [kFixedGridColumns] = 32.
const int kDefaultGridColumns = 6;
const int kMaxGridColumns = 32;
const int kFixedGridColumns = 32;
const List<int> kSupportedGridColumns = [32];

/// WP-676 — masaüstü bandında bir pano kartının **boyanan** genişlik tavanı.
///
/// Kaynak: `docs/design/DESKTOP-UI-SPEC.md` §2.3, "Grafik kartı **720** (min
/// 360)" satırı. Pano kartlarının en geniş türü grafik kartıdır; tek sayılık
/// döşeme tavanı (320) ondan daha sıkıdır, yani 720 bu ekranın **en
/// müsamahakâr** tavanı.
///
/// 🔴 ÖLÇÜLDÜ (WP-676, gerçek uygulama, `TargetPlatform.windows`,
/// devicePixelRatio 1, çizilen `Card` kutuları): 1920 ve 2560 px pencerede ana
/// panonun iki kartı da **1440 px** genişliğinde boyanıyordu ve içindeki en
/// geniş metin 717 / 442 px'ti — kart içeriğine göre değil **pencereye** göre
/// boyutlanmıştı. Sahibin "her biri 800 px genişliğinde, içinde tek bir sayı"
/// şikâyetinin ana panodaki karşılığı budur.
///
/// ⚠️ Sütun sayısı (`kMaxGridColumns` = 32) BİLEREK değişmiyor: tavan hücre
/// sayısıyla değil **piksel** ile konuyor, ızgara koordinat uzayı aynı kalıyor.
/// Depoda kayıtlı tuzak (yeni sütun seçeneği eklenip `kMaxGridColumns`
/// yükseltilmeyince runtime assert çökmesi) böylece hiç doğmuyor.
const double kDesktopMaxCardWidthPx = 720;

/// [cell] genişliğindeki bir ızgarada [kDesktopMaxCardWidthPx]'i aşmayan en
/// geniş kart — hücre cinsinden.
///
/// Kart genişliği `w · cell + (w − 1) · gap` olduğu için tavan doğrudan hücreye
/// çevrilir; sayı ızgaranın gerçek ölçüsünden gelir, sabit değildir. 1440 px'lik
/// içerik bandında (SPEC §2.3 ızgara tavanı) sonuç **16**'dır, yani ızgaranın
/// tam yarısı → masaüstünde pano en az iki sütuna açılır.
int desktopMaxCardCells({
  required double cell,
  required double gap,
  required int columns,
}) {
  if (cell <= 0 || !cell.isFinite) return columns;
  final fit = ((kDesktopMaxCardWidthPx + gap) / (cell + gap)).floor();
  return fit.clamp(1, columns);
}

/// Eski çağrılar/testler için 6-sütun varsayılanı. Aktif render sütunu artık
/// `dashboardGridColumnsProvider` üzerinden gelir (her zaman 32).
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

/// 🔴 WP-836 — HER KART TÜRÜNÜN KENDİ VARSAYILAN HÜCRESİ.
///
/// Sahip (gerçek cihaz, v85): *"kartları eklediğinde genelde hepsini elle
/// boyutunu ayarlamak gerekiyor, hep bozuk geliyor"* ve *"sayaç widget'ının
/// uzunluğu artsın, ilk hali az"*.
///
/// **ÖNCEKİ KURAL:** yeni kart, TÜRÜNDEN BAĞIMSIZ olarak
/// [DashboardCardConfig.defaultAddWidth] / [DashboardCardConfig.defaultAddHeight]
/// ile geliyordu (6-sütun 3×3 ölçeği → 32-ızgarada **16×16 hücre**). Dar
/// telefonda (içerik 328 px, hücre 2.5 px, boşluk 8 px; `h` satır =
/// `10.5·h − 8` px) bu **160×160 px**'lik bir kutudur.
///
/// O kutunun kartlara dar geldiği bu depoda zaten ÖLÇÜLMÜŞTÜ —
/// `test/features/home/card_scroll_inventory_test.dart` `_budget` tablosu, dar
/// telefon sütunu: `activeMembers` 98.8 px, `monthly` 56–84 px, `heatmap`
/// 70 px, `goal` 34–50 px kart-İÇİ dikey kaydırma payı üretiyor. Aynı kartların
/// hepsi 32×26 hücrede (265 px) 0'a iniyor. Yani "hep bozuk geliyor" bir
/// izlenim değil, ölçülmüş bir artıktır: kullanıcı her eklediği kartı elle
/// büyütmek zorunda kalıyor.
///
/// **Sayaç ayrıca bir EŞİK meselesi.** `study_timer_card.dart`
/// `kTimerCoreMaxHeight` = 240 px: bunun altındaki hücrede yalnız kartın
/// ÇEKİRDEĞİ (geçen süre + Başlat/Durdur) çizilir; "Bugün" toplamı, büyük saat
/// ve faz satırı gizlenir. Varsayılan düzendeki 21 satır dar telefonda
/// **212.5 px**'tir — yani sayaç ilk açılışta çekirdek modda geliyordu.
/// 28 satır = **286 px** o eşiği aşar ve kart "az" görünmekten çıkar. Bir üst
/// eşik (`kTimerFullMinHeight` = 400 px) KASTEN hedeflenmedi: tam kartın
/// içeriği 328 px genişlikte ~600 px istiyor, 400 px'lik hücre eşiği geçer ama
/// karta yeniden kart-içi kaydırma sokar (WP-662'nin kapattığı kusur).
///
/// ⚠️ Tablo yalnız **YENİ EKLENEN** karta uygulanır. Kullanıcının kaydedilmiş
/// düzeni `DashboardLayoutNotifier.build()` içinde diskteki hâliyle çözülür ve
/// bu tabloya hiç uğramaz — mevcut kullanıcının kartları küçülüp büyümez.
extension DashboardCardDefaultCells on DashboardCardType {
  /// 32 sütunluk ızgara ölçüsünde `w × h` hücre.
  ///
  /// Genişlik iki değerden birini alır: 32 (tam) veya 16 (yarım). Yükseklikler
  /// yukarıdaki envanter ölçümünden türer — kartın içeriğinin dar telefonda
  /// kaydırıcı doğurmadan sığdığı en küçük makul satır.
  ({int w, int h}) get _cells32 => switch (this) {
    // Sayaç: çekirdek eşiğini (240 px) aşan ilk makul boy.
    DashboardCardType.timer => (w: 32, h: 28),
    // Hedef halkası + düzenleme satırı: 32×16'da 50 px taşıyordu.
    DashboardCardType.goal => (w: 32, h: 22),
    // Dört küçük sayı; yarım döşemede ölçülen taşma 0 (envanterde satırı yok).
    // Varsayılan düzendeki kutusuyla da aynı kalsın diye 16×16.
    DashboardCardType.today => (w: 16, h: 16),
    DashboardCardType.weekly => (w: 32, h: 20),
    DashboardCardType.line => (w: 32, h: 20),
    // 32×16'da 56 px taşıyordu.
    DashboardCardType.monthly => (w: 32, h: 24),
    DashboardCardType.weekdayWeekend => (w: 32, h: 18),
    DashboardCardType.hours => (w: 32, h: 18),
    DashboardCardType.rhythm => (w: 32, h: 20),
    DashboardCardType.scatter => (w: 32, h: 18),
    // WP-858: bu boyda rekor kartı artık kart-içi kaydırmasız (dar telefonda
    // 211 px → 0; yoğun karo + sığan kadar kayıt). Önce taşıyordu (WP-836).
    DashboardCardType.records => (w: 32, h: 26),
    // İçerik boyu sabit (~154 px) + başlık; 32×16'da 70 px taşıyordu.
    DashboardCardType.heatmap => (w: 32, h: 24),
    DashboardCardType.leaderboard => (w: 32, h: 22),
    DashboardCardType.groupGoal => (w: 32, h: 18),
    DashboardCardType.groupTrend => (w: 32, h: 18),
    // 32×16'da 98.8 px taşıyordu; 32×26'da 0.
    DashboardCardType.activeMembers => (w: 32, h: 26),
    DashboardCardType.tasks => (w: 32, h: 22),
    DashboardCardType.dday => (w: 16, h: 16),
  };

  /// [_cells32]'yi aktif sütun sayısına ölçekler. Runtime ızgara WP-186'dan
  /// beri sabit 32 olduğu için bu pratikte birebir kopyadır; ölçekleme yalnız
  /// 6-sütun tabanlı eski testleri/çağrıları bozmamak için var.
  ({int w, int h}) defaultCells(int columns) {
    final cells = _cells32;
    return (
      w: (cells.w * columns / kFixedGridColumns).round().clamp(1, columns),
      h: (cells.h * columns / kFixedGridColumns).round().clamp(1, 99),
    );
  }
}

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

  /// Yeni kart varsayılan genişliği: 6-sütun medium yarım (3) ölçeği.
  static int defaultAddWidth(int columns) =>
      (3 * columns / kDefaultGridColumns).round().clamp(1, columns);

  /// Yeni kart varsayılan yüksekliği: 6-sütun medium (3) ölçeği — 32'de 16.
  static int defaultAddHeight(int columns) =>
      (3 * columns / kDefaultGridColumns).round().clamp(1, 99);

  static DashboardCardConfig firstAvailable(
    List<DashboardCardConfig> existing,
    DashboardCardType type, {
    int columns = kDefaultGridColumns,
    int? w,
    int? h,
  }) {
    final safeW = w ?? defaultAddWidth(columns);
    final safeH = h ?? defaultAddHeight(columns);
    return _firstAvailable(
      existing,
      _clamped(type, 0, 0, safeW, safeH, columns: columns),
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
    DashboardCardType.tasks => TasksCard(size: size),
    DashboardCardType.dday => DDayCard(size: size),
  };

  // Sınırlı yükseklik ver (Row'da sınırsız kısıtı engeller). Kullanıcı serbest
  // boyut ayarladıysa onu, yoksa boyuta göre varsayılanı kullan (§2D).
  return SizedBox(height: height ?? defaultCardHeight(size), child: card);
}
