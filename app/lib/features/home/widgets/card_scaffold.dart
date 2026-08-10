import 'package:flutter/material.dart';

import '../../../core/desktop/desktop_layout.dart';

/// WP-676 — SPEC KURAL 2.2: **etiket–değer satırı kabı doldurmaz.**
///
/// 🔴 ÖLÇÜLDÜ (gerçek uygulama, `TargetPlatform.windows`, çizilen glif
/// kutuları): ana panoda "Bugün özeti" → "0sn" satırı 1920 ve 2560 px
/// pencerede **1408 px**, aradaki boş aralık **1182 px** idi. "Grup hedefi" →
/// "%0" 873 px, "Sıralama" → grup adı 722 px. Üçü de SPEC'in 600 px'lik sert
/// tavanının (80 karakter, WCAG 2.1 SC 1.4.8) çok üstünde.
///
/// Bu yardımcı SPEC'in **hedef** değerini uygular: 496 px
/// ([DesktopBreakpoints.labelValueTargetWidth], Bringhurst 66ch). Satır kabı
/// bundan genişse 496'da bırakılır ve **sola hizalanır** — SPEC §2.2'nin lafzı.
///
/// ⚠️ Mobil dal ellenmez: kural yalnız `large` (≥ 1200 px) pencerede açılır
/// (SPEC §1.2 merdiveni). 390×844'te [child] birebir döner, ağaç değişmez.
Widget cardLabelValueRow(BuildContext context, {required Widget child}) {
  if (MediaQuery.sizeOf(context).width < DesktopBreakpoints.large) return child;
  return Align(
    alignment: AlignmentDirectional.centerStart,
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: DesktopBreakpoints.labelValueTargetWidth,
      ),
      child: child,
    ),
  );
}

/// WP-508 — Ana Sayfa kartlarının ortak kaydırma kuralı.
///
/// İçerik kartın kutusuna **sığıyorsa** dikey sürükleme jesti hiç kabul edilmez
/// (dış sayfa akar); **taşıyorsa** kart kendi içinde kaydırılır.
///
/// 🔴 Varlık sebebi: pano hücresi her karta sabit piksel yükseklik verir
/// (`dashboard_card.dart` → `SizedBox`), kartlar da o sınırlı kutuda koşulsuz
/// kaydırıcı kuruyordu. Flutter'da en içteki `Scrollable` sürüklemeyi gesture
/// arena'da kazanır; içerik zaten sığdığı için hiçbir şey oynamaz ve **dış
/// sayfa da kaymaz** — kullanıcı yalnız stretch overscroll animasyonunu görür.
///
/// ⚠️ Çözüm "kart hiç kaydırmasın" DEĞİL: o zaman taşan içerik kırpılır ve
/// WP-497'de düzeltilen "sığmayan üye tamamen kayboluyor" hatası geri gelir.
class CardOverflowScrollPhysics extends ScrollPhysics {
  const CardOverflowScrollPhysics({super.parent});

  @override
  CardOverflowScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      CardOverflowScrollPhysics(parent: buildParent(ancestor));

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) {
    // Ölçüm yapılmadan jest kabul edilmez; doğru cevabı ilk düzenden sonra
    // `applyNewDimensions` → `setCanDrag` zaten yeniden sorar.
    if (!position.hasContentDimensions || !position.hasPixels) return false;
    // Taşma varsa kart kayar. `pixels` başlangıçta değilse (içerik küçüldü)
    // kullanıcı başa dönebilmeli, yoksa liste kilitli kalır.
    return position.maxScrollExtent > position.minScrollExtent ||
        position.pixels != position.minScrollExtent;
  }
}

/// [CardOverflowScrollPhysics]'in `ListView`/`GridView` gibi kendi kaydırıcısını
/// kuran kart gövdelerine geçilecek örneği.
///
/// Bu sabiti geçmek `physics`i **açıkça** belirlediği için ayrıca zorunludur:
/// `physics`/`primary`/`controller` verilmemiş dikey bir `ScrollView`
/// `AlwaysScrollableScrollPhysics`e düşer (`scroll_view.dart`) ve "taşma yoksa
/// jesti bırak" varsayılan kuralı da devre dışı kalır.
const ScrollPhysics kCardOverflowScrollPhysics = CardOverflowScrollPhysics();

/// [child]'ı yalnız gerçekten taştığında kaydırılabilir yapar; sığdığında
/// sürükleme dış sayfaya gider (bkz. [CardOverflowScrollPhysics]).
///
/// Sınırsız (`isFinite` olmayan) yükseklikte hiç kaydırıcı kurulmamalıdır —
/// viewport sınırsız kısıt alamaz. O kontrol çağıranda kalır çünkü çağıranlar
/// aynı kısıttan başka kararlar da (compact düzen, `Expanded`) veriyor.
Widget cardScrollIfOverflows({
  required Widget child,
  Axis axis = Axis.vertical,
}) => SingleChildScrollView(
  scrollDirection: axis,
  // Dış sayfanın `PrimaryScrollController`'ını devralmasın: aynı controller'a
  // iki pozisyon bağlanır ve kart dış sayfayı sürüklemeye başlar.
  primary: false,
  physics: kCardOverflowScrollPhysics,
  child: child,
);

/// §2E — Kartın kalan (bounded) yüksekliği gövdeyi doldurmaya yetiyorsa `true`
/// döner; yetmiyorsa çağıran kart dikey kaydırmaya düşer, böylece hiçbir en-boy
/// oranında taşma (RenderFlex overflow) olmaz.
///
/// Ana Sayfa ızgarasında her karta `h * satır` piksel bounded yükseklik verilir
/// (`dashboardCardFor` → `SizedBox`), bu yüzden pratikte doldurma yolu kullanılır;
/// çok kısa hücre veya bounded olmayan bağlam (feedback/test) için kaydırma yolu
/// güvenlik ağıdır.
bool cardShouldFill(
  double maxHeight, {
  double minBody = 96,
  double headerReserve = 44,
}) {
  return maxHeight.isFinite && maxHeight >= minBody + headerReserve;
}

/// Ortak kart başlığı (§2E): tek satır + ellipsis. Bir `Row` içinde
/// kullanılırken `Flexible`/`Expanded` ile sarılmalı ki dar hücrede yatay
/// taşma olmasın; bir `Column` çocuğu olarak doğrudan kullanılabilir.
Widget cardTitle(BuildContext context, String text) => Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium,
    );

/// Kart **basligina** konan aksiyon simgesi.
///
/// 🔴 WP-642 varlik sebebi. [CardScaffold]'ta baslik, govdenin **disinda**
/// duran ayri bir cocuktur: govdeye kurulan dokunma hedefi (`InkWell`)
/// basligi KAPSAMAZ. Basliga ciplak bir [Icon] konuldugunda kullanici onu
/// dugme sanar, basar, hicbir sey olmaz -- proje sahibi bunu cihazda bildirdi
/// (D-Day kartinin kalem simgesi). Kart testleri govdeye dokundugu icin kusuru
/// hicbir kapi gormedi.
///
/// Bu yardimci [onPressed]'i **zorunlu** kilar: artik basliga aksiyon koymanin
/// tiklanamayan bir yolu yok. Ciplak [Icon] yazmak hala mumkun ama o zaman da
/// aksiyon gibi gorunmemesi cagiranin sorumlulugudur.
///
/// 🔴 Dokunma hedefi 40x24'e **olculerek** daraltildi, tahminle degil. Pano
/// hucresi karta sabit piksel yukseklik verir; baslikta buyuyen her piksel
/// govdeden calinir. Material'in 48 px varsayilani basligi 24.5 px'den 48 px'e
/// sisirirdi. Ara deger de yetmiyor: 32x32 ile `dday_multi_exam` taşma testi
/// kucuk kartta **7.47 px** ve **10.94 px** ile kirmizi dustu (uc kayit, iki
/// yerlesim). Basligin dogal yuksekligi ~24.5 px oldugu icin 24 px hedef
/// yuksekligi yerlesimi hic degistirmez; genislik 40 px serbesttir cunku
/// basligi `Expanded` doldurur.
///
/// Bu 48 px'lik Material tavsiyesinin altindadir. Kabul edilebilir olmasinin
/// sebebi simgenin **tek** dokunma hedefi olmamasi: kart govdesi de ayni
/// pencereyi acar. Simge kesfedilebilirlik, govde ise buyuk hedeftir.
Widget cardHeaderAction({
  required IconData icon,
  required VoidCallback onPressed,
  required String tooltip,
  Key? key,
  double iconSize = 16,
}) => IconButton(
      key: key,
      icon: Icon(icon, size: iconSize),
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      // 🔴 `constraints` TEK BASINA YETMEZ -- olculdu. [MaterialTapTargetSize]
      // varsayilani `padded`, butonun etrafina kendi 48 px'lik kutusunu ekler
      // ve `constraints` ne verilirse verilsin baslik ayni miktarda buyur:
      // 32x32 ve 32x24 denemeleri kucuk kartta **ayni** 7.47 / 10.94 px taşmayi
      // uretti. Yerlesimi geri getiren sey `shrinkWrap`tir.
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      // 🔴 `visualDensity: compact` BURADA YOK, kasten. Varken `constraints`i
      // (-8,-8) daha kucultuyordu: **olculdu**, 32x24 istenirken gercekte
      // 24x16 cikti -- yani dokunma hedefinin yuksekligi 16 px'lik simgenin
      // kendisiyle ayniydi. Olculmeseydi "dugme yaptik" denip 16 px'lik bir
      // hedef gonderilecekti. Verilen `constraints` ile GERCEK boyut ayni sey
      // degil; testi de gercek boyutu olcer.
      constraints: const BoxConstraints.tightFor(width: 40, height: 24),
    );

/// Ortak Ana Sayfa kart iskeleti (§2E): sabit yükseklikli [header] + kalan alanı
/// dolduran gövde. Gövdeye çözülmüş piksel yüksekliği ([bodyBuilder]'ın ikinci
/// argümanı) verilir; grafik kartları bunu doğrudan grafik yüksekliği olarak
/// kullanır. Böylece kart büyütülünce grafik/gövde de büyür, küçültülünce küçülür;
/// çok kısaldığında ise tüm kart kaydırılarak taşma engellenir.
class CardScaffold extends StatelessWidget {
  const CardScaffold({
    super.key,
    required this.header,
    required this.bodyBuilder,
    this.minBodyHeight = 96,
    this.fallbackBodyHeight = 160,
    this.padding = const EdgeInsets.all(16),
    this.headerGap = 12,
  });

  final Widget header;

  /// Gövde kurucusu; kendisine kullanılabilir gövde yüksekliği geçilir
  /// (doldurma modunda gerçek kalan yükseklik, kaydırma modunda
  /// [fallbackBodyHeight]).
  final Widget Function(BuildContext context, double bodyHeight) bodyBuilder;

  final double minBodyHeight;
  final double fallbackBodyHeight;
  final EdgeInsets padding;
  final double headerGap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (cardShouldFill(constraints.maxHeight, minBody: minBodyHeight)) {
            return Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  cardLabelValueRow(context, child: header),
                  SizedBox(height: headerGap),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, bodyConstraints) =>
                          bodyBuilder(context, bodyConstraints.maxHeight),
                    ),
                  ),
                ],
              ),
            );
          }

          // WP-172: Sınırsız yükseklik (Gruplar ListView) → iç kaydırma YOK;
          // ebeveyn scroll eder. Sonlu ama kısa hücre (Home ızgara) → kart içi kaydırma.
          final unbounded = !constraints.maxHeight.isFinite;
          final column = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              cardLabelValueRow(context, child: header),
              SizedBox(height: headerGap),
              bodyBuilder(context, fallbackBodyHeight),
            ],
          );
          return Padding(
            padding: padding,
            child: unbounded
                ? column
                : cardScrollIfOverflows(child: column),
          );
        },
      ),
    );
  }
}
