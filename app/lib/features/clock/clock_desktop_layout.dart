import 'package:flutter/material.dart';

import '../../core/desktop/desktop_layout.dart';

/// WP-678 — Saat (Araçlar) sekmesinin masaüstü düzen ilkeleri.
///
/// SPEC: `docs/design/DESKTOP-UI-SPEC.md` §1.2 + §2.2 + §2.3 + §3 A2 + §4.
/// Buradaki hiçbir sayı uydurma değildir; her biri SPEC'ten ya da
/// [DesktopBreakpoints]ten türetilir ve türetme yazılıdır.
///
/// 🔴 ÖLÇÜLEN KUSUR (WP-678 öncesi, gerçek uygulama Windows platformunda
/// çizilerek; ölçüm `test/features/clock/clock_desktop_layout_test.dart`):
///
/// | alt sekme | pencere | içerik | en geniş kart | en geniş etiket–değer |
/// |---|---:|---:|---:|---:|
/// | alarm | 1920 | 1680 | **1720** (içindeki en geniş metin 595) | 641 |
/// | alarm | 2560 | 2320 | **2360** (595) | 855 |
/// | zamanlayıcı | 1920 | 1472 | **1720** (içindeki en geniş metin **180**) | 641 |
/// | zamanlayıcı | 2560 | 2005 | **2360** (180) | 855 |
/// | görevler | 1920 | 1472 | — | **999** ("Aktif" → "Tamamlananlar") |
/// | görevler | 2560 | 2005 | — | **1319** |
///
/// Zamanlayıcı satırı sahibin şikâyetinin birebir kendisidir: 2360 px'lik bir
/// kart, içinde tek bir `15:00` yazıyor — 2180 px ölü alan.
///
/// SPEC §5 tablosu bu ekranı "A4 (saat merkezde, sınır yok)" diye işaretler.
/// **Bu satır bu sekme için yanlıştır** ve bilinçli olarak izlenmedi: sekmede
/// büyük bir saat görseli YOKTUR (`clock_screen.dart` yalnız üç listeye —
/// alarm, zamanlayıcı, görev — açılır). A4'ün gerekçesi "sabit en-boy oranlı,
/// genişledikçe daha iyi görünen tek bir çizim"dir; burada çizim yok, liste
/// var. Bu yüzden §3 **A2 (pano/ızgara)** uygulandı. Sapma raporlandı.

/// Izgara oluğu. SPEC §4: 640 px üstü pencerelerde **24 epx** (Fluent 2 Layout).
const double kClockGridGutter = 24;

/// Tek bir saat bloğunun (alarm kartı, zamanlayıcı kartı, görev bölümü)
/// genişlik tavanı.
///
/// 🔴 Türetildi, seçilmedi. SPEC KURAL 2.2 bir etiket–değer satırının **sert
/// tavanını 600 px** koyar (80 karakter × 7.5 px; WCAG 2.1 SC 1.4.8). Bu
/// ekrandaki kartların iç dolgusu 16 + 16 = 32 px (`timers_screen.dart`
/// `EdgeInsets.all(16)`), yani 600 px'lik bir satırın sığdığı en geniş kart
/// **632 px**'tir. 632, 4'ün katıdır (WinUI ölçek platosu kuralı, SPEC §1.2).
/// Kardeş ekran Gruplar aynı sayıyı aynı türetmeyle kullanıyor
/// (`classroom_screen.dart` `kGroupBlockMaxWidth`); iki ekran arasında ikinci
/// bir dil icat edilmedi.
const double kClockBlockMaxWidth = 632;

/// Komut şeridi (Araçlar ikon şeridi, Görevler sekme çubuğu) genişlik tavanı.
///
/// 🔴 Türetildi. Bu şeritler tek bir yatay `Flex` içinde yan yana duran
/// **etiketlerdir**; en soldaki etiketin sol kenarı ile en sağdakinin sağ
/// kenarı arasındaki mesafe tam olarak SPEC KURAL 2.2'nin ölçtüğü mesafedir.
/// Dolayısıyla tavanı da aynıdır: [DesktopBreakpoints.maxLabelValueWidth].
/// Ölçüm bunu doğruluyordu — 2560 px'te "Alarm" → "Timer" 839 px, "Aktif" →
/// "Tamamlananlar" 1319 px; ikisi de göz sıçramasının satırı kaybettiği
/// mesafe.
const double kClockStripMaxWidth = DesktopBreakpoints.maxLabelValueWidth;

/// Bir saat bloğu ızgarasının sütun sayısı — karar **gerçekte kalan banda**
/// göre verilir, pencere genişliğine göre değil (1920 px'lik pencerede sol
/// şerit ve kenar boşluğu düştükten sonra karar verilecek genişlik 1392 px'tir).
///
/// SPEC §1.2: `large` (1200) iki pane, `xlarge` (1600) üç. Bant
/// [DesktopBreakpoints.maxContentWidth] (1440) ile tavanlandığı için üçüncü
/// sütun bugünkü tavanla hiç açılmaz; merdiven yine de tam yazılır ki tavan bir
/// gün yükselirse kural kendiliğinden doğru davransın.
int clockBlockColumns(double band) {
  if (band >= DesktopBreakpoints.xlarge) return 3;
  if (band >= DesktopBreakpoints.expanded) return 2;
  return 1;
}

/// Sola hizalı, [kClockStripMaxWidth] ile sınırlı komut şeridi kabı.
class ClockCommandStrip extends StatelessWidget {
  const ClockCommandStrip({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: kClockStripMaxWidth),
      child: child,
    ),
  );
}

/// Saat bloklarının akıcı ızgarası (SPEC §3 A2).
///
/// 🔴 `Row` DEĞİL `Wrap`. Sebebi Gruplar ekranında ölçüldü ve burada da geçerli:
/// `Row` yatay bir `RenderFlex` yaratır, komşu kartların içindeki metinler o
/// Flex'in altında **aynı görsel satır** sayılır ve bir kartın etiketiyle
/// ötekinin değeri 1392 px'lik sahte bir etiket–değer satırı üretir.
/// `RenderWrap` bir `RenderFlex` DEĞİLDİR; bu sahte eşleşme yapısal olarak
/// olamaz. Ayrıca sütuna sığmayan blok alt sıraya akar — sabit sütun sayısı
/// taşırmaz (`personal_stats_view` 2×2 hatası tekrarlanmaz).
class ClockBlockGrid extends StatelessWidget {
  const ClockBlockGrid({required this.blocks, super.key});

  final List<Widget> blocks;

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final band = constraints.maxWidth;
        final columns = clockBlockColumns(band).clamp(1, blocks.length);
        final even = (band - kClockGridGutter * (columns - 1)) / columns;
        final width = even < kClockBlockMaxWidth ? even : kClockBlockMaxWidth;
        return Wrap(
          spacing: kClockGridGutter,
          runSpacing: kClockGridGutter,
          children: [
            for (final block in blocks) SizedBox(width: width, child: block),
          ],
        );
      },
    );
  }
}

/// [items]'ı sıra bozmadan [columns] bitişik parçaya böler.
///
/// 🔴 `i % columns` (dönüşümlü) DEĞİL. Tamamlanmış görevler listesi tarihe göre
/// sıralıdır; dönüşümlü dağıtım o sırayı ekranda okunamaz hâle getirirdi.
/// Bitişik parçalama gazete sütunu gibi davranır: her sütun kendi içinde
/// yukarıdan aşağı sıralı kalır. Hiçbir öğe düşmez (SPEC §7: işlev değişmez).
List<List<T>> clockColumnChunks<T>(List<T> items, int columns) {
  if (columns <= 1 || items.length <= 1) return [items];
  final perColumn = (items.length / columns).ceil();
  final out = <List<T>>[];
  for (var start = 0; start < items.length; start += perColumn) {
    final end = start + perColumn;
    out.add(items.sublist(start, end > items.length ? items.length : end));
  }
  return out;
}
