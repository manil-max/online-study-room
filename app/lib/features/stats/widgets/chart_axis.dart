import 'package:online_study_room/l10n/app_localizations.dart';

/// WP-237: grafik eksenleri için ortak yardımcılar (X etiket adımı + Y ölçeği).
///
/// Amaç: yer varken **her günün** numarası görünsün (eskiden sabit her 2–3
/// günde bir yazılıyordu) ve çizgi/çubuk grafiklerinde eksik olan **Y ekseni
/// ölçeği** tek yerden gelsin.

/// [count] etiket için, [maxWidth] piksele sığacak en küçük atlama adımı.
///
/// Her etiket ~[labelWidth] piksel yer kaplar; sığdığı kadar etiketi (ideal:
/// hepsini) gösterir. Genişlik bilinmiyorsa (0/negatif) 1 döner → her etiket.
int axisLabelStep(int count, double maxWidth, {double labelWidth = 22}) {
  if (count <= 1) return 1;
  if (maxWidth <= 0) return 1;
  final capacity = (maxWidth / labelWidth).floor();
  if (capacity >= count) return 1;
  if (capacity <= 1) return count;
  return (count / capacity).ceil();
}

/// Y ekseni için ~4–5 yatay çizgi verecek "yuvarlak" dakika aralığı.
///
/// [maxMinutes] serideki en yüksek değerdir (dakika). Dönen aralık dakika
/// cinsindedir; grid + sol etiket ortak kullanır.
double niceMinuteInterval(double maxMinutes) {
  if (maxMinutes <= 0) return 15;
  const candidates = <double>[
    5,
    10,
    15,
    30,
    60,
    120,
    180,
    240,
    360,
    480,
    600,
    720,
    1440,
  ];
  final target = maxMinutes / 4; // ~4 aralık hedefi
  for (final c in candidates) {
    if (c >= target) return c;
  }
  return candidates.last;
}

/// Eksen boyunca tek birim: en yüksek değer ≥ 90 dk ise saat, yoksa dakika.
bool axisUsesHours(double maxMinutes) => maxMinutes >= 90;

/// Y ekseni ölçeği: üst sınır **her zaman** aralığın tam katıdır.
///
/// 🔴 WP-499 (V58-N04 / rapor T09) kök nedeni: üst sınır ile aralık ayrı ayrı
/// seçiliyordu. Grafik `maxY = veriMaks × 1.2` diyor, aralığı ise ayrıca
/// yuvarlak bir sayıya oturtuyordu — ikisi birbirinin katı değil.
///
/// fl_chart eksen üzerinde `min`den `max`a aralık aralık yürür ve **son adım
/// `max`a denk gelmiyorsa `max` için bir etiket daha üretir**
/// (`axis_chart_helper.dart`, `SideTitles.maxIncluded` varsayılanı `true`).
/// Sonuç: tepede iki etiket, aralarında `maxY - k×aralık` kadar boşluk. Bu
/// fark keyfî küçük olabilir — 51 dk'lık bir seride `maxY = 61.2`, aralık 30,
/// son tık 60 → iki etiket eksenin **%2**'si kadar, yani üst üste.
///
/// Ek olarak ızgara çizgileri `maxIncluded: false` ile çizilir
/// (`axis_chart_painter.dart`), yani fazladan etiketin çizgisi de yoktur:
/// kullanıcı tepede boşlukta duran ikinci bir sayı görür.
///
/// Çözüm sıralamayı tersine çevirmek: **önce aralık, sonra o aralığın üst
/// katına yuvarlanmış üst sınır.** Böylece son adım her zaman `max`a denk gelir
/// ve fazladan etiket hiç üretilmez.
///
/// ⚠️ `maxIncluded: false` tek başına **yanlış** çözümdür (kart tuzağı): üst
/// sınır zaten aralığın katıysa o bayrak tepe etiketini **siler**, ölçek
/// okunamaz hâle gelir. Bu yüzden burada kullanılmıyor.
class MinuteAxis {
  const MinuteAxis({
    required this.maxY,
    required this.interval,
    required this.useHours,
  });

  /// Eksenin üst sınırı (dakika). `interval`in tam katıdır.
  final double maxY;

  /// İki etiket/ızgara çizgisi arası (dakika).
  final double interval;

  /// Etiketler saat mi dakika mı yazıyor.
  final bool useHours;

  /// Eksende çizilecek etiket değerleri (0 hariç — grafik onu çizmiyor).
  ///
  /// fl_chart'ın ürettiği kümenin aynısı: üst sınır aralığın katı olduğu için
  /// listenin sonu tam `maxY`dir ve arada tek bir eşit olmayan adım yoktur.
  List<double> get labelValues => [
    for (var step = 1; step * interval <= maxY + interval / 100000; step++)
      step * interval,
  ];
}

/// [maxMinutes] (serinin en yüksek değeri) için Y ekseni ölçeği.
///
/// [headroom] veri tepesinin üstünde bırakılacak paydır; yuvarlama bundan
/// **sonra** yapılır, o yüzden gerçek pay her zaman biraz daha büyüktür.
MinuteAxis minuteAxis(double maxMinutes, {double headroom = 1.15}) {
  if (maxMinutes <= 0) {
    // Boş seride ölçek yine de okunur olmalı: 0–60 dk, 15 dk aralık.
    return const MinuteAxis(maxY: 60, interval: 15, useHours: false);
  }
  final raw = maxMinutes * headroom;
  final interval = niceMinuteInterval(raw);
  // Kayan nokta payı: `raw` aralığın tam katıysa `ceil` onu bir üst kata
  // atmasın (örn. 119.99999999 → 4 değil 5 aralık).
  final steps = (raw / interval - 1e-9).ceil();
  return MinuteAxis(
    maxY: (steps < 1 ? 1 : steps) * interval,
    interval: interval,
    // Birim serinin kendi tepesine göre seçilir, yuvarlanmış sınıra göre
    // değil: 89 dk'lık bir seri yuvarlama yüzünden "saat"e geçmemeli.
    useHours: axisUsesHours(maxMinutes),
  );
}

/// Y ekseni etiketi. [useHours] true ise saat ("1.5s"), değilse dakika ("30dk").
/// Tam sayıda saatte ondalık gösterilmez.
String chartYLabel(
  double minutes,
  AppLocalizations l10n, {
  required bool useHours,
}) {
  if (useHours) {
    final h = minutes / 60;
    final text = h == h.roundToDouble()
        ? h.toStringAsFixed(0)
        : h.toStringAsFixed(1);
    return '$text${l10n.statsSaatKisa}';
  }
  return '${minutes.round()}${l10n.statsDakikaKisa}';
}
