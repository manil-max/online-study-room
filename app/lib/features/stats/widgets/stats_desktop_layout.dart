import 'package:flutter/material.dart';

import '../../../core/desktop/desktop_layout.dart';

/// WP-673 — İstatistik ekranının masaüstü (A2 "pano") düzen ilkeleri.
///
/// SPEC: `docs/design/DESKTOP-UI-SPEC.md` §3 A2 + §2.3 + §4. Buradaki hiçbir
/// sayı uydurma değildir; her biri SPEC'ten ya da `DesktopBreakpoints`ten gelir.
///
/// 🔴 ÖLÇÜLEN KUSUR (WP-673 öncesi, `personal_stats_view.dart:216-256`):
/// dört özet kartı **elle 2×2** diziliyordu — iki ayrı `Row(Expanded, Expanded)`.
/// Sütun sayısı genişliğe hiç bakmıyordu, dolayısıyla 1920 px pencerede her kart
/// ~800 px oluyor ve içinde tek bir `2s` yazıyordu (sahibin 3 numaralı
/// şikâyeti). Buradaki ızgara sütun sayısını **pencere sınıfından**, kart
/// genişliğini **içerik tavanından** alır.

/// [StatsSectionColumns] sutunlarinin key onu: `stats-section-column-0`, `-1`.
const String kStatsSectionColumnKeyPrefix = 'stats-section-column-';

/// SPEC §4: masaüstü ızgara oluğu 24 px (WinUI: >640 px pencerede 24 epx).
const double kStatsGridGutter = 24;

/// SPEC §2.3 "Tek sayılık istatistik döşemesi": maks **320**, min **200**.
const double kStatsTileMaxWidth = DesktopBreakpoints.maxStatTileWidth;
const double kStatsTileMinWidth = 200;

/// SPEC §2.3 "Grafik kartı": maks **720**, min **360**.
const double kStatsChartMaxWidth = DesktopBreakpoints.maxChartCardWidth;

/// SPEC §3 A2 tablosu — tek sayılık döşemenin sütun sayısı.
///
/// | bant | sütun |
/// |---|---|
/// | `compact` 640–1007 | 2 |
/// | `expanded` 1008–1199 | 4 |
/// | `large` 1200–1599 | 4 |
/// | `xlarge` ≥1600 | 6 |
///
/// Karar **pencere** genişliğinden verilir, içerik bandından değil: bant zaten
/// 1440'ta tavanlanır (SPEC §2.3), o yüzden banttan bakan bir eşik `xlarge`
/// basamağını hiç göremezdi.
int statsTileColumns(double windowWidth) =>
    switch (DesktopBreakpoints.windowClass(windowWidth)) {
      DesktopNavigationMode.minimal => 1,
      DesktopNavigationMode.compact => 2,
      DesktopNavigationMode.expanded => 4,
      DesktopNavigationMode.large => 4,
      DesktopNavigationMode.xlarge => 6,
    };

/// SPEC §3 A2 tablosu — grafik kartının sütun sayısı: `large` (1200) ve
/// üstünde 2, altında 1.
int statsChartColumns(double windowWidth) =>
    DesktopBreakpoints.windowClass(windowWidth) ==
            DesktopNavigationMode.large ||
        DesktopBreakpoints.windowClass(windowWidth) ==
            DesktopNavigationMode.xlarge
    ? 2
    : 1;

/// Tek sayılık istatistik döşemelerinin akıcı ızgarası (SPEC §3 A2).
///
/// `Wrap` bilinçli: sütun sayısı sığmazsa satır **kırılır**, `RenderFlex
/// overflow` atmaz. Döşeme genişliği [kStatsTileMaxWidth]'te tavanlanır — bir
/// kartın pencereye göre değil **içeriğine göre** boyutlanması budur.
class StatsTileGrid extends StatelessWidget {
  const StatsTileGrid({required this.tiles, super.key});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final windowWidth = MediaQuery.sizeOf(context).width;
    return LayoutBuilder(
      builder: (context, constraints) {
        final band = constraints.maxWidth;
        final columns = statsTileColumns(windowWidth).clamp(1, tiles.length);
        final raw = columns == 1
            ? band
            : (band - kStatsGridGutter * (columns - 1)) / columns;
        final tileWidth = raw.clamp(kStatsTileMinWidth, kStatsTileMaxWidth);
        return Wrap(
          spacing: kStatsGridGutter,
          runSpacing: kStatsGridGutter,
          children: [
            for (final tile in tiles) SizedBox(width: tileWidth, child: tile),
          ],
        );
      },
    );
  }
}

/// Bağımsız bölümlerin (başlık + kart) 1 ya da 2 sütuna akıtılması (SPEC §3 A2).
///
/// Sütunlar **dönüşümlü** doldurulur (0,2,4… sol; 1,3,5… sağ). Sebebi: kart
/// yükseklikleri farklı; `Wrap` kullanılsaydı her satır en uzun karta göre
/// hizalanır ve aralarda tırtıklı boşluk kalırdı. Hiçbir bölüm gizlenmez,
/// yalnız yeri değişir (SPEC §7: işlev değişmez).
///
/// Satır genişliği `sütun × 720 + oluk` ile tavanlanır ([kStatsChartMaxWidth],
/// SPEC §2.3): 1440'lık bantta sütun başına 708 px düşer, tavanın altında.
class StatsSectionColumns extends StatelessWidget {
  const StatsSectionColumns({
    required this.sections,
    this.spacing = 16,
    super.key,
  });

  final List<Widget> sections;

  /// Aynı sütundaki iki bölüm arası dikey boşluk.
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (sections.isEmpty) return const SizedBox.shrink();
    final windowWidth = MediaQuery.sizeOf(context).width;
    final columns = statsChartColumns(windowWidth).clamp(1, sections.length);
    if (columns <= 1) return _singleColumn(sections);

    final buckets = List.generate(columns, (_) => <Widget>[]);
    for (var i = 0; i < sections.length; i++) {
      buckets[i % columns].add(sections[i]);
    }
    final maxRowWidth =
        columns * kStatsChartMaxWidth + kStatsGridGutter * (columns - 1);
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxRowWidth),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < buckets.length; i++) ...[
              if (i > 0) const SizedBox(width: kStatsGridGutter),
              Expanded(
                // Testler sutunu KEY'den bulur: cizilen kutuyu olcmek icin
                // ozel bir tutamak lazim (kaynakta `Expanded` gormek kanit
                // degil, boyanan genislik kanit).
                key: ValueKey('$kStatsSectionColumnKeyPrefix$i'),
                child: _stack(buckets[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// TEK sutunlu bant (`compact` 640–1007 ve `expanded` 1008–1199).
  ///
  /// 🔴 WP-683 GEDIK 1 — OLCULDU. Bu dal WP-683'e kadar `_stack(sections)`i
  /// CIPLAK donduruyordu: ne `Align`, ne `ConstrainedBox`, hicbir tavan. Ayni
  /// harness, `DesktopContent(1440)` kabuğu, `devicePixelRatio = 1`:
  ///
  /// | pencere | sutun | en genis kart |
  /// |---:|---:|---:|
  /// | 1008 | 1 | **960 px** ← ihlal (tavan 720) |
  /// | 1200 | 2 | 564 px |
  /// | 1920 | 2 | 684 px |
  /// | 2560 | 2 | 684 px |
  ///
  /// Kusur iki kapinin arasindan gecti: WP-673 ve WP-680 yalniz **1920 ve
  /// 2560** ciziyor, ikisi de `columns == 2` bandi. 1008–1199 arasini hicbir
  /// iddia olcmuyordu. Sahibin 3 numarali sikayeti ("dev kart, icinde tek bir
  /// sayi") bu bantta aynen duruyordu.
  ///
  /// Tavan cok sutunlu daldakiyle AYNI sayidir ([kStatsChartMaxWidth], SPEC
  /// §2.3 "Grafik karti"), yeni bir dil icat edilmedi. Sola hizalanir: SPEC
  /// §3 A2 artan yeri ortalamaz, `Align`in `topStart`i A2'nin davranisidir.
  Widget _singleColumn(List<Widget> items) => LayoutBuilder(
    builder: (context, constraints) {
      final band = constraints.maxWidth;
      final width = band < kStatsChartMaxWidth ? band : kStatsChartMaxWidth;
      return Align(
        alignment: AlignmentDirectional.topStart,
        child: SizedBox(
          // Anahtar tavani UYGULAYAN kutunun uzerindedir. `Align`a konulsaydi
          // olculen sey kabin genisligi olurdu (kap her zaman bandi doldurur)
          // ve kapi tavan yokken de yesil yanardi.
          key: const ValueKey('${kStatsSectionColumnKeyPrefix}0'),
          width: width,
          child: _stack(items),
        ),
      );
    },
  );

  Widget _stack(List<Widget> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < items.length; i++) ...[
        if (i > 0) SizedBox(height: spacing),
        items[i],
      ],
    ],
  );
}

/// Başlık + gövde: bir "bölüm". Mobil dalda da kullanılır; başlık ile kart
/// arasındaki 8 px ve başlık tipografisi WP-673 öncesiyle **birebir** aynıdır,
/// yani mobil çıktı değişmez.
class StatsSection extends StatelessWidget {
  const StatsSection({required this.child, this.title, super.key});

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final heading = title;
    if (heading == null) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(heading, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
