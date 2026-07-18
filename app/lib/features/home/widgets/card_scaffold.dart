import 'package:flutter/material.dart';

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
                : SingleChildScrollView(child: column),
          );
        },
      ),
    );
  }
}
