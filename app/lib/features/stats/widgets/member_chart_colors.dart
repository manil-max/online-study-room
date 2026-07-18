import 'package:flutter/material.dart';

/// Aynı grup üyesine tüm grafiklerde tek, benzersiz renk verir.
///
/// Kimlikler alfabetik sıralanır: katkı sıralaması değişse de veya grafik farklı
/// sırada çizilse de renk eşlemesi korunur. Renkler sabit bir paletten dönmez;
/// mevcut üye sayısına göre renk çemberine eşit aralıkla yayılır. Böylece her
/// büyüklükteki grupta her üye ayrı renk alır ve benzer tonlar aynı yere yığılmaz.
Map<String, Color> memberChartColors(Iterable<String> memberIds) {
  final ids = memberIds.toSet().toList()..sort();
  if (ids.isEmpty) return const {};

  // 24° ile başlamak, ilk rengi uygulamanın mavi vurgu renginden ayırır.
  // Yüksek saturation + dengeli lightness koyu/açık temada okunur kalır.
  final hueStep = 360 / ids.length;
  return Map.unmodifiable({
    for (var i = 0; i < ids.length; i++)
      ids[i]: HSLColor.fromAHSL(
        1,
        (24 + hueStep * i) % 360,
        0.70,
        0.62,
      ).toColor(),
  });
}
