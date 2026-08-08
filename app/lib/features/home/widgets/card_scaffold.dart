import 'package:flutter/material.dart';

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
                  header,
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
              header,
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
