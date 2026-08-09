import 'package:flutter/material.dart';

import '../charts/series_palette.dart' show chartSeriesColor;

/// Aynı grup üyesine tüm grafiklerde tek, benzersiz renk verir.
///
/// Kimlikler alfabetik sıralanır: katkı sıralaması değişse de veya grafik farklı
/// sırada çizilse de renk eşlemesi korunur. Renkler sabit bir paletten dönmez;
/// mevcut üye sayısına göre renk çemberine eşit aralıkla yayılır. Böylece her
/// büyüklükteki grupta her üye ayrı renk alır ve benzer tonlar aynı yere yığılmaz.
///
/// 🔴 WP-627: açıklık eskiden sabit `0.62` idi ve zemin hesaba **hiç**
/// girmiyordu; üstelik kod yorumu "koyu/açık temada okunur kalır" diye tersini
/// iddia ediyordu. Ölçüm yorumu yalanladı: `nordic_snow` beyaz yüzeyinde 60
/// tonun **33'ü** 3.0 altındaydı, en kötüsü 1.38. Beş kişilik bir grupta bir
/// üyenin çizgisi pratikte yoktu ve kayıp sessizdi — grafiği açan kullanıcı
/// eksik çizgiyi "veri yok" sanıyordu.
///
/// Artık renk [surface]'in fonksiyonu: kural [chartSeriesColor] içinde **tek**
/// yerde durur, `SeriesPalette` ile aynıdır.
///
/// 🔴 [surface] zorunludur. Varsayılan bir zemin koymak tam olarak eski hatayı
/// geri getirirdi: çağıran unutur, renk sessizce yanlış zemine göre çözülür.
Map<String, Color> memberChartColors(
  Iterable<String> memberIds, {
  required Color surface,
}) {
  final ids = memberIds.toSet().toList()..sort();
  if (ids.isEmpty) return const {};

  // 24° ile başlamak, ilk rengi uygulamanın mavi vurgu renginden ayırır.
  final hueStep = 360 / ids.length;
  return Map.unmodifiable({
    for (var i = 0; i < ids.length; i++)
      ids[i]: chartSeriesColor(surface: surface, hue: 24 + hueStep * i),
  });
}
